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

**Date:** Mar 28, 2026
**Current Phase:** Phase 1 — Project Setup & Plane Detection
**Last Milestone:** Documentation scaffolding complete; no Swift code written yet.
**Next Task:** Replace SwiftData template with ARViewContainer in ContentView.swift,
then implement ARSessionManager skeleton with horizontal plane detection.

---

## What Was Accomplished

This was a **documentation-only session** — no Swift or Metal code was written.

**Files created/updated:**
- `CLAUDE.md` — appended 4 new gotchas, `## Build Commands`, `## GPU Frame Capture`, `## Test Strategy`, `## Folder Structure (Planned)` sections; updated Xcode 16+ coding convention note
- `docs/ARCHITECTURE.md` — written from scratch: MVVM overview, folder structure, all 4 manager component specs, ASCII data flow diagram, Metal pipeline design, threading model, key API reference table
- `docs/SHADOW_MATH.md` — written from scratch: full planar shadow matrix derivation (general + horizontal simplified), Swift/SIMD code sketch, degeneracy guard, penumbra radial falloff with MSL pseudocode, lux→intensity mapping, color temperature tint (stretch), disc mesh sizing, calibration table
- `docs/PROGRESS.md` — written from scratch: 6-week tracker with Week 1 pre-populated from proposal timeline, Weeks 2–6 as structured templates, stretch goals, Report & Presentation checklist
- `docs/HANDOFF.md` — written from scratch: session start instructions, architecture snapshot, cumulative gotchas list
- `docs/DECISIONS.md` — written from scratch: 6 ADRs (ARKit, RealityKit, CustomMaterial, Metal/MSL, @Observable, horizontal planes only), each with Decision/Rationale/Rejected Alternatives

---

## What Was Left Incomplete

No Swift code has been written yet. The Xcode project still contains the default SwiftData template (Item.swift, ContentView.swift with SwiftData boilerplate). All Week 1 goals remain to be implemented.

---

## Unresolved Bugs

None — no code has been written yet.

---

## Key Decisions Made

All major architecture decisions are now formally recorded as ADRs in `docs/DECISIONS.md`. No new decisions beyond what was already in the proposal.

---

## Exact Next Steps

1. **Delete SwiftData template code:** Remove `Item.swift`; strip SwiftData imports and `@Query` from `ContentView.swift`.
2. **Create `ARViewContainer.swift`** in `Penumbra/Views/` — `UIViewRepresentable` wrapping `ARView`. Update `ContentView.swift` to host it.
3. **Create `ARSessionManager.swift`** in `Penumbra/Managers/` — `@Observable @MainActor` class; configure `ARWorldTrackingConfiguration` with `.horizontalPlane` detection and `environmentTexturing: .automatic`; start session.
4. **Add debug plane visualization** — add a translucent `ModelEntity` plane mesh on each detected `ARPlaneAnchor` so you can confirm detection is working on device.
5. **Test on physical iPad** — build and run, walk around a table/floor, confirm plane anchors appear.
6. **Commit** once plane detection is verified on device.

---

## Architecture Snapshot

Quick reference for re-orientation at the start of any session:

### 4 Manager Classes

| Manager | Owns | Publishes |
|---------|------|-----------|
| `ARSessionManager` | ARSession, ARWorldTrackingConfiguration | detectedPlanes, currentFrame |
| `SceneManager` | ARView, all ModelEntities | placedObjects |
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

_(Add new gotchas here as discovered)_
