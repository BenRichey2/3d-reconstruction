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

@Observable class ScanState {
  var isScanning = false
  var scanStatus = "Begin Scan"
  var points: [SIMD3<Float>] = []
  var numKeyFrames = 0
}

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

struct ARViewContainer: UIViewRepresentable {

  var scanState: ScanState

  func makeCoordinator() -> Coordinator {
    Coordinator(state: scanState)
  }

  class Coordinator: NSObject, ARSessionDelegate {

      init(state: ScanState) {
          self.scanState = state
          super.init()
    }

    var scanState: ScanState
    var lastKeyFrameTransform: simd_float4x4? = nil
    let transThresh = Float(0.05) // 5 cm
    let rotThresh = Float(10.0)     // 10 degrees


    func getCloud(
      depthBuf: CVPixelBuffer,
      confBuf: CVPixelBuffer,
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
      let status2 = CVPixelBufferLockBaseAddress(confBuf, lockFlags)
      guard status == kCVReturnSuccess && status2 == kCVReturnSuccess else {
        print("Failed to lock pixel/confidence map buffer base address")
        return cloud
      }
      defer {
        CVPixelBufferUnlockBaseAddress(depthBuf, lockFlags)
        CVPixelBufferUnlockBaseAddress(confBuf, lockFlags)
      }
      guard let baseAddress = CVPixelBufferGetBaseAddress(
        depthBuf
      ) else {
        print("Could not get base address for depth pixels")
        return cloud
      }
      guard let baseConfAddress = CVPixelBufferGetBaseAddress(
        confBuf
      ) else {
        print("Could not get base address for confidence map")
        return cloud
      }
      let floatsPerRow = CVPixelBufferGetBytesPerRow(
        depthBuf
      ) / MemoryLayout<Float32>.stride
      let byteBuf = baseAddress.assumingMemoryBound(
        to: Float32.self
      )
      let uint8sPerRow = CVPixelBufferGetBytesPerRow(
        confBuf
      ) / MemoryLayout<UInt8>.stride
      let byteConfBuf = baseConfAddress.assumingMemoryBound(
        to: UInt8.self
      )
      for v in 0..<height {
        for u in 0..<width {
          let confIdx = (v * uint8sPerRow) + u
          let conf = byteConfBuf[confIdx]
          if conf != UInt8(2) {
            continue
          }
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

    func cameraToWorldCoord(
      cloud: [SIMD3<Float>],
      transform: simd_float4x4
    ) -> [SIMD3<Float>] {
      var worldCloud: [SIMD3<Float>] = []
      for point in cloud {
        let res = transform * SIMD4<Float>(x: point.x, y: -point.y, z: -point.z, w: 1)
        worldCloud.append(SIMD3<Float>(x: res.x, y: res.y, z: res.z))
      }
      return worldCloud
    }

    func isKeyFrame(transform: simd_float4x4) -> Bool {
      if lastKeyFrameTransform == nil {
        lastKeyFrameTransform = transform
        return false
      }
      if let lastTransform = lastKeyFrameTransform {
        // Get euclidean distance from last frame to current frame translation
        let lastTrans = lastTransform[3]
        let currentTrans = transform[3]
        let xDist = pow(lastTrans.x - currentTrans.x, 2)
        let yDist = pow(lastTrans.y - currentTrans.y, 2)
        let zDist = pow(lastTrans.z - currentTrans.z, 2)
        let transDist = (xDist + yDist + zDist).squareRoot()
        if transDist >= transThresh {
          lastKeyFrameTransform = transform
          return true
        }
        // Get rotational difference from last frame to current frame orientation
        let lastQuat = simd_quaternion(lastTransform)
        let currentQuat = simd_quaternion(transform)
        let lastQn = lastQuat / simd_length(lastQuat)
        let currentQn = currentQuat / simd_length(currentQuat)
        let dot = simd_dot(lastQn, currentQn)
        let angle = 2.0 * acos(min(1, abs(dot))) * 180.0 / .pi
        if angle > rotThresh {
          lastKeyFrameTransform = transform
          return true
        }
      }
      return false
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
      guard frame.camera.trackingState == .normal
        && scanState.isScanning else { return }
      if let depthData = frame.sceneDepth {
        if isKeyFrame(transform: frame.camera.transform) {
          scanState.numKeyFrames += 1
          let buf: CVPixelBuffer = depthData.depthMap
          let width = CVPixelBufferGetWidth(buf)
          let height = CVPixelBufferGetHeight(buf)
          let img: CVPixelBuffer = frame.capturedImage
          let imWidth = CVPixelBufferGetWidth(img)
          if let confBuf: CVPixelBuffer = depthData.confidenceMap {
            let cloud: [SIMD3<Float>] = getCloud(
              depthBuf: buf,
              confBuf: confBuf,
              intrinsics: frame.camera.intrinsics,
              width: width,
              height: height,
              rgbWidth: imWidth
            )
            scanState.points = scanState.points + cameraToWorldCoord(
              cloud: cloud,
              transform: frame.camera.transform
            )
            print("Point cloud has \(scanState.points.count) points and \(scanState.numKeyFrames) key frames.")
          }
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
    var state = ScanState()
    var body: some View {
      ARViewContainer(scanState: state)
        .ignoresSafeArea()
        .overlay(
          Button(state.scanStatus) {
            state.isScanning = !state.isScanning
            if state.isScanning {
              state.scanStatus = "End Scan"
            } else {
              state.scanStatus = "Begin Scan"
              if saveCloud(cloud: state.points) {
                print("Saved cloud with \(state.points.count) points")
              }
            }
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
