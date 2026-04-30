# Penumbra — Session Handoff Document
CS 4361 Final Project | Spring 2026 | Zain Karim

---

## How to Start a New Session

1. Open Claude Code in the Penumbra project directory.
2. Say: **"Read docs/HANDOFF.md and docs/PROGRESS.md before we start."**
3. Tell Claude what you just worked on (or point to the "What Was Accomplished"
   section below) and what you want to do next.
4. If starting a new week, update the "Current Session State" section below and
   check off completed goals in PROGRESS.md.

**Always update this file at the END of each work session** before closing Xcode.

---

## Current Session State

**Date:** Apr 30, 2026
**Current Phase:** Week 6 — Scene Refinement & Demo Build
**Last Milestone:** Week 5 complete. AO contact spot verified (fixed z-fighting with +1 mm y-offset). Sphere brightness responds to ambient intensity. Debug planes hidden. Calibration tuned (innerRadius=0.35, shadowRadiusMultiplier=1.8, referenceIntensity=800).
**Next Task:** Week 6 goals — shadow quality tuning pass, UI polish (SwiftUI HUD), demo scenario design, Instruments profiling, record demo video.

---

## What Was Accomplished

### Week 1 (Mar 28) — CLOSED ✅

**Files deleted:**
- `Penumbra/Penumbra/Item.swift` — SwiftData model removed

**Files modified:**
- `Penumbra/Penumbra/PenumbraApp.swift` — stripped SwiftData/ModelContainer boilerplate; now a plain `WindowGroup { ContentView() }`
- `Penumbra/Penumbra/ContentView.swift` — replaced NavigationSplitView/SwiftData body with `ARViewContainer().ignoresSafeArea()`

**Files created:**
- `Penumbra/Penumbra/Views/ARViewContainer.swift` — `UIViewRepresentable` wrapping `ARView`; `Coordinator` holds strong ref to `ARSessionManager`
- `Penumbra/Penumbra/Managers/ARSessionManager.swift` — `@Observable @MainActor` ARKit session manager; `ARWorldTrackingConfiguration` with `.horizontal` plane detection and `.automatic` environment texturing; debug blue translucent plane visualization via `ModelEntity` + `SimpleMaterial`

**Verified on device:** Blue translucent rectangles appear and grow on detected horizontal surfaces. Plane updates (resize/reposition) work as device moves.

### Week 5 (Apr 30) — CLOSED ✅

**Files modified:**
- `ShadowRenderer.swift` — added AO contact spot disc (radius = sphereRadius × 0.6, y = 0.002 to clear directional disc depth); tuned innerRadius=0.35, shadowRadiusMultiplier=1.8; AO uniforms: intensity=0.75, innerRadius=0.1
- `SceneManager.swift` — added `updateObjectAppearance(intensity:)`: drives sphere tint brightness = 0.4 + 0.6 × intensity each frame
- `ARSessionManager.swift` — added `showDebugPlanes = false`; guarded `addDebugPlane`/`updateDebugPlane`; wired `updateObjectAppearance` into per-frame update
- `LightingEstimator.swift` — referenceIntensity 1000→800 lux

**Bug fixed:** AO spot invisible from above due to z-fighting with directional disc at same y=0.001. Fixed by placing AO spot at y=0.002.

**Verified on device:** AO spot visible from all angles, stays pinned under sphere. Sphere brightens/dims with room lighting. No debug plane clutter.

### Week 4 (Apr 30) — CLOSED ✅

