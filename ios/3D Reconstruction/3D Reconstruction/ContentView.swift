//
//  ContentView.swift
//  3D Reconstruction
//
//  Created by Ben Richey on 9/17/26.
//

import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
  func makeCoordinator() -> Coordinator {
    Coordinator()
  }
  class Coordinator: NSObject, ARSessionDelegate {
    var lastPrintTime: TimeInterval = 0
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
        let lockFlags = CVPixelBufferLockFlags.readOnly
        let status = CVPixelBufferLockBaseAddress(buf, lockFlags)
        guard status == kCVReturnSuccess else {
          print("Failed to lock pixel buffer base address")
          return
        }
        defer {
          CVPixelBufferUnlockBaseAddress(buf, lockFlags)
        }
        guard let baseAddress = CVPixelBufferGetBaseAddress(buf) else {
          print("Could not get base address")
          return
        }
        let floatsPerRow = CVPixelBufferGetBytesPerRow(buf) / MemoryLayout<Float32>.stride
        let byteBuf = baseAddress.assumingMemoryBound(to: Float32.self)
        let pixelIdx = (96 * floatsPerRow) + 128
        let dist = byteBuf[pixelIdx]
        print("Distance from center pixel: \(dist)")
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
