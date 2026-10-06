# Heat-map redesign: density-colorized fragment shader

- **Date:** 2026-05-30
- **Branch:** `feat/heatmap-density-shader`
- **Status:** Approved design, pending implementation plan

## Problem

The dive-activity and dive-site maps render a heat-map overlay
([`HeatMapLayer`](../../../lib/features/maps/presentation/widgets/heat_map_layer.dart))
that is too "pin-point": the clouds are tiny and barely visible, especially when
zoomed out to a regional or world view. Four compounding causes in the current
`_HeatMapPainter`:

1. **Fixed 30 px radius in screen space** — the blob is ~30 logical pixels at
   every zoom, so on a wide view it is a speck.
2. **Radius shrunk again by weight** — `radius * (0.5 + normalizedWeight * 0.5)`,
   so only the single most-weighted point gets the full radius.
3. **Alpha multiplied by per-point normalized weight** — `opacity * normalizedWeight`,
   so a low-count site next to a high-count one is driven to near-zero alpha.
4. **Single global-max normalization** — one heavily-dived "home" site crushes
   every other site's intensity toward zero.

There is also a latent control gap: `HeatMapSettings` carries `radius` and
`opacity`, but the controls widget only exposes an on/off toggle, so the values
are effectively frozen at 30 / 0.6.

## Decisions (locked with the user)

- **Look:** large, soft, diffuse clouds — an atmospheric glow over dive regions.
- **Weighting:** every site visible — soften the weighting so even a single-dive
  site shows a clear cloud, while favorites glow brightest.
- **Engine:** a true density-colorized heat-map implemented with a **fragment
  shader** (not a refinement of the per-point painter).
- **Controls:** no user-facing slider; ship good hard-tuned defaults.
- **Shader-load failure:** render nothing (graceful absence), not a non-shader
  fallback path.

## Goals

- Clouds are clearly visible and read as soft regional glow at world/regional
  zoom, separating into per-site detail as the user zooms in.
- Every site with coordinates shows a visible cloud; overlapping activity
  resolves into hotter colors (blue -> cyan -> green -> yellow -> orange -> red).
- No regression to the four `HeatMapLayer` call sites or to existing page tests.

## Non-goals (out of scope)

- A user-facing size/intensity slider (explicitly deferred).
- Changing marker/cluster rendering, providers' data sources, or the heat-map
  data model (`HeatMapPoint`, the two data providers).
- Per-call-site custom gradients (the unused `gradient` param is removed).

## Approach: two-pass density heat-map

### Pass 1 - accumulate density (CPU canvas -> offscreen image)

Draw **every point at the same large radius** as a soft radial **alpha** gradient
(single neutral color, e.g. white), additively blended with `BlendMode.plus`,
into an offscreen `ui.Image`. The accumulated value at each pixel is the local
**density**: bright where many clouds overlap, dim where one sits alone. Weight
controls per-point **intensity (brightness)**, never size.

Per-point center intensity (pure, testable):

```
intensity = floor + (1 - floor) * pow(weight / maxWeight, gamma)
```

with `floor ≈ 0.35`, `gamma = 0.5` (sqrt). This guarantees the faintest single
site still maps to a clearly visible palette color and replaces the harsh
single-max normalization. `maxWeight <= 0` -> render nothing.

Radial falloff: a soft multi-stop gradient from `intensity` at center to `0` at
the radius (approximating a bell), giving soft cloud edges.

### Pass 2 - colorize by density (GPU fragment shader)

A full-size quad is painted with a fragment shader that samples the density
image and maps **accumulated density -> palette color**, then applies overall
opacity and a soft edge. Colorizing by accumulated density (rather than
per-point weight) is what makes overlaps resolve into a clean hot color instead
of additively summing colored circles toward a blown-out white smear.

Shader uniforms / sampler (declaration order fixes the `setFloat`/`setImageSampler`
indices):

| Index | Kind        | Name           | Meaning                              |
| ----- | ----------- | -------------- | ------------------------------------ |
| 0,1   | float (vec2)| `uResolution`  | paint size in pixels                 |
| 2     | float       | `uOpacity`     | overall opacity (from settings)      |
| 3     | float       | `uEdgeSoftness`| density at which alpha reaches full  |
| 0     | sampler2D   | `uDensity`     | Pass-1 density image                 |

Shader logic (outline):

```glsl
#include <flutter/runtime_effect.glsl>
uniform vec2 uResolution;
uniform float uOpacity;
uniform float uEdgeSoftness;
uniform sampler2D uDensity;
out vec4 fragColor;

vec3 palette(float t) { /* 6-stop mix(): blue..red, matching _defaultGradient */ }

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;
  float density = texture(uDensity, uv).r;          // 0..1, clamped by plus blend
  float a = uOpacity * smoothstep(0.0, uEdgeSoftness, density);
  fragColor = vec4(palette(density) * a, a);        // premultiplied alpha
}
```

