# Penumbra — System Architecture
CS 4361 Final Project | Spring 2026 | Zain Karim

---

## Overview

Penumbra is an iOS AR application that places virtual 3D objects and casts
physically-grounded shadows onto real detected surfaces. The architecture follows
**MVVM**, with the AR session and rendering pipeline separated into focused
manager classes rather than living in a monolithic view model.

**Framework stack:**
```
SwiftUI (UI layer)
  └── ARView (RealityKit — scene graph, entity rendering)
        ├── ARKit (plane detection, camera tracking, lighting estimation)
        └── Metal / MSL (custom shadow shaders via CustomMaterial API)
```

The key design constraint is that `CustomMaterial` (the bridge between Metal
shaders and RealityKit) requires explicit GPU-level control: the shadow mesh is
a separate `ModelEntity` with a `CustomMaterial` whose vertex shader projects
vertices onto the detected plane using the estimated light direction. RealityKit's
built-in shadow pass is disabled to prevent double-shadow artifacts.

---

## Folder Structure (Planned)

```
Penumbra/
├── Views/
│   ├── ContentView.swift          — SwiftUI root; owns ARViewContainer
│   └── ARViewContainer.swift      — UIViewRepresentable wrapping ARView
├── Managers/
│   ├── ARSessionManager.swift     — ARSession ownership, ARSCNViewDelegate
│   ├── SceneManager.swift         — entity placement, tap gesture handling
│   ├── LightingEstimator.swift    — ARLightEstimate / ARDirectionalLightEstimate
│   └── ShadowRenderer.swift       — CustomMaterial creation and update
├── Shaders/
│   ├── ShadowVertex.metal         — planar shadow projection vertex shader
│   └── ShadowFragment.metal       — soft-edge alpha falloff fragment shader
└── Models/
    └── (placeholder OBJ/USDZ assets)
```

---

## Component Responsibilities

### ARSessionManager
**Owns:** `ARSession`, `ARWorldTrackingConfiguration`, `ARSessionDelegate`.

**Publishes (via @Observable):**
- `detectedPlanes: [UUID: PlaneAnchorInfo]` — current set of detected horizontal planes
- `currentFrame: ARFrame?` — most recent camera frame (for lighting estimate access)

**Does NOT:** create or manage any RealityKit entities. Its only output is plane
anchor data and raw frame data. It is the boundary between ARKit and the rest of
the app.

**Key behavior:** Configures `ARWorldTrackingConfiguration` with
`.horizontalPlane` detection and `environmentTexturing: .automatic` (required
for `ARDirectionalLightEstimate` to become available). Calls
`SceneManager.updatePlanes()` and `LightingEstimator.update(frame:)` from
`session(_:didUpdate:)`.

---

### SceneManager
**Owns:** `ARView`, the root `Entity`, all placed `ModelEntity` objects, and
their corresponding shadow mesh entities.

**Publishes:** `placedObjects: [ModelEntity]`

**Does NOT:** access `ARSession` directly or read `ARLightEstimate`. It receives
already-processed data from the other managers.

**Key behavior:**
- Handles tap gestures: raycasts against detected planes via
  `ARView.raycast(from:allowing:alignment:)`, places a `ModelEntity` at the hit
  location.
- For each placed object, calls `ShadowRenderer.makeShadowEntity(for:)` to
  create a companion shadow mesh entity parented to the plane anchor.
- Each frame, calls `ShadowRenderer.update(shadowEntity:lightDirection:intensity:)`
  to push updated uniforms to the CustomMaterial.

---

### LightingEstimator
**Owns:** the most recent `ARLightEstimate` and `ARDirectionalLightEstimate`.

**Publishes:**
- `lightDirection: SIMD3<Float>` — normalized direction toward the light source
  (defaults to `[0, 1, 0]` when directional estimate unavailable)
- `intensity: Float` — [0, 1] normalized from ARKit's lux value
- `colorTemperature: Float` — Kelvin (stretch goal: used for shadow tint)

**Does NOT:** create any entities or interact with RealityKit.

**Key behavior:** Called each frame with the latest `ARFrame`. Checks
`frame.lightEstimate as? ARDirectionalLightEstimate` before accessing
directional data. Normalizes `ambientIntensity` (lux) against a reference value
of 1000 lux. See `docs/SHADOW_MATH.md §3` for the mapping formula.

---

### ShadowRenderer
**Owns:** the `CustomMaterial` instances for all shadow meshes.

**Does NOT:** own any `Entity` directly — it creates and returns them to
`SceneManager`.

**Key behavior:**
- `makeShadowEntity(for objectEntity: ModelEntity) -> ModelEntity` — generates
  a disc mesh (N=32 vertices), creates a `CustomMaterial` pointing to
  `ShadowVertex.metal` and `ShadowFragment.metal`, returns a `ModelEntity`
  ready to be parented to the plane anchor.
- `update(shadowEntity:lightDirection:intensity:planeY:)` — updates the
  `CustomMaterial`'s `CustomMaterial.Parameter` values each frame: `lightDir`,
  `shadowIntensity`, `planeY`, `objectCenter`.
