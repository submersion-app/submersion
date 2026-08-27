# Density-Colorized Heat-Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the tiny, pin-point heat-map blobs with large, soft, density-colorized clouds where every dive site is visible and overlapping activity glows hotter.

**Architecture:** Two-pass render. Pass 1 accumulates every point as a soft radial alpha blob (additive blend) into an offscreen `ui.Image` — the density field. Pass 2 paints a full-screen quad with a fragment shader that maps accumulated density through a blue->red palette. Pure helper math is extracted for unit testing; the shader program is loaded once via a cached Riverpod `FutureProvider`.

**Tech Stack:** Flutter, `dart:ui` (`FragmentProgram`, `PictureRecorder`, `Canvas`), flutter_map (`MapCamera`), Riverpod, GLSL fragment shader.

**Spec:** `docs/superpowers/specs/2026-05-30-heatmap-density-shader-design.md`

---

## File Structure

| File | Responsibility |
| ---- | -------------- |
| `lib/features/maps/presentation/widgets/heat_map_density.dart` (NEW) | Pure, testable math: per-point intensity curve, blob gradient stops, off-screen culling. No Flutter bindings. |
| `test/features/maps/heat_map_density_test.dart` (NEW) | Unit tests for the pure helpers. |
| `shaders/heatmap.frag` (NEW) | GLSL fragment shader: density -> palette colorization. |
| `lib/features/maps/presentation/providers/heat_map_shader_provider.dart` (NEW) | `FutureProvider<ui.FragmentProgram>` that loads & caches the compiled shader once. |
| `lib/features/maps/presentation/widgets/heat_map_layer.dart` (REWRITE) | `ConsumerStatefulWidget` + two-pass `CustomPainter`. Owns the `FragmentShader` lifecycle. |
| `lib/features/maps/presentation/providers/heat_map_providers.dart` (MODIFY) | Bump `HeatMapSettings` defaults (radius 30->60, opacity 0.6->0.7). |
| `pubspec.yaml` (MODIFY) | Register the shader asset. |

The 4 `HeatMapLayer` call sites pass only `points`/`radius`/`opacity` and are unchanged.

---

## Task 1: Pure density helpers (TDD)

**Files:**
- Create: `lib/features/maps/presentation/widgets/heat_map_density.dart`
- Test: `test/features/maps/heat_map_density_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/features/maps/heat_map_density_test.dart`:

```dart
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_density.dart';

void main() {
  group('densityIntensity', () {
    test('returns 0 when maxWeight <= 0', () {
      expect(densityIntensity(5, 0), 0.0);
      expect(densityIntensity(5, -1), 0.0);
    });

    test('returns the floor for the lowest weight', () {
      expect(densityIntensity(0, 10), closeTo(0.35, 1e-9));
    });

    test('returns 1.0 when weight equals maxWeight', () {
      expect(densityIntensity(10, 10), closeTo(1.0, 1e-9));
    });

    test('is monotonic increasing in weight', () {
      final a = densityIntensity(1, 10);
      final b = densityIntensity(5, 10);
      final c = densityIntensity(9, 10);
      expect(a, lessThan(b));
      expect(b, lessThan(c));
    });

    test('sqrt curve lifts small weights (normalized 0.25 -> 0.675)', () {
      expect(densityIntensity(2.5, 10), closeTo(0.35 + 0.65 * 0.5, 1e-9));
    });

    test('respects custom floor and gamma', () {
      expect(densityIntensity(0, 10, floor: 0.5), closeTo(0.5, 1e-9));
      expect(
        densityIntensity(5, 10, floor: 0.0, gamma: 1.0),
        closeTo(0.5, 1e-9),
      );
    });
  });

  group('densityBlobGradient', () {
    test('center alpha equals intensity, edge is transparent', () {
      final g = densityBlobGradient(0.6);
      expect(g.colors.first.a, closeTo(0.6, 1e-6));
      expect(g.colors.last.a, closeTo(0.0, 1e-6));
    });

    test('stops run 0..1 and match colors length', () {
      final g = densityBlobGradient(0.5);
      expect(g.stops.first, 0.0);
      expect(g.stops.last, 1.0);
      expect(g.stops.length, g.colors.length);
    });

    test('clamps intensity into range', () {
      expect(densityBlobGradient(2.0).colors.first.a, closeTo(1.0, 1e-6));
      expect(densityBlobGradient(-1.0).colors.first.a, closeTo(0.0, 1e-6));
    });
  });

  group('isPointVisible', () {
    const size = Size(200, 100);

    test('inside is visible', () {
      expect(isPointVisible(const Offset(100, 50), size, 60), isTrue);
    });

    test('far off-screen beyond radius is culled', () {
      expect(isPointVisible(const Offset(-100, 50), size, 60), isFalse);
      expect(isPointVisible(const Offset(400, 50), size, 60), isFalse);
    });

    test('just off-screen within radius padding is visible', () {
      expect(isPointVisible(const Offset(-30, 50), size, 60), isTrue);
      expect(isPointVisible(const Offset(230, 50), size, 60), isTrue);
    });
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/maps/heat_map_density_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'submersion' ... heat_map_density.dart` / `densityIntensity` is not defined.

