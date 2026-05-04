//
//  SceneManager.swift
//  Penumbra
//
//  Created by Zain Karim on 4/3/26.
//

import ARKit
import RealityKit
import UIKit
import Observation

@Observable
@MainActor
final class SceneManager {

    private(set) var placedObjects: [ModelEntity] = []

    weak var arView: ARView?
    var shadowRenderer: ShadowRenderer?
    weak var hudState: HUDState?

    private var currentAnchor: AnchorEntity?
    private let baseRadius: Float = 0.05
    private var pinchBaseScale: Float = 1.0
    private var debugArrowAnchor: AnchorEntity?

    // MARK: - Tap Handling

    func handleTap(_ gesture: UITapGestureRecognizer) {
        guard let arView else { return }

        let touchLocation = gesture.location(in: arView)
        let results = arView.raycast(
            from: touchLocation,
            allowing: .existingPlaneGeometry,
            alignment: .horizontal
        )

        guard let hit = results.first else { return }
        placeObject(at: hit)
    }

    // MARK: - Pinch Handling

    func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        guard let sphere = placedObjects.first else { return }

        switch gesture.state {
        case .began:
            pinchBaseScale = sphere.scale.x
        case .changed:
            let newScale = max(1.0, min(4.0, pinchBaseScale * Float(gesture.scale)))
            sphere.scale = SIMD3<Float>(repeating: newScale)
            sphere.position.y = baseRadius * newScale
            shadowRenderer?.updateScale(newScale)
        default:
            break
        }
    }

    // MARK: - Object Placement

    private func placeObject(at hit: ARRaycastResult) {
        guard let arView else { return }

        // Remove existing sphere and its shadows
        if let old = currentAnchor {
            arView.scene.removeAnchor(old)
            shadowRenderer?.removeAll()
            placedObjects.removeAll()
        }

        let mesh = MeshResource.generateSphere(radius: baseRadius)
        let sphere = ModelEntity(mesh: mesh, materials: [makeMaterial(for: hudState?.selectedMaterial ?? .matte)])
        sphere.position.y = baseRadius
        sphere.components[GroundingShadowComponent.self] = GroundingShadowComponent(castsShadow: false)

        let hitPos = SIMD3<Float>(
            hit.worldTransform.columns.3.x,
            hit.worldTransform.columns.3.y,
            hit.worldTransform.columns.3.z
        )
        let anchorEntity = AnchorEntity(world: hitPos)
        anchorEntity.addChild(sphere)
        arView.scene.addAnchor(anchorEntity)

        currentAnchor = anchorEntity
        placedObjects.append(sphere)
        hudState?.hasPlacedObject = true

        try? shadowRenderer?.attachShadow(to: sphere, on: anchorEntity, sphereRadius: baseRadius)
    }

    // MARK: - Material

    func applyMaterial(_ option: MaterialOption) {
        for object in placedObjects {
            guard var comp = object.model else { continue }
            comp.materials = [makeMaterial(for: option)]
            object.model = comp
        }
    }

    private func makeMaterial(for option: MaterialOption) -> any Material {
        switch option {
        case .matte:
            var mat = SimpleMaterial()
            mat.color = .init(tint: UIColor(white: 0.9, alpha: 1.0), texture: nil)
            mat.metallic = .float(0)
            mat.roughness = .float(1)
            return mat
        case .reflective:
            var mat = PhysicallyBasedMaterial()
            mat.baseColor = .init(tint: .white)
            mat.metallic = .init(floatLiteral: 1.0)
            mat.roughness = .init(floatLiteral: 0.02)
            return mat
        case .red:
            var mat = SimpleMaterial()
            mat.color = .init(tint: UIColor(red: 0.85, green: 0.15, blue: 0.15, alpha: 1.0), texture: nil)
            mat.metallic = .float(0)
            mat.roughness = .float(0.6)
            return mat
        case .blue:
            var mat = SimpleMaterial()
            mat.color = .init(tint: UIColor(red: 0.15, green: 0.35, blue: 0.9, alpha: 1.0), texture: nil)
            mat.metallic = .float(0)
            mat.roughness = .float(0.6)
            return mat
        case .green:
            var mat = SimpleMaterial()
            mat.color = .init(tint: UIColor(red: 0.15, green: 0.75, blue: 0.3, alpha: 1.0), texture: nil)
            mat.metallic = .float(0)
            mat.roughness = .float(0.6)
            return mat
        case .yellow:
            var mat = SimpleMaterial()
            mat.color = .init(tint: UIColor(red: 0.95, green: 0.85, blue: 0.1, alpha: 1.0), texture: nil)
            mat.metallic = .float(0)
            mat.roughness = .float(0.6)
            return mat
        }
    }

    // MARK: - Lighting Response

    func updateObjectAppearance(intensity: Float) {
        guard hudState?.selectedMaterial == .matte else { return }
        let brightness = CGFloat(0.4 + 0.6 * intensity)
        let tint = UIColor(white: brightness, alpha: 1.0)
        for object in placedObjects {
            guard var comp = object.model else { continue }
            var mat = SimpleMaterial()
            mat.color = .init(tint: tint, texture: nil)
            mat.metallic = .float(0)
            mat.roughness = .float(1)
            comp.materials = [mat]
            object.model = comp
        }
    }

    // MARK: - Debug Arrow

    func updateDebugArrow(lightDirection: SIMD3<Float>) {
        guard let arView else { return }

        if debugArrowAnchor == nil {
            let anchor = AnchorEntity(world: SIMD3<Float>(0, 0.2, -0.5))
            anchor.addChild(makeDebugArrow())
            arView.scene.addAnchor(anchor)
            debugArrowAnchor = anchor
        }

        guard let arrow = debugArrowAnchor?.children.first else { return }
        arrow.orientation = quaternion(from: [0, 1, 0], to: lightDirection)
    }

    private func makeDebugArrow() -> Entity {
        let parent = Entity()

        let shaft = ModelEntity(
            mesh: .generateCylinder(height: 0.3, radius: 0.01),
            materials: [SimpleMaterial(color: .systemYellow, isMetallic: false)]
        )
        shaft.position = [0, 0.15, 0]
        parent.addChild(shaft)

        let tip = ModelEntity(
            mesh: .generateCone(height: 0.08, radius: 0.025),
            materials: [SimpleMaterial(color: .systemOrange, isMetallic: false)]
        )
        tip.position = [0, 0.34, 0]
        parent.addChild(tip)

        return parent
    }

    private func quaternion(from: SIMD3<Float>, to target: SIMD3<Float>) -> simd_quatf {
        let t = normalize(target)
        let dot = simd_dot(from, t)
        if dot > 0.9999  { return simd_quatf(ix: 0, iy: 0, iz: 0, r: 1) }
        if dot < -0.9999 { return simd_quatf(angle: .pi, axis: SIMD3<Float>(1, 0, 0)) }
        return simd_quatf(angle: acos(dot), axis: normalize(simd_cross(from, t)))
    }
}