The 6 palette stops are the exact colors currently in `_defaultGradient`
(`#3B82F6, #06B6D4, #22C55E, #EAB308, #F97316, #EF4444`), hardcoded in GLSL.

## Components and files

- **NEW** `shaders/heatmap.frag` — the density->palette shader above.
- `pubspec.yaml` — add:
  ```yaml
  flutter:
    shaders:
      - shaders/heatmap.frag
  ```
- **NEW** `lib/features/maps/presentation/providers/heat_map_shader_provider.dart`
  — `FutureProvider<ui.FragmentProgram>` that loads & caches
  `FragmentProgram.fromAsset('shaders/heatmap.frag')` once.
- **NEW** `lib/features/maps/presentation/widgets/heat_map_density.dart` — pure,
  unit-testable helpers: `densityIntensity(weight, maxWeight, {floor, gamma})`,
  the falloff gradient stops builder, and `isPointVisible(offset, size, radius)`
  culling. Keeps the painter lean and the math TDD-able.
- **REWRITE** `lib/features/maps/presentation/widgets/heat_map_layer.dart` —
  becomes a `ConsumerStatefulWidget` that watches the shader provider, lazily
  creates one `ui.FragmentShader`, and disposes it. `_HeatMapPainter` runs the
  two passes and disposes the per-frame density image. The unused `gradient`
  param is removed.
- `lib/features/maps/presentation/providers/heat_map_providers.dart` — bump
  `HeatMapSettings` defaults: `radius` 30 -> **60**, `opacity` 0.6 -> **0.7**.
- **NEW** `test/features/maps/heat_map_density_test.dart`.
- The **4 call sites are unchanged** (they pass only `points`/`radius`/`opacity`):
  - `lib/features/maps/presentation/pages/dive_activity_map_page.dart`
  - `lib/features/dive_sites/presentation/pages/site_map_page.dart`
  - `lib/features/dive_sites/presentation/widgets/site_map_content.dart`
  - `lib/features/dive_log/presentation/widgets/dive_map_content.dart`

## Starting defaults (final-tuned live in the app)

| Param          | Value  | Role                                            |
| -------------- | ------ | ----------------------------------------------- |
| radius         | 60 px  | uniform cloud size for every point              |
| opacity        | 0.7    | overall overlay opacity                         |
| floor          | 0.35   | minimum per-point intensity (every site visible)|
| gamma          | 0.5    | sqrt weighting curve                            |
| edgeSoftness   | 0.15   | density at which shader alpha reaches full      |

## Error handling and edge cases

- Empty points or `maxWeight <= 0` -> render nothing.
- Shader still loading or load error -> render nothing (the overlay appears a
  frame late; this also keeps headless widget tests from crashing on shader
  compilation). Log the error with `debugPrint` only.
- Dispose the `ui.FragmentShader` on widget teardown and the density `ui.Image`
  each frame.
- Off-screen points are culled with radius padding before drawing (Pass 1).
- DPR: build the density buffer at the paint's logical size and set
  `uResolution` to match; verify `FlutterFragCoord` UV scaling on a hi-DPI
  device when running.

## Testing strategy

- **TDD the pure helpers** in `heat_map_density.dart` to >=80%:
  - `densityIntensity`: equals `floor` at weight 0, `1.0` at `weight == maxWeight`,
    monotonic increasing, `0` when `maxWeight <= 0`, sqrt lifts small weights.
  - falloff stops: center == intensity, edge == 0, ordered stops.
  - `isPointVisible`: inside/outside/edge-with-padding cases.
- **Shader render path:** verified by running the app, not golden tests —
  `FragmentProgram.fromAsset` likely will not compile in the headless
  `flutter test` engine, so goldens are unreliable. Verify visually on macOS
  (dev), at least one mobile target, and smoke-test the desktop targets.
- **Regression:** existing page tests must still pass; because the shader
  provider resolves to loading/error in the test engine, `HeatMapLayer` renders
  nothing rather than throwing.

## Risks and mitigations

- **Cross-platform shader support** (iOS/Android/macOS/Windows/Linux) — the
  accepted risk. Mitigation: graceful "render nothing" on load failure; smoke
  test desktop targets.
- **`FlutterFragCoord` DPR nuance** — verify UV mapping on a hi-DPI device.
- **Premultiplied-alpha output** — Flutter fragment shaders expect premultiplied
  alpha; the shader multiplies rgb by `a`. Confirm visually (a common source of
  too-bright / haloed output).

## Build sequence (for the plan)

1. Add the shader asset + pubspec wiring (no behavior yet).
2. Pure helpers `heat_map_density.dart` + tests (TDD).
3. Shader provider.
4. Rewrite `HeatMapLayer` + `_HeatMapPainter` to the two-pass pipeline.
5. Bump `HeatMapSettings` defaults.
6. `flutter analyze`, `dart format`, run the app, tune defaults, smoke-test
   platforms.