- [ ] **Step 3: Write the implementation**

Create `lib/features/maps/presentation/widgets/heat_map_density.dart`:

```dart
import 'dart:math' as math;
import 'dart:ui';

/// Pure helpers for the density heat-map render passes.
///
/// Kept free of Flutter bindings so they can be unit-tested directly.

/// Per-point center intensity for the density accumulation pass.
///
/// Returns a value in `[floor, 1.0]`: a site at [maxWeight] returns 1.0, while
/// the faintest site returns [floor], guaranteeing it stays visible. The
/// [gamma] curve (gamma < 1, e.g. sqrt) lifts small weights so a single "home"
/// site no longer crushes everything else. Returns 0 when [maxWeight] <= 0.
double densityIntensity(
  double weight,
  double maxWeight, {
  double floor = 0.35,
  double gamma = 0.5,
}) {
  if (maxWeight <= 0) return 0.0;
  final normalized = (weight / maxWeight).clamp(0.0, 1.0);
  final softened = math.pow(normalized, gamma).toDouble();
  return floor + (1.0 - floor) * softened;
}

/// Radial-gradient colors + stops for a single density blob.
///
/// Uses white so the density pass records a single accumulating channel; the
/// alpha carries [intensity] at the center and falls to 0 at the edge with a
/// soft mid-stop for a bell-like cloud. [intensity] is clamped to `[0, 1]`.
({List<Color> colors, List<double> stops}) densityBlobGradient(
  double intensity,
) {
  final i = intensity.clamp(0.0, 1.0);
  return (
    colors: [
      Color.fromRGBO(255, 255, 255, i),
      Color.fromRGBO(255, 255, 255, i * 0.5),
      Color.fromRGBO(255, 255, 255, 0.0),
    ],
    stops: const [0.0, 0.55, 1.0],
  );
}

/// Whether a blob centered at [screen] can contribute to the [size] canvas,
/// given cloud [radius]. Includes radius padding so a center just off-screen
/// still renders its visible edge.
bool isPointVisible(Offset screen, Size size, double radius) {
  return screen.dx >= -radius &&
      screen.dx <= size.width + radius &&
      screen.dy >= -radius &&
      screen.dy <= size.height + radius;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/maps/heat_map_density_test.dart`
Expected: PASS — all 12 tests green.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format lib/features/maps/presentation/widgets/heat_map_density.dart test/features/maps/heat_map_density_test.dart
flutter analyze
git add lib/features/maps/presentation/widgets/heat_map_density.dart test/features/maps/heat_map_density_test.dart
git commit -m "feat(maps): add density-heatmap helper functions with tests"
```

Expected: `flutter analyze` reports no new issues; commit succeeds.

---

## Task 2: Fragment shader asset

**Files:**
- Create: `shaders/heatmap.frag`
- Modify: `pubspec.yaml` (flutter section)

- [ ] **Step 1: Create the shader**

Create `shaders/heatmap.frag`:

```glsl
#version 460 core

#include <flutter/runtime_effect.glsl>

// Uniform declaration order fixes the Dart-side indices:
//   setFloat(0) = uResolution.x   setFloat(1) = uResolution.y
//   setFloat(2) = uOpacity        setFloat(3) = uEdgeSoftness
//   setImageSampler(0) = uDensity
uniform vec2 uResolution;
uniform float uOpacity;
uniform float uEdgeSoftness;
uniform sampler2D uDensity;

out vec4 fragColor;

