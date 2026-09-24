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
    print(ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth))
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