**Files created:**
- `Penumbra/Penumbra/Shaders/ShadowVertex.metal` — no-op geometry modifier; shadow disc positioning is CPU-driven via entity transforms each frame.
- `Penumbra/Penumbra/Shaders/ShadowFragment.metal` — surface shader: reads `uv0` radial coord, applies `alpha = intensity * (1 - metal::smoothstep(innerRadius, 1.0, r))`. Uniforms via `params.uniforms().custom_parameter()` (`.x` = intensity, `.y` = innerRadius). Outputs black unlit color with computed opacity.
- `Penumbra/Penumbra/Managers/ShadowRenderer.swift` — `@Observable @MainActor`; `loadMaterial()` builds `CustomMaterial(.unlit, .transparent, .faceCulling .none)` with geometry modifier in initializer (not a separate setter — see Gotcha #11); `attachShadow(to:on:sphereRadius:)` generates 32-segment triangle-fan disc mesh (UV center=(0.5,0.5), edge at distance 0.5) and adds disc as sibling child of plane anchor; `update(lightDirection:intensity:)` applies planar projection formula CPU-side and pushes `material.custom.value` to all shadow entities.

**Files modified:**
- `LightingEstimator.swift` — (1) fallback changed from `[0,1,0]` to `normalize([0.5,1.0,0.5])`; (2) `primaryLightDirection` now transformed from camera-local space to world space: `let rotated = frame.camera.transform * SIMD4<Float>(rawDir, 0); lightDirection = normalize(SIMD3<Float>(rotated.x, rotated.y, rotated.z))`.
- `SceneManager.swift` — added `var shadowRenderer: ShadowRenderer?`; `sphere.position.y = radius` (sits on plane); calls `shadowRenderer?.attachShadow(to:on:sphereRadius:)`.
- `ARSessionManager.swift` — added `var shadowRenderer: ShadowRenderer?`; calls `shadowRenderer?.update(lightDirection:intensity:)` each frame.
- `ARViewContainer.swift` — instantiates `ShadowRenderer`, calls `loadMaterial()` synchronously, injects into both `SceneManager` and `ARSessionManager`, adds to `Coordinator`.

**Known compiler quirks fixed this session:**
- `metal::length`, `metal::smoothstep`, `metal::saturate` — RealityKit header doesn't pull in `using namespace metal`, requires explicit prefix (Gotcha #13).
- `CustomMaterial(surfaceShader:geometryModifier:lightingModel:)` — geometry modifier goes in the init, not as a settable property (Gotcha #11).
- `SIMD4<Float>` has no `.xyz` swizzle in Swift — use `.x, .y, .z` individually (fixed in LightingEstimator line 34–35).

**Verified on device (Apr 30):**
1. Shadow disc appears as a soft dark circle under the placed sphere. ✅
2. Shadow disc repositions as device moves around the sphere. ✅
3. Shadow fades/intensifies with room lighting changes. ✅

### Week 3 (Apr 30) — CLOSED ✅

**Files created:**
- `Penumbra/Penumbra/Managers/LightingEstimator.swift` — `@Observable @MainActor`; consumes `ARFrame` each frame; publishes `lightDirection: SIMD3<Float>`, `intensity: Float`, `colorTemperature: Float`; guards `ARDirectionalLightEstimate` availability; lux→[0,1] mapping with 1000 lux reference.

**Files modified:**
- `Penumbra/Penumbra/Managers/ARSessionManager.swift` — added `var lightingEstimator` and `var sceneManager` injection properties; added `session(_:didUpdate frame:)` delegate method that bridges to main actor, calls `lightingEstimator.update(frame:)` and `sceneManager.updateDebugArrow(lightDirection:)`.
- `Penumbra/Penumbra/Managers/SceneManager.swift` — added `updateDebugArrow(lightDirection:)`, `makeDebugArrow()`, and `quaternion(from:to:)` helpers; debug arrow is cylinder+cone entity at world `[0, 0.2, -0.5]`, oriented via quaternion each frame.
- `Penumbra/Penumbra/Views/ARViewContainer.swift` — added `lightingEstimator` to Coordinator; updated `makeUIView` to instantiate `LightingEstimator` and inject into `ARSessionManager` and `SceneManager`.

**Verified on device:** Arrow appears at `[0, 0.2, -0.5]` world position at launch. Ambient lux reads ~900–1100 and maps to intensity correctly. `ARDirectionalLightEstimate` was not returned (diffuse/cloudy lighting environment — expected behavior, guard works correctly). Arrow tilt will be visible in direct sunlight or under a single strong overhead light.

---

### Week 2 (Apr 3) — CLOSED ✅

**Files created:**
- `Penumbra/Penumbra/Managers/SceneManager.swift` — `@Observable @MainActor`; `weak var arView`; raycasts against `.existingPlaneGeometry` on tap; places white sphere anchored to hit plane anchor; disables `GroundingShadowComponent` (prep for Week 4 custom shadow)

**Files modified:**
- `Penumbra/Penumbra/Views/ARViewContainer.swift` — added `SceneManager` instantiation and `UITapGestureRecognizer` wired through Coordinator `@objc handleTap`

**Verified on device:** Sphere placed at tap location, stays pinned to detected plane as device moves.

---

## What Was Left Incomplete

All code for Week 4 is written. Remaining items are on-device verification only (see Week 4 pending list above).

---

## Unresolved Bugs

**Light direction may still be off after camera-transform fix.** On-device test needed. If the arrow is 180° inverted (points away from the light instead of toward it), change `LightingEstimator.swift:35` from `normalize(SIMD3<Float>(rotated.x, rotated.y, rotated.z))` to `normalize(SIMD3<Float>(-rotated.x, -rotated.y, -rotated.z))`. If the direction is still ~90° wrong, the convention for `primaryLightDirection` on this iOS version may differ — consider logging raw values and comparing to the known light source position.

---

## Key Decisions Made

- `ARSessionManager` takes `ARView` in its initializer (rather than creating it internally) so the view layer retains ownership of `ARView` and the manager stays focused on session logic.
- Debug plane visualization uses a single `ModelEntity` plane mesh per anchor (not a dot grid) — simpler and cheaper for GPU. Will be removed or made togglable in Week 5.
- `LightingEstimator` has no `import RealityKit` — enforces the contract that it never touches entities (per ARCHITECTURE.md).
- `ARSessionManager` holds references to both `LightingEstimator` and `SceneManager` (injected after construction by `ARViewContainer`) so `session(_:didUpdate frame:)` can drive both in one place, matching ARCHITECTURE.md's data flow diagram.

---

## Exact Next Steps (Week 5 — Visual Polish)

First: complete the on-device verification checklist in the Week 4 section above. Fix the light direction if still wrong (see Unresolved Bugs).

Then, Week 5 goals (`docs/PROGRESS.md`):
1. **Ambient occlusion contact spot** — small dark ellipse at the base of the sphere, always directly beneath it regardless of light direction. Simplest approach: a second, much smaller shadow disc (radius ≈ sphere_radius * 0.6) with high opacity and very small innerRadius (≈ 0.1), always at position (sphere.x, 0.001, sphere.z) with no light-direction offset.
2. **Object material response to ambient intensity** — update the sphere's `SimpleMaterial` roughness or emissive based on `lightingEstimator.intensity` each frame so it looks brighter/dimmer with real lighting.
3. **Tune calibration parameters** — on-device: adjust `innerRadius` (default 0.4), `shadowRadiusMultiplier` (default 1.5), `referenceIntensity` (default 1000 lux) in `ShadowRenderer.swift` to match observed appearance.
4. **Remove or hide debug plane visualization** — make it togglable (a Bool flag in `ARSessionManager`) rather than permanently visible; default to hidden.
5. **Commit polished milestone.**

---

## Architecture Snapshot

Quick reference for re-orientation at the start of any session:

### 4 Manager Classes

| Manager | Owns | Publishes |
|---------|------|-----------|
| `ARSessionManager` | ARSession, ARWorldTrackingConfiguration | detectedPlaneCount |
| `SceneManager` | `ARView` (weak ref), all placed `ModelEntity` instances | `placedObjects: [ModelEntity]` |
| `LightingEstimator` | ARLightEstimate processing | lightDirection, intensity, colorTemp |
| `ShadowRenderer` | CustomMaterial instances | (none — called by SceneManager) |

All managers are `@MainActor` and `@Observable`.

### Shadow Pipeline (5 Steps)

1. **ARKit** detects horizontal plane → `ARSessionManager` publishes anchor
2. **LightingEstimator** reads `ARDirectionalLightEstimate` → normalized light
   direction + intensity
3. **ShadowRenderer** builds shadow matrix each frame (see SHADOW_MATH.md §1)
4. **ShadowVertex.metal** projects disc vertices onto the detected plane using
   the shadow matrix
5. **ShadowFragment.metal** applies radial alpha falloff
   `alpha = intensity * (1 - smoothstep(innerRadius, 1, r))`

### Key Metal Files

- `Penumbra/Shaders/ShadowVertex.metal` — planar shadow projection vertex shader
- `Penumbra/Shaders/ShadowFragment.metal` — soft-edge alpha falloff fragment shader

### Key Docs

- `docs/ARCHITECTURE.md` — full component design, data flow, threading model
- `docs/SHADOW_MATH.md` — complete math derivation with Swift/MSL code sketches
- `docs/DECISIONS.md` — ADRs explaining every major technology choice
- `docs/PROGRESS.md` — week-by-week goals and status tracker

---

## Known Gotchas (Cumulative)

**Never delete entries from this list. Add new ones as they are discovered.**

1. **Metal shader errors are silent at runtime.** RealityKit silently falls back
   to a default material if a `.metal` shader fails to compile. Always check the
   Xcode build log under "Compile Metal" after any shader change — the app will
   launch without shadows rather than crashing.

2. **RealityKit built-in shadow pass must be disabled.** RealityKit's default
   shadow system conflicts with the custom shadow mesh, producing a doubled or
   incorrect shadow. Set `.castsShadow = false` on the placed object's
   ModelComponent before adding the ShadowRenderer mesh.

3. **`ARDirectionalLightEstimate` requires textured environments.** It is not
   available in plain/untextured surroundings. Always guard:
   `if let directional = frame.lightEstimate as? ARDirectionalLightEstimate { ... }`
   Fall back to a default light direction (e.g., straight down: `[0, 1, 0]`) when
   the directional estimate is unavailable.

4. **Shadow mesh Z-fighting.** Place the shadow mesh at `planeY + 0.001 m`
   (not exactly planeY) to prevent z-fighting with the detected plane surface.

5. **PBXFileSystemSynchronizedRootGroup (Xcode 16+).** New source files added
   to the project directory are automatically included in the build target — no
   manual Xcode project navigator additions needed, as long as the file is placed
   in the correct source group folder.

6. **`ARSessionDelegate` methods are called on a background thread.** The delegate
   callbacks (`didAdd`, `didUpdate`, `didRemove`) arrive off the main actor. Bridge
   back with `Task { @MainActor in ... }` before touching any RealityKit entities or
   `@Observable` properties.

7. **SceneManager must hold ARView weakly.** Use `weak var arView: ARView?` in SceneManager — `ARViewContainer`/`Coordinator` already owns the strong reference. A strong reference in SceneManager would create a retain cycle.

8. **`session(_:didUpdate frame:)` fires at ~60 fps.** Each call creates a Swift concurrency Task via `Task { @MainActor in }`. This is acceptable overhead for a student project. A production app would batch updates or throttle with a frame counter.

9. **`ARDirectionalLightEstimate` is unavailable in diffuse/cloudy lighting.** Even with `environmentTexturing = .automatic`, ARKit won't produce a directional estimate unless there is a clear dominant light source (direct sun, single strong overhead). Diffuse overcast or multi-source indoor lighting stays `ARLightEstimate` (ambient only) indefinitely. The `[0, 1, 0]` fallback fires in these conditions — this is correct behavior, not a bug.

10. **The `[0, 1, 0]` straight-down fallback will degenerate the shadow matrix.** When `lightDirection = [0, 1, 0]`, the shadow projection matrix has `dot = L.y ≈ 1`, which is actually fine — but a **straight-down light produces a shadow directly under the object with zero spread**, which looks unnatural. Before Week 4, change the fallback to `normalize([0.5, 1.0, 0.5])` (45° from above) so the shadow always has a visible offset even when the directional estimate is unavailable.

11. **`CustomMaterial.geometryModifier` is not a settable property.** In RealityKit for iOS 17+ (confirmed via swiftinterface), the geometry modifier is passed in the initializer, not set afterward: `CustomMaterial(surfaceShader:geometryModifier:lightingModel:)`. Setting `material.geometryModifier = ...` after construction does not compile.

12. **`material.custom.value` is the correct way to pass float4 uniforms to CustomMaterial shaders.** In the Metal surface shader, access it via `params.uniforms().custom_parameter()` which returns `float4`. Do NOT try to use `surface.parameters.custom.value` — the correct path is `params.uniforms()`, not `params.surface()`.

13. **Metal stdlib functions need `metal::` prefix in RealityKit shaders.** `<RealityKit/RealityKit.h>` does not include `using namespace metal;`, so standard library calls (`length`, `smoothstep`, `saturate`, `normalize`, etc.) must be written as `metal::length(...)`, `metal::smoothstep(...)`, etc. or the shader will fail to compile with "use of undeclared identifier".

14. **`ARDirectionalLightEstimate.primaryLightDirection` is in camera-local space, not world space.** Despite the ARKit header comment saying "world space," empirical observation shows the direction is 90° off when the device is in landscape (matching a camera-to-world rotation mismatch). Fix: multiply by `frame.camera.transform` with `w=0` before storing: `let worldDir = (frame.camera.transform * SIMD4<Float>(rawDir, 0)).xyz`. If the result is 180° inverted instead, also negate: `lightDirection = normalize(-worldDir)`.

_(Add new gotchas here as discovered)_