// 6-stop palette matching the previous _defaultGradient.
vec3 palette(float t) {
  vec3 c0 = vec3(0.231, 0.510, 0.965); // #3B82F6 blue
  vec3 c1 = vec3(0.024, 0.714, 0.831); // #06B6D4 cyan
  vec3 c2 = vec3(0.133, 0.773, 0.369); // #22C55E green
  vec3 c3 = vec3(0.918, 0.702, 0.031); // #EAB308 yellow
  vec3 c4 = vec3(0.976, 0.451, 0.086); // #F97316 orange
  vec3 c5 = vec3(0.937, 0.267, 0.267); // #EF4444 red
  float x = clamp(t, 0.0, 1.0) * 5.0;
  vec3 c = c0;
  c = mix(c, c1, clamp(x - 0.0, 0.0, 1.0));
  c = mix(c, c2, clamp(x - 1.0, 0.0, 1.0));
  c = mix(c, c3, clamp(x - 2.0, 0.0, 1.0));
  c = mix(c, c4, clamp(x - 3.0, 0.0, 1.0));
  c = mix(c, c5, clamp(x - 4.0, 0.0, 1.0));
  return c;
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uResolution;
  float density = texture(uDensity, uv).r;
  // Soft edge: alpha ramps from 0 to full as density crosses uEdgeSoftness.
  float a = uOpacity * smoothstep(0.0, uEdgeSoftness, density);
  vec3 rgb = palette(density);
  // Flutter fragment shaders output premultiplied alpha.
  fragColor = vec4(rgb * a, a);
}
```

- [ ] **Step 2: Register the shader in pubspec.yaml**

In `pubspec.yaml`, locate the `flutter:` section:

```yaml
flutter:
  generate: true
  uses-material-design: true

  assets:
    - assets/data/
    - assets/data/tide/
    - assets/icon/
```

Add a `shaders:` block immediately after the `assets:` block (same 2-space indent under `flutter:`):

```yaml
  shaders:
    - shaders/heatmap.frag
```

- [ ] **Step 3: Fetch packages so the shader is registered**

Run: `flutter pub get`
Expected: completes with `Got dependencies!` (or `Resolving dependencies...` then exit 0). Note: the shader is compiled at app build time, not by `pub get`; full validation happens when the app runs in Task 6.

- [ ] **Step 4: Commit**

```bash
git add shaders/heatmap.frag pubspec.yaml
git commit -m "build(maps): add density-colorized heat-map fragment shader"
```

Expected: commit succeeds.

---

## Task 3: Shader program provider

**Files:**
- Create: `lib/features/maps/presentation/providers/heat_map_shader_provider.dart`

- [ ] **Step 1: Write the provider**

Create `lib/features/maps/presentation/providers/heat_map_shader_provider.dart`:

```dart
import 'dart:ui' as ui;

import 'package:submersion/core/providers/provider.dart';

/// Loads and caches the compiled heat-map fragment program once.
///
/// `FutureProvider` keeps a single resolved [ui.FragmentProgram] for the app's
/// lifetime, so every [HeatMapLayer] reuses the same compiled program. On load
/// failure the AsyncValue surfaces the error and the layer renders nothing.
final heatMapShaderProgramProvider = FutureProvider<ui.FragmentProgram>((ref) {
  return ui.FragmentProgram.fromAsset('shaders/heatmap.frag');
});
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: no new issues. (`FutureProvider` and `Ref` come from the `core/providers/provider.dart` barrel, which re-exports flutter_riverpod — the same import used by `heat_map_providers.dart`.)

- [ ] **Step 3: Commit**

```bash
git add lib/features/maps/presentation/providers/heat_map_shader_provider.dart
git commit -m "feat(maps): load and cache heat-map fragment program"
```

Expected: commit succeeds.

---

## Task 4: Enlarge default heat-map settings

**Files:**
- Modify: `lib/features/maps/presentation/providers/heat_map_providers.dart:75-79`

- [ ] **Step 1: Bump the defaults**

In `lib/features/maps/presentation/providers/heat_map_providers.dart`, the `HeatMapSettings` constructor currently reads:

```dart
  const HeatMapSettings({
    this.opacity = 0.6,
    this.radius = 30.0,
    this.isVisible = true,
  });
```

Change the two default values to:

```dart
  const HeatMapSettings({
    this.opacity = 0.7,
    this.radius = 60.0,
    this.isVisible = true,
  });
```

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: no new issues. (`HeatMapSettings` is a plain class behind a `StateProvider`; it is unrelated to `SettingsNotifier`, so no test mocks need updating.)

- [ ] **Step 3: Commit**

```bash
git add lib/features/maps/presentation/providers/heat_map_providers.dart
git commit -m "feat(maps): enlarge default heat-map cloud radius and opacity"
```

Expected: commit succeeds.

---

## Task 5: Rewrite HeatMapLayer as a density-shader layer

**Files:**
- Modify (full rewrite): `lib/features/maps/presentation/widgets/heat_map_layer.dart`

- [ ] **Step 1: Replace the file contents**

