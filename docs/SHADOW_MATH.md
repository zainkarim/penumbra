# Penumbra — Shadow Math Reference
CS 4361 Final Project | Spring 2026 | Zain Karim

This document derives all shadow math used in the project: the planar projection
matrix, the penumbra edge falloff, the intensity mapping, and shadow mesh sizing.
It is the authoritative reference for `ShadowVertex.metal`, `ShadowFragment.metal`,
and the CPU-side matrix construction in `ShadowRenderer.swift`.

---

## 1. Planar Shadow Projection

### Problem Statement
Given:
- A directional light at direction **L** (unit vector pointing *toward* the light, world space).
- A horizontal plane defined by normal **n** = (0, 1, 0) and point **p₀** = (0, planeY, 0).
- A shadow-casting vertex **v** in world space.

Find **v'**: the point where the ray from **L** through **v** intersects the plane.

### Ray–Plane Intersection Derivation

The shadow ray from a directional light through vertex **v**:
```
P(t) = v - t * L
```
(subtracting because L points toward the light; shadow projects opposite)

Plane equation: `n · (P - p₀) = 0`

Substituting:
```
n · (v - t*L - p₀) = 0
n · (v - p₀) = t * (n · L)
t = (n · (v - p₀)) / (n · L)
v' = v - t * L
```

### 4×4 Shadow Matrix (Column-Major)

For light direction **L** = (lx, ly, lz), plane normal **n** = (nx, ny, nz),
and plane offset `d = n · p₀`:

```
dot = n · L

     ┌                                              ┐
     │  dot-lx*nx    -ly*nx    -lz*nx      0        │
M =  │   -lx*ny    dot-ly*ny   -lz*ny      0        │
     │   -lx*nz     -ly*nz   dot-lz*nz     0        │
     │   -lx*d      -ly*d      -lz*d      dot       │
     └                                              ┘
```

Apply as: `v' = M * float4(v, 1)`, then divide by w (= dot, the homogeneous coord).

### Simplified Form for Horizontal Y-Up Plane

For **n** = (0, 1, 0) and `planeY = y₀`, so `d = y₀`:
```
dot = L.y

M[col][row] (column-major):

col 0: [ L.y,  -L.x,    0,  -L.x*y₀ ]
col 1: [   0,     0,    0,      -y₀  ]
col 2: [   0,  -L.z,  L.y,  -L.z*y₀ ]
col 3: [   0,     0,    0,      L.y  ]
```

### Swift/SIMD Implementation Sketch

```swift
// In ShadowRenderer.swift
func makeShadowMatrix(lightDir: SIMD3<Float>, planeY: Float) -> float4x4 {
    let L = normalize(lightDir)   // points toward the light source
    let d = planeY
    let dot = L.y                 // n=(0,1,0) so n·L = L.y

    guard abs(dot) > 0.001 else {
        // Degenerate: light nearly grazing plane — return identity (shadow invisible)
        return float4x4(1)
    }

    // Columns of float4x4 (column-major)
    let col0 = SIMD4<Float>( dot,        -L.x,    0,  -L.x * d)
    let col1 = SIMD4<Float>( 0,           0,      0,  -d       )
    let col2 = SIMD4<Float>( 0,          -L.z,    dot, -L.z * d)
    let col3 = SIMD4<Float>( 0,           0,      0,   dot     )

    return float4x4(col0, col1, col2, col3)
}
```

### Degeneracy Guard

When `|L.y| < 0.001` the light is nearly grazing the plane and the shadow
projects to infinity. Return the identity matrix and set `shadowIntensity = 0`
to make the shadow invisible. This prevents GPU divide-by-zero and avoids
visually jarring artifacts at extreme sun angles.

---

## 2. Penumbra Edge Falloff

### Physical Phenomenon

A hard shadow edge (umbra only) occurs only with a perfect point light at
infinite distance. Real light sources have finite angular size, creating a
**penumbra**: a gradient transition zone between full shadow and full light.

Penumbra approximates this with a radial alpha gradient on the shadow disc:
fully opaque at the center (directly beneath the object), fading smoothly to
transparent at the disc edge.

### Radial Coordinate System

The shadow disc mesh is generated in the XZ plane, centered at the origin,
with normalized radius 1 in object space. Each vertex carries a `radialCoord: float2`
varying equal to its normalized XZ position. In the fragment shader:

```
r = length(radialCoord)    // 0 at center, 1 at disc edge
```

### Falloff Function

```
alpha(r) = shadowIntensity * (1.0 - smoothstep(innerRadius, 1.0, r))
```

Where:
- `shadowIntensity` ∈ [0, 1]: overall darkness (driven by lux mapping, see §3)
- `innerRadius` ∈ [0, 1]: inner edge of the penumbra gradient.
  - At `r < innerRadius`: shadow is at full `shadowIntensity` (hard core)
  - At `r = 1.0`: shadow is fully transparent
  - Default: `innerRadius = 0.4`
- `smoothstep(a, b, x)` = Hermite interpolation: 0 when x ≤ a, 1 when x ≥ b,
  smooth S-curve in between — gives a physically plausible soft edge without
  a multi-sample blur pass.

