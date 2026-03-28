# Penumbra — Weekly Progress Tracker
CS 4361 Final Project | Spring 2026 | Zain Karim

**How to update:** At the end of each work session, fill in the Status, check
completed goals, log hours, and note any blockers. Update HANDOFF.md at the
same time.

---

## Week 1 — Project Setup & Plane Detection
**Dates:** Mar 28–30 | **Budget:** 6 hrs | **Deadline:** Mar 30

### Goals
- [ ] Create Xcode project (Penumbra, SwiftUI, iOS 17+)
- [ ] Replace SwiftData template code with ARViewContainer (UIViewRepresentable)
- [ ] Implement ARSessionManager skeleton (@Observable, ARWorldTrackingConfiguration)
- [ ] Enable horizontal plane detection (.horizontalPlane)
- [ ] Verify plane detection renders visually on device (debug plane visualization)
- [ ] Create Managers/, Views/, Shaders/, Models/ folder structure
- [ ] Commit working plane detection milestone

### Status
Started Mar 28

### Hours Log
| Date | Hours | Notes |
|------|-------|-------|
| Mar 28 | — | |
| Mar 29 | — | |
| Mar 30 | — | |
| **Total** | **—** | |

### Blockers
_None yet_

---

## Week 2 — Scene Geometry & Object Placement
**Dates:** Mar 31–Apr 6 | **Budget:** 8 hrs | **Deadline:** Apr 6

### Goals
- [ ] Implement tap-to-place gesture in SceneManager
- [ ] ARView.raycast() against detected horizontal planes
- [ ] Place a built-in 3D model (sphere or cube ModelEntity) at tap location
- [ ] Anchor entity to detected plane anchor
- [ ] Basic scene lighting (default RealityKit environment lighting)
- [ ] Verify object stays grounded as device moves
- [ ] Commit working object placement milestone

### Status
_Not started_

### Hours Log
| Date | Hours | Notes |
|------|-------|-------|
| | | |
| **Total** | **—** | |

### Blockers
_None_

---

## Week 3 — Lighting Estimation
**Dates:** Apr 7–13 | **Budget:** 10 hrs | **Deadline:** Apr 13

### Goals
- [ ] Implement LightingEstimator (@Observable)
- [ ] Integrate ARLightEstimate (ambientIntensity, ambientColorTemperature)
- [ ] Guard and extract ARDirectionalLightEstimate.primaryLightDirection
- [ ] Implement lux → [0,1] intensity mapping (see SHADOW_MATH.md §3)
- [ ] Map estimated light direction to virtual scene light source in real time
- [ ] Visual debug: display light direction vector as an arrow entity
- [ ] Commit working lighting estimation milestone

### Status
_Not started_

### Hours Log
| Date | Hours | Notes |
|------|-------|-------|
| | | |
| **Total** | **—** | |

### Blockers
_None_

---

## Week 4 — Shadow Casting System (Core)
**Dates:** Apr 14–20 | **Budget:** 18–20 hrs | **Deadline:** Apr 20

### Goals
- [ ] Implement ShadowVertex.metal (planar shadow projection, see SHADOW_MATH.md §1)
- [ ] Implement ShadowFragment.metal (alpha falloff, see SHADOW_MATH.md §2)
- [ ] Implement ShadowRenderer: CustomMaterial bridge, disc mesh generation
- [ ] Disable RealityKit built-in shadow pass on placed objects
- [ ] Wire ShadowRenderer into SceneManager: create shadow entity per placed object
- [ ] Update shadow matrix each frame with current light direction and plane Y
- [ ] Verify shadow moves correctly as device moves around object
- [ ] Verify shadow softens/darkens with real lighting changes
- [ ] Commit working shadow casting milestone

### Status
_Not started_

### Hours Log
| Date | Hours | Notes |
|------|-------|-------|
| | | |
| **Total** | **—** | |

### Blockers
_None_

---

## Week 5 — Shading & Visual Polish
**Dates:** Apr 21–25 | **Budget:** 6 hrs | **Deadline:** Apr 25

### Goals
- [ ] Ambient occlusion at object contact point (dark spot at base of object)
- [ ] Virtual object material response to ARKit ambient intensity
- [ ] Tune shadow calibration parameters (innerRadius, referenceIntensity, etc.)
- [ ] Remove debug plane visualization (or make it togglable)
- [ ] On-device visual review: shadow looks plausible in multiple environments
- [ ] Commit polished shadow milestone

### Status
_Not started_

### Hours Log
| Date | Hours | Notes |
|------|-------|-------|
| | | |
| **Total** | **—** | |

### Blockers
_None_

---

## Week 6 — Scene Refinement & Demo Build
**Dates:** Apr 26–28 | **Budget:** 6 hrs | **Deadline:** Apr 28

### Goals
- [ ] Shadow quality tuning pass (edge softness, disc radius calibration)
- [ ] UI polish (minimal SwiftUI HUD, tap instructions)
- [ ] Demo scenario design: choose 2–3 real environments for video
- [ ] Performance profiling on iPad with Instruments (Metal System Trace)
- [ ] Record demo video
- [ ] Tag stable demo commit

### Status
_Not started_

### Hours Log
| Date | Hours | Notes |
|------|-------|-------|
| | | |
| **Total** | **—** | |

### Blockers
_None_

---

## [Stretch] OBJ Model Import
**Target date:** Apr 28 | **Budget:** 6 hrs
**Condition:** Pursue only if all core goals are complete and stable by Apr 25.

### Goals
- [ ] File picker (UIDocumentPickerViewController) for .obj files
- [ ] Parse OBJ using tinyobjloader or ModelIO
- [ ] Dynamic model swap at runtime
- [ ] Shadow disc radius adapts to loaded model AABB

### Status
_Deferred — begin only after Week 5 complete_

---

## [Stretch] visionOS Port
**Target date:** Apr 30 | **Budget:** 8 hrs
**Condition:** Pursue only if core + OBJ import are stable and Vision Pro hardware is accessible.

### Goals
- [ ] RealityKit scene adaptation for visionOS spatial computing
- [ ] Hand tracking for object placement (replace tap gesture)
- [ ] Mixed reality shadow display in visionOS passthrough
- [ ] Verify shadow pipeline compiles for visionOS target

### Status
_Deferred — contingent on hardware access_

---

## Report & Presentation
**Due:** May 2 | **Budget:** 6 hrs

### Report Sections
- [ ] Introduction & motivation
- [ ] Related work (how commercial AR handles shadows)
- [ ] System architecture (reference ARCHITECTURE.md)
- [ ] Shadow math derivation (reference SHADOW_MATH.md)
- [ ] Implementation challenges and gotchas
- [ ] Results: video stills, qualitative evaluation
- [ ] Stretch goal outcomes (if any)
- [ ] Conclusion & future work

### Presentation
- [ ] 5-minute demo video finalized
- [ ] Key slides: pipeline diagram, shadow math, live demo clips

---

## Stretch Goals Summary

| Goal | Condition | Est. Hours |
|------|-----------|------------|
| OBJ model import via file picker | Core stable by Apr 25 | 6 hrs |
| Multiple simultaneous objects | Core stable, time permitting | — |
| Shadow softness slider (UI) | Easy add during polish week | — |
| visionOS port | Core + OBJ stable + hardware access | 8 hrs |