Replace the entire contents of `lib/features/maps/presentation/widgets/heat_map_layer.dart` with:

```dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/maps/domain/entities/heat_map_point.dart';
import 'package:submersion/features/maps/presentation/providers/heat_map_shader_provider.dart';
import 'package:submersion/features/maps/presentation/widgets/heat_map_density.dart';

/// A flutter_map layer that displays a density-colorized heat map.
///
/// Two passes: (1) accumulate every point as a soft radial alpha blob with
/// additive blending into an offscreen density image; (2) a fragment shader
/// maps the accumulated density through a blue->red palette. Renders nothing
/// until the shader program has loaded (or if loading fails).
class HeatMapLayer extends ConsumerStatefulWidget {
  /// The points to render on the heat map.
  final List<HeatMapPoint> points;

  /// Cloud radius in logical pixels (uniform for every point).
  final double radius;

  /// Overall opacity of the heat map (0.0 to 1.0).
  final double opacity;

  const HeatMapLayer({
    super.key,
    required this.points,
    this.radius = 60.0,
    this.opacity = 0.7,
  });

  @override
  ConsumerState<HeatMapLayer> createState() => _HeatMapLayerState();
}

class _HeatMapLayerState extends ConsumerState<HeatMapLayer> {
  ui.FragmentProgram? _program;
  ui.FragmentShader? _shader;

  @override
  void dispose() {
    _shader?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) return const SizedBox.shrink();

    return ref
        .watch(heatMapShaderProgramProvider)
        .when(
          loading: () => const SizedBox.shrink(),
          error: (error, _) {
            debugPrint('HeatMapLayer: shader failed to load: $error');
            return const SizedBox.shrink();
          },
          data: (program) {
            // Lazily create (and cache) one shader instance per loaded program.
            if (!identical(program, _program)) {
              _shader?.dispose();
              _shader = program.fragmentShader();
              _program = program;
            }
            return ExcludeSemantics(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: _HeatMapPainter(
                        points: widget.points,
                        radius: widget.radius,
                        opacity: widget.opacity,
                        shader: _shader!,
                        camera: MapCamera.of(context),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
  }
}

/// Two-pass density heat-map painter.
class _HeatMapPainter extends CustomPainter {
  final List<HeatMapPoint> points;
  final double radius;
  final double opacity;
  final ui.FragmentShader shader;
  final MapCamera camera;

  /// Density value at which the shader's alpha reaches full opacity.
  static const double _edgeSoftness = 0.15;

  _HeatMapPainter({
    required this.points,
    required this.radius,
    required this.opacity,
    required this.shader,
    required this.camera,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.isEmpty) return;

    final maxWeight = points.fold<double>(
      0.0,
      (m, p) => p.weight > m ? p.weight : m,
    );
    if (maxWeight <= 0) return;

    // Pass 1: accumulate density into an offscreen image.
    final densityImage = _buildDensityImage(size, maxWeight);

    // Pass 2: colorize the density field via the fragment shader.
    shader
      ..setFloat(0, size.width)
      ..setFloat(1, size.height)
      ..setFloat(2, opacity)
      ..setFloat(3, _edgeSoftness)
      ..setImageSampler(0, densityImage);

    canvas.drawRect(Offset.zero & size, Paint()..shader = shader);

    // Safe to dispose now: the shader retains a native reference to the bound
    // sampler image until the next setImageSampler call. Mirrors the existing
    // drawImage+dispose pattern previously used here.
    densityImage.dispose();
  }

  ui.Image _buildDensityImage(Size size, double maxWeight) {
    final recorder = ui.PictureRecorder();
    final bufferCanvas = Canvas(recorder);

    for (final point in points) {
      final screen = camera.latLngToScreenOffset(point.location);
      if (!isPointVisible(screen, size, radius)) continue;

      final intensity = densityIntensity(point.weight, maxWeight);
      if (intensity <= 0) continue;

      final blob = densityBlobGradient(intensity);
      final gradient = RadialGradient(
        colors: blob.colors,
        stops: blob.stops,
      ).createShader(Rect.fromCircle(center: screen, radius: radius));

      bufferCanvas.drawCircle(
        screen,
        radius,
        Paint()
          ..shader = gradient
          ..blendMode = BlendMode.plus,
      );
    }

    final picture = recorder.endRecording();
    final image = picture.toImageSync(size.width.ceil(), size.height.ceil());
    picture.dispose();
    return image;
  }

  @override
  bool shouldRepaint(covariant _HeatMapPainter oldDelegate) {
    return points != oldDelegate.points ||
        radius != oldDelegate.radius ||
        opacity != oldDelegate.opacity ||
        shader != oldDelegate.shader ||
        camera != oldDelegate.camera;
  }
}
```