### MSL Fragment Shader (Pseudocode)

```metal
// ShadowFragment.metal
struct ShadowUniforms {
    float shadowIntensity;
    float innerRadius;
};

fragment float4 shadowFragment(
    VertexOut in [[stage_in]],
    constant ShadowUniforms &uniforms [[buffer(0)]])
{
    float r = length(in.radialCoord);
    float alpha = uniforms.shadowIntensity *
                  (1.0 - smoothstep(uniforms.innerRadius, 1.0, r));
    return float4(0.0, 0.0, 0.0, alpha);
}
```

The `CustomMaterial` lighting model must be `.unlit` so RealityKit does not
apply PBR shading on top of the shadow disc alpha.

---

## 3. Intensity Mapping

### ARKit → [0,1] Normalization

ARKit reports `ambientIntensity` in **lux** (luminous flux per unit area).
Typical indoor values: 100–500 lux. Bright outdoor sunlight: 10,000+ lux.

We map to [0, 1] with a reference intensity:
```
shadowIntensity = clamp(ambientIntensity / referenceIntensity, 0.0, 1.0)
```

Default `referenceIntensity = 1000.0` lux.

Example values:
| Environment | Approx. Lux | shadowIntensity |
|-------------|-------------|-----------------|
| Dim room | 100–200 | 0.10–0.20 |
| Office lighting | 300–500 | 0.30–0.50 |
| Bright indoor | 800 | 0.80 |
| Outdoor overcast | 1000+ | 1.00 (clamped) |
| Direct sunlight | 10,000+ | 1.00 (clamped) |

### Swift Implementation Sketch

```swift
// In LightingEstimator.swift
let referenceIntensity: Float = 1000.0

func updateIntensity(from estimate: ARLightEstimate) {
    let lux = Float(estimate.ambientIntensity)
    self.intensity = min(lux / referenceIntensity, 1.0)
}
```

---

## 4. Color Temperature → Shadow Tint (Stretch Goal)

ARKit's `ambientColorTemperature` returns Kelvin (typically 2700–6500 K).
Shadows are perceptually complementary to the light color: warm incandescent
light (low K) produces slightly cool/blue shadows; cool daylight (high K)
produces slightly warm/amber shadows.

Implementation approach (stretch goal):
1. Convert Kelvin → RGB using the Tanner Helland algorithm (piecewise polynomial
   approximation, suitable for real-time use).
2. Invert the hue to get the complementary shadow tint color.
3. Blend into the shadow fragment output:

```metal
float3 shadowColor = mix(float3(0,0,0), complementTint, uniforms.tintStrength);
return float4(shadowColor, alpha);
```

`tintStrength` default: 0.15 (subtle — should not overpower the darkness).

---

## 5. Shadow Mesh Sizing

### Disc Radius from Object AABB

The shadow disc must cover the object's ground footprint plus penumbra margin:

```
shadowRadius = max(aabb.extents.x, aabb.extents.z) * shadowRadiusMultiplier
```

Default `shadowRadiusMultiplier = 1.5` (50% margin for penumbra fade zone).

### Disc Mesh Generation

The disc is a triangle fan: 1 center vertex + N circumference vertices + 1
repeated first vertex to close the fan.

```swift
// In ShadowRenderer.swift — makeShadowMesh(radius:)
let N = 32
// Center vertex: position (0,0,0), radialCoord (0,0)
for i in 0..<N {
    let angle = Float(i) / Float(N) * 2 * .pi
    let x = cos(angle)   // normalized; scale by radius in vertex shader
    let z = sin(angle)
    // Vertex: position (x * radius, 0, z * radius)
    // radialCoord: (x, z) — length = 1 at disc edge
}
```

`radialCoord` is passed as a vertex attribute so the fragment shader can
compute `r = length(radialCoord)` without any additional texture lookup.

### Vertex Count Recommendation

| N | Visual quality | Notes |
|---|---------------|-------|
| 16 | Acceptable | Slight polygon edge visible up close |
| 32 | Good (default) | Smooth at all typical AR distances |
| 64 | Excellent | Only if performance headroom exists |

Do not use N < 12 (visible angular facets destroy the illusion).

---

## 6. Calibration Notes

Update this table as on-device calibration improves:

| Parameter | Default | Range | Notes |
|-----------|---------|-------|-------|
| `innerRadius` | 0.4 | 0.0–0.9 | Inner edge of penumbra. Lower = harder edge. |
| `referenceIntensity` | 1000.0 lux | 500–2000 | Lux value → shadowIntensity = 1.0 |
| `shadowRadiusMultiplier` | 1.5 | 1.0–3.0 | Disc radius as multiple of object AABB footprint |
| `zOffset` | +0.001 m | 0.0005–0.005 | Y offset above plane to prevent z-fighting |
| `discVertexCount` | 32 | 16–64 | N for shadow disc triangle fan |
| `tintStrength` | 0.15 | 0.0–0.3 | Shadow color temperature tint strength (stretch) |
