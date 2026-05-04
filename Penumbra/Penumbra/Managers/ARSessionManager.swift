//
//  ARSessionManager.swift
//  Penumbra
//
//  Created by Zain Karim on 3/28/26.
//

import ARKit
import Metal
import RealityKit
import Observation

@Observable
@MainActor
final class ARSessionManager: NSObject {

    private(set) var detectedPlaneCount: Int = 0

    private let arView: ARView
    var lightingEstimator: LightingEstimator?
    var sceneManager: SceneManager?
    var shadowRenderer: ShadowRenderer?
    weak var hudState: HUDState?

    // Grid plane visualization
    private var gridMaterial: CustomMaterial?
    private var gridEntities: [UUID: ModelEntity] = [:]
    private var planeAges: [UUID: Int] = [:]

    // Material change tracking (polled each frame at 60 fps)
    private var lastAppliedMaterial: MaterialOption = .matte

    init(arView: ARView) {
        self.arView = arView
        super.init()
        configureSession()
        loadGridMaterial()
    }

    // MARK: - Session Configuration

    private func configureSession() {
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal]
        config.environmentTexturing = .automatic
        arView.session.delegate = self
        arView.session.run(config)
    }

    // MARK: - Grid Material

    private func loadGridMaterial() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let library = device.makeDefaultLibrary() else { return }

        let surfaceShader   = CustomMaterial.SurfaceShader(named: "planeGridSurfaceShader",   in: library)
        let geometryModifier = CustomMaterial.GeometryModifier(named: "planeGridGeometryModifier", in: library)

        do {
            var mat = try CustomMaterial(
                surfaceShader: surfaceShader,
                geometryModifier: geometryModifier,
                lightingModel: .unlit
            )
            mat.blending = .transparent(opacity: .init(floatLiteral: 1.0))
            mat.faceCulling = .none
            mat.custom.value = SIMD4<Float>(0, 0, 0, 0)
            gridMaterial = mat
        } catch {
            print("PlaneGrid material load failed: \(error)")
        }
    }
}

// MARK: - ARSessionDelegate

extension ARSessionManager: ARSessionDelegate {

    nonisolated func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        Task { @MainActor in
            for anchor in anchors {
                guard let plane = anchor as? ARPlaneAnchor else { continue }
                detectedPlaneCount += 1
                hudState?.detectedPlaneCount = detectedPlaneCount
                addGridPlane(for: plane)
            }
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        Task { @MainActor in
            for anchor in anchors {
                guard let plane = anchor as? ARPlaneAnchor else { continue }
                updateGridPlane(for: plane)
            }
        }
    }

    nonisolated func session(_ session: ARSession, didUpdate frame: ARFrame) {
        Task { @MainActor in
            updateGridFadeIn()
            pollMaterialChanges()

            let (direction, intensity) = resolvedLightParams(frame: frame)
            shadowRenderer?.update(lightDirection: direction, intensity: intensity)
            sceneManager?.updateObjectAppearance(intensity: intensity)
        }
    }

    nonisolated func session(_ session: ARSession, didRemove anchors: [ARAnchor]) {
        Task { @MainActor in
            for anchor in anchors {
                guard let plane = anchor as? ARPlaneAnchor else { continue }
                removeGridPlane(for: plane)
                detectedPlaneCount = max(0, detectedPlaneCount - 1)
                hudState?.detectedPlaneCount = detectedPlaneCount
            }
        }
    }

    // MARK: - Light Params

    @MainActor
    private func resolvedLightParams(frame: ARFrame) -> (SIMD3<Float>, Float) {
        switch hudState?.lightMode ?? .auto {
        case .auto:
            lightingEstimator?.update(frame: frame)
            let dir = lightingEstimator?.lightDirection ?? normalize(SIMD3<Float>(0.5, 1.0, 0.5))
            let int = lightingEstimator?.intensity ?? 0.5
            return (dir, int)
        case .manual:
            return (manualLightDirection(), Float(hudState?.manualIntensity ?? 0.7))
        case .off:
            return (normalize(SIMD3<Float>(0.5, 1.0, 0.5)), 0.0)
        }
    }