- [ ] **Step 2: Analyze (confirms all 4 call sites still compile)**

Run: `flutter analyze`
Expected: no new issues. The 4 call sites
(`dive_activity_map_page.dart`, `site_map_page.dart`, `site_map_content.dart`,
`dive_map_content.dart`) pass only `points`/`radius`/`opacity`, which the new
constructor still accepts; the removed `gradient` param was unused.

- [ ] **Step 3: Run the density helper tests and the map-rendering regression tests**

Run: `flutter test test/features/maps/heat_map_density_test.dart`
Run: `flutter test test/features/osm_tile_user_agent_test.dart`
Run: `flutter test test/features/maps/heat_map_point_test.dart`
Expected: all PASS. `osm_tile_user_agent_test.dart` pumps the real map pages but
overrides `diveActivityHeatMapProvider` / `siteCoverageHeatMapProvider` with
empty lists, so `HeatMapLayer` returns early on `points.isEmpty` and never loads
the shader — confirming the new shader dependency does not break headless tests.
(Run files individually, not the whole `test/` dir, to avoid Bash timeouts.)

- [ ] **Step 4: Format and commit**

```bash
dart format lib/features/maps/presentation/widgets/heat_map_layer.dart
flutter analyze
git add lib/features/maps/presentation/widgets/heat_map_layer.dart
git commit -m "refactor(maps): render heat map via density-colorized shader"
```

Expected: commit succeeds.

---

## Task 6: Run, verify, and tune

**Files:**
- Possibly modify: `shaders/heatmap.frag`, `heat_map_layer.dart` (`_edgeSoftness`), `heat_map_providers.dart` (defaults) — only if tuning is needed.

- [ ] **Step 1: Whole-project analyze and format check**

Run: `flutter analyze`
Run: `dart format --set-exit-if-changed lib/ test/`
Expected: analyze clean; format reports no changes (matches the pre-push hook).

- [ ] **Step 2: Run the app on macOS**

Run: `flutter run -d macos`
Open the Dive Activity map (and the Dive Sites map). Toggle the heat-map on with the blur icon in the app bar.

- [ ] **Step 2a: Confirm the new behavior**

Verify visually:
- Clouds are large and soft (not pin-point dots).
- Every site with coordinates shows a visible cloud (single-dive sites included).
- Overlapping / heavily-dived areas shift toward the warm end (yellow/orange/red).
- No hard square edges, no blown-out white smears, no flicker while panning/zooming.

- [ ] **Step 2b: Check the two known shader gotchas**

- **Premultiplied alpha:** if clouds look washed-out, haloed, or too bright, the
  `fragColor = vec4(rgb * a, a)` premultiply in `heatmap.frag` is the suspect.
- **DPR / UV mapping:** on the hi-DPI macOS display, confirm clouds are centered
  on their markers and not offset/scaled. If they are misaligned, the
  `FlutterFragCoord().xy / uResolution` mapping needs a device-pixel-ratio
  correction — adjust the density image size and `uResolution` together.

- [ ] **Step 3: Tune defaults if needed**

If clouds run too hot too fast, raise `gamma` toward 0.7 or lower `floor` in the
`densityIntensity` call. If they are too faint, raise `opacity` default or lower
`_edgeSoftness`. If too small/large, adjust the `radius` default. Re-run to
confirm.

- [ ] **Step 4: Smoke-test the cross-platform shader (accepted risk)**

Build/run on at least one additional target to confirm the shader compiles and
renders (the accepted cross-platform risk). For example:

Run: `flutter run -d ios` (or an Android device/emulator)
Expected: heat-map renders the same as macOS. If the shader fails to load on a
platform, the layer renders nothing (no crash) and logs via `debugPrint`.

- [ ] **Step 5: Commit any tuning changes**

Only if Step 3 changed constants:

```bash
dart format lib/ shaders/
flutter analyze
git add -A
git commit -m "fix(maps): tune heat-map cloud defaults after visual review"
```

Expected: commit succeeds. If no tuning was needed, skip this step.

---

## Definition of Done

- All density-helper unit tests pass.
- `flutter analyze` is clean and `dart format` reports no changes.
- The heat-map renders as large, soft, density-colorized clouds on macOS, every
  site visible, verified by running the app.
- The shader has been smoke-tested on at least one second platform.
- All work committed on `feat/heatmap-density-shader`.
