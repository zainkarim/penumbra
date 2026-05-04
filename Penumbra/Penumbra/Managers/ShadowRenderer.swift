//
//  ShadowRenderer.swift
//  Penumbra
//
//  Created by Zain Karim on 4/30/26.
//
//  Owns the CustomMaterial pipeline and one shadow disc + one AO spot per placed object.
//  Both discs stay centered at the sphere footprint (no geometry movement).
//  Each frame, ShadowRenderer computes the normalized shadow direction and passes it
//  via custom uniform (.z, .w) so ShadowFragment.metal can render an asymmetric opacity
//  gradient — darker on the shadow side, lighter on the lit side.

import Metal
import RealityKit
import Observation

@Observable
@MainActor
final class ShadowRenderer {

    weak var arView: ARView?

    private struct ShadowEntry {
        let sphere: ModelEntity
        let shadow: ModelEntity   // directional shadow disc
        let aoSpot: ModelEntity   // contact AO spot
        let sphereRadius: Float   // base (unscaled) radius — used to clamp disc offset
    }

    private var entries: [ShadowEntry] = []
    private var materialTemplate: CustomMaterial?

    // innerRadius ≈ 0: nearly the entire disc is gradient → no visible hard boundary at any camera angle.
    // shadowRadiusMultiplier = 5: disc is 5× sphere radius → edge is always far from the sphere.
    private let innerRadius: Float = 0.02
    private let shadowRadiusMultiplier: Float = 5.0
    private let zOffset: Float = 0.001

    private let aoRadiusMultiplier: Float = 2.0
    private let aoIntensity:        Float = 0.55
    private let aoInnerRadius:      Float = 0.15

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
        guard let template = materialTemplate else { return }

        // Directional shadow disc — repositioned each frame by update()
        let shadowRadius = sphereRadius * shadowRadiusMultiplier
        var shadowMat = template
        shadowMat.custom.value = SIMD4<Float>(0.5, innerRadius, 0, 0)
        let shadow = ModelEntity(mesh: try makeShadowMesh(radius: shadowRadius), materials: [shadowMat])
        shadow.components[GroundingShadowComponent.self] = GroundingShadowComponent(castsShadow: false)
        shadow.position.y = zOffset
        anchor.addChild(shadow)

        // AO contact spot — pinned directly beneath sphere, never moves
        let aoRadius = sphereRadius * aoRadiusMultiplier
        var aoMat = template
        aoMat.custom.value = SIMD4<Float>(aoIntensity, aoInnerRadius, 0, 0)
        let aoSpot = ModelEntity(mesh: try makeShadowMesh(radius: aoRadius), materials: [aoMat])
        aoSpot.components[GroundingShadowComponent.self] = GroundingShadowComponent(castsShadow: false)
        aoSpot.position = SIMD3<Float>(sphere.position.x, zOffset + 0.001, sphere.position.z)
        anchor.addChild(aoSpot)

        entries.append(ShadowEntry(sphere: sphere, shadow: shadow, aoSpot: aoSpot, sphereRadius: sphereRadius))
    }

    // MARK: - Lifecycle

    func removeAll() {
        entries.removeAll()
    }

    func updateScale(_ scale: Float) {
        for entry in entries {
            entry.shadow.scale = SIMD3<Float>(repeating: scale)
            entry.aoSpot.scale = SIMD3<Float>(repeating: scale)
        }
    }

    // MARK: - Per-Frame Update

    func update(lightDirection: SIMD3<Float>, intensity: Float) {
        for entry in entries {
            let rawCenter = ShadowMath.shadowCenter(
                spherePos: entry.sphere.position,
                lightDir: lightDirection
            )

            let rawX = rawCenter.x
            let rawZ = rawCenter.y
            let dist = (rawX * rawX + rawZ * rawZ).squareRoot()

            // Normalized shadow direction for the shader's directional gradient.
            // Both discs stay centered — directionality comes from asymmetric opacity in the shader.
            let dirX: Float = dist > 0.001 ? rawX / dist : 0
            let dirZ: Float = dist > 0.001 ? rawZ / dist : 0

            // Update shadow disc material: intensity + direction each frame.
            guard var discComp = entry.shadow.model,
                  var discMat  = discComp.materials.first as? CustomMaterial else { continue }
            discMat.custom.value = SIMD4<Float>(intensity, innerRadius, dirX, dirZ)
            discComp.materials   = [discMat]
            entry.shadow.model   = discComp

            // Update AO spot material: direction each frame (its intensity/innerRadius are fixed).
            guard var aoComp = entry.aoSpot.model,
                  var aoMat  = aoComp.materials.first as? CustomMaterial else { continue }
            aoMat.custom.value = SIMD4<Float>(aoIntensity, aoInnerRadius, dirX, dirZ)
            aoComp.materials   = [aoMat]
            entry.aoSpot.model = aoComp
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
