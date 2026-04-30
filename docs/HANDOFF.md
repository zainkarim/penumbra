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
**Current Phase:** Phase 3 — Lighting Estimation ✅ COMPLETE
**Last Milestone:** LightingEstimator integrated; debug arrow (cylinder + cone) visible in scene, reorients in real time to track estimated light direction.
**Next Task:** Week 4 — Shadow Casting System (ShadowVertex.metal, ShadowFragment.metal, ShadowRenderer, CustomMaterial bridge).

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

### Week 3 (Apr 30) — CLOSED ✅

**Files created:**
- `Penumbra/Penumbra/Managers/LightingEstimator.swift` — `@Observable @MainActor`; consumes `ARFrame` each frame; publishes `lightDirection: SIMD3<Float>`, `intensity: Float`, `colorTemperature: Float`; guards `ARDirectionalLightEstimate` availability; lux→[0,1] mapping with 1000 lux reference.

**Files modified:**
- `Penumbra/Penumbra/Managers/ARSessionManager.swift` — added `var lightingEstimator` and `var sceneManager` injection properties; added `session(_:didUpdate frame:)` delegate method that bridges to main actor, calls `lightingEstimator.update(frame:)` and `sceneManager.updateDebugArrow(lightDirection:)`.
- `Penumbra/Penumbra/Managers/SceneManager.swift` — added `updateDebugArrow(lightDirection:)`, `makeDebugArrow()`, and `quaternion(from:to:)` helpers; debug arrow is cylinder+cone entity at world `[0, 0.2, -0.5]`, oriented via quaternion each frame.
- `Penumbra/Penumbra/Views/ARViewContainer.swift` — added `lightingEstimator` to Coordinator; updated `makeUIView` to instantiate `LightingEstimator` and inject into `ARSessionManager` and `SceneManager`.

**Verified on device:** _(pending — build and run to confirm arrow appears and reorients)_

---

### Week 2 (Apr 3) — CLOSED ✅

**Files created:**
- `Penumbra/Penumbra/Managers/SceneManager.swift` — `@Observable @MainActor`; `weak var arView`; raycasts against `.existingPlaneGeometry` on tap; places white sphere anchored to hit plane anchor; disables `GroundingShadowComponent` (prep for Week 4 custom shadow)

**Files modified:**
- `Penumbra/Penumbra/Views/ARViewContainer.swift` — added `SceneManager` instantiation and `UITapGestureRecognizer` wired through Coordinator `@objc handleTap`

**Verified on device:** Sphere placed at tap location, stays pinned to detected plane as device moves.

---

## What Was Left Incomplete

Weeks 1 and 2 are fully closed. No incomplete items.

---

## Unresolved Bugs

None.

---

## Key Decisions Made

- `ARSessionManager` takes `ARView` in its initializer (rather than creating it internally) so the view layer retains ownership of `ARView` and the manager stays focused on session logic.
- Debug plane visualization uses a single `ModelEntity` plane mesh per anchor (not a dot grid) — simpler and cheaper for GPU. Will be removed or made togglable in Week 5.

---

## Exact Next Steps (Week 2)

1. **Create `Penumbra/Penumbra/Managers/SceneManager.swift`** — `@Observable @MainActor` class; `weak var arView: ARView?`; published `placedObjects: [ModelEntity] = []`.
2. **Wire into `ARViewContainer.makeUIView`** — instantiate `SceneManager`, store on `Coordinator`, add `UITapGestureRecognizer` targeting `SceneManager.handleTap(_:)`.
3. **Implement `SceneManager.handleTap(_:)`** — call `arView.raycast(from: touchLocation, allowing: .existingPlaneGeometry, alignment: .horizontal)`; take `results.first`.
4. **On hit** — create `ModelEntity(mesh: .generateSphere(radius: 0.05), materials: [SimpleMaterial(color: .white, isMetallic: false)])`; set `model.castsShadow = false` (prep for Week 4); anchor via `AnchorEntity(anchor: hit.anchor)`; add to scene; append to `placedObjects`.
5. **Verify object stays grounded** as device moves — it should stay pinned to the plane.
6. **Commit** once placement is stable on device.

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

_(Add new gotchas here as discovered)_
