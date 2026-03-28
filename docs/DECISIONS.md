# Penumbra — Architecture Decision Records
CS 4361 Final Project | Spring 2026 | Zain Karim

Each ADR captures a single technology or design decision: what was chosen,
why, and what was rejected. Add new ADRs as significant decisions are made.

---

## ADR-001 — ARKit over Vision Framework for Plane Detection

**Date:** Mar 28, 2026
**Status:** Accepted

### Decision
Use ARKit (`ARWorldTrackingConfiguration` with `.horizontalPlane` detection)
for all plane detection and scene understanding.

### Rationale
- ARKit is the primary Apple AR framework, directly integrated with RealityKit.
  Plane anchors (`ARPlaneAnchor`) are the correct abstraction for placing a
  shadow mesh on a detected surface.
- ARKit provides `ARLightEstimate` and `ARDirectionalLightEstimate` — the
  lighting data that drives the entire shadow pipeline. No other Apple framework
  exposes this in real time.
- ARKit's `ARFrame` gives per-frame camera data and world tracking, which are
  both required for real-time shadow matrix updates.
- Mature, well-documented API with extensive WWDC session coverage.

### Rejected Alternatives
- **Vision framework:** Designed for image analysis (object recognition,
  barcode detection, body pose), not spatial scene understanding. Does not
  provide plane geometry or lighting estimation. Not suitable for AR placement.
- **Core ML + custom plane segmentation:** Would require training a custom
  model and provides no lighting estimation or anchor management. Far more
  complex for no benefit over ARKit.

---

## ADR-002 — RealityKit over SceneKit

**Date:** Mar 28, 2026
**Status:** Accepted

### Decision
Use RealityKit as the 3D rendering framework, not SceneKit.

### Rationale
- RealityKit is Apple's current-generation AR rendering framework, designed
  from the ground up to work with ARKit. It handles the AR camera feed
  compositing, PBR rendering, and anchor-to-entity binding automatically.
- `CustomMaterial` — the API required for the custom Metal shadow shader
  pipeline — is a RealityKit API. It does not exist in SceneKit.
- RealityKit's entity-component system is a cleaner architecture than
  SceneKit's node tree for a manager-pattern codebase.
- First-class support for iOS 17+ Swift concurrency patterns (`@MainActor`,
  async/await).

### Rejected Alternatives
- **SceneKit:** Older framework, no `CustomMaterial` equivalent. SceneKit
  shaders use `SCNProgram` which is lower-level and requires more boilerplate
  for the same result. No longer receiving significant new features from Apple.
- **Metal rendering without RealityKit:** Writing a full AR renderer from
  scratch using Metal alone is feasible but massively out of scope for a
  6-week course project. RealityKit handles camera compositing, depth occlusion,
  and PBR lighting — none of which we want to reimplement.

---

## ADR-003 — CustomMaterial over Baked Textures / Standard Decals / Projective Shadow Maps

**Date:** Mar 28, 2026
**Status:** Accepted

### Decision
Implement shadow rendering via RealityKit's `CustomMaterial` API, backed by
custom Metal vertex and fragment shaders.

### Rationale
- `CustomMaterial` is the only RealityKit mechanism that allows direct GPU
  control over shadow geometry. It is the explicit requirement of the project
  proposal ("custom Metal shader pipeline").
- Provides complete control over the shadow projection math (vertex shader) and
  edge falloff (fragment shader) — the two core CS 4361 graphics concepts the
  project is meant to demonstrate.
- Allows per-frame uniform updates (light direction, intensity, plane position)
  without rebuilding geometry or materials.
- Directly connects to course material: the shadow matrix derivation maps to
  Lecture 2 (transformations/projections); the fragment alpha falloff maps to
  Lecture 4 (shading).

### Rejected Alternatives
- **Baked shadow texture:** A pre-rendered circular gradient blob texture placed
  on the floor. Widely used in games for performance. Rejected because it does
  not respond to real light direction — the shadow is always centered beneath
  the object, which is physically wrong and visually unconvincing. Defeats the
  purpose of the project.
- **RealityKit built-in shadow pass:** RealityKit provides a built-in
  shadow casting system. Rejected because (a) it cannot be driven by
  `ARDirectionalLightEstimate`, (b) it does not expose the soft-edge penumbra
  math we need to demonstrate, and (c) it conflicts with the custom shadow mesh
  (hence `.castsShadow = false` on placed objects).
