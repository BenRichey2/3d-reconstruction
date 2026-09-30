//
//  ContentView.swift
//  3D Reconstruction
//
//  Created by Ben Richey on 9/17/26.
//

import SwiftUI
import RealityKit
import ARKit
import simd

struct ARViewContainer: UIViewRepresentable {
  func makeCoordinator() -> Coordinator {
    Coordinator()
  }
  class Coordinator: NSObject, ARSessionDelegate {
    var lastPrintTime: TimeInterval = 0
    var savedOne = false

    func serializeCloud(cloud: [SIMD3<Float>]) -> String {
      var strCloud = "ply\nformat ascii 1.0\n"
      strCloud += "element vertex \(cloud.count)\n"
      strCloud += "property float x\n"
      strCloud += "property float y\n"
      strCloud += "property float z\n"
      strCloud += "end_header"
      for point in cloud {
        strCloud += "\n\(point.x) \(point.y) \(point.z)"
      }
      return strCloud
    }

    func saveCloud(cloud: [SIMD3<Float>]) {
      guard let docDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
          print("ERROR: failed to get documents directory")
          return
      }
      let fileURL = docDirectory.appendingPathComponent("cloud.ply")

      do {
          try serializeCloud(cloud: cloud).write(to: fileURL, atomically: true, encoding: .ascii)
      } catch {
        print("Failed to save file: \(error)")
      }
    }

    func getCloud(depthBuf: CVPixelBuffer, intrinsics: simd_float3x3, width: Int, height: Int, rgbWidth: Int) -> [SIMD3<Float>] {

      let factor = Float(rgbWidth) / Float(width)
      let fx = intrinsics[0,0] / factor
      let fy = intrinsics[1,1] / factor
      let cx = intrinsics[2,0] / factor
      let cy = intrinsics[2,1] / factor

      var cloud: [SIMD3<Float>] = []

      let lockFlags = CVPixelBufferLockFlags.readOnly
      let status = CVPixelBufferLockBaseAddress(depthBuf, lockFlags)
      guard status == kCVReturnSuccess else {
        print("Failed to lock pixel buffer base address")
        return cloud
      }
      defer {
        CVPixelBufferUnlockBaseAddress(depthBuf, lockFlags)
      }
      guard let baseAddress = CVPixelBufferGetBaseAddress(depthBuf) else {
        print("Could not get base address")
        return cloud
      }
      let floatsPerRow = CVPixelBufferGetBytesPerRow(depthBuf) / MemoryLayout<Float32>.stride
      let byteBuf = baseAddress.assumingMemoryBound(to: Float32.self)
      for v in 0..<height {
        for u in 0..<width {
          let pixelIdx = (v * floatsPerRow) + u
          let depth = byteBuf[pixelIdx]
          if depth <= 0 || depth.isNaN {
            continue
          }
          let x = (Float(u) - cx) * depth / fx
          let y = (Float(v) - cy) * depth / fy
          let point = SIMD3<Float>(x: x, y: y, z: depth)
          cloud.append(point)
        }
      }
      return cloud
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
      guard frame.timestamp - lastPrintTime > 1.0 else { return }
      if let depthData = frame.sceneDepth {
        let buf: CVPixelBuffer = depthData.depthMap
        let width = CVPixelBufferGetWidth(buf)
        let height = CVPixelBufferGetHeight(buf)
        print("Depth map: \(width)x\(height)")
        let img: CVPixelBuffer = frame.capturedImage
        let imWidth = CVPixelBufferGetWidth(img)
        let imHeight = CVPixelBufferGetHeight(img)
        print("RGB image: \(imWidth)x\(imHeight)")
        let cloud: [SIMD3<Float>] = getCloud(depthBuf: buf, intrinsics: frame.camera.intrinsics, width: width, height: height, rgbWidth: imWidth)
        let numPoints = cloud.count
        print("Points in depth cloud: \(numPoints)")
        var lo = [Float.infinity, Float.infinity, Float.infinity]
        var hi = [-Float.infinity, -Float.infinity, -Float.infinity]
        for point in cloud {
          if point.x < lo[0] {
            lo[0] = point.x
          }
          if point.x > hi[0] {
            hi[0] = point.x
          }
          if point.y < lo[1] {
            lo[1] = point.y
          }
          if point.y > hi[1] {
            hi[1] = point.y
          }
          if point.z < lo[2] {
            lo[2] = point.z
          }
          if point.z > hi[2] {
            hi[2] = point.z
          }
        }
        print("Min XYZ: \(lo)")
        print("Max XYZ: \(hi)")
        if frame.camera.trackingState == .normal && !savedOne {
          saveCloud(cloud: cloud)
          savedOne = true
        }
      } else {
        print("SceneDepth is nil")
      }
      lastPrintTime = frame.timestamp
      print("Intrinsics:")
      print(frame.camera.intrinsics)
      print("Transform:")
      print(frame.camera.transform)
      print("Timestamp:")
      print(frame.timestamp)
      print("Tracking state:")
      print(frame.camera.trackingState)
    }
  }
  func makeUIView(context: Context) -> ARView {
    let arView = ARView(frame: .zero)
    arView.session.delegate = context.coordinator
    let config = ARWorldTrackingConfiguration()
    if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
      config.frameSemantics.insert(.sceneDepth)
    }
    arView.session.run(config)
    return arView
  }
  func updateUIView(_ uiView: ARView, context: Context) {}
}

struct ContentView: View {
    var body: some View {
      ARViewContainer().ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
