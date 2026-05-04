# Penumbra

Real-time AR shadow casting for iOS. Places virtual 3D objects on detected surfaces and casts soft, physically-grounded shadows driven by ARKit lighting estimation.

Built for CS 4361 Computer Graphics — Spring 2026, UT Dallas.

---

## Demo

Shadow direction, softness, and intensity update in real time based on the estimated light in the room. An ambient occlusion contact spot keeps the object grounded in diffuse lighting conditions where directional estimation is unavailable.

---

## Tech Stack

- **Swift** / SwiftUI
- **ARKit** — plane detection, `ARDirectionalLightEstimate`
- **RealityKit** — scene graph, `CustomMaterial` API
- **Metal / MSL** — custom vertex + fragment shaders for the shadow pipeline

Targets: iPad Air M3, iPhone 15 Pro · iOS 17+ · Xcode 16+

---

## How to Build and Run

A physical device is required — AR does not run in the simulator.

1. Open `Penumbra/Penumbra.xcodeproj` in Xcode
2. Connect a physical iPhone or iPad
3. Select your device as the run destination
4. Select the **Penumbra** scheme and press **Run** (⌘R)

To build from the command line:

```bash
# Find your device UDID
xcrun devicectl list devices

# Build
xcodebuild -scheme Penumbra \
  -destination 'platform=iOS,id=<DEVICE_UDID>' \
  -configuration Debug build
```

---

## Usage

1. Point the camera at a flat horizontal surface and move slowly — a grid fades in as planes are detected
2. Tap the surface to place a sphere
3. The shadow appears immediately and tracks room lighting
4. Open the sidebar (swipe from the right edge) to:
   - Change the object material (6 options)
   - Switch between Auto / Manual / Off light modes
   - Adjust shadow direction and intensity manually
5. Pinch the sphere to scale it

---

## Project Structure

```
Penumbra/
├── Views/
│   ├── ContentView.swift        — SwiftUI root
│   ├── ARViewContainer.swift    — UIViewRepresentable wrapping ARView
│   └── HUDOverlayView.swift     — Liquid Glass sidebar HUD
├── Managers/
│   ├── ARSessionManager.swift   — ARSession, plane detection
│   ├── SceneManager.swift       — entity placement, tap + pinch gestures
│   ├── LightingEstimator.swift  — ARLightEstimate wrapper
│   └── ShadowRenderer.swift     — CustomMaterial bridge, shadow disc lifecycle
├── Shaders/
│   ├── ShadowVertex.metal       — geometry modifier (no-op; disc positioned by CPU)
│   ├── ShadowFragment.metal     — radial falloff + directional gradient
│   └── PlaneGrid.metal          — plane grid overlay with fade animation
└── Models/
    ├── ShadowMath.swift         — pure-Swift shadow math helpers
    └── HUDState.swift           — @Observable HUD state carrier
```

---

## Shadow Pipeline

1. ARKit detects a horizontal plane
2. `LightingEstimator` extracts light direction and intensity from `ARDirectionalLightEstimate`
3. `ShadowRenderer` computes the shadow center (ray–plane intersection, CPU-side) and packs direction + intensity into shader uniforms
4. `ShadowFragment.metal` applies a radial `smoothstep` falloff modulated by an asymmetric directional gradient — encoding light direction as a shader effect rather than disc movement
5. A second AO disc (tighter radius, constant intensity) is composited above the directional shadow for contact grounding
