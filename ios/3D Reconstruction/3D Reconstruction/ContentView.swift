//
//  ContentView.swift
//  3D Reconstruction
//
//  Created by Ben Richey on 9/17/26.
//

import Foundation
import SwiftUI
import RealityKit
import ARKit
import simd

var buttonPressed = false

struct ARViewContainer: UIViewRepresentable {

  func makeCoordinator() -> Coordinator {
    Coordinator()
  }

  class Coordinator: NSObject, ARSessionDelegate {

    func serializeCloud(cloud: [SIMD3<Float>]) -> String {
      var strCloud = "ply\nformat ascii 1.0\n"
      strCloud += "element vertex \(cloud.count)\n"
      strCloud += "property float x\n"
      strCloud += "property float y\n"
      strCloud += "property float z\n"
      strCloud += "end_header\n"
      for point in cloud {
        strCloud += "\(point.x) \(point.y) \(point.z)\n"
      }
      return strCloud
    }

    func saveCloud(cloud: [SIMD3<Float>]) -> Bool {
      guard let docDirectory = FileManager.default.urls(
        for: .documentDirectory, in: .userDomainMask
      ).first else {
          print("ERROR: failed to get documents directory")
          return false
      }
      let formatter = DateFormatter()
      formatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
      let dateStr = formatter.string(from: Date())
      let fileURL = docDirectory.appendingPathComponent(
        "cloud_\(dateStr).ply"
      )

      do {
        try serializeCloud(cloud: cloud)
          .write(
            to: fileURL,
            atomically: true,
            encoding: .ascii
          )
      } catch {
        print("Failed to save file: \(error)")
        return false
      }
      return true
    }

    func getCloud(
      depthBuf: CVPixelBuffer,
      intrinsics: simd_float3x3,
      width: Int,
      height: Int,
      rgbWidth: Int
    ) -> [SIMD3<Float>] {

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
      guard let baseAddress = CVPixelBufferGetBaseAddress(
        depthBuf
      ) else {
        print("Could not get base address")
        return cloud
      }
      let floatsPerRow = CVPixelBufferGetBytesPerRow(
        depthBuf
      ) / MemoryLayout<Float32>.stride
      let byteBuf = baseAddress.assumingMemoryBound(
        to: Float32.self
      )
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
      guard frame.camera.trackingState == .normal
        && buttonPressed else { return }
      if let depthData = frame.sceneDepth {
        buttonPressed = false
        let buf: CVPixelBuffer = depthData.depthMap
        let width = CVPixelBufferGetWidth(buf)
        let height = CVPixelBufferGetHeight(buf)
        let img: CVPixelBuffer = frame.capturedImage
        let imWidth = CVPixelBufferGetWidth(img)
        let cloud: [SIMD3<Float>] = getCloud(
          depthBuf: buf,
          intrinsics: frame.camera.intrinsics,
          width: width,
          height: height,
          rgbWidth: imWidth
        )
        if saveCloud(cloud: cloud) {
          print("Saved cloud with \(cloud.count) points")
        }
      } else {
        print("SceneDepth is nil")
      }
    }
  }

  func makeUIView(context: Context) -> ARView {
    let arView = ARView(frame: .zero)
    arView.session.delegate = context.coordinator
    let config = ARWorldTrackingConfiguration()
    if ARWorldTrackingConfiguration.supportsFrameSemantics(
      .sceneDepth
    ) {
      config.frameSemantics.insert(.sceneDepth)
    }
    arView.session.run(config)
    return arView
  }

  func updateUIView(_ uiView: ARView, context: Context) {}
}

struct ContentView: View {
    var body: some View {
      ARViewContainer()
        .ignoresSafeArea()
        .overlay(
          Button("Save .ply") {
            buttonPressed = true
          }
          .buttonStyle(.borderedProminent)
          .padding(.bottom, 30)
          , alignment: .bottom
        )
    }
}

#Preview {
    ContentView()
}