- **Projective shadow map (render-to-texture):** Correct approach for complex
  scenes but requires a separate render pass and shadow map texture. Overkill
  for a single object on a flat horizontal plane where the analytic planar
  shadow matrix is exact.

---

## ADR-004 — Metal / MSL for Shadow Shaders

**Date:** Mar 28, 2026
**Status:** Accepted

### Decision
Write shadow shaders in Metal Shading Language (MSL).

### Rationale
- MSL is the only option for `CustomMaterial` shaders on iOS/macOS. There is no
  GLSL or HLSL path — Apple's GPU pipeline exclusively uses MSL.
- This is not a choice between alternatives; it is a constraint of the
  RealityKit `CustomMaterial` API.
- MSL is syntactically similar to C++ with SIMD extensions, which makes it
  accessible given Swift/C++ familiarity.

### Rejected Alternatives
- **GLSL:** Not supported on Apple hardware in this context.
- **HLSL:** Not supported on Apple hardware.
- **SceneKit SCNProgram (GLSL-like):** Would require switching to SceneKit,
  rejected per ADR-002.

### Notes
The Metal shader compile pipeline has a known gotcha: compile errors appear only
in the build log, not at runtime. RealityKit silently falls back to a default
material on shader compile failure. See CLAUDE.md "Known Constraints & Gotchas".

---

## ADR-005 — `@Observable` (iOS 17) over `ObservableObject`

**Date:** Mar 28, 2026
**Status:** Accepted

### Decision
Use the `@Observable` macro (Observation framework, iOS 17+) for all manager
classes instead of `ObservableObject` / `@Published`.

### Rationale
- `@Observable` is the modern replacement for `ObservableObject` in iOS 17+,
  which is the project's minimum deployment target.
- No need to annotate every published property with `@Published` — the macro
  automatically tracks access at the property level, giving more granular
  SwiftUI view updates.
- Cleaner syntax: no `@StateObject`, `@ObservedObject`, or `@EnvironmentObject`
  needed — just `@State var manager = ARSessionManager()`.
- Consistent with "use latest Swift patterns" coding convention in CLAUDE.md.

### Rejected Alternatives
- **`ObservableObject` / `@Published`:** Older pattern, still functional but
  deprecated in spirit for iOS 17+ code. Would require `@Published` on every
  property and the coarser `objectWillChange` notification mechanism.
- **Combine publishers:** More powerful than needed for this use case. `@Observable`
  is simpler for one-way data flow from managers to views.

---

## ADR-006 — Horizontal Planes Only (Vertical Planes as Stretch Goal)

**Date:** Mar 28, 2026
**Status:** Accepted

### Decision
The core shadow pipeline targets horizontal planes (floors, tables) only.
Vertical plane shadow casting is a stretch goal.

### Rationale
- Horizontal planes are by far the most common AR placement surface (floor,
  desk, table) and provide the clearest physical intuition for shadow casting
  (gravity down, shadow on the ground).
- The planar shadow matrix derivation (SHADOW_MATH.md §1) simplifies
  significantly for the horizontal case: **n** = (0, 1, 0), eliminating two
  of the four non-trivial matrix terms.
- `ARWorldTrackingConfiguration.planeDetection = .horizontalPlane` is simpler
  to configure and produces more reliable results than `.verticalPlane` in
  typical indoor environments.
- Vertical planes (walls) require handling the case where `n · L` approaches
  zero (light nearly parallel to wall), which adds complexity to the degeneracy
  guard without contributing to the core project goals.

### Rejected Alternatives
- **Both horizontal and vertical from the start:** Adds significant complexity
  (general-case shadow matrix, more edge cases in plane normal handling) without
  clear visual benefit for a floor-based demo. Can be added in Week 6 if time
  permits.
- **Vertical only:** No practical use case for this project.

---

## Future Decisions (Template)

Use this template for new ADRs:

```
## ADR-00X — [Title]

**Date:** [Date]
**Status:** Accepted / Proposed / Superseded by ADR-00Y

### Decision
[One sentence: what was chosen]

### Rationale
[Why this choice makes sense given the constraints]

### Rejected Alternatives
[What else was considered and why it was rejected]
```
