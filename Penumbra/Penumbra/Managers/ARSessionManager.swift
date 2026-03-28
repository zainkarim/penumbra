//
//  ARSessionManager.swift
//  Penumbra
//
//  Created by Zain Karim on 3/28/26.
//

import ARKit
import RealityKit
import Observation

@Observable
@MainActor
final class ARSessionManager: NSObject {

    private(set) var detectedPlaneCount: Int = 0

    private let arView: ARView

    init(arView: ARView) {
        self.arView = arView
        super.init()
        configureSession()
    }

    // MARK: - Session Configuration

    private func configureSession() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.delegate = self
        arView.session.run(config)
    }
}

// MARK: - ARSessionDelegate

extension ARSessionManager: ARSessionDelegate {

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        Task { @MainActor in
            for anchor in anchors {
                guard let plane = anchor as? ARPlaneAnchor else { continue }
                detectedPlaneCount += 1
                addDebugPlane(for: plane)
            }
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        Task { @MainActor in
            for anchor in anchors {
                guard let plane = anchor as? ARPlaneAnchor else { continue }
                updateDebugPlane(for: plane)
            }
        }
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        Task { @MainActor in
            for anchor in anchors {
                guard let plane = anchor as? ARPlaneAnchor else { continue }
                removeDebugPlane(for: plane)
                detectedPlaneCount = max(0, detectedPlaneCount - 1)
            }
        }
    }

    // MARK: - Debug Plane Visualization

    @MainActor
    private func addDebugPlane(for anchor: ARPlaneAnchor) {
        let anchorEntity = AnchorEntity(anchor: anchor)
        anchorEntity.name = debugAnchorName(for: anchor)

        let extent = anchor.planeExtent
        let mesh = MeshResource.generatePlane(width: extent.width, depth: extent.height)
        var material = SimpleMaterial()
        material.color = .init(tint: UIColor.systemBlue.withAlphaComponent(0.3), texture: nil)
        material.metallic = .float(0)
        material.roughness = .float(1)

        let planeEntity = ModelEntity(mesh: mesh, materials: [material])
        anchorEntity.addChild(planeEntity)
        arView.scene.addAnchor(anchorEntity)
    }

    @MainActor
    private func updateDebugPlane(for anchor: ARPlaneAnchor) {
        let name = debugAnchorName(for: anchor)
        guard let anchorEntity = arView.scene.anchors.first(where: { $0.name == name }),
              let planeEntity = anchorEntity.children.first as? ModelEntity else { return }

        let extent = anchor.planeExtent
        planeEntity.model?.mesh = MeshResource.generatePlane(width: extent.width, depth: extent.height)
    }

    @MainActor
    private func removeDebugPlane(for anchor: ARPlaneAnchor) {
        let name = debugAnchorName(for: anchor)
        if let anchorEntity = arView.scene.anchors.first(where: { $0.name == name }) {
            arView.scene.removeAnchor(anchorEntity)
        }
    }

    private func debugAnchorName(for anchor: ARPlaneAnchor) -> String {
        "debugPlane_\(anchor.identifier.uuidString)"
    }
}
