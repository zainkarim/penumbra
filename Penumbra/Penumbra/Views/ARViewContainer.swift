//
//  ARViewContainer.swift
//  Penumbra
//
//  Created by Zain Karim on 3/28/26.
//

import SwiftUI
import RealityKit

struct ARViewContainer: UIViewRepresentable {

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        context.coordinator.sessionManager = ARSessionManager(arView: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator {
        var sessionManager: ARSessionManager?
    }
}