    @MainActor
    private func manualLightDirection() -> SIMD3<Float> {
        let az = Float(hudState?.manualAzimuth ?? 135.0) * .pi / 180.0
        let el = Float(hudState?.manualElevation ?? 45.0) * .pi / 180.0
        return normalize(SIMD3<Float>(sin(az) * cos(el), sin(el), cos(az) * cos(el)))
    }

    // MARK: - Material Polling

    @MainActor
    private func pollMaterialChanges() {
        let current = hudState?.selectedMaterial ?? .matte
        guard current != lastAppliedMaterial else { return }
        lastAppliedMaterial = current
        sceneManager?.applyMaterial(current)
    }

    // MARK: - Grid Fade-in / Hold / Fade-out
    //
    // Animation timeline at 60 fps:
    //   frames   0– 59  → fade in  (opacity 0 → 1,  ~1 s)
    //   frames  60– 89  → hold     (opacity 1,       ~0.5 s)
    //   frames  90–149  → fade out (opacity 1 → 0,  ~1 s)
    //   frames 150+     → done, stop updating

    @MainActor
    private func updateGridFadeIn() {
        for (id, entity) in gridEntities {
            let age = planeAges[id, default: 150]
            guard age < 150 else { continue }
            planeAges[id] = age + 1

            let opacity: Float
            switch age {
            case 0..<60:   opacity = Float(age + 1) / 60.0
            case 60..<90:  opacity = 1.0
            default:       opacity = 1.0 - Float(age - 89) / 60.0
            }

            guard var comp = entity.model,
                  var mat = comp.materials.first as? CustomMaterial else { continue }
            let prev = mat.custom.value
            mat.custom.value = SIMD4<Float>(max(0, opacity), prev.y, prev.z, 0)
            comp.materials = [mat]
            entity.model = comp
        }
    }

    // MARK: - Grid Plane Entities

    @MainActor
    private func addGridPlane(for anchor: ARPlaneAnchor) {
        guard let template = gridMaterial else { return }
        let extent = anchor.planeExtent

        var mat = template
        mat.custom.value = SIMD4<Float>(0, extent.width, extent.height, 0)

        let mesh = MeshResource.generatePlane(width: extent.width, depth: extent.height)
        let planeEntity = ModelEntity(mesh: mesh, materials: [mat])
        planeEntity.components[GroundingShadowComponent.self] = GroundingShadowComponent(castsShadow: false)

        let anchorEntity = AnchorEntity(anchor: anchor)
        anchorEntity.name = gridAnchorName(for: anchor)
        anchorEntity.addChild(planeEntity)
        arView.scene.addAnchor(anchorEntity)

        gridEntities[anchor.identifier] = planeEntity
        planeAges[anchor.identifier] = 0
    }

    @MainActor
    private func updateGridPlane(for anchor: ARPlaneAnchor) {
        guard let entity = gridEntities[anchor.identifier] else { return }
        let extent = anchor.planeExtent
        entity.model?.mesh = MeshResource.generatePlane(width: extent.width, depth: extent.height)

        guard var comp = entity.model,
              var mat = comp.materials.first as? CustomMaterial else { return }
        let currentOpacity = mat.custom.value.x
        mat.custom.value = SIMD4<Float>(currentOpacity, extent.width, extent.height, 0)
        comp.materials = [mat]
        entity.model = comp
    }

    @MainActor
    private func removeGridPlane(for anchor: ARPlaneAnchor) {
        let name = gridAnchorName(for: anchor)
        if let anchorEntity = arView.scene.anchors.first(where: { $0.name == name }) {
            arView.scene.removeAnchor(anchorEntity)
        }
        gridEntities.removeValue(forKey: anchor.identifier)
        planeAges.removeValue(forKey: anchor.identifier)
    }

    private func gridAnchorName(for anchor: ARPlaneAnchor) -> String {
        "gridPlane_\(anchor.identifier.uuidString)"
    }
}