- Disables RealityKit's built-in shadow casting on all managed entities via
  `.castsShadow = false`.

---

## Data Flow

```
Camera feed
    │
    ▼
ARSession (ARKit)
    │  session(_:didUpdate frame:)
    ▼
ARSessionManager
    ├──► LightingEstimator.update(frame:)
    │         │
    │         │  lightDirection, intensity
    │         ▼
    │    [Published to SceneManager via @Observable binding]
    │
    └──► SceneManager.updatePlanes(anchors:)
              │
              │  (each frame) ShadowRenderer.update(...)
              ▼
         ShadowRenderer
              │
              │  CustomMaterial parameter update
              ▼
         ARView (RealityKit renders shadow mesh entities)
```

Tap gesture path:
```
User tap on screen
    │
    ▼
SceneManager (gesture recognizer on ARView)
    │  ARView.raycast(...)
    ▼
Hit result on detected plane
    │
    ▼
SceneManager.placeObject(at: worldTransform)
    │  ShadowRenderer.makeShadowEntity(for:)
    ▼
New ModelEntity + ShadowEntity added to scene
```

---

## Metal Pipeline Design

### ShadowVertex.metal
**Inputs:**
- Vertex position (object-space disc vertex on the XZ plane)
- Uniforms buffer: `lightDir: float3`, `planeY: float`, `objectCenter: float3`

**Steps:**
1. Compute world-space vertex position = objectCenter + disc vertex offset.
2. Apply the planar shadow projection matrix (see `docs/SHADOW_MATH.md §1`)
   using `lightDir` and the horizontal plane at `planeY`.
3. Offset Y by `+0.001` to avoid z-fighting.
4. Pass through a `radialCoord: float2` varying (UV from disc center) for the
   fragment shader.

**Key uniform:** The shadow matrix is computed on the CPU in `ShadowRenderer`
each frame and passed as a `float4x4` uniform — not computed per-vertex in the
shader, to avoid redundant matrix construction.

### ShadowFragment.metal
**Inputs:**
- `radialCoord: float2` from vertex shader (range [-1, 1] from disc center)
- Uniforms: `shadowIntensity: float`, `innerRadius: float`

**Steps:**
1. Compute `r = length(radialCoord)` — normalized radial distance (0 = center,
   1 = disc edge).
2. Apply falloff: `alpha = shadowIntensity * (1.0 - smoothstep(innerRadius, 1.0, r))`
3. Output `float4(0, 0, 0, alpha)` — black shadow with soft edge.

See `docs/SHADOW_MATH.md §2` for the full falloff derivation.

### CustomMaterial Bridge Constraints
- `CustomMaterial` requires iOS 15+ — wrap in `if #available(iOS 15, *)`.
- Shader function names must be declared in a `CustomMaterial.SurfaceShader` or
  `CustomMaterial.GeometryModifier` — cannot use arbitrary Metal function names.
- Parameters passed via `CustomMaterial.Parameter` are limited to scalar and
  vector types. Matrices must be passed as a packed buffer via a custom
  `MTLBuffer` if needed, or decomposed into 4 `float4` parameters.
- Shader compilation errors are silent at runtime — always verify in build log.

---

## Threading Model

ARKit calls `ARSessionDelegate` methods on a **background serial queue** in some
configurations, but RealityKit entity mutations must happen on the **main thread**.

All manager classes are annotated `@MainActor`. The `ARSessionDelegate` methods
in `ARSessionManager` dispatch back to the main actor before calling into
`SceneManager` or `LightingEstimator`:

```swift
@MainActor
func session(_ session: ARSession, didUpdate frame: ARFrame) {
    lightingEstimator.update(frame: frame)
    sceneManager.updateShadows(
        lightDirection: lightingEstimator.lightDirection,
        intensity: lightingEstimator.intensity
    )
}
```

Metal command buffer encoding happens on the main thread via RealityKit's render
loop — `ShadowRenderer` does not manage its own `MTLCommandQueue`.

---

## Key API Reference

| Need | API |
|------|-----|
| Detect horizontal planes | `ARWorldTrackingConfiguration.planeDetection = .horizontal` |
| Get light direction | `ARDirectionalLightEstimate.primaryLightDirection` (SIMD3<Float>, world space) |
| Get ambient intensity (lux) | `ARLightEstimate.ambientIntensity` (Float, lux) |
| Get color temperature | `ARLightEstimate.ambientColorTemperature` (Float, Kelvin) |
| Custom vertex/fragment shaders | `RealityKit.CustomMaterial(surfaceShader:geometryModifier:lightingModel:)` |
| Disable built-in shadow | `entity.components[ModelComponent.self]?.materials` — set `.castsShadow = false` on the object; shadow mesh uses unlit CustomMaterial |
| Raycast to place entity | `ARView.raycast(from: screenPoint, allowing: .estimatedPlane, alignment: .horizontal)` |
| Place entity at world transform | `entity.transform = Transform(matrix: hitResult.worldTransform)` |
| Pass data to Metal shader | `CustomMaterial.Parameter` (scalar/vector) or `MTLBuffer` |
