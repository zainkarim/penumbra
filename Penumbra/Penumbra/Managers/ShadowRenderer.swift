//
//  ShadowRenderer.swift
//  Penumbra
//
//  Created by Zain Karim on 4/30/26.
//
//  Owns the CustomMaterial pipeline and one shadow disc entity per placed object.
//  Each frame, ShadowRenderer:
//    1. Repositions each disc using the planar shadow projection formula
//       (SHADOW_MATH.md §1) evaluated on the CPU.
//    2. Updates the material's custom uniform (intensity, innerRadius) so the
//       GPU fragment shader (ShadowFragment.metal) can compute the soft edge.

import Metal
import RealityKit
import Observation

@Observable
@MainActor
final class ShadowRenderer {

    weak var arView: ARView?

    private struct ShadowEntry {
        let sphere: ModelEntity
        let shadow: ModelEntity
    }

    private var entries: [ShadowEntry] = []
    private var materialTemplate: CustomMaterial?

    private let innerRadius: Float = 0.4
    private let shadowRadiusMultiplier: Float = 1.5
    private let zOffset: Float = 0.001

    // MARK: - Setup

    func loadMaterial() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        guard let library = device.makeDefaultLibrary() else {
            print("ShadowRenderer: default Metal library unavailable — check build log for shader compile errors")
            return
        }

        let surfaceShader = CustomMaterial.SurfaceShader(named: "shadowSurfaceShader", in: library)
        let geometryModifier = CustomMaterial.GeometryModifier(named: "shadowGeometryModifier", in: library)

        var material = try CustomMaterial(surfaceShader: surfaceShader, geometryModifier: geometryModifier, lightingModel: .unlit)
        material.blending = .transparent(opacity: .init(floatLiteral: 1.0))
        material.faceCulling = .none
        material.custom.value = SIMD4<Float>(0.5, innerRadius, 0, 0)

        materialTemplate = material
    }

    // MARK: - Shadow Attachment

    func attachShadow(to sphere: ModelEntity, on anchor: AnchorEntity, sphereRadius: Float) throws {
        guard materialTemplate != nil else { return }

        let shadowRadius = sphereRadius * shadowRadiusMultiplier
        let mesh = try makeShadowMesh(radius: shadowRadius)
        let shadow = ModelEntity(mesh: mesh, materials: [materialTemplate!])
        shadow.components[GroundingShadowComponent.self] = GroundingShadowComponent(castsShadow: false)
        shadow.position.y = zOffset

        anchor.addChild(shadow)
        entries.append(ShadowEntry(sphere: sphere, shadow: shadow))
    }

    // MARK: - Per-Frame Update

    func update(lightDirection: SIMD3<Float>, intensity: Float) {
        guard var material = materialTemplate else { return }
        material.custom.value = SIMD4<Float>(intensity, innerRadius, 0, 0)

        // Safe light direction: skip degenerate grazing angles
        let L = normalize(lightDirection)
        let safeL: SIMD3<Float> = abs(L.y) > 0.001 ? L : normalize(SIMD3<Float>(0.5, 1.0, 0.5))

        for entry in entries {
            // Planar shadow projection (SHADOW_MATH.md §1, horizontal plane n=(0,1,0))
            // t = sphere.y / L.y;  shadow_center = sphere_pos - t * L
            let spherePos = entry.sphere.position
            let t = spherePos.y / safeL.y
            entry.shadow.position.x = spherePos.x - t * safeL.x
            entry.shadow.position.z = spherePos.z - t * safeL.z

            // Push updated intensity to entity material
            guard var comp = entry.shadow.model else { continue }
            comp.materials = [material]
            entry.shadow.model = comp
        }
    }

    // MARK: - Disc Mesh

    // Triangle-fan disc in the XZ plane (N=32 segments).
    // UV layout: center = (0.5, 0.5), edge at distance 0.5 from center → r=1 in shader.
    private func makeShadowMesh(radius: Float) throws -> MeshResource {
        let N = 32
        var positions:  [SIMD3<Float>] = [.zero]
        var normals:    [SIMD3<Float>] = [SIMD3<Float>(0, 1, 0)]
        var texCoords:  [SIMD2<Float>] = [SIMD2<Float>(0.5, 0.5)]
        var indices:    [UInt32]       = []

        for i in 0..<N {
            let angle = Float(i) / Float(N) * 2 * .pi
            let x = cos(angle)
            let z = sin(angle)
            positions.append(SIMD3<Float>(x * radius, 0, z * radius))
            normals.append(SIMD3<Float>(0, 1, 0))
            texCoords.append(SIMD2<Float>(x * 0.5 + 0.5, z * 0.5 + 0.5))
        }

        for i in 0..<N {
            indices.append(0)
            indices.append(UInt32(i + 1))
            indices.append(UInt32((i + 1) % N + 1))
        }

        var descriptor = MeshDescriptor(name: "shadowDisc")
        descriptor.positions          = MeshBuffer(positions)
        descriptor.normals            = MeshBuffer(normals)
        descriptor.textureCoordinates = MeshBuffer(texCoords)
        descriptor.primitives         = .triangles(indices)

        return try MeshResource.generate(from: [descriptor])
    }
}
