# Dive 3D Z-Metric Path Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single-dive 3D slab with a 3D path (X = time, Y = depth, Z = a diver-picked metric or None), with labeled axes, wall grids, wall shadows, hover tooltips, labeled markers, and camera presets.

**Architecture:** The existing `Scene3d` pipeline is generalized in place: `SceneGeometryService` gains an optional Z-axis input, a `PathBuilder` tube replaces the flat ribbon, a `ShadowBuilder` projects the path onto the three walls, and `buildDiveAxes` emits the same `AxisFrame` + `AxisLabelSet` pair the other scenes already render. The viewport's tissue-typed hover plumbing becomes a `HoverPicker` interface, and its `axisChromeOnly` boolean becomes a `SceneChromeMode` enum with a new `framed` mode (grid behind, axes in front).

**Tech Stack:** Flutter, Riverpod, CustomPainter (`Canvas.drawVertices`), pure-Dart geometry under `lib/features/dive_3d/domain/`, `flutter_test`, `flutter gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-08-26-dive-3d-z-metric-path-design.md`

## Global Constraints

- Work ONLY in the worktree `/Users/ericgriffin/repos/submersion-app/submersion/.claude/worktrees/dive-3d-path` (branch `worktree-dive-3d-path`). Every path below is relative to that root; every Read/Edit/Write must use the worktree's absolute path, never the main checkout's.
- No em-dashes anywhere (code, comments, docs, commits). No emojis in code or docs.
- Geometry stays in meters/seconds except the Z metric series, which arrives in display units (the provider converts through `UnitFormatter`).
- Scene box: X = 0..`SceneBounds.xSpan` (10), Y = 0..-`SceneBounds.ySpan` (6), Z = -`SceneBounds.zPathHalfSpan`..+`zPathHalfSpan` (2.5). Larger Z metric values toward the viewer (+Z).
- Tube half-width `SceneBounds.zHalfWidth` (0.09). Shadow quads half-thickness 0.015, lifted 0.02 off their wall. Shadow opacity 0.45, drop lines 0.3, about 24 drop lines. Ceiling sheet amber `0xFFF59E0B` at 0.35, violation red `0xFFEF4444`.
- Hover pick radius 12 px on the path. Camera presets: Default (yaw -32, pitch 22), Front (0, 0), Side (90, 0), Top (0, 90).
- Overlay defaults on the dive scene: ceiling on, markers on, shadows on, curtain off, strata off.
- `compute()` only above 2000 samples (unchanged); widget tests must use bounded pumps around painters that repaint on listenables.
- New l10n keys go into `lib/l10n/arb/app_en.arb` AND all ten locale ARBs (ar, de, es, fr, he, hu, it, nl, pt, zh), inserted textually by anchor line (never JSON round-trip an ARB); run `flutter gen-l10n` only after every locale has the translations.
- Whole-project `flutter analyze` must be clean including infos (CI treats infos as fatal). Run `dart format .` before every commit.
- Test invocation: `flutter test <path>` from the worktree root. Do not pipe `flutter test` into `grep`/`tail` when you need the exit code.

---

## File structure

**Create**

| File | Responsibility |
| --- | --- |
| `lib/features/dive_3d/domain/geometry/nice_step.dart` | `niceStep`, `formatTickValue` (moved out of `seascape_axes.dart`) |
| `lib/features/dive_3d/domain/geometry/strip_indices.dart` | `stripIndices(pairCount)` shared by every strip builder |
| `lib/features/dive_3d/domain/geometry/z_axis_spec.dart` | `ZAxisSpec` (lo/hi/step/symbol, `zOf`, `ticks`, `fromRange`), `ZAxisInput` |
| `lib/features/dive_3d/domain/geometry/z_series.dart` | `resampleZSeries`: pick decimated indices, interpolate gaps, hold ends |
| `lib/features/dive_3d/domain/geometry/path_builder.dart` | `PathBuilder.build`: the tube |
| `lib/features/dive_3d/domain/geometry/shadow_builder.dart` | `ShadowBuilder.build`: wall shadows + drop lines |
| `lib/features/dive_3d/domain/geometry/dive_axes.dart` | `AxisTick`, `depthAxisTicks`, `timeAxisTicks`, `buildDiveAxes` |
| `lib/features/dive_3d/application/z_axis_input.dart` | `buildZAxisInput(data, metric, units)` |
| `lib/features/dive_3d/presentation/renderer/hover_picker.dart` | `ScenePick`, `HoverPicker`, `GridHoverPicker`, `PathPick`, `PathHoverPicker` |
| `lib/features/dive_3d/presentation/renderer/camera_pose.dart` | `CameraPose` presets |
| `lib/features/dive_3d/presentation/dive_chrome.dart` | `diveChromeStyle(context)` |
| `lib/features/dive_3d/presentation/widgets/dive_readout_rows.dart` | `ReadoutRow`, `diveReadoutRows(...)` |
| `lib/features/dive_3d/presentation/widgets/dive_hover_tooltip.dart` | `DiveHoverTooltip` |

**Modify**

| File | Change |
| --- | --- |
| `domain/geometry/scene_bounds.dart` | add `zPathHalfSpan` |
| `presentation/scene_overlay.dart` | add `shadows` |
| `domain/metric_palette.dart` | add `SceneMetric.tts` |
| `domain/entities/dive_3d_scene_data.dart` | `availableMetrics` includes tts; add `zAxisMetrics` |
| `domain/geometry/ribbon_builder.dart` | curtain takes `zs`; use `strip_indices.dart` |
| `domain/geometry/ceiling_builder.dart` | becomes the margin sheet, takes `zs` |
| `domain/geometry/marker_layout.dart` | takes the path's `zs` |
| `domain/scene_geometry_service.dart` | new signature; path, shadows, no grid; widened bounds; `scrubPath.zs` |
| `domain/spatial/seascape_axes.dart` | import `niceStep` from `nice_step.dart` |
| `application/providers.dart` | key `(diveId, colorMetric, zMetric)`; `dive3dZAxisProvider` |
| `presentation/renderer/tissue_chrome_painters.dart` | ring/guides/marker labels from `ScenePick`; `paintHoverRing` helper |
| `presentation/widgets/dive_3d_interactive_viewport.dart` | `chromeMode`, `picker`, `hoverPick: ValueNotifier<ScenePick?>`, pose presets |
| `presentation/pages/dive_3d_page.dart` | Z menu, color chips, overlay defaults, axes, tooltip, readout, marker sheet |
| `presentation/pages/spatial_site_page.dart`, `lib/features/site_scape/presentation/site_terrain_pane.dart` | `chromeMode: axesOnly`, `GridHoverPicker`, unwrap payload |
| `presentation/widgets/scene_readout_panel.dart` | rebuilt on `diveReadoutRows` |
| `lib/l10n/arb/*.arb` | 14 new keys |

**Delete**: `domain/geometry/grid_builder.dart` and `test/features/dive_3d/domain/geometry/grid_builder_test.dart`.

---

### Task 1: Extract `niceStep` into `nice_step.dart`

**Files:**
- Create: `lib/features/dive_3d/domain/geometry/nice_step.dart`
- Modify: `lib/features/dive_3d/domain/spatial/seascape_axes.dart`
- Test: `test/features/dive_3d/domain/geometry/nice_step_test.dart`

**Interfaces:**
- Produces: `double niceStep(double target)`, `String formatTickValue(double value, double step)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_3d/domain/geometry/nice_step_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/nice_step.dart';

void main() {
  test('niceStep rounds up to 1/2/5 x 10^n', () {
    expect(niceStep(2.5), 5);
    expect(niceStep(4.5), 5);
    expect(niceStep(37.5), 50);
    expect(niceStep(543.75), 1000);
    expect(niceStep(7.5), 10);
    expect(niceStep(0.2975), closeTo(0.5, 1e-12));
    expect(niceStep(0.5), closeTo(0.5, 1e-12));
    expect(niceStep(0), 0);
    expect(niceStep(-3), 0);
  });

  test('formatTickValue drops decimals for whole steps only', () {
    expect(formatTickValue(20, 5), '20');
    expect(formatTickValue(1.5, 0.5), '1.5');
    expect(formatTickValue(-20, 10), '-20');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/domain/geometry/nice_step_test.dart`
Expected: FAIL (file `nice_step.dart` does not exist).

- [ ] **Step 3: Create `nice_step.dart` and repoint `seascape_axes.dart`**

```dart
// lib/features/dive_3d/domain/geometry/nice_step.dart
import 'dart:math' as math;

/// Rounds [target] up to a "nice" step (1/2/5 x 10^n). Returns 0 for
/// non-positive targets (no ticks).
double niceStep(double target) {
  if (target <= 0) return 0;
  final exp = (math.log(target) / math.ln10).floorToDouble();
  final magnitude = math.pow(10.0, exp).toDouble();
  final base = target / magnitude;
  final double factor;
  if (base <= 1) {
    factor = 1;
  } else if (base <= 2) {
    factor = 2;
  } else if (base <= 5) {
    factor = 5;
  } else {
    factor = 10;
  }
  return factor * magnitude;
}

/// Tick text: whole numbers for whole steps, one decimal otherwise.
String formatTickValue(double value, double step) =>
    step % 1 == 0 ? value.toStringAsFixed(0) : value.toStringAsFixed(1);
```

In `lib/features/dive_3d/domain/spatial/seascape_axes.dart`:
- delete the `niceStep` function and the `_formatTick` function,
- delete `import 'dart:math' as math;` (nothing else in the file uses it),
- add `import 'package:submersion/features/dive_3d/domain/geometry/nice_step.dart';`,
- replace the two `_formatTick(v, step)` calls with `formatTickValue(v, step)`.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/dive_3d/domain/geometry/nice_step_test.dart test/features/dive_3d/domain/spatial`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_3d test/features/dive_3d
git add lib/features/dive_3d/domain/geometry/nice_step.dart lib/features/dive_3d/domain/spatial/seascape_axes.dart test/features/dive_3d/domain/geometry/nice_step_test.dart
git commit -m "refactor(dive_3d): extract niceStep into nice_step.dart"
```

---

### Task 2: `SceneMetric.tts`, palette ramp, and Z-capable metrics

**Files:**
- Modify: `lib/features/dive_3d/domain/metric_palette.dart`
- Modify: `lib/features/dive_3d/domain/entities/dive_3d_scene_data.dart`
- Modify: `lib/features/dive_3d/domain/scene_geometry_service.dart` (`_metricSeries` switch)
- Modify: `lib/features/dive_3d/presentation/pages/dive_3d_page.dart` (`_metricLabel` switch; temporary English literal until Task 12 adds the key)
- Test: `test/features/dive_3d/domain/metric_palette_test.dart`, `test/features/dive_3d/domain/entities/dive_3d_scene_data_z_metrics_test.dart`

**Interfaces:**
- Produces: `SceneMetric.tts`; `Set<SceneMetric> Dive3dSceneData.zAxisMetrics` (metrics with at least two finite samples, never `depth`).

- [ ] **Step 1: Write the failing tests**

Append to `test/features/dive_3d/domain/metric_palette_test.dart` (inside `main`):

```dart
  test('tts colors run neutral to amber across the series range', () {
    final colors = MetricPalette.colorsFor(SceneMetric.tts, [0, 10, 20]);
    // First sample is the low end (gray-blue), last is amber: red channel rises.
    expect(colors[0], lessThan(colors[6]));
    expect(colors[6], greaterThan(0.9)); // amber red channel ~0.96
  });
```

Create `test/features/dive_3d/domain/entities/dive_3d_scene_data_z_metrics_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';

Dive3dSceneData data({
  List<double?> temperatures = const [null, null, null],
  List<int?> ttss = const [null, null, null],
}) => Dive3dSceneData(
  diveId: 'd1',
  times: const [0, 60, 120],
  depths: const [0, 10, 0],
  temperatures: temperatures,
  ascentRates: const [null, null, null],
  ppO2s: const [null, null, null],
  cnss: const [null, null, null],
  heartRates: const [null, null, null],
  ceilings: const [null, null, null],
  ttss: ttss,
  tankPressures: const {},
  gasSwitches: const [],
  bookmarkEvents: const [],
  photos: const [],
  durationSeconds: 120,
  maxDepthMeters: 10,
);

void main() {
  test('zAxisMetrics never offers depth and needs two finite samples', () {
    expect(data().zAxisMetrics, isEmpty);
    expect(data(temperatures: [20, null, null]).zAxisMetrics, isEmpty);
    expect(
      data(temperatures: [20, 18, null]).zAxisMetrics,
      {SceneMetric.temperature},
    );
  });

  test('tts counts as an available and Z-capable metric', () {
    final d = data(ttss: [null, 600, 300]);
    expect(d.availableMetrics, contains(SceneMetric.tts));
    expect(d.zAxisMetrics, {SceneMetric.tts});
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_3d/domain/metric_palette_test.dart test/features/dive_3d/domain/entities/dive_3d_scene_data_z_metrics_test.dart`
Expected: compile errors (`SceneMetric.tts`, `zAxisMetrics` undefined).

- [ ] **Step 3: Implement**

`metric_palette.dart`: add `tts` as the last enum value and a dedicated ramp.

```dart
enum SceneMetric {
  depth,
  temperature,
  ascentRate,
  ppO2,
  cns,
  heartRate,
  tankPressure,
  tts,
}
```

Inside `MetricPalette` add:

```dart
  // Neutral-to-amber ramp for time-to-surface: no red, since red is the
  // ceiling violation color in the same scene.
  static const List<Color> _ttsRamp = [Color(0xFF7C8494), Color(0xFFF5A623)];
```

and change `colorsFor` so the color pick reads:

```dart
      final color = v == null || !v.isFinite
          ? _nullColor
          : metric == SceneMetric.ascentRate
          ? _ascentBand(v)
          : metric == SceneMetric.tts
          ? Color.lerp(_ttsRamp[0], _ttsRamp[1], normalize(v))!
          : _lerpRamp(normalize(v));
```

`dive_3d_scene_data.dart`: add tts to `availableMetrics` and the new getter.

```dart
  Set<SceneMetric> get availableMetrics => {
    SceneMetric.depth,
    if (_any(temperatures)) SceneMetric.temperature,
    if (_any(ascentRates)) SceneMetric.ascentRate,
    if (_any(ppO2s)) SceneMetric.ppO2,
    if (_any(cnss)) SceneMetric.cns,
    if (_any(heartRates)) SceneMetric.heartRate,
    if (tankPressures.values.any((l) => l.isNotEmpty)) SceneMetric.tankPressure,
    if (_any(ttsSeconds)) SceneMetric.tts,
  };

  /// The tts series as doubles (seconds), for the metric pipeline.
  List<double?> get ttsSeconds => [for (final t in ttss) t?.toDouble()];

  int _finiteCount(List<double?> series) =>
      series.where((v) => v != null && v.isFinite).length;

  /// Metrics that can drive the Z axis: at least two finite samples so a
  /// path exists between them. Depth is the Y axis and never offered.
  Set<SceneMetric> get zAxisMetrics => {
    if (_finiteCount(temperatures) >= 2) SceneMetric.temperature,
    if (_finiteCount(ascentRates) >= 2) SceneMetric.ascentRate,
    if (_finiteCount(ppO2s) >= 2) SceneMetric.ppO2,
    if (_finiteCount(cnss) >= 2) SceneMetric.cns,
    if (_finiteCount(heartRates) >= 2) SceneMetric.heartRate,
    if (tankPressures.values.any((l) => l.length >= 2))
      SceneMetric.tankPressure,
    if (_finiteCount(ttsSeconds) >= 2) SceneMetric.tts,
  };
```

`scene_geometry_service.dart` `_metricSeries`: add `case SceneMetric.tts: return pick(data.ttsSeconds);`.

`dive_3d_page.dart` `_metricLabel`: add `SceneMetric.tts => 'TTS',` (replaced by the l10n key in Task 12).

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/dive_3d/domain`
Expected: all PASS (the exhaustive switches now compile).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_3d test/features/dive_3d
git add -A lib/features/dive_3d test/features/dive_3d
git commit -m "feat(dive_3d): add tts metric and Z-capable metric set"
```

---

### Task 3: `ZAxisSpec` and `ZAxisInput`

**Files:**
- Create: `lib/features/dive_3d/domain/geometry/z_axis_spec.dart`
- Modify: `lib/features/dive_3d/domain/geometry/scene_bounds.dart` (add `zPathHalfSpan`)
- Test: `test/features/dive_3d/domain/geometry/z_axis_spec_test.dart`

**Interfaces:**
- Produces:
  - `SceneBounds.zPathHalfSpan = 2.5`
  - `class ZAxisSpec { final double lo, hi, step; final String symbol; double zOf(double v); List<double> get ticks; factory ZAxisSpec.fromRange({required double min, required double max, required String symbol, int targetTicks = 5}) }`
  - `class ZAxisInput { final SceneMetric metric; final ZAxisSpec spec; final List<double?> values; }` (`values` parallel to `Dive3dSceneData.times`, in display units)

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_3d/domain/geometry/z_axis_spec_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/z_axis_spec.dart';

void main() {
  test('fromRange snaps outward to a nice step (hand-computed vectors)', () {
    final c = ZAxisSpec.fromRange(min: 12, max: 22, symbol: '°C');
    expect((c.lo, c.hi, c.step), (10.0, 25.0, 5.0));
    final f = ZAxisSpec.fromRange(min: 53.6, max: 71.6, symbol: '°F');
    expect((f.lo, f.hi, f.step), (50.0, 75.0, 5.0));
    final bar = ZAxisSpec.fromRange(min: 60, max: 210, symbol: 'bar');
    expect((bar.lo, bar.hi, bar.step), (50.0, 250.0, 50.0));
    final psi = ZAxisSpec.fromRange(min: 870, max: 3045, symbol: 'psi');
    expect((psi.lo, psi.hi, psi.step), (0.0, 4000.0, 1000.0));
    final rate = ZAxisSpec.fromRange(min: -12, max: 18, symbol: 'm/min');
    expect((rate.lo, rate.hi, rate.step), (-20.0, 20.0, 10.0));
    final ppo2 = ZAxisSpec.fromRange(min: 0.21, max: 1.4, symbol: '');
    expect(ppo2.lo, closeTo(0, 1e-9));
    expect(ppo2.hi, closeTo(1.5, 1e-9));
    expect(ppo2.step, closeTo(0.5, 1e-9));
  });

  test('a flat series still gets a non-empty band', () {
    final flat = ZAxisSpec.fromRange(min: 20, max: 20, symbol: '°C');
    expect(flat.hi, greaterThan(flat.lo));
    expect(flat.ticks.length, greaterThanOrEqualTo(2));
  });

  test('zOf maps lo..hi onto the path span, larger toward +Z', () {
    const spec = ZAxisSpec(lo: 10, hi: 20, step: 5, symbol: '');
    expect(spec.zOf(10), -SceneBounds.zPathHalfSpan);
    expect(spec.zOf(20), SceneBounds.zPathHalfSpan);
    expect(spec.zOf(15), closeTo(0, 1e-9));
    expect(spec.zOf(99), SceneBounds.zPathHalfSpan); // clamped
  });

  test('ticks run lo..hi inclusive without float drift', () {
    const spec = ZAxisSpec(lo: 0, hi: 1.5, step: 0.5, symbol: '');
    expect(spec.ticks, [0.0, 0.5, 1.0, 1.5]);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/domain/geometry/z_axis_spec_test.dart`
Expected: FAIL (missing file / `zPathHalfSpan`).

- [ ] **Step 3: Implement**

`scene_bounds.dart`: add after `zSlabHalfWidth`:

```dart
  /// Half of the Z span the single-dive path scene uses when a metric is on
  /// the Z axis. The compare/career slab width stays at [zSlabHalfWidth].
  static const double zPathHalfSpan = 2.5;
```

```dart
// lib/features/dive_3d/domain/geometry/z_axis_spec.dart
import 'package:submersion/features/dive_3d/domain/geometry/nice_step.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';

/// The Z axis of the path scene: a nice-number range in the diver's DISPLAY
/// unit (the provider converts before building), mapped onto the scene's
/// Z span. Plain immutable data so it crosses compute() untouched.
class ZAxisSpec {
  final double lo;
  final double hi;
  final double step;

  /// Unit symbol for the axis title ('°C', 'psi', 'm/min', '' for ppO2).
  final String symbol;

  const ZAxisSpec({
    required this.lo,
    required this.hi,
    required this.step,
    required this.symbol,
  });

  /// Snaps [min]..[max] outward to a nice step that yields about
  /// [targetTicks] ticks. A flat series (min == max) is widened by a
  /// tenth of its magnitude (or 1.0 at zero) so the band is never empty.
  factory ZAxisSpec.fromRange({
    required double min,
    required double max,
    required String symbol,
    int targetTicks = 5,
  }) {
    var span = max - min;
    if (span <= 0) span = max.abs() > 0 ? max.abs() * 0.1 : 1.0;
    final step = niceStep(span / (targetTicks - 1));
    final lo = (min / step).floor() * step;
    var hi = (max / step).ceil() * step;
    if (hi <= lo) hi = lo + step;
    return ZAxisSpec(lo: lo, hi: hi, step: step, symbol: symbol);
  }

  /// Scene Z for a display-unit value; larger values toward the viewer.
  double zOf(double value) {
    if (hi <= lo) return 0;
    final t = ((value - lo) / (hi - lo)).clamp(0.0, 1.0);
    return -SceneBounds.zPathHalfSpan + t * 2 * SceneBounds.zPathHalfSpan;
  }

  /// Tick values lo..hi inclusive, computed by index so no float drift.
  List<double> get ticks {
    if (step <= 0 || hi <= lo) return [lo];
    final count = ((hi - lo) / step).round();
    return [for (var i = 0; i <= count; i++) lo + i * step];
  }
}

/// Everything the geometry service needs to put a metric on Z: which
/// metric, its axis, and the full-resolution series (display units,
/// parallel to Dive3dSceneData.times, nulls where the computer logged
/// nothing).
class ZAxisInput {
  final SceneMetric metric;
  final ZAxisSpec spec;
  final List<double?> values;

  const ZAxisInput({
    required this.metric,
    required this.spec,
    required this.values,
  });
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/dive_3d/domain/geometry/z_axis_spec_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_3d test/features/dive_3d
git add lib/features/dive_3d/domain/geometry/z_axis_spec.dart lib/features/dive_3d/domain/geometry/scene_bounds.dart test/features/dive_3d/domain/geometry/z_axis_spec_test.dart
git commit -m "feat(dive_3d): add ZAxisSpec with nice-number range and Z mapping"
```

---

### Task 4: Z series resampling

**Files:**
- Create: `lib/features/dive_3d/domain/geometry/z_series.dart`
- Test: `test/features/dive_3d/domain/geometry/z_series_test.dart`

**Interfaces:**
- Produces: `List<double>? resampleZSeries({required List<double?> values, required List<int> indices})`: returns one finite double per index; interior nulls linearly interpolated over the FULL-resolution series (by sample index), leading/trailing nulls take the nearest finite value; returns null when fewer than two finite values exist.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_3d/domain/geometry/z_series_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/z_series.dart';

void main() {
  test('interior gaps interpolate, ends hold the nearest value', () {
    final out = resampleZSeries(
      values: [null, 10, null, null, 40, null],
      indices: [0, 1, 2, 3, 4, 5],
    );
    expect(out, [10, 10, 20, 30, 40, 40]);
  });

  test('picks only the requested indices', () {
    final out = resampleZSeries(
      values: [0, 10, 20, 30],
      indices: [0, 2],
    );
    expect(out, [0, 20]);
  });

  test('fewer than two finite samples means no Z series', () {
    expect(resampleZSeries(values: [null, 5, null], indices: [0, 1, 2]), isNull);
    expect(
      resampleZSeries(values: [double.nan, 5, null], indices: [0, 1, 2]),
      isNull,
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/domain/geometry/z_series_test.dart`
Expected: FAIL (missing file).

- [ ] **Step 3: Implement**

```dart
// lib/features/dive_3d/domain/geometry/z_series.dart

/// Fills a metric series so the path never breaks, then picks the decimated
/// [indices]. Interior nulls interpolate linearly between their finite
/// neighbors (by sample index, which is what the decimator works in);
/// leading and trailing nulls take the nearest finite value. Returns null
/// when fewer than two finite values exist: a Z axis needs a path.
List<double>? resampleZSeries({
  required List<double?> values,
  required List<int> indices,
}) {
  final n = values.length;
  bool finite(int i) {
    final v = values[i];
    return v != null && v.isFinite;
  }

  final finiteIdx = [for (var i = 0; i < n; i++) if (finite(i)) i];
  if (finiteIdx.length < 2) return null;

  final filled = List<double>.filled(n, 0);
  var k = 0; // index into finiteIdx of the nearest finite sample at/after i
  for (var i = 0; i < n; i++) {
    if (finite(i)) {
      filled[i] = values[i]!;
      if (finiteIdx[k] < i) k++;
      continue;
    }
    if (i < finiteIdx.first) {
      filled[i] = values[finiteIdx.first]!;
    } else if (i > finiteIdx.last) {
      filled[i] = values[finiteIdx.last]!;
    } else {
      while (finiteIdx[k] < i) {
        k++;
      }
      final hi = finiteIdx[k], lo = finiteIdx[k - 1];
      final a = values[lo]!, b = values[hi]!;
      filled[i] = a + (b - a) * ((i - lo) / (hi - lo));
    }
  }
  return [for (final i in indices) filled[i]];
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/dive_3d/domain/geometry/z_series_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_3d test/features/dive_3d
git add lib/features/dive_3d/domain/geometry/z_series.dart test/features/dive_3d/domain/geometry/z_series_test.dart
git commit -m "feat(dive_3d): resample Z metric series with gap interpolation"
```

---

### Task 5: `stripIndices` extraction and `PathBuilder`

**Files:**
- Create: `lib/features/dive_3d/domain/geometry/strip_indices.dart`
- Create: `lib/features/dive_3d/domain/geometry/path_builder.dart`
- Modify: `lib/features/dive_3d/domain/geometry/ribbon_builder.dart` (use `stripIndices`, drop `_stripIndices`)
- Test: `test/features/dive_3d/domain/geometry/path_builder_test.dart`

**Interfaces:**
- Produces: `Uint32List stripIndices(int pairCount)`; `MeshData PathBuilder.build({required List<double> times, required List<double> depths, required List<double> zs, required Float32List sampleColors, required SceneBounds bounds})`. Vertex layout: strip A (Z-width) vertices `0..2n-1`, strip B (Y-width) vertices `2n..4n-1`; per sample i, strip A pair is `(2i, 2i+1)`, strip B pair is `(2n+2i, 2n+2i+1)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_3d/domain/geometry/path_builder_test.dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/path_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/strip_indices.dart';

void main() {
  const bounds = SceneBounds(durationSeconds: 100, maxDepthMeters: 30);
  final colors = Float32List.fromList([1, 0, 0, 0, 1, 0, 0, 0, 1]);

  test('stripIndices yields two triangles per segment', () {
    expect(stripIndices(1), isEmpty);
    expect(stripIndices(3), [0, 1, 2, 1, 3, 2, 2, 3, 4, 3, 5, 4]);
  });

  test('tube has two crossed strips: 4 vertices and 4 triangles per sample', () {
    final mesh = PathBuilder.build(
      times: [0, 50, 100],
      depths: [0, 30, 0],
      zs: [-1, 0, 1],
      sampleColors: colors,
      bounds: bounds,
    );
    expect(mesh.vertexCount, 12);
    expect(mesh.triangleCount, 8);
  });

  test('strip A straddles Z and strip B straddles Y at the sample position', () {
    final mesh = PathBuilder.build(
      times: [0, 50, 100],
      depths: [0, 30, 0],
      zs: [-1, 0.5, 1],
      sampleColors: colors,
      bounds: bounds,
    );
    const h = SceneBounds.zHalfWidth;
    // Sample 1: x = 5, y = -6, z = 0.5.
    final p = mesh.positions;
    expect(p.sublist(6, 12), [5, -6, 0.5 - h, 5, -6, 0.5 + h]);
    final b = 2 * 3 * 3 + 6; // strip B starts at vertex 6 (2n), sample 1 -> +6 floats
    expect(p.sublist(b, b + 6), [5, -6 - h, 0.5, 5, -6 + h, 0.5]);
  });

  test('all four vertices of a sample share its color', () {
    final mesh = PathBuilder.build(
      times: [0, 50, 100],
      depths: [0, 30, 0],
      zs: [0, 0, 0],
      sampleColors: colors,
      bounds: bounds,
    );
    final c = mesh.colors;
    for (final v in [2, 3, 8, 9]) {
      expect(c.sublist(v * 3, v * 3 + 3), [0, 1, 0]);
    }
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/domain/geometry/path_builder_test.dart`
Expected: FAIL (missing files).

- [ ] **Step 3: Implement**

```dart
// lib/features/dive_3d/domain/geometry/strip_indices.dart
import 'dart:typed_data';

/// Indices for a triangle strip of [pairCount] vertex pairs laid out as
/// (2i, 2i+1): two triangles per segment. Shared by every strip builder.
Uint32List stripIndices(int pairCount) {
  if (pairCount < 2) return Uint32List(0);
  final indices = Uint32List((pairCount - 1) * 6);
  var j = 0;
  for (var i = 0; i < pairCount - 1; i++) {
    final a = i * 2, b = i * 2 + 1, c = i * 2 + 2, d = i * 2 + 3;
    indices[j++] = a;
    indices[j++] = b;
    indices[j++] = c;
    indices[j++] = b;
    indices[j++] = d;
    indices[j++] = c;
  }
  return indices;
}
```

```dart
// lib/features/dive_3d/domain/geometry/path_builder.dart
import 'dart:typed_data';

import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/strip_indices.dart';

/// The dive path as a tube: two crossed triangle strips (one widened in Z,
/// one widened in Y) along (xOf(t), yOf(depth), z). A thin cross reads as
/// a tube from every camera pose without the cost of a real cylinder.
/// Per-vertex colors come from the color metric's palette.
class PathBuilder {
  static MeshData build({
    required List<double> times,
    required List<double> depths,
    required List<double> zs,
    required Float32List sampleColors,
    required SceneBounds bounds,
  }) {
    final n = times.length;
    const h = SceneBounds.zHalfWidth;
    final positions = Float32List(n * 12);
    final colors = Float32List(n * 12);
    for (var i = 0; i < n; i++) {
      final x = bounds.xOf(times[i]);
      final y = bounds.yOf(depths[i]);
      final z = zs[i];
      // Strip A: pair (2i, 2i+1), widened in Z.
      final a = i * 6;
      positions[a] = x;
      positions[a + 1] = y;
      positions[a + 2] = z - h;
      positions[a + 3] = x;
      positions[a + 4] = y;
      positions[a + 5] = z + h;
      // Strip B: pair (2n+2i, 2n+2i+1), widened in Y.
      final b = n * 6 + i * 6;
      positions[b] = x;
      positions[b + 1] = y - h;
      positions[b + 2] = z;
      positions[b + 3] = x;
      positions[b + 4] = y + h;
      positions[b + 5] = z;
      final c = i * 3;
      for (var k = 0; k < 3; k++) {
        colors[a + k] = sampleColors[c + k];
        colors[a + 3 + k] = sampleColors[c + k];
        colors[b + k] = sampleColors[c + k];
        colors[b + 3 + k] = sampleColors[c + k];
      }
    }
    final stripA = stripIndices(n);
    final indices = Uint32List(stripA.length * 2);
    indices.setRange(0, stripA.length, stripA);
    for (var i = 0; i < stripA.length; i++) {
      indices[stripA.length + i] = stripA[i] + n * 2;
    }
    return MeshData(positions: positions, indices: indices, colors: colors);
  }
}
```

`ribbon_builder.dart`: add `import 'package:submersion/features/dive_3d/domain/geometry/strip_indices.dart';`, replace both `_stripIndices(n)` calls with `stripIndices(n)`, and delete the private `_stripIndices` method.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/dive_3d/domain/geometry`
Expected: all PASS (ribbon tests unchanged).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_3d test/features/dive_3d
git add -A lib/features/dive_3d/domain/geometry test/features/dive_3d/domain/geometry
git commit -m "feat(dive_3d): add PathBuilder tube and shared stripIndices"
```

---

### Task 6: `ShadowBuilder`

**Files:**
- Create: `lib/features/dive_3d/domain/geometry/shadow_builder.dart`
- Test: `test/features/dive_3d/domain/geometry/shadow_builder_test.dart`

**Interfaces:**
- Produces: `typedef ShadowMeshes = ({MeshData walls, MeshData drops});` and `ShadowMeshes ShadowBuilder.build({required List<double> times, required List<double> depths, required List<double> zs, required SceneBounds bounds})`. `walls` = three strips (back wall, floor, left wall) of `n` pairs each, vertices `0..2n-1`, `2n..4n-1`, `4n..6n-1`; `drops` = one quad (4 vertices, 2 triangles) per drop line.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_3d/domain/geometry/shadow_builder_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/shadow_builder.dart';

void main() {
  const bounds = SceneBounds(
    durationSeconds: 100,
    maxDepthMeters: 30,
    sceneMinZ: -SceneBounds.zPathHalfSpan,
    sceneMaxZ: SceneBounds.zPathHalfSpan,
  );

  test('three wall strips, one per wall, each lifted off its wall', () {
    final s = ShadowBuilder.build(
      times: [0, 50, 100],
      depths: [0, 30, 0],
      zs: [-1, 0, 1],
      bounds: bounds,
    );
    expect(s.walls.vertexCount, 18);
    expect(s.walls.triangleCount, 12);
    final p = s.walls.positions;
    // Back wall pair for sample 1: x = 5, y = -6 +/- half, z = minZ + lift.
    expect(p[6], 5);
    expect(p[7], closeTo(-6 - ShadowBuilder.halfThickness, 1e-6));
    expect(p[8], closeTo(bounds.sceneMinZ + ShadowBuilder.lift, 1e-6));
    // Floor pair for sample 1 lives at vertex 2n + 2 = 8.
    expect(p[8 * 3 + 1], closeTo(bounds.sceneMinY + ShadowBuilder.lift, 1e-6));
    expect(p[8 * 3 + 2], closeTo(0 - ShadowBuilder.halfThickness, 1e-6));
    // Left wall pair for sample 1 lives at vertex 4n + 2 = 14.
    expect(p[14 * 3], closeTo(ShadowBuilder.lift, 1e-6));
    expect(p[14 * 3 + 2], 0);
    expect(s.walls.opacity, 0.45);
  });

  test('drop lines are quads from the path to the floor, about 24 of them', () {
    final n = 240;
    final times = [for (var i = 0; i < n; i++) i * 100 / (n - 1)];
    final s = ShadowBuilder.build(
      times: times,
      depths: List.filled(n, 15),
      zs: List.filled(n, 0.5),
      bounds: bounds,
    );
    expect(s.drops.vertexCount, 24 * 4);
    expect(s.drops.triangleCount, 24 * 2);
    // First quad: top pair at y = yOf(15) = -3, bottom pair on the floor.
    expect(s.drops.positions[1], -3);
    expect(s.drops.positions[7], bounds.sceneMinY);
    expect(s.drops.opacity, 0.3);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/domain/geometry/shadow_builder_test.dart`
Expected: FAIL (missing file).

- [ ] **Step 3: Implement**

```dart
// lib/features/dive_3d/domain/geometry/shadow_builder.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/strip_indices.dart';

typedef ShadowMeshes = ({MeshData walls, MeshData drops});

/// Projects the path onto the three walls of the scene box as thin gray
/// strips (the same thin-quad trick the old grid used, so the painter needs
/// no line primitive), plus sparse vertical drop lines from the path to the
/// floor. Each shadow is a 2D chart: depth vs time on the back wall,
/// metric vs time on the floor, depth vs metric on the left wall.
class ShadowBuilder {
  static const Color _color = Color(0xFF9CA3AF);
  static const double wallOpacity = 0.45;
  static const double dropOpacity = 0.3;
  static const double halfThickness = 0.015;

  /// Offset off each wall toward the box interior so the strip never
  /// z-fights the frame grid drawn behind the scene.
  static const double lift = 0.02;
  static const int dropLineTarget = 24;

  static ShadowMeshes build({
    required List<double> times,
    required List<double> depths,
    required List<double> zs,
    required SceneBounds bounds,
  }) {
    final n = times.length;
    final xs = [for (final t in times) bounds.xOf(t)];
    final ys = [for (final d in depths) bounds.yOf(d)];
    final zBack = bounds.sceneMinZ + lift;
    final yFloor = bounds.sceneMinY + lift;

    final positions = Float32List(n * 18);
    for (var i = 0; i < n; i++) {
      final x = xs[i], y = ys[i], z = zs[i];
      // Back wall (z fixed): widened in Y.
      _pair(positions, i * 6, x, y - halfThickness, zBack, x, y + halfThickness, zBack);
      // Floor (y fixed): widened in Z.
      _pair(positions, n * 6 + i * 6, x, yFloor, z - halfThickness, x, yFloor, z + halfThickness);
      // Left wall (x fixed): widened in Y.
      _pair(positions, n * 12 + i * 6, lift, y - halfThickness, z, lift, y + halfThickness, z);
    }
    final strip = stripIndices(n);
    final indices = Uint32List(strip.length * 3);
    for (var s = 0; s < 3; s++) {
      for (var i = 0; i < strip.length; i++) {
        indices[s * strip.length + i] = strip[i] + s * n * 2;
      }
    }
    final walls = MeshData(
      positions: positions,
      indices: indices,
      colors: _flat(n * 6),
      opacity: wallOpacity,
    );

    final step = math.max(1, (n / dropLineTarget).round());
    final picks = [for (var i = 0; i < n; i += step) i];
    final dropPositions = Float32List(picks.length * 12);
    final dropIndices = Uint32List(picks.length * 6);
    for (var j = 0; j < picks.length; j++) {
      final i = picks[j];
      final x = xs[i], y = ys[i], z = zs[i];
      final p = j * 12;
      _pair(dropPositions, p, x, y, z - halfThickness, x, y, z + halfThickness);
      _pair(dropPositions, p + 6, x, bounds.sceneMinY, z - halfThickness, x, bounds.sceneMinY, z + halfThickness);
      final base = j * 4, q = j * 6;
      dropIndices[q] = base;
      dropIndices[q + 1] = base + 1;
      dropIndices[q + 2] = base + 2;
      dropIndices[q + 3] = base + 1;
      dropIndices[q + 4] = base + 3;
      dropIndices[q + 5] = base + 2;
    }
    final drops = MeshData(
      positions: dropPositions,
      indices: dropIndices,
      colors: _flat(picks.length * 4),
      opacity: dropOpacity,
    );
    return (walls: walls, drops: drops);
  }

  static void _pair(
    Float32List out,
    int at,
    double x1, double y1, double z1,
    double x2, double y2, double z2,
  ) {
    out[at] = x1;
    out[at + 1] = y1;
    out[at + 2] = z1;
    out[at + 3] = x2;
    out[at + 4] = y2;
    out[at + 5] = z2;
  }

  static Float32List _flat(int vertexCount) {
    final colors = Float32List(vertexCount * 3);
    for (var v = 0; v < vertexCount; v++) {
      colors[v * 3] = _color.r;
      colors[v * 3 + 1] = _color.g;
      colors[v * 3 + 2] = _color.b;
    }
    return colors;
  }
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/dive_3d/domain/geometry/shadow_builder_test.dart`
Expected: PASS. (The 240-sample case: `(240 / 24).round()` = 10, so picks are 0, 10, ..., 230 = 24 quads.)

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_3d test/features/dive_3d
git add lib/features/dive_3d/domain/geometry/shadow_builder.dart test/features/dive_3d/domain/geometry/shadow_builder_test.dart
git commit -m "feat(dive_3d): add ShadowBuilder for wall shadows and drop lines"
```

---

### Task 7: Ceiling margin sheet

**Files:**
- Modify: `lib/features/dive_3d/domain/geometry/ceiling_builder.dart`
- Test: `test/features/dive_3d/domain/geometry/ceiling_builder_test.dart` (rewrite)

**Interfaces:**
- Produces: `MeshData? CeilingBuilder.build({required List<double> times, required List<double> depths, required List<double> zs, required List<double?> ceilings, required SceneBounds bounds})`. Vertex pair per active sample: `(x, yOf(depth), z)` then `(x, yOf(ceiling), z)`.

- [ ] **Step 1: Replace the test file**

```dart
// test/features/dive_3d/domain/geometry/ceiling_builder_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/ceiling_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

void main() {
  const bounds = SceneBounds(durationSeconds: 100, maxDepthMeters: 30);

  test('returns null when no ceiling exists', () {
    final mesh = CeilingBuilder.build(
      times: [0.0, 50.0],
      depths: [10.0, 12.0],
      zs: [0, 0],
      ceilings: [null, 0.0],
      bounds: bounds,
    );
    expect(mesh, isNull);
  });

  test('builds a sheet from the path up to the ceiling at the path Z', () {
    final mesh = CeilingBuilder.build(
      times: [0.0, 50.0, 100.0],
      depths: [20.0, 20.0, 20.0],
      zs: [0.5, 0.5, -0.5],
      ceilings: [null, 6.0, 3.0],
      bounds: bounds,
    )!;
    expect(mesh.vertexCount, 4); // 2 ceiling samples x 2 verts
    expect(mesh.triangleCount, 2);
    // Sample at t=50: bottom vertex on the path (depth 20 -> y = -4),
    // top vertex at the ceiling (6 m -> y = -1.2), both at z = 0.5.
    expect(mesh.positions.sublist(0, 6), [5, -4, 0.5, 5, -1.2, 0.5]);
    // Sample at t=100 sits at z = -0.5.
    expect(mesh.positions[8], -0.5);
  });

  test('violation samples (depth shallower than ceiling) are red', () {
    final mesh = CeilingBuilder.build(
      times: [0.0, 10.0],
      depths: [10.0, 4.0], // second sample above 6m ceiling
      zs: [0, 0],
      ceilings: [6.0, 6.0],
      bounds: bounds,
    )!;
    expect(mesh.colors[1], greaterThan(0.4)); // amber g channel
    expect(mesh.colors[7], lessThan(0.4)); // violation g channel
  });

  test('separate deco periods are not bridged', () {
    final mesh = CeilingBuilder.build(
      times: [0.0, 10.0, 20.0, 30.0],
      depths: [20.0, 20.0, 20.0, 20.0],
      zs: [0, 0, 0, 0],
      ceilings: [6.0, null, 6.0, 6.0],
      bounds: bounds,
    )!;
    expect(mesh.vertexCount, 6);
    expect(mesh.triangleCount, 2); // only the 20-30 s run forms a quad
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/domain/geometry/ceiling_builder_test.dart`
Expected: FAIL (no `zs` parameter).

- [ ] **Step 3: Rewrite the builder body**

Replace the class doc and `build` in `ceiling_builder.dart` with:

```dart
/// The deco margin as a translucent sheet standing between the path and its
/// ceiling depth, following the path in Z. Its height is the margin the
/// diver has to the ceiling; samples where the diver is shallower than the
/// ceiling (a violation) render red.
class CeilingBuilder {
  static const Color _safe = Color(0xFFF59E0B);
  static const Color _violation = Color(0xFFEF4444);
  static const double _opacity = 0.35;

  static MeshData? build({
    required List<double> times,
    required List<double> depths,
    required List<double> zs,
    required List<double?> ceilings,
    required SceneBounds bounds,
  }) {
    final active = <int>[];
    for (var i = 0; i < ceilings.length; i++) {
      final c = ceilings[i];
      if (c != null && c > 0) active.add(i);
    }
    if (active.length < 2) return null;

    final positions = Float32List(active.length * 6);
    final colors = Float32List(active.length * 6);
    for (var j = 0; j < active.length; j++) {
      final i = active[j];
      final x = bounds.xOf(times[i]);
      final color = depths[i] < ceilings[i]! ? _violation : _safe;
      final p = j * 6;
      positions[p] = x;
      positions[p + 1] = bounds.yOf(depths[i]);
      positions[p + 2] = zs[i];
      positions[p + 3] = x;
      positions[p + 4] = bounds.yOf(ceilings[i]!);
      positions[p + 5] = zs[i];
      for (var k = 0; k < 2; k++) {
        colors[p + k * 3] = color.r;
        colors[p + k * 3 + 1] = color.g;
        colors[p + k * 3 + 2] = color.b;
      }
    }

    // Strip indices, but break the strip across gaps in the active run so
    // separate deco periods do not get bridged by a stray quad.
    final indexList = <int>[];
    for (var j = 0; j < active.length - 1; j++) {
      if (active[j + 1] != active[j] + 1) continue;
      final a = j * 2, b = j * 2 + 1, c = j * 2 + 2, d = j * 2 + 3;
      indexList.addAll([a, b, c, b, d, c]);
    }
    if (indexList.isEmpty) return null;
    return MeshData(
      positions: positions,
      indices: Uint32List.fromList(indexList),
      colors: colors,
      opacity: _opacity,
    );
  }
}
```

(`_zHalf` is deleted.) `scene_geometry_service.dart` will not compile until Task 9; that is expected. To keep this task green on its own, run only the builder test.

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/dive_3d/domain/geometry/ceiling_builder_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_3d test/features/dive_3d
git add lib/features/dive_3d/domain/geometry/ceiling_builder.dart test/features/dive_3d/domain/geometry/ceiling_builder_test.dart
git commit -m "feat(dive_3d): turn the deco ceiling into a margin sheet on the path"
```

---

### Task 8: Curtain and markers follow the path's Z

**Files:**
- Modify: `lib/features/dive_3d/domain/geometry/ribbon_builder.dart` (`curtain` gains `zs`)
- Modify: `lib/features/dive_3d/domain/geometry/marker_layout.dart` (`layout` gains `pathTimes`/`pathZs`)
- Test: `test/features/dive_3d/domain/geometry/ribbon_builder_test.dart` (curtain group), `test/features/dive_3d/domain/geometry/marker_layout_z_test.dart`

**Interfaces:**
- Produces: `RibbonBuilder.curtain({required times, required depths, required List<double> zs, required bounds})`; `MarkerLayout.layout({required data, required bounds, List<double>? pathTimes, List<double>? pathZs})` (marker Z interpolated from the decimated path; 0 when the path is not given).

- [ ] **Step 1: Write the failing tests**

In `ribbon_builder_test.dart`, every `RibbonBuilder.curtain(` call gains `zs: List<double>.filled(<times length>, 0),` with the same length as its `times` list, and add this test inside the `RibbonBuilder.curtain` group:

```dart
    test('curtain hangs at the path Z of each sample', () {
      final mesh = RibbonBuilder.curtain(
        times: [0, 100],
        depths: [10, 20],
        zs: [-1.5, 2.0],
        bounds: const SceneBounds(durationSeconds: 100, maxDepthMeters: 20),
      );
      expect(mesh.positions[2], -1.5); // top vertex, sample 0
      expect(mesh.positions[5], -1.5); // floor vertex, sample 0
      expect(mesh.positions[8], 2.0); // top vertex, sample 1
    });
```

Create `test/features/dive_3d/domain/geometry/marker_layout_z_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';

void main() {
  final data = Dive3dSceneData(
    diveId: 'd1',
    times: const [0, 60, 120],
    depths: const [0, 18, 0],
    temperatures: const [null, null, null],
    ascentRates: const [null, null, null],
    ppO2s: const [null, null, null],
    cnss: const [null, null, null],
    heartRates: const [null, null, null],
    ceilings: const [null, null, null],
    ttss: const [null, null, null],
    tankPressures: const {},
    gasSwitches: [
      GasSwitchWithTank(
        gasSwitch: GasSwitch(
          id: 'gs1',
          diveId: 'd1',
          timestamp: 60,
          tankId: 't1',
          createdAt: DateTime.utc(2026),
        ),
        tankName: 'EAN50',
        gasMix: 'EAN50',
        o2Fraction: 0.5,
      ),
    ],
    bookmarkEvents: const [],
    photos: const [],
    durationSeconds: 120,
    maxDepthMeters: 18,
  );
  const bounds = SceneBounds(durationSeconds: 120, maxDepthMeters: 18);

  test('marker Z interpolates the decimated path', () {
    final markers = MarkerLayout.layout(
      data: data,
      bounds: bounds,
      pathTimes: const [0, 120],
      pathZs: const [-2, 2],
    );
    expect(markers.single.z, closeTo(0, 1e-9));
  });

  test('marker Z is 0 without a path', () {
    expect(MarkerLayout.layout(data: data, bounds: bounds).single.z, 0);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_3d/domain/geometry/ribbon_builder_test.dart test/features/dive_3d/domain/geometry/marker_layout_z_test.dart`
Expected: FAIL (no `zs` / `pathTimes` parameters).

- [ ] **Step 3: Implement**

`ribbon_builder.dart` `curtain`:

```dart
  static MeshData curtain({
    required List<double> times,
    required List<double> depths,
    required List<double> zs,
    required SceneBounds bounds,
  }) {
    final n = times.length;
    final positions = Float32List(n * 6);
    final colors = Float32List(n * 6);
    final floorY = bounds.sceneMinY;
    for (var i = 0; i < n; i++) {
      final x = bounds.xOf(times[i]);
      final p = i * 6;
      positions[p] = x;
      positions[p + 1] = bounds.yOf(depths[i]);
      positions[p + 2] = zs[i];
      positions[p + 3] = x;
      positions[p + 4] = floorY;
      positions[p + 5] = zs[i];
      for (var k = 0; k < 2; k++) {
        colors[p + k * 3] = _curtainColor.r;
        colors[p + k * 3 + 1] = _curtainColor.g;
        colors[p + k * 3 + 2] = _curtainColor.b;
      }
    }
    return MeshData(
      positions: positions,
      indices: stripIndices(n),
      colors: colors,
      opacity: _curtainOpacity,
    );
  }
```

`marker_layout.dart` `layout`:

```dart
  static List<SceneMarker> layout({
    required Dive3dSceneData data,
    required SceneBounds bounds,
    List<double>? pathTimes,
    List<double>? pathZs,
  }) {
    if (!data.hasProfile) return const [];
    final lookup = ProfileLookup(data.times);
    final nullableDepths = data.depths.cast<double?>();
    final zLookup = pathTimes == null || pathZs == null
        ? null
        : ProfileLookup(pathTimes);
    final nullableZs = pathZs?.cast<double?>();

    SceneMarker at({
      required SceneMarkerKind kind,
      required String? refId,
      required String label,
      required int t,
    }) {
      final depth = lookup.interpolate(nullableDepths, t.toDouble()) ?? 0;
      final z = zLookup?.interpolate(nullableZs!, t.toDouble()) ?? 0;
      return SceneMarker(
        kind: kind,
        refId: refId,
        label: label,
        x: bounds.xOf(t),
        y: bounds.yOf(depth) + _floatOffset,
        z: z,
        timestampSeconds: t,
      );
    }
    // ... the rest of the method is unchanged ...
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/dive_3d/domain/geometry`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_3d test/features/dive_3d
git add -A lib/features/dive_3d/domain/geometry test/features/dive_3d/domain/geometry
git commit -m "feat(dive_3d): curtain and markers follow the path Z"
```

---

### Task 9: `SceneGeometryService` builds the path scene

**Files:**
- Modify: `lib/features/dive_3d/domain/scene_geometry_service.dart`
- Modify: `lib/features/dive_3d/presentation/scene_overlay.dart` (add `shadows`)
- Delete: `lib/features/dive_3d/domain/geometry/grid_builder.dart`, `test/features/dive_3d/domain/geometry/grid_builder_test.dart`
- Modify: `lib/features/dive_3d/application/providers.dart` (compile fix only: pass `data, key.metric`; the real provider change is Task 11)
- Modify: `lib/features/dive_3d/presentation/pages/dive_3d_page.dart` (compile fix only: the overlays switch gains `SceneOverlay.shadows => 'Wall shadows'` as a temporary literal until Task 12)
- Test: `test/features/dive_3d/domain/scene_geometry_service_test.dart`, `test/features/dive_3d/domain/scene_geometry_service_metrics_test.dart`, `test/features/dive_3d/domain/scene_geometry_service_z_test.dart` (new), `test/features/dive_3d/application/providers_test.dart`

**Interfaces:**
- Produces: `Scene3d SceneGeometryService.build(Dive3dSceneData data, SceneMetric colorMetric, {ZAxisInput? zAxis})`. Layer order: strata (overlay `strata`), shadow walls then drops (overlay `shadows`, only with an effective Z), curtain (`curtain`), ceiling sheet (`ceiling`), path (structural, last). Bounds carry `sceneMinZ = -zPathHalfSpan`, `sceneMaxZ = +zPathHalfSpan`. `scrubPath.zs` is set.
- `SceneOverlay.shadows`.

- [ ] **Step 1: Write the failing tests**

Create `test/features/dive_3d/domain/scene_geometry_service_z_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/z_axis_spec.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/scene_geometry_service.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';

Dive3dSceneData data() => const Dive3dSceneData(
  diveId: 'd1',
  times: [0, 60, 120, 180],
  depths: [0, 20, 20, 0],
  temperatures: [22, null, 16, 21],
  ascentRates: [null, null, null, null],
  ppO2s: [null, null, null, null],
  cnss: [null, null, null, null],
  heartRates: [null, null, null, null],
  ceilings: [null, 3.0, 3.0, null],
  ttss: [null, null, null, null],
  tankPressures: {},
  gasSwitches: [],
  bookmarkEvents: [],
  photos: [],
  durationSeconds: 180,
  maxDepthMeters: 20,
);

List<SceneLayer> layersFor(Scene3d s, SceneOverlay o) =>
    s.layers.where((l) => l.overlay == o).toList();

void main() {
  const service = SceneGeometryService();
  const spec = ZAxisSpec(lo: 10, hi: 25, step: 5, symbol: '°C');

  test('None: flat path at z = 0, no shadows, same widened box', () {
    final scene = service.build(data(), SceneMetric.depth);
    expect(scene.scrubPath!.zs, [0, 0, 0, 0]);
    expect(layersFor(scene, SceneOverlay.shadows), isEmpty);
    expect(scene.bounds.sceneMinZ, -SceneBounds.zPathHalfSpan);
    expect(scene.bounds.sceneMaxZ, SceneBounds.zPathHalfSpan);
    expect(scene.layers.last.overlay, isNull); // the path is last
    expect(scene.layers.last.mesh.vertexCount, 16); // tube: 4 per sample
  });

  test('metric on Z: path Z follows the spec, shadows present, gap filled', () {
    final scene = service.build(
      data(),
      SceneMetric.depth,
      zAxis: ZAxisInput(
        metric: SceneMetric.temperature,
        spec: spec,
        values: data().temperatures,
      ),
    );
    final zs = scene.scrubPath!.zs!;
    expect(zs[0], closeTo(spec.zOf(22), 1e-6));
    expect(zs[1], closeTo(spec.zOf(19), 1e-6)); // interpolated 22 -> 16
    expect(zs[2], closeTo(spec.zOf(16), 1e-6));
    expect(layersFor(scene, SceneOverlay.shadows), hasLength(2));
    // Ceiling sheet and curtain ride the same Z as the path.
    final ceiling = layersFor(scene, SceneOverlay.ceiling).single.mesh;
    expect(ceiling.positions[2], closeTo(zs[1], 1e-6));
    final curtain = layersFor(scene, SceneOverlay.curtain).single.mesh;
    expect(curtain.positions[2], closeTo(zs[0], 1e-6));
  });

  test('a Z series with fewer than two finite samples falls back to None', () {
    final scene = service.build(
      data(),
      SceneMetric.depth,
      zAxis: const ZAxisInput(
        metric: SceneMetric.temperature,
        spec: spec,
        values: [22, null, null, null],
      ),
    );
    expect(scene.scrubPath!.zs, [0, 0, 0, 0]);
    expect(layersFor(scene, SceneOverlay.shadows), isEmpty);
  });
}
```

Update the existing tests:
- `scene_geometry_service_test.dart`: in 'builds ribbon, curtain and strata layers', change `expect(ribbonLayer(scene).mesh.vertexCount, 200);` to `400` (the tube has 4 vertices per sample). In 'decimates geometry above 2000 samples', change the two bounds to `lessThanOrEqualTo(4 * 2000)` and `greaterThan(4 * 1000)`.
- `scene_geometry_service_metrics_test.dart`: delete the `gridMesh` helper and the whole `'grid step parameter controls line count'` test.
- `providers_test.dart`: this task only fixes compilation; the key rename happens in Task 11. Change `expect(scene!.layers.lastWhere((l) => l.overlay == null).mesh.vertexCount, 6)` to `12`, and replace the two "Grid" lines (`expect(scene.layers.first.overlay, isNull);` and its comment) with `expect(scene.layers.last.overlay, isNull); // the path`.
- `test/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport_test.dart`: `buildScene()` still compiles (positional `SceneMetric.depth`).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_3d/domain/scene_geometry_service_z_test.dart`
Expected: FAIL (no `zAxis` parameter; ceiling builder mismatch).

- [ ] **Step 3: Implement**

`scene_overlay.dart`: add `shadows,` after `markers,`.

Delete `grid_builder.dart` and `grid_builder_test.dart` (`git rm`).

Rewrite `scene_geometry_service.dart` from the imports through the end of `build` (keep `_metricSeries`, `_resampledPressure`, and `ProfileLookupOverPressure` as they are, plus the `tts` case from Task 2):

```dart
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_decimator.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/ceiling_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/geometry/path_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/ribbon_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/shadow_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/strata_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/z_axis_spec.dart';
import 'package:submersion/features/dive_3d/domain/geometry/z_series.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';

/// Pure, synchronous assembly of the single-dive path scene. Isolate-
/// friendly: callers wrap it in compute() (repo convention: the pure worker
/// is the tested unit, the isolate hop is not). X = run time, Y = depth,
/// Z = the metric in [zAxis] (flat at 0 when null or when the series has
/// too few samples to form a path). Produces the renderer-neutral
/// [Scene3d] every dive_3d scene shares.
class SceneGeometryService {
  static const int targetPoints = 2000;

  const SceneGeometryService();

  Scene3d build(
    Dive3dSceneData data,
    SceneMetric colorMetric, {
    ZAxisInput? zAxis,
  }) {
    final bounds = SceneBounds(
      durationSeconds: data.durationSeconds,
      maxDepthMeters: data.maxDepthMeters,
      sceneMinZ: -SceneBounds.zPathHalfSpan,
      sceneMaxZ: SceneBounds.zPathHalfSpan,
    );

    final indices = decimateSeriesIndices(
      data.depths,
      targetPoints: targetPoints,
    );
    List<double> pickD(List<double> s) => [for (final i in indices) s[i]];
    List<double?> pickN(List<double?> s) => [for (final i in indices) s[i]];

    final times = pickD(data.times);
    final depths = pickD(data.depths);
    final colorValues = _metricSeries(data, colorMetric, indices);
    final sampleColors = MetricPalette.colorsFor(colorMetric, colorValues);

    final zValues = zAxis == null
        ? null
        : resampleZSeries(values: zAxis.values, indices: indices);
    final hasZ = zAxis != null && zValues != null;
    final zs = hasZ
        ? [for (final v in zValues) zAxis.spec.zOf(v)]
        : List<double>.filled(times.length, 0);

    final strata = StrataBuilder.build(
      bands: StrataBuilder.bin(
        depths: data.depths,
        temperatures: data.temperatures,
      ),
      bounds: bounds,
    );
    final shadows = hasZ
        ? ShadowBuilder.build(
            times: times,
            depths: depths,
            zs: zs,
            bounds: bounds,
          )
        : null;
    final ceiling = CeilingBuilder.build(
      times: times,
      depths: depths,
      zs: zs,
      ceilings: pickN(data.ceilings),
      bounds: bounds,
    );

    final layers = <SceneLayer>[
      if (strata != null) SceneLayer(strata, overlay: SceneOverlay.strata),
      if (shadows != null) ...[
        SceneLayer(shadows.walls, overlay: SceneOverlay.shadows),
        SceneLayer(shadows.drops, overlay: SceneOverlay.shadows),
      ],
      SceneLayer(
        RibbonBuilder.curtain(
          times: times,
          depths: depths,
          zs: zs,
          bounds: bounds,
        ),
        overlay: SceneOverlay.curtain,
      ),
      if (ceiling != null) SceneLayer(ceiling, overlay: SceneOverlay.ceiling),
      SceneLayer(
        PathBuilder.build(
          times: times,
          depths: depths,
          zs: zs,
          sampleColors: sampleColors,
          bounds: bounds,
        ),
      ),
    ];

    final duration = data.durationSeconds <= 0 ? 1.0 : data.durationSeconds;
    return Scene3d(
      layers: layers,
      markers: MarkerLayout.layout(
        data: data,
        bounds: bounds,
        pathTimes: times,
        pathZs: zs,
      ),
      bounds: bounds,
      scrubPath: ScrubPath(
        normalizedTimes: [for (final t in times) t / duration],
        xs: [for (final t in times) bounds.xOf(t)],
        ys: [for (final d in depths) bounds.yOf(d)],
        zs: zs,
      ),
    );
  }
```

`application/providers.dart` compile fix: change `_buildGeometry` to

```dart
Scene3d _buildGeometry((Dive3dSceneData, SceneMetric) input) =>
    const SceneGeometryService().build(input.$1, input.$2);
```

and in `dive3dGeometryProvider` drop the `depthUnit`/`gridStep` lines and call `_buildGeometry((data, key.metric))` / `compute(_buildGeometry, (data, key.metric))`. (Task 11 replaces this provider wholesale.) Remove the now-unused `units.dart` and `settings_providers.dart` imports if the analyzer flags them.

`dive_3d_page.dart` compile fix: in the overlays `switch`, add `SceneOverlay.shadows => 'Wall shadows',` (Task 12 swaps in the l10n key).

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/dive_3d`
Expected: all PASS. If `dive_3d_page_test.dart`'s 'overlay menu' test now finds 5 `CheckedPopupMenuItem`s instead of 4, update that expectation to `findsNWidgets(5)`.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_3d test/features/dive_3d
git add -A lib/features/dive_3d test/features/dive_3d
git commit -m "feat(dive_3d): build the single-dive scene as a Z-metric path"
```

---

### Task 10: `buildDiveAxes` and tick helpers

**Files:**
- Create: `lib/features/dive_3d/domain/geometry/dive_axes.dart`
- Test: `test/features/dive_3d/domain/geometry/dive_axes_test.dart`

**Interfaces:**
- Produces:
  - `class AxisTick { final double value; final String text; const AxisTick(this.value, this.text); }`
  - `List<AxisTick> depthAxisTicks({required double maxDepthMeters, required double stepMeters, required double Function(double meters) toDisplay})`: `value` in meters, `text` = rounded display value ('0' first).
  - `List<AxisTick> timeAxisTicks(double durationSeconds)`: `value` in seconds, `text` in whole minutes; step is the first of 60/120/300/600/900/1800/3600 s giving at most 6 ticks (3600 s otherwise); the 0 tick is included.
  - `typedef DiveAxes = ({AxisFrame frame, AxisLabelSet labels});`
  - `DiveAxes buildDiveAxes({required SceneBounds bounds, required List<AxisTick> depthTicks, required List<AxisTick> timeTicks, ZAxisSpec? zAxis, required String depthTitle, required String timeTitle, String? zTitle})`.

Geometry (all in scene units; `x0 = 0`, `x1 = xSpan`, `yTop = 0`, `yFloor = bounds.sceneMinY`, `zBack = bounds.sceneMinZ`, `zFront = bounds.sceneMaxZ`, `tick = xSpan * 0.02`):
- `axisY`: `(x0, yTop, zFront) -> (x0, yFloor, zFront)`; `tickY` at each depth tick: `(x0, y, zFront) -> (x0, y, zFront + tick)`; tick label anchored at `(x0, y, zFront)`; title at `(x0, yTop, zFront)`.
- `axisX`: `(x0, yFloor, zFront) -> (x1, yFloor, zFront)`; `tickX` at each time tick: `(x, yFloor, zFront) -> (x, yFloor, zFront + tick)`; label at `(x, yFloor, zFront)`; title at `(x1, yFloor, zFront)`.
- `axisZ` (only with `zAxis`): `(x1, yFloor, zFront) -> (x1, yFloor, zBack)`; `tickZ` at each spec tick `z = zAxis.zOf(v)`: `(x1, yFloor, z) -> (x1 + tick, yFloor, z)`; label at `(x1, yFloor, z)` with `formatTickValue(v, step)`; title at `(x1, yFloor, zBack)`.
- `frameGrid`: box edges (the 9 edges of the back wall, floor, and left wall), plus at every depth tick a back-wall line `(x0, y, zBack) -> (x1, y, zBack)` and a left-wall line `(x0, y, zBack) -> (x0, y, zFront)`; at every time tick a back-wall vertical `(x, yTop, zBack) -> (x, yFloor, zBack)` and a floor line `(x, yFloor, zBack) -> (x, yFloor, zFront)`; with `zAxis`, at every Z tick a floor line `(x0, yFloor, z) -> (x1, yFloor, z)` and a left-wall vertical `(x0, yTop, z) -> (x0, yFloor, z)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_3d/domain/geometry/dive_axes_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/axis_frame.dart';
import 'package:submersion/features/dive_3d/domain/geometry/dive_axes.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/z_axis_spec.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/axis_labels.dart';

void main() {
  const bounds = SceneBounds(
    durationSeconds: 3120,
    maxDepthMeters: 38,
    sceneMinZ: -SceneBounds.zPathHalfSpan,
    sceneMaxZ: SceneBounds.zPathHalfSpan,
  );

  test('depth ticks step in meters and label in the display unit', () {
    final metric = depthAxisTicks(
      maxDepthMeters: 38,
      stepMeters: 10,
      toDisplay: (m) => m,
    );
    expect(metric.map((t) => t.text), ['0', '10', '20', '30']);
    final imperial = depthAxisTicks(
      maxDepthMeters: 38,
      stepMeters: 7.62,
      toDisplay: (m) => m / 0.3048,
    );
    expect(imperial.map((t) => t.text), ['0', '25', '50', '75', '100']);
    expect(imperial[1].value, closeTo(7.62, 1e-9));
  });

  test('time ticks pick the first nice step with at most six ticks', () {
    expect(timeAxisTicks(3120).map((t) => t.text), ['0', '10', '20', '30', '40', '50']);
    expect(timeAxisTicks(180).map((t) => t.text), ['0', '1', '2', '3']);
    expect(timeAxisTicks(3120)[1].value, 600);
  });

  test('frame has three axes, ticks, and wall grids when Z is set', () {
    const spec = ZAxisSpec(lo: 10, hi: 25, step: 5, symbol: '°C');
    final axes = buildDiveAxes(
      bounds: bounds,
      depthTicks: depthAxisTicks(maxDepthMeters: 38, stepMeters: 10, toDisplay: (m) => m),
      timeTicks: timeAxisTicks(3120),
      zAxis: spec,
      depthTitle: 'Depth (m)',
      timeTitle: 'Run time (min)',
      zTitle: 'Temperature (°C)',
    );
    final roles = axes.frame.segments.map((s) => s.role).toSet();
    expect(roles, containsAll(AxisRole.values));
    final zTicks = axes.frame.segments.where((s) => s.role == AxisRole.tickZ);
    expect(zTicks, hasLength(4)); // 10, 15, 20, 25
    expect(zTicks.first.z1, closeTo(spec.zOf(10), 1e-9));
    expect(zTicks.first.x1, SceneBounds.xSpan);
    final depthTick = axes.frame.segments.firstWhere((s) => s.role == AxisRole.tickY && s.y1 != 0);
    expect(depthTick.y1, closeTo(bounds.yOf(10), 1e-9));
    expect(depthTick.z1, bounds.sceneMaxZ);
    final titles = axes.labels.labels.where((l) => l.kind == AxisLabelKind.title).map((l) => l.text);
    expect(titles, ['Depth (m)', 'Run time (min)', 'Temperature (°C)']);
    final zLabels = axes.labels.labels.where((l) => l.kind == AxisLabelKind.tick && l.x == SceneBounds.xSpan).map((l) => l.text);
    expect(zLabels, ['10', '15', '20', '25']);
  });

  test('None mode omits the Z axis, its ticks, and its grid lines', () {
    final axes = buildDiveAxes(
      bounds: bounds,
      depthTicks: depthAxisTicks(maxDepthMeters: 38, stepMeters: 10, toDisplay: (m) => m),
      timeTicks: timeAxisTicks(3120),
      depthTitle: 'Depth (m)',
      timeTitle: 'Run time (min)',
    );
    final roles = axes.frame.segments.map((s) => s.role).toSet();
    expect(roles, isNot(contains(AxisRole.axisZ)));
    expect(roles, isNot(contains(AxisRole.tickZ)));
    // Box edges + 4 depth ticks x 2 walls + 6 time ticks x 2 walls.
    final grid = axes.frame.segments.where((s) => s.role == AxisRole.frameGrid);
    expect(grid, hasLength(9 + 4 * 2 + 6 * 2));
    expect(axes.labels.labels.where((l) => l.kind == AxisLabelKind.title), hasLength(2));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/domain/geometry/dive_axes_test.dart`
Expected: FAIL (missing file).

- [ ] **Step 3: Implement**

```dart
// lib/features/dive_3d/domain/geometry/dive_axes.dart
import 'package:submersion/features/dive_3d/domain/geometry/axis_frame.dart';
import 'package:submersion/features/dive_3d/domain/geometry/nice_step.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/z_axis_spec.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/axis_labels.dart';

/// A tick on a dive axis: [value] in the axis's native unit (meters or
/// seconds), [text] already formatted for display.
class AxisTick {
  final double value;
  final String text;
  const AxisTick(this.value, this.text);
}

/// Depth ticks every [stepMeters] from the surface to the max depth, labeled
/// with the rounded display value ([toDisplay] converts meters to the
/// diver's unit). The unit symbol belongs in the axis title, not here.
List<AxisTick> depthAxisTicks({
  required double maxDepthMeters,
  required double stepMeters,
  required double Function(double meters) toDisplay,
}) {
  final ticks = <AxisTick>[const AxisTick(0, '0')];
  if (stepMeters <= 0) return ticks;
  for (var d = stepMeters; d <= maxDepthMeters + 1e-9; d += stepMeters) {
    ticks.add(AxisTick(d, toDisplay(d).round().toString()));
  }
  return ticks;
}

const List<int> _timeStepsSeconds = [60, 120, 300, 600, 900, 1800, 3600];

/// Whole-minute time ticks: the first step in the 1/2/5/10/15/30/60 min
/// ladder that yields at most six ticks across the runtime.
List<AxisTick> timeAxisTicks(double durationSeconds) {
  final step = _timeStepsSeconds.firstWhere(
    (s) => durationSeconds / s <= 6,
    orElse: () => 3600,
  );
  final ticks = <AxisTick>[const AxisTick(0, '0')];
  for (var t = step; t <= durationSeconds + 1e-9; t += step) {
    ticks.add(AxisTick(t.toDouble(), (t ~/ 60).toString()));
  }
  return ticks;
}

typedef DiveAxes = ({AxisFrame frame, AxisLabelSet labels});

/// Axes, ticks, labels, and wall grids for the path scene. Depth runs up the
/// front-left edge, time along the front floor edge, and the Z metric (when
/// present) along the right floor edge, so every axis sits on a visible
/// edge at the default pose. Pure geometry with pre-formatted strings:
/// titles arrive localized and unit-suffixed from the caller.
DiveAxes buildDiveAxes({
  required SceneBounds bounds,
  required List<AxisTick> depthTicks,
  required List<AxisTick> timeTicks,
  ZAxisSpec? zAxis,
  required String depthTitle,
  required String timeTitle,
  String? zTitle,
}) {
  const x0 = 0.0;
  const x1 = SceneBounds.xSpan;
  const yTop = 0.0;
  final yFloor = bounds.sceneMinY;
  final zBack = bounds.sceneMinZ;
  final zFront = bounds.sceneMaxZ;
  const tick = SceneBounds.xSpan * 0.02;

  final segments = <AxisSegment>[
    AxisSegment(AxisRole.axisY, x0, yTop, zFront, x0, yFloor, zFront),
    AxisSegment(AxisRole.axisX, x0, yFloor, zFront, x1, yFloor, zFront),
    // Box edges: back wall (4), floor (3 new), left wall (2 new).
    AxisSegment(AxisRole.frameGrid, x0, yTop, zBack, x1, yTop, zBack),
    AxisSegment(AxisRole.frameGrid, x0, yFloor, zBack, x1, yFloor, zBack),
    AxisSegment(AxisRole.frameGrid, x0, yTop, zBack, x0, yFloor, zBack),
    AxisSegment(AxisRole.frameGrid, x1, yTop, zBack, x1, yFloor, zBack),
    AxisSegment(AxisRole.frameGrid, x0, yFloor, zBack, x0, yFloor, zFront),
    AxisSegment(AxisRole.frameGrid, x1, yFloor, zBack, x1, yFloor, zFront),
    AxisSegment(AxisRole.frameGrid, x0, yFloor, zFront, x1, yFloor, zFront),
    AxisSegment(AxisRole.frameGrid, x0, yTop, zBack, x0, yTop, zFront),
    AxisSegment(AxisRole.frameGrid, x0, yTop, zFront, x0, yFloor, zFront),
  ];
  final labels = <AxisLabel>[
    AxisLabel(AxisLabelKind.title, x0, yTop, zFront, depthTitle),
    AxisLabel(AxisLabelKind.title, x1, yFloor, zFront, timeTitle),
  ];

  for (final t in depthTicks) {
    final y = bounds.yOf(t.value);
    segments.add(AxisSegment(AxisRole.tickY, x0, y, zFront, x0, y, zFront + tick));
    segments.add(AxisSegment(AxisRole.frameGrid, x0, y, zBack, x1, y, zBack));
    segments.add(AxisSegment(AxisRole.frameGrid, x0, y, zBack, x0, y, zFront));
    labels.add(AxisLabel(AxisLabelKind.tick, x0, y, zFront, t.text));
  }
  for (final t in timeTicks) {
    final x = bounds.xOf(t.value);
    segments.add(AxisSegment(AxisRole.tickX, x, yFloor, zFront, x, yFloor, zFront + tick));
    segments.add(AxisSegment(AxisRole.frameGrid, x, yTop, zBack, x, yFloor, zBack));
    segments.add(AxisSegment(AxisRole.frameGrid, x, yFloor, zBack, x, yFloor, zFront));
    labels.add(AxisLabel(AxisLabelKind.tick, x, yFloor, zFront, t.text));
  }
  if (zAxis != null) {
    segments.add(AxisSegment(AxisRole.axisZ, x1, yFloor, zFront, x1, yFloor, zBack));
    labels.add(AxisLabel(AxisLabelKind.title, x1, yFloor, zBack, zTitle ?? zAxis.symbol));
    for (final v in zAxis.ticks) {
      final z = zAxis.zOf(v);
      segments.add(AxisSegment(AxisRole.tickZ, x1, yFloor, z, x1 + tick, yFloor, z));
      segments.add(AxisSegment(AxisRole.frameGrid, x0, yFloor, z, x1, yFloor, z));
      segments.add(AxisSegment(AxisRole.frameGrid, x0, yTop, z, x0, yFloor, z));
      labels.add(AxisLabel(AxisLabelKind.tick, x1, yFloor, z, formatTickValue(v, zAxis.step)));
    }
  }
  return (frame: AxisFrame(segments), labels: AxisLabelSet(labels));
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/dive_3d/domain/geometry/dive_axes_test.dart`
Expected: PASS. (Grid count in None mode: 9 edges + 4 depth ticks x 2 + 6 time ticks x 2 = 29.)

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_3d test/features/dive_3d
git add lib/features/dive_3d/domain/geometry/dive_axes.dart test/features/dive_3d/domain/geometry/dive_axes_test.dart
git commit -m "feat(dive_3d): add dive axis frame, tick helpers, and labels"
```

---

### Task 11: Z axis input and the geometry provider key

**Files:**
- Create: `lib/features/dive_3d/application/z_axis_input.dart`
- Modify: `lib/features/dive_3d/application/providers.dart`
- Modify: `lib/features/dive_3d/presentation/pages/dive_3d_page.dart` (compile fix: the one `dive3dGeometryProvider((diveId: ..., metric: _metric))` call becomes `(diveId: widget.diveId, colorMetric: _metric, zMetric: null)`; Task 17 finishes the page)
- Test: `test/features/dive_3d/application/z_axis_input_test.dart`, `test/features/dive_3d/application/providers_test.dart`

**Interfaces:**
- Produces:
  - `ZAxisInput? buildZAxisInput(Dive3dSceneData data, SceneMetric metric, UnitFormatter units)`: null when the metric has fewer than two finite samples; `depth` is an `ArgumentError`.
  - `typedef Dive3dGeometryKey = ({String diveId, SceneMetric colorMetric, SceneMetric? zMetric});`
  - `typedef Dive3dZAxisKey = ({String diveId, SceneMetric? zMetric});`
  - `final dive3dZAxisProvider = Provider.family<ZAxisInput?, Dive3dZAxisKey>`
  - `dive3dGeometryProvider` keyed by `Dive3dGeometryKey`.

Display conversions: temperature `units.convertTemperature`, symbol `units.temperatureSymbol`; tankPressure `units.convertPressure` on the first non-empty tank resampled onto `data.times`, symbol `units.pressureSymbol`; ascentRate `units.convertDepth`, symbol `'${units.depthSymbol}/min'`; tts seconds / 60, symbol `'min'`; ppO2 symbol `''`; cns `'%'`; heartRate `'bpm'`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/dive_3d/application/z_axis_input_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/application/z_axis_input.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

Dive3dSceneData data({
  Map<String, List<TankPressurePoint>> tanks = const {},
}) => Dive3dSceneData(
  diveId: 'd1',
  times: const [0, 60, 120],
  depths: const [0, 20, 0],
  temperatures: const [22, 12, null],
  ascentRates: const [null, null, null],
  ppO2s: const [null, null, null],
  cnss: const [null, null, null],
  heartRates: const [null, null, null],
  ceilings: const [null, null, null],
  ttss: const [null, 600, 300],
  tankPressures: tanks,
  gasSwitches: const [],
  bookmarkEvents: const [],
  photos: const [],
  durationSeconds: 120,
  maxDepthMeters: 20,
);

void main() {
  const metric = UnitFormatter(AppSettings());
  const imperial = UnitFormatter(
    AppSettings(
      temperatureUnit: TemperatureUnit.fahrenheit,
      pressureUnit: PressureUnit.psi,
    ),
  );

  test('temperature converts to the display unit and gets a nice range', () {
    final c = buildZAxisInput(data(), SceneMetric.temperature, metric)!;
    expect(c.values, [22, 12, null]);
    expect((c.spec.lo, c.spec.hi, c.spec.step, c.spec.symbol), (10.0, 25.0, 5.0, '°C'));
    final f = buildZAxisInput(data(), SceneMetric.temperature, imperial)!;
    expect(f.values[0], closeTo(71.6, 1e-9));
    expect(f.spec.symbol, '°F');
    expect((f.spec.lo, f.spec.hi), (50.0, 75.0));
  });

  test('tts is minutes; tank pressure resamples the first tank', () {
    final tts = buildZAxisInput(data(), SceneMetric.tts, metric)!;
    expect(tts.values, [null, 10, 5]);
    expect(tts.spec.symbol, 'min');
    final tanks = {
      't1': [
        TankPressurePoint(timestamp: 0, pressure: 200),
        TankPressurePoint(timestamp: 120, pressure: 100),
      ],
    };
    final bar = buildZAxisInput(data(tanks: tanks), SceneMetric.tankPressure, metric)!;
    expect(bar.values[1], closeTo(150, 1e-9));
    expect(bar.spec.symbol, 'bar');
    final psi = buildZAxisInput(data(tanks: tanks), SceneMetric.tankPressure, imperial)!;
    expect(psi.values[0], closeTo(2900.75, 0.01));
    expect(psi.spec.symbol, 'psi');
  });

  test('too few samples yields null; depth is rejected', () {
    expect(buildZAxisInput(data(), SceneMetric.ppO2, metric), isNull);
    expect(() => buildZAxisInput(data(), SceneMetric.depth, metric), throwsArgumentError);
  });
}
```

In `test/features/dive_3d/application/providers_test.dart`:
- change `point` to `DiveProfilePoint point(int t, double d, {double? temp}) => DiveProfilePoint(timestamp: t, depth: d, temperature: temp);`
- every `dive3dGeometryProvider((diveId: 'd1', metric: SceneMetric.depth))` becomes `dive3dGeometryProvider((diveId: 'd1', colorMetric: SceneMetric.depth, zMetric: null))`
- append this test inside `main`:

```dart
  test('a Z metric puts shadows in the scene and exposes its axis', () async {
    final container = await makeContainer(
      sourceProfiles: {
        'src': SourceProfile(
          sourceId: 'src',
          computerId: null,
          isEdited: false,
          points: [point(0, 0, temp: 22), point(60, 10, temp: 14), point(120, 0, temp: 20)],
        ),
      },
    );
    final axis = container.read(
      dive3dZAxisProvider((diveId: 'd1', zMetric: SceneMetric.temperature)),
    );
    // Scene data is async; the axis provider resolves once it has loaded.
    await container.read(dive3dSceneDataProvider('d1').future);
    final resolved = axis ??
        container.read(
          dive3dZAxisProvider((diveId: 'd1', zMetric: SceneMetric.temperature)),
        );
    expect(resolved!.spec.symbol, '°C');
    final scene = await container.read(
      dive3dGeometryProvider((
        diveId: 'd1',
        colorMetric: SceneMetric.depth,
        zMetric: SceneMetric.temperature,
      )).future,
    );
    expect(scene!.layers.where((l) => l.overlay == SceneOverlay.shadows), hasLength(2));
  });
```

(add `import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';` to that test file.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_3d/application/z_axis_input_test.dart test/features/dive_3d/application/providers_test.dart`
Expected: FAIL (missing file, record key mismatch).

- [ ] **Step 3: Implement**

```dart
// lib/features/dive_3d/application/z_axis_input.dart
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/z_axis_spec.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/domain/scene_geometry_service.dart';

/// Converts [metric]'s full-resolution series into the diver's display
/// units and fits a nice axis around it. Returns null when fewer than two
/// finite samples exist (no path to draw), which the UI shows as None.
ZAxisInput? buildZAxisInput(
  Dive3dSceneData data,
  SceneMetric metric,
  UnitFormatter units,
) {
  final (values, symbol) = switch (metric) {
    SceneMetric.depth => throw ArgumentError('depth is the Y axis'),
    SceneMetric.temperature => (
      [for (final t in data.temperatures) t == null ? null : units.convertTemperature(t)],
      units.temperatureSymbol,
    ),
    SceneMetric.ascentRate => (
      [for (final r in data.ascentRates) r == null ? null : units.convertDepth(r)],
      '${units.depthSymbol}/min',
    ),
    SceneMetric.ppO2 => (data.ppO2s, ''),
    SceneMetric.cns => (data.cnss, '%'),
    SceneMetric.heartRate => (data.heartRates, 'bpm'),
    SceneMetric.tts => (
      [for (final s in data.ttsSeconds) s == null ? null : s / 60],
      'min',
    ),
    SceneMetric.tankPressure => (_tankSeries(data, units), units.pressureSymbol),
  };
  final finite = [for (final v in values) if (v != null && v.isFinite) v];
  if (finite.length < 2) return null;
  var min = finite.first, max = finite.first;
  for (final v in finite) {
    if (v < min) min = v;
    if (v > max) max = v;
  }
  return ZAxisInput(
    metric: metric,
    spec: ZAxisSpec.fromRange(min: min, max: max, symbol: symbol),
    values: values,
  );
}

List<double?> _tankSeries(Dive3dSceneData data, UnitFormatter units) {
  final series = data.tankPressures.values.where((p) => p.isNotEmpty).toList();
  if (series.isEmpty) return List<double?>.filled(data.times.length, null);
  final lookup = ProfileLookupOverPressure(series.first);
  return [
    for (final t in data.times)
      switch (lookup.at(t)) {
        null => null,
        final bar => units.convertPressure(bar),
      },
  ];
}
```

`providers.dart`: replace everything from `typedef Dive3dGeometryKey` to the end with:

```dart
typedef Dive3dGeometryKey = ({
  String diveId,
  SceneMetric colorMetric,
  SceneMetric? zMetric,
});
typedef Dive3dZAxisKey = ({String diveId, SceneMetric? zMetric});

/// The Z axis for (dive, metric) in the diver's display units, or null for
/// None, for an unavailable metric, or while scene data is still loading.
/// Watches settings so a unit change re-fits the axis.
final dive3dZAxisProvider = Provider.family<ZAxisInput?, Dive3dZAxisKey>((
  ref,
  key,
) {
  final zMetric = key.zMetric;
  final data = ref.watch(dive3dSceneDataProvider(key.diveId)).value;
  if (zMetric == null || data == null) return null;
  return buildZAxisInput(data, zMetric, UnitFormatter(ref.watch(settingsProvider)));
});

Scene3d _buildGeometry((Dive3dSceneData, SceneMetric, ZAxisInput?) input) =>
    const SceneGeometryService().build(input.$1, input.$2, zAxis: input.$3);

/// Profiles below this sample count build geometry synchronously; the
/// isolate hop only pays for itself on large tech-dive profiles.
const int _computeThreshold = 2000;

/// Scene per (dive, color metric, Z metric). Family caching makes switching
/// back instant; compute() keeps large builds off the UI thread.
final dive3dGeometryProvider =
    FutureProvider.family<Scene3d?, Dive3dGeometryKey>((ref, key) async {
      final data = await ref.watch(dive3dSceneDataProvider(key.diveId).future);
      if (data == null) return null;
      final zAxis = ref.watch(
        dive3dZAxisProvider((diveId: key.diveId, zMetric: key.zMetric)),
      );
      if (data.times.length < _computeThreshold) {
        return _buildGeometry((data, key.colorMetric, zAxis));
      }
      return compute(_buildGeometry, (data, key.colorMetric, zAxis));
    });
```

Add imports `package:submersion/core/utils/unit_formatter.dart`, `package:submersion/features/dive_3d/application/z_axis_input.dart`, `package:submersion/features/dive_3d/domain/geometry/z_axis_spec.dart`; keep `settings_providers.dart`; drop `core/constants/units.dart` if unused.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/dive_3d`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_3d test/features/dive_3d
git add -A lib/features/dive_3d test/features/dive_3d
git commit -m "feat(dive_3d): Z axis input in display units and a Z-aware geometry key"
```

---

### Task 12: Localized strings for the path scene (all 11 ARBs)

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and `app_{ar,de,es,fr,he,hu,it,nl,pt,zh}.arb`
- Generated: `lib/l10n/arb/app_localizations*.dart` (via `flutter gen-l10n`)
- Test: `test/features/dive_3d/l10n_keys_test.dart`

**Interfaces:**
- Produces these `AppLocalizations` getters: `dive3d_zAxis`, `dive3d_zAxis_none`, `dive3d_overlay_shadows`, `dive3d_metric_tts`, `dive3d_axis_depth(String unitSymbol)`, `dive3d_axis_time`, `dive3d_pose_menu`, `dive3d_pose_default`, `dive3d_pose_front`, `dive3d_pose_side`, `dive3d_pose_top`, `dive3d_readout_runTime`, `dive3d_readout_ceiling`, `dive3d_readout_tank(int n)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_3d/l10n_keys_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('path scene strings exist in English and German', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(en.dive3d_zAxis, 'Z axis');
    expect(en.dive3d_axis_depth('ft'), 'Depth (ft)');
    expect(en.dive3d_readout_tank(2), 'Tank 2');
    expect(en.dive3d_pose_side, 'Side (depth vs metric)');
    final de = await AppLocalizations.delegate.load(const Locale('de'));
    expect(de.dive3d_zAxis, 'Z-Achse');
    expect(de.dive3d_overlay_shadows, 'Wandschatten');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/l10n_keys_test.dart`
Expected: FAIL (getters undefined).

- [ ] **Step 3: Insert the keys into every ARB by anchor line, then generate**

Save this script as `scratch_add_l10n.py` in the worktree root (do NOT commit it; delete it afterwards), then run `python3 scratch_add_l10n.py`.

```python
import json, io

KEYS = [
    ("dive3d_zAxis", None),
    ("dive3d_zAxis_none", None),
    ("dive3d_overlay_shadows", None),
    ("dive3d_metric_tts", None),
    ("dive3d_axis_depth", {"unitSymbol": {"type": "String"}}),
    ("dive3d_axis_time", None),
    ("dive3d_pose_menu", None),
    ("dive3d_pose_default", None),
    ("dive3d_pose_front", None),
    ("dive3d_pose_side", None),
    ("dive3d_pose_top", None),
    ("dive3d_readout_runTime", None),
    ("dive3d_readout_ceiling", None),
    ("dive3d_readout_tank", {"n": {"type": "int"}}),
]

T = {
 "en": ["Z axis", "None", "Wall shadows", "TTS", "Depth ({unitSymbol})", "Run time (min)", "Camera", "Default view", "Front (depth vs time)", "Side (depth vs metric)", "Top (metric vs time)", "Run time", "Ceiling", "Tank {n}"],
 "de": ["Z-Achse", "Keine", "Wandschatten", "TTS", "Tiefe ({unitSymbol})", "Laufzeit (min)", "Kamera", "Standardansicht", "Vorne (Tiefe vs. Zeit)", "Seite (Tiefe vs. Messwert)", "Oben (Messwert vs. Zeit)", "Laufzeit", "Ceiling", "Flasche {n}"],
 "es": ["Eje Z", "Ninguno", "Sombras en paredes", "TTS", "Profundidad ({unitSymbol})", "Tiempo de inmersión (min)", "Cámara", "Vista predeterminada", "Frontal (profundidad vs. tiempo)", "Lateral (profundidad vs. métrica)", "Superior (métrica vs. tiempo)", "Tiempo de inmersión", "Techo", "Botella {n}"],
 "fr": ["Axe Z", "Aucun", "Ombres sur les parois", "TTS", "Profondeur ({unitSymbol})", "Temps de plongée (min)", "Caméra", "Vue par défaut", "Face (profondeur / temps)", "Côté (profondeur / mesure)", "Dessus (mesure / temps)", "Temps de plongée", "Plafond", "Bloc {n}"],
 "it": ["Asse Z", "Nessuno", "Ombre sulle pareti", "TTS", "Profondità ({unitSymbol})", "Tempo di immersione (min)", "Camera", "Vista predefinita", "Frontale (profondità / tempo)", "Laterale (profondità / metrica)", "Dall'alto (metrica / tempo)", "Tempo di immersione", "Soffitto", "Bombola {n}"],
 "nl": ["Z-as", "Geen", "Wandschaduwen", "TTS", "Diepte ({unitSymbol})", "Duiktijd (min)", "Camera", "Standaardweergave", "Voor (diepte vs. tijd)", "Zijkant (diepte vs. meetwaarde)", "Boven (meetwaarde vs. tijd)", "Duiktijd", "Plafond", "Fles {n}"],
 "pt": ["Eixo Z", "Nenhum", "Sombras nas paredes", "TTS", "Profundidade ({unitSymbol})", "Tempo de mergulho (min)", "Câmera", "Vista padrão", "Frente (profundidade vs. tempo)", "Lado (profundidade vs. métrica)", "Topo (métrica vs. tempo)", "Tempo de mergulho", "Teto", "Cilindro {n}"],
 "hu": ["Z tengely", "Nincs", "Falárnyékok", "TTS", "Mélység ({unitSymbol})", "Merülési idő (perc)", "Kamera", "Alapnézet", "Elölnézet (mélység / idő)", "Oldalnézet (mélység / mérőszám)", "Felülnézet (mérőszám / idő)", "Merülési idő", "Plafon", "Palack {n}"],
 "ar": ["المحور Z", "بدون", "ظلال الجدران", "TTS", "العمق ({unitSymbol})", "زمن الغوص (دقيقة)", "الكاميرا", "العرض الافتراضي", "أمامي (العمق مقابل الزمن)", "جانبي (العمق مقابل القياس)", "علوي (القياس مقابل الزمن)", "زمن الغوص", "السقف", "أسطوانة {n}"],
 "he": ["ציר Z", "ללא", "צללי קירות", "TTS", "עומק ({unitSymbol})", "זמן צלילה (דק')", "מצלמה", "תצוגת ברירת מחדל", "חזית (עומק מול זמן)", "צד (עומק מול מדד)", "מלמעלה (מדד מול זמן)", "זמן צלילה", "תקרה", "מיכל {n}"],
 "zh": ["Z 轴", "无", "壁面投影", "TTS", "深度（{unitSymbol}）", "潜水时间（分钟）", "相机", "默认视图", "正面（深度/时间）", "侧面（深度/指标）", "顶部（指标/时间）", "潜水时间", "减压天花板", "气瓶 {n}"],
}

ANCHOR = '"dive3d_metric_tankPressure":'

for locale, values in T.items():
    path = f"lib/l10n/arb/app_{locale}.arb"
    with io.open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    idx = next(i for i, l in enumerate(lines) if l.strip().startswith(ANCHOR))
    # Skip the anchor's own @meta line if present.
    if idx + 1 < len(lines) and lines[idx + 1].strip().startswith('"@dive3d_metric_tankPressure"'):
        idx += 1
    new = []
    for (key, placeholders), value in zip(KEYS, values):
        assert key not in "\n".join(lines), f"{key} already in {path}"
        new.append('  "%s": %s,' % (key, json.dumps(value, ensure_ascii=False)))
        if locale == "en":
            meta = {"placeholders": placeholders} if placeholders else {}
            new.append('  "@%s": %s,' % (key, json.dumps(meta, ensure_ascii=False)))
    lines[idx + 1:idx + 1] = new
    text = "\n".join(lines)
    json.loads(text)  # must still parse
    with io.open(path, "w", encoding="utf-8") as f:
        f.write(text)
    print(locale, "ok")
```

Then:

```bash
flutter gen-l10n
grep -A1 "get dive3d_zAxis " lib/l10n/arb/app_localizations_de.dart   # must print 'Z-Achse'
rm scratch_add_l10n.py
```

Now swap the temporary literals in `lib/features/dive_3d/presentation/pages/dive_3d_page.dart`: `SceneMetric.tts => 'TTS'` becomes `SceneMetric.tts => context.l10n.dive3d_metric_tts`, and `SceneOverlay.shadows => 'Wall shadows'` becomes `SceneOverlay.shadows => context.l10n.dive3d_overlay_shadows`.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/dive_3d/l10n_keys_test.dart test/features/dive_3d/presentation/pages/dive_3d_page_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_3d test/features/dive_3d
git add lib/l10n/arb lib/features/dive_3d/presentation/pages/dive_3d_page.dart test/features/dive_3d/l10n_keys_test.dart
git commit -m "i18n: add path scene strings for the 3D dive view"
```

---

### Task 13: `HoverPicker`, `ScenePick`, and the path picker

**Files:**
- Create: `lib/features/dive_3d/presentation/renderer/hover_picker.dart`
- Test: `test/features/dive_3d/presentation/renderer/hover_picker_test.dart`

**Interfaces:**
- Produces:

```dart
class ScenePick {
  final double x, y, z;      // world anchor
  final Offset screenPos;    // where it was published (viewport-local)
  final Object payload;      // TissuePick or PathPick
  ScenePick withScreenPos(Offset p);
}
abstract interface class HoverPicker {
  ScenePick? pick(SceneProjector projector, Offset cursor);
}
class GridHoverPicker implements HoverPicker { GridHoverPicker(TissueSurfaceGrid grid); TissueSurfaceGrid get grid; }
class PathPick { final int index; }
class PathHoverPicker implements HoverPicker { PathHoverPicker(ScrubPath path, {double thresholdPx = 12}); }
```

Both pickers cache their projected vertices keyed by projector identity (`identical`), so the viewport must hand them the SAME projector instance until the camera or size changes (Task 14 memoizes it).

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_3d/presentation/renderer/hover_picker_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/hover_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';

void main() {
  const size = Size(400, 300);
  const bounds = SceneBounds(
    durationSeconds: 100,
    maxDepthMeters: 20,
    sceneMinZ: -SceneBounds.zPathHalfSpan,
    sceneMaxZ: SceneBounds.zPathHalfSpan,
  );
  final path = ScrubPath(
    normalizedTimes: const [0, 0.5, 1],
    xs: [bounds.xOf(0), bounds.xOf(50), bounds.xOf(100)],
    ys: [bounds.yOf(0), bounds.yOf(20), bounds.yOf(0)],
    zs: const [-2, 0, 2],
  );

  test('path picker returns the nearest sample within the radius', () {
    final projector = SceneProjector(size: size, bounds: bounds);
    final picker = PathHoverPicker(path);
    final target = projector.project(path.xs[1], path.ys[1], path.zs![1]);
    final pick = picker.pick(projector, target + const Offset(4, -3))!;
    expect((pick.payload as PathPick).index, 1);
    expect((pick.x, pick.y, pick.z), (path.xs[1], path.ys[1], 0.0));
    expect(pick.screenPos, target);
    expect(picker.pick(projector, target + const Offset(40, 0)), isNull);
  });

  test('withScreenPos keeps the world anchor and payload', () {
    const pick = ScenePick(x: 1, y: 2, z: 3, screenPos: Offset.zero, payload: PathPick(4));
    final moved = pick.withScreenPos(const Offset(9, 9));
    expect((moved.x, moved.y, moved.z), (1.0, 2.0, 3.0));
    expect(moved.screenPos, const Offset(9, 9));
    expect(identical(moved.payload, pick.payload), isTrue);
  });

  test('grid picker wraps the tissue pick with its world anchor', () {
    final result = SubsurfaceTissueBuilder.buildResult(
      BuhlmannAlgorithm().processProfile(
        depths: const [0, 30, 30, 30, 0],
        timestamps: const [0, 120, 600, 1200, 1400],
      ),
      colorFn: thermalColor,
    );
    final projector = SceneProjector(size: size, bounds: result.scene.bounds);
    final picker = GridHoverPicker(result.grid);
    const col = 1, comp = 5;
    final (x, y, z) = result.grid.positionAt(col, comp);
    final pick = picker.pick(projector, projector.project(x, y, z))!;
    final tissue = pick.payload as TissuePick;
    expect((tissue.col, tissue.comp), (col, comp));
    expect((pick.x, pick.y, pick.z), (x, y, z));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/presentation/renderer/hover_picker_test.dart`
Expected: FAIL (missing file).

- [ ] **Step 3: Implement**

```dart
// lib/features/dive_3d/presentation/renderer/hover_picker.dart
import 'dart:ui';

import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_grid.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';

/// A hovered or tapped scene point: its world anchor (so the ring and guide
/// lines can be re-projected every frame), where it was published on
/// screen (viewport-local, pan included), and a scene-specific payload the
/// tooltip reads (a [TissuePick] or a [PathPick]).
class ScenePick {
  final double x, y, z;
  final Offset screenPos;
  final Object payload;

  const ScenePick({
    required this.x,
    required this.y,
    required this.z,
    required this.screenPos,
    required this.payload,
  });

  ScenePick withScreenPos(Offset p) =>
      ScenePick(x: x, y: y, z: z, screenPos: p, payload: payload);
}

/// Finds what sits under the cursor. Implementations cache their projected
/// vertices by projector identity, so callers hand over the SAME projector
/// instance until the camera or canvas size changes.
abstract interface class HoverPicker {
  ScenePick? pick(SceneProjector projector, Offset cursor);
}

/// Picks vertices of a [TissueSurfaceGrid] (tissue landscape and seascape
/// terrain), delegating to [pickNearestTissueVertex].
class GridHoverPicker implements HoverPicker {
  final TissueSurfaceGrid grid;
  SceneProjector? _projector;
  List<Offset>? _projected;
  List<double>? _viewDepths;

  GridHoverPicker(this.grid);

  void _ensure(SceneProjector p) {
    if (identical(_projector, p)) return;
    final n = grid.columns * grid.compartments;
    final proj = List<Offset>.filled(n, Offset.zero);
    final depths = List<double>.filled(n, 0);
    for (var col = 0; col < grid.columns; col++) {
      for (var comp = 0; comp < grid.compartments; comp++) {
        final (x, y, z) = grid.positionAt(col, comp);
        final i = col * grid.compartments + comp;
        proj[i] = p.project(x, y, z);
        depths[i] = p.viewDepth(x, y, z);
      }
    }
    _projector = p;
    _projected = proj;
    _viewDepths = depths;
  }

  @override
  ScenePick? pick(SceneProjector projector, Offset cursor) {
    if (grid.isEmpty) return null;
    _ensure(projector);
    final t = pickNearestTissueVertex(
      cursor: cursor,
      projected: _projected!,
      viewDepths: _viewDepths!,
      columns: grid.columns,
      compartments: grid.compartments,
    );
    if (t == null) return null;
    final (x, y, z) = grid.positionAt(t.col, t.comp);
    return ScenePick(x: x, y: y, z: z, screenPos: t.screenPos, payload: t);
  }
}

/// The decimated sample index picked on the dive path.
class PathPick {
  final int index;
  const PathPick(this.index);
}

/// Picks the nearest node of a [ScrubPath] within [thresholdPx].
class PathHoverPicker implements HoverPicker {
  final ScrubPath path;
  final double thresholdPx;
  SceneProjector? _projector;
  List<Offset>? _projected;

  PathHoverPicker(this.path, {this.thresholdPx = 12});

  void _ensure(SceneProjector p) {
    if (identical(_projector, p)) return;
    final zs = path.zs;
    _projected = [
      for (var i = 0; i < path.xs.length; i++)
        p.project(path.xs[i], path.ys[i], zs?[i] ?? 0),
    ];
    _projector = p;
  }

  @override
  ScenePick? pick(SceneProjector projector, Offset cursor) {
    if (path.xs.isEmpty) return null;
    _ensure(projector);
    final projected = _projected!;
    var best = -1;
    var bestSq = thresholdPx * thresholdPx;
    for (var i = 0; i < projected.length; i++) {
      final dSq = (projected[i] - cursor).distanceSquared;
      if (dSq <= bestSq && (best < 0 || dSq < bestSq)) {
        best = i;
        bestSq = dSq;
      }
    }
    if (best < 0) return null;
    return ScenePick(
      x: path.xs[best],
      y: path.ys[best],
      z: path.zs?[best] ?? 0,
      screenPos: projected[best],
      payload: PathPick(best),
    );
  }
}
```

- [ ] **Step 4: Run the test**

Run: `flutter test test/features/dive_3d/presentation/renderer/hover_picker_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_3d test/features/dive_3d
git add lib/features/dive_3d/presentation/renderer/hover_picker.dart test/features/dive_3d/presentation/renderer/hover_picker_test.dart
git commit -m "feat(dive_3d): add HoverPicker with grid and path implementations"
```

---

### Task 14: Viewport chrome modes and picker-based hover

**Files:**
- Modify: `lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart`
- Modify: `lib/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart`
- Modify: `lib/features/dive_3d/presentation/pages/dive_3d_page.dart` (tissue body + `_sceneScaffold`)
- Modify: `lib/features/dive_3d/presentation/pages/spatial_site_page.dart`
- Modify: `lib/features/site_scape/presentation/site_terrain_pane.dart`
- Test: `test/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport_test.dart`, `test/features/dive_3d/presentation/renderer/tissue_chrome_painters_test.dart`, `test/features/site_scape/presentation/site_terrain_pane_test.dart`

**Interfaces:**
- Produces (viewport):

```dart
enum SceneChromeMode { none, tissue, axesOnly, framed }

const Dive3dInteractiveViewport({
  super.key,
  required this.scene,
  required this.scrubPosition,
  required this.visibleOverlays,
  this.onMarkerTap,
  this.scrubCursor = ScrubCursorStyle.dot,
  this.chromeMode = SceneChromeMode.none,
  this.surfaceGrid,          // tissue mode only (wireframe + overlay painters)
  this.axisFrame,
  this.axisLabels,
  this.chromeStyle,
  this.picker,               // HoverPicker?
  this.hoverPick,            // ValueNotifier<ScenePick?>?
  this.chartMode = false,
  this.contourLabels,
  this.terrainImagery,
  this.imageryWhiteTexel,
});
```

  `axisChromeOnly` is gone. Hover works whenever `picker` and `hoverPick` are both set, in any mode.
- Produces (painters): `void paintHoverRing(Canvas canvas, Offset center, TissueChromeStyle style)`; `AxisChromePainter({..., ValueListenable<ScenePick?>? hoverPick, bool hoverGuides = false, List<SceneMarker>? markerLabels, bool showCompass = true, ...})` (no `surfaceGrid`); `TissueOverlayPainter({..., required ValueListenable<ScenePick?> hoverPick})`.
- `framed` mode paints `TissueFramePainter` (grid roles only) behind the scene and `AxisChromePainter(hoverGuides: true, showCompass: false, markerLabels: scene.markers when markers are visible)` in front; the scrub cursor stays on the scene's foreground painter.

- [ ] **Step 1: Update the tests first**

`dive_3d_interactive_viewport_test.dart`:
- `pumpViewport`: replace the `bool axisChromeOnly = false` parameter with `SceneChromeMode chromeMode = SceneChromeMode.none`, and the `axisChromeOnly: axisChromeOnly,` argument with `chromeMode: chromeMode,`. The caller at the panning test (`axisChromeOnly: true`) becomes `chromeMode: SceneChromeMode.axesOnly`.
- In the three hover tests (`hover over a surface vertex publishes a pick`, `published pick screenPos tracks the vertex after panning`, `hover pick screenPos re-tracks the vertex after a zoom ...`): change `final hoverPick = ValueNotifier<TissuePick?>(null);` to `final hoverPick = ValueNotifier<ScenePick?>(null);`, add `picker: GridHoverPicker(result.grid),` and `chromeMode: SceneChromeMode.tissue,` next to the existing `surfaceGrid: result.grid,`, and rewrite the assertions on `col`/`comp` as `final tissue = hoverPick.value!.payload as TissuePick; expect(tissue.col, col); expect(tissue.comp, comp);` (`screenPos` assertions stay on `hoverPick.value!.screenPos`).
- Add `import 'package:submersion/features/dive_3d/presentation/renderer/hover_picker.dart';`.
- Add this test:

```dart
  testWidgets('framed mode paints the frame behind and axis chrome in front', (
    tester,
  ) async {
    final scene = buildScene();
    final axes = buildDiveAxes(
      bounds: scene.bounds,
      depthTicks: depthAxisTicks(maxDepthMeters: 18, stepMeters: 10, toDisplay: (m) => m),
      timeTicks: timeAxisTicks(120),
      depthTitle: 'Depth (m)',
      timeTitle: 'Run time (min)',
    );
    const style = TissueChromeStyle(
      axisX: Color(0xFFFFFFFF), axisY: Color(0xFFFFFFFF), axisZ: Color(0xFFFFFFFF),
      grid: Color(0x33FFFFFF), wireframe: Color(0x00000000),
      marker: Color(0xFFFFFFFF), markerOutline: Color(0xFF000000), label: Color(0xFFFFFFFF),
    );
    final hoverPick = ValueNotifier<ScenePick?>(null);
    addTearDown(hoverPick.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Dive3dInteractiveViewport(
            scene: scene,
            scrubPosition: ValueNotifier<double>(0),
            visibleOverlays: SceneOverlay.values.toSet(),
            chromeMode: SceneChromeMode.framed,
            axisFrame: axes.frame,
            axisLabels: axes.labels,
            chromeStyle: style,
            picker: PathHoverPicker(scene.scrubPath!),
            hoverPick: hoverPick,
          ),
        ),
      ),
    );
    await tester.pump();
    final paints = tester.widgetList<CustomPaint>(
      find.descendant(of: find.byType(Dive3dInteractiveViewport), matching: find.byType(CustomPaint)),
    );
    expect(paints.map((p) => p.painter).whereType<TissueFramePainter>(), hasLength(1));
    final chrome = paints.map((p) => p.foregroundPainter).whereType<AxisChromePainter>().single;
    expect(chrome.hoverGuides, isTrue);
    expect(chrome.showCompass, isFalse);
    expect(chrome.markerLabels, isNotNull);
    // Hovering the middle path sample publishes a PathPick.
    final projector = SceneProjector(size: tester.getSize(find.byType(Dive3dInteractiveViewport)), bounds: scene.bounds);
    final path = scene.scrubPath!;
    final origin = tester.getTopLeft(find.byType(Dive3dInteractiveViewport));
    final target = origin + projector.project(path.xs[1], path.ys[1], path.zs![1]);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(target);
    await tester.pump();
    expect((hoverPick.value!.payload as PathPick).index, 1);
  });
```

  (add imports for `dive_axes.dart`.)

`tissue_chrome_painters_test.dart`: the `AxisChromePainter` hover test (around line 79) builds `ValueNotifier<TissuePick?>` and passes `surfaceGrid:`. Change it to

```dart
      final (x, y, z) = result.grid.positionAt(1, 3);
      final pick = ValueNotifier<ScenePick?>(
        ScenePick(
          x: x, y: y, z: z,
          screenPos: const Offset(200, 150),
          payload: const TissuePick(col: 1, comp: 3, screenPos: Offset(200, 150)),
        ),
      );
```

  and drop the `surfaceGrid:` argument. The `TissueOverlayPainter` test (around line 145) changes `ValueNotifier<TissuePick?>(null)` to `ValueNotifier<ScenePick?>(null)`. Add the `hover_picker.dart` import. (If the test's grid variable has another name, use that name; the test file defines it near the top.)

`site_terrain_pane_test.dart` lines 131-134 become:

```dart
    expect(viewport.picker, isA<GridHoverPicker>());
    expect(viewport.hoverPick, isNotNull);
    expect(viewport.chromeMode, SceneChromeMode.axesOnly);
```

  (import `hover_picker.dart` and keep the viewport import.)

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport_test.dart`
Expected: compile errors (`SceneChromeMode`, `picker`, `hoverGuides` unknown).

- [ ] **Step 3: Painters**

In `tissue_chrome_painters.dart`:
- imports: add `package:submersion/features/dive_3d/domain/geometry/marker_layout.dart` and `package:submersion/features/dive_3d/presentation/renderer/hover_picker.dart`; remove the `tissue_surface_picker.dart` import.
- Add a top-level helper after `paintAxisLabels`:

```dart
/// The hover ring: a dark halo under a light ring so it reads on any
/// surface color. Shared by every chrome painter that shows a pick.
void paintHoverRing(Canvas canvas, Offset center, TissueChromeStyle style) {
  canvas.drawCircle(
    center,
    6,
    Paint()
      ..color = style.markerOutline.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5,
  );
  canvas.drawCircle(
    center,
    6,
    Paint()
      ..color = style.marker.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2,
  );
}

/// Draws [a]->[b] as a 4 px on / 3 px off dashed line.
void paintDashedLine(Canvas canvas, Offset a, Offset b, Paint paint) {
  final total = (b - a).distance;
  if (total < 1e-3) return;
  final dir = (b - a) / total;
  var d = 0.0;
  while (d < total) {
    final end = math.min(d + 4, total);
    canvas.drawLine(a + dir * d, a + dir * end, paint);
    d = end + 3;
  }
}
```

- `AxisChromePainter`: replace the `surfaceGrid`/`hoverPick` fields with

```dart
  final ValueListenable<ScenePick?>? hoverPick;

  /// Dashed guide lines from the pick to the back wall, floor, and left
  /// wall (the path scene), tying the tube to its wall shadows.
  final bool hoverGuides;

  /// Markers to label with a chip above their anchor (the path scene);
  /// markers with an empty label stay as the scene painter's dots.
  final List<SceneMarker>? markerLabels;

  /// The seascape's compass rose; off for the analytical path scene.
  final bool showCompass;
```

  constructor: `this.hoverPick, this.hoverGuides = false, this.markerLabels, this.showCompass = true,` (remove `this.surfaceGrid`). In `paint`: `if (showCompass) _paintCompass(canvas, size, p); _paintMarkerLabels(canvas, p); _paintHoverRing(canvas, p);`. Replace `_paintHoverRing` with:

```dart
  void _paintHoverRing(Canvas canvas, SceneProjector p) {
    final pick = hoverPick?.value;
    if (pick == null) return;
    final center = p.project(pick.x, pick.y, pick.z);
    if (hoverGuides) {
      final guide = Paint()
        ..color = style.label.withValues(alpha: 0.7)
        ..strokeWidth = 1;
      paintDashedLine(canvas, center, p.project(pick.x, pick.y, bounds.sceneMinZ), guide);
      paintDashedLine(canvas, center, p.project(pick.x, bounds.sceneMinY, pick.z), guide);
      paintDashedLine(canvas, center, p.project(0, pick.y, pick.z), guide);
    }
    paintHoverRing(canvas, center, style);
  }

  void _paintMarkerLabels(Canvas canvas, SceneProjector p) {
    final markers = markerLabels;
    if (markers == null) return;
    for (final m in markers) {
      if (m.label.isEmpty) continue;
      final at = p.project(m.x, m.y, m.z);
      final tp = TextPainter(
        text: TextSpan(
          text: m.label,
          style: TextStyle(color: style.label, fontSize: 9.5, fontWeight: FontWeight.w600),
        ),
        textDirection: textDirection,
      )..layout();
      final center = at - const Offset(0, 14);
      final rect = Rect.fromCenter(center: center, width: tp.width + 10, height: tp.height + 4);
      canvas.drawLine(at, Offset(at.dx, rect.bottom), Paint()..color = style.label.withValues(alpha: 0.6)..strokeWidth = 1);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        Paint()..color = style.markerOutline.withValues(alpha: 0.85),
      );
      tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
    }
  }
```

  `shouldRepaint`: replace `!identical(old.surfaceGrid, surfaceGrid) ||` with `!identical(old.markerLabels, markerLabels) || old.hoverGuides != hoverGuides || old.showCompass != showCompass ||`.
- `TissueOverlayPainter`: field `final ValueListenable<ScenePick?> hoverPick;` and

```dart
  void _paintMarker(Canvas canvas, SceneProjector p) {
    final pick = hoverPick.value;
    if (pick == null) return;
    paintHoverRing(canvas, p.project(pick.x, pick.y, pick.z), style);
  }
```

- [ ] **Step 4: Viewport**

In `dive_3d_interactive_viewport.dart`:
- imports: add `hover_picker.dart`; remove `tissue_surface_picker.dart`.
- Add above the widget class:

```dart
/// Which chrome the viewport composes around the scene painter.
/// `tissue`: frame behind + wireframe/overlay painters (needs surfaceGrid).
/// `axesOnly`: axes, labels, compass, contour labels in front (seascape).
/// `framed`: frame grid behind + axes/labels/guides in front (dive path).
enum SceneChromeMode { none, tissue, axesOnly, framed }
```

- Fields: replace `final ValueNotifier<TissuePick?>? hoverPick;` with `final HoverPicker? picker;` and `final ValueNotifier<ScenePick?>? hoverPick;`; replace `final bool axisChromeOnly;` with `final SceneChromeMode chromeMode;`; constructor per the Interfaces block.
- Replace `_projectorFor` and delete `_ensureProjection` plus its cache fields (`_projected`, `_viewDepths`, `_cacheYaw`, `_cachePitch`, `_cacheZoom`, `_cacheSize`, `_cacheGrid`):

```dart
  // One projector per (camera, size, bounds): pickers cache projections by
  // projector identity, so a fresh instance per call would defeat them.
  SceneProjector? _projector;
  double? _projYaw, _projPitch, _projZoom;
  Size? _projSize;
  SceneBounds? _projBounds;

  SceneProjector _projectorFor(Size size) {
    final cached = _projector;
    if (cached != null &&
        _projYaw == _yaw &&
        _projPitch == _pitch &&
        _projZoom == _zoom &&
        _projSize == size &&
        identical(_projBounds, widget.scene.bounds)) {
      return cached;
    }
    final p = SceneProjector(
      size: size,
      bounds: widget.scene.bounds,
      yawDegrees: _yaw,
      pitchDegrees: _pitch,
      zoom: _zoom,
    );
    _projector = p;
    _projYaw = _yaw;
    _projPitch = _pitch;
    _projZoom = _zoom;
    _projSize = size;
    _projBounds = widget.scene.bounds;
    return p;
  }
```

  (add `import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';`.)
- Replace `_refreshHoverAfterCameraChange` and `_pickAt`:

```dart
  // The ring re-projects the pick's world anchor every paint, but the
  // tooltip overlay lives outside the paint transform and is placed from the
  // published screenPos, so a camera change with a stationary cursor would
  // strand it. Re-derive screenPos so both stay locked to the point.
  void _refreshHoverAfterCameraChange() {
    final size = _lastLayoutSize;
    final notifier = widget.hoverPick;
    final pick = notifier?.value;
    if (size == null || notifier == null || pick == null) return;
    notifier.value = pick.withScreenPos(
      _projectorFor(size).project(pick.x, pick.y, pick.z) + _pan,
    );
  }

  void _pickAt(Size size, Offset local) {
    final notifier = widget.hoverPick;
    final picker = widget.picker;
    if (notifier == null || picker == null) return;
    // Projections are computed without pan; the painted output is translated
    // by _pan, so map the cursor back into untranslated projection space and
    // republish screenPos in viewport-local (painted) space for the tooltip.
    final pick = picker.pick(_projectorFor(size), local - _pan);
    notifier.value = pick?.withScreenPos(pick.screenPos + _pan);
  }
```

- In `build`, replace everything from `final hasChrome =` through the `final painted = ...;` statement with:

```dart
        final mode = widget.chromeMode;
        final hasHover = widget.picker != null && widget.hoverPick != null;
        assert(
          mode == SceneChromeMode.none ||
              (widget.axisFrame != null && widget.chromeStyle != null),
          'chrome modes need axisFrame and chromeStyle',
        );
        assert(
          mode != SceneChromeMode.tissue ||
              (widget.surfaceGrid != null && widget.hoverPick != null),
          'tissue chrome needs surfaceGrid and hoverPick',
        );

        final cursorPainter = _ScrubCursorPainter(
          scene: widget.scene,
          yawDegrees: _yaw,
          pitchDegrees: _pitch,
          zoom: _zoom,
          scrubPosition: widget.scrubPosition,
          style: widget.scrubCursor,
        );
        final scenePaint = CustomPaint(
          painter: Dive3dScenePainter(
            scene: widget.scene,
            yawDegrees: _yaw,
            pitchDegrees: _pitch,
            zoom: _zoom,
            visibleOverlays: widget.visibleOverlays,
            terrainImagery: widget.terrainImagery,
            imageryWhiteTexel: widget.imageryWhiteTexel,
          ),
          foregroundPainter: mode == SceneChromeMode.tissue
              ? TissueChromePainter(
                  scene: widget.scene,
                  grid: widget.surfaceGrid!,
                  frame: widget.axisFrame!,
                  style: widget.chromeStyle!,
                  yawDegrees: _yaw,
                  pitchDegrees: _pitch,
                  zoom: _zoom,
                  labels: widget.axisLabels,
                  textDirection: Directionality.of(context),
                )
              : cursorPainter,
          child: const SizedBox.expand(),
        );

        TissueFramePainter framePainter() => TissueFramePainter(
          bounds: widget.scene.bounds,
          frame: widget.axisFrame!,
          style: widget.chromeStyle!,
          yawDegrees: _yaw,
          pitchDegrees: _pitch,
          zoom: _zoom,
        );
        AxisChromePainter axisPainter({
          required bool guides,
          required bool compass,
        }) => AxisChromePainter(
          bounds: widget.scene.bounds,
          frame: widget.axisFrame!,
          labels: widget.axisLabels,
          style: widget.chromeStyle!,
          yawDegrees: _yaw,
          pitchDegrees: _pitch,
          zoom: _zoom,
          textDirection: Directionality.of(context),
          hoverPick: hasHover ? widget.hoverPick : null,
          hoverGuides: guides,
          showCompass: compass,
          markerLabels:
              guides && widget.visibleOverlays.contains(SceneOverlay.markers)
              ? widget.scene.markers
              : null,
          contourLabels: widget.contourLabels,
          panOffset: _pan,
        );

        final painted = switch (mode) {
          SceneChromeMode.none => scenePaint,
          // Frame grid draws behind the surface (paint order gives
          // occlusion); the hover marker + cursor draw on top.
          SceneChromeMode.tissue => CustomPaint(
            painter: framePainter(),
            foregroundPainter: TissueOverlayPainter(
              scene: widget.scene,
              grid: widget.surfaceGrid!,
              style: widget.chromeStyle!,
              yawDegrees: _yaw,
              pitchDegrees: _pitch,
              zoom: _zoom,
              scrubPosition: widget.scrubPosition,
              hoverPick: widget.hoverPick!,
            ),
            child: scenePaint,
          ),
          SceneChromeMode.axesOnly => CustomPaint(
            foregroundPainter: axisPainter(guides: false, compass: true),
            child: scenePaint,
          ),
          SceneChromeMode.framed => CustomPaint(
            painter: framePainter(),
            foregroundPainter: axisPainter(guides: true, compass: false),
            child: scenePaint,
          ),
        };
```

  The `MouseRegion` condition stays `hasHover`.

- [ ] **Step 5: Callers**

`dive_3d_page.dart`:
- `final ValueNotifier<ScenePick?> _hoverPick = ValueNotifier(null);` (import `hover_picker.dart`; drop the `tissue_surface_picker.dart` import if nothing else uses `TissuePick` there, otherwise keep it).
- `_sceneScaffold` signature gains `SceneChromeMode chromeMode = SceneChromeMode.none, HoverPicker? picker,` and passes `chromeMode: chromeMode, picker: picker, hoverPick: chromeMode == SceneChromeMode.none ? null : _hoverPick,` to the viewport (keep `surfaceGrid`, `axisFrame`, `axisLabels`, `chromeStyle`).
- `_buildTissueBody` passes `chromeMode: SceneChromeMode.tissue, picker: GridHoverPicker(surface.grid),` and its tooltip becomes:

```dart
      tooltip: ValueListenableBuilder<ScenePick?>(
        valueListenable: _hoverPick,
        builder: (context, pick, _) {
          final payload = pick?.payload;
          if (pick == null || payload is! TissuePick) {
            return const SizedBox.shrink();
          }
          return CustomSingleChildLayout(
            delegate: TissueTooltipLayoutDelegate(pick.screenPos),
            child: TissueHoverTooltip(
              pick: payload,
              grid: surface.grid,
              runtimeSeconds: runtime,
              colorFn: colorFn,
            ),
          );
        },
      ),
```

  (delete `_positionedTooltip`).

`spatial_site_page.dart`: `_hoverPick` becomes `ValueNotifier<ScenePick?>`; the viewport call replaces `axisChromeOnly: true,` + `surfaceGrid: ...` with

```dart
                            chromeMode: SceneChromeMode.axesOnly,
                            picker: grid == null
                                ? null
                                : GridHoverPicker(
                                    seascapePickGrid(grid, scene.layers.first.mesh),
                                  ),
```

  and the tooltip builder (around line 247) becomes `ValueListenableBuilder<ScenePick?>` whose body reads `final payload = pick?.payload; if (pick == null || payload is! TissuePick) return const SizedBox.shrink();` and passes `SeascapeHoverTooltip(pick: payload, grid: grid)` under `TissueTooltipLayoutDelegate(pick.screenPos)`.

`site_terrain_pane.dart`: the same three edits (notifier type, `chromeMode: SceneChromeMode.axesOnly` + `picker: GridHoverPicker(seascapePickGrid(...))` replacing `axisChromeOnly`/`surfaceGrid`, tooltip unwrap).

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/dive_3d test/features/site_scape`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
dart format lib test
git add -A lib/features/dive_3d lib/features/site_scape test/features/dive_3d test/features/site_scape
git commit -m "refactor(dive_3d): chrome modes and HoverPicker in the interactive viewport"
```

---

### Task 15: Camera pose presets

**Files:**
- Create: `lib/features/dive_3d/presentation/renderer/camera_pose.dart`
- Modify: `lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart`
- Test: `test/features/dive_3d/presentation/renderer/camera_pose_test.dart`, `test/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport_test.dart`

**Interfaces:**
- Produces: `enum CameraPose { defaultView(-32, 22), front(0, 0), side(90, 0), top(0, 90); final double yawDegrees, pitchDegrees; }`; viewport parameter `bool showPosePresets = false`; when true a `PopupMenuButton<CameraPose>` with `key: ValueKey('dive3dPoseMenu')` sits under the reset button; choosing a pose sets yaw/pitch, resets zoom and pan; double-tap and the reset button return to `CameraPose.defaultView`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/dive_3d/presentation/renderer/camera_pose_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/camera_pose.dart';

void main() {
  test('presets carry the spec poses', () {
    expect((CameraPose.defaultView.yawDegrees, CameraPose.defaultView.pitchDegrees), (-32.0, 22.0));
    expect((CameraPose.front.yawDegrees, CameraPose.front.pitchDegrees), (0.0, 0.0));
    expect((CameraPose.side.yawDegrees, CameraPose.side.pitchDegrees), (90.0, 0.0));
    expect((CameraPose.top.yawDegrees, CameraPose.top.pitchDegrees), (0.0, 90.0));
  });
}
```

Append to the viewport test:

```dart
  testWidgets('pose menu snaps the camera and reset returns to default', (
    tester,
  ) async {
    await pumpViewport(tester, scene: buildScene(), showPosePresets: true);
    await tester.tap(find.byKey(const ValueKey('dive3dPoseMenu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Side (depth vs metric)'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    var painter = scenePainterOf(tester);
    expect(painter.yawDegrees, 90);
    expect(painter.pitchDegrees, 0);
    await tester.tap(find.byIcon(Icons.center_focus_strong));
    await tester.pump();
    painter = scenePainterOf(tester);
    expect(painter.yawDegrees, -32);
    expect(painter.pitchDegrees, 22);
  });
```

  and give `pumpViewport` a `bool showPosePresets = false` parameter forwarded to the widget.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_3d/presentation/renderer/camera_pose_test.dart test/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement**

```dart
// lib/features/dive_3d/presentation/renderer/camera_pose.dart
/// Camera presets for the path scene. Front looks along +Z (depth vs
/// time), side along -X (depth vs metric), top straight down (metric vs
/// time): each turns one wall shadow into a front-on 2D chart.
enum CameraPose {
  defaultView(-32, 22),
  front(0, 0),
  side(90, 0),
  top(0, 90);

  final double yawDegrees;
  final double pitchDegrees;
  const CameraPose(this.yawDegrees, this.pitchDegrees);
}
```

Viewport: add `final bool showPosePresets;` (`this.showPosePresets = false` in the constructor), a state field `CameraPose _pose = CameraPose.defaultView;`, and change `_applyPose` to:

```dart
  void _applyPose() {
    if (widget.chartMode) {
      _yaw = chartYawDegrees;
      _pitch = chartPitchDegrees;
    } else {
      _yaw = _pose.yawDegrees;
      _pitch = _pose.pitchDegrees;
    }
    _zoom = 1.0;
    _pan = Offset.zero;
  }

  void _resetCamera() {
    setState(() {
      _pose = CameraPose.defaultView;
      _applyPose();
    });
    _refreshHoverAfterCameraChange();
  }

  void _selectPose(CameraPose pose) {
    setState(() {
      _pose = pose;
      _applyPose();
    });
    _refreshHoverAfterCameraChange();
  }
```

(`_initialYaw`/`_initialPitch` constants are deleted; the viewport tests that assert `-32`/`22` keep passing through `CameraPose.defaultView`.) In `_zoomControls`, after the reset button add:

```dart
        if (widget.showPosePresets) ...[
          const SizedBox(height: 6),
          Material(
            color: scheme.surface.withValues(alpha: 0.7),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: PopupMenuButton<CameraPose>(
              key: const ValueKey('dive3dPoseMenu'),
              icon: const Icon(Icons.threed_rotation, size: 20),
              tooltip: context.l10n.dive3d_pose_menu,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 36, height: 36),
              onSelected: _selectPose,
              itemBuilder: (context) => [
                for (final pose in CameraPose.values)
                  PopupMenuItem(
                    value: pose,
                    child: Text(switch (pose) {
                      CameraPose.defaultView => context.l10n.dive3d_pose_default,
                      CameraPose.front => context.l10n.dive3d_pose_front,
                      CameraPose.side => context.l10n.dive3d_pose_side,
                      CameraPose.top => context.l10n.dive3d_pose_top,
                    }),
                  ),
              ],
            ),
          ),
        ],
```

(`_zoomControls` needs `final scheme = Theme.of(context).colorScheme;` at its top; import `camera_pose.dart`.)

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/dive_3d/presentation`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_3d test/features/dive_3d
git add -A lib/features/dive_3d test/features/dive_3d
git commit -m "feat(dive_3d): camera pose presets in the interactive viewport"
```

---

### Task 16: Readout rows, readout panel, hover tooltip

**Files:**
- Create: `lib/features/dive_3d/presentation/widgets/dive_readout_rows.dart`
- Create: `lib/features/dive_3d/presentation/widgets/dive_hover_tooltip.dart`
- Modify: `lib/features/dive_3d/presentation/widgets/scene_readout_panel.dart`
- Test: `test/features/dive_3d/presentation/widgets/dive_readout_rows_test.dart`, `test/features/dive_3d/presentation/widgets/dive_hover_tooltip_test.dart`, `test/features/dive_3d/presentation/widgets/scene_readout_panel_test.dart`

**Interfaces:**
- Produces:

```dart
class ReadoutRow { final String label; final String value; final bool emphasized; }
List<ReadoutRow> diveReadoutRows({
  required Dive3dSceneData data,
  required double timestampSeconds,
  required UnitFormatter units,
  required AppLocalizations l10n,
  SceneMetric? emphasize,
});
class DiveHoverTooltip extends ConsumerWidget {
  const DiveHoverTooltip({required this.data, required this.timestampSeconds, this.emphasize});
}
class SceneReadoutPanel extends ConsumerWidget {
  const SceneReadoutPanel({required this.data, required this.position, this.emphasize});
}
```

Rows, in order, each only when its series has a value at that instant (interpolated over the FULL-resolution series with `ProfileLookup`): run time `m:ss` (`dive3d_readout_runTime`), depth (`dive3d_metric_depth`, `units.formatDepth`), temperature (`dive3d_metric_temperature`, `units.formatTemperature`), ascent rate (`dive3d_metric_ascentRate`, `'${units.convertDepth(r).toStringAsFixed(1)} ${units.depthSymbol}/min'`), ppO2 (`dive3d_metric_ppO2`, two decimals), CNS (`dive3d_metric_cns`, `'${cns.round()}%'`), heart rate (`dive3d_metric_heartRate`, `'${hr.round()} bpm'`), ceiling when > 0 (`dive3d_readout_ceiling`, `units.formatDepth`), TTS (`dive3d_metric_tts`, `'${(tts / 60).round()} min'`), one row per tank in `data.tankPressures` order (`dive3d_readout_tank(n)`, `units.formatPressure` of `ProfileLookupOverPressure(points).at(t)`). `emphasized` is true for the row whose metric equals [emphasize].

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/dive_3d/presentation/widgets/dive_readout_rows_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_readout_rows.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  final data = Dive3dSceneData(
    diveId: 'd1',
    times: const [0, 100],
    depths: const [0, 20],
    temperatures: const [20, 10],
    ascentRates: const [null, null],
    ppO2s: const [0.21, 0.63],
    cnss: const [0, 10],
    heartRates: const [null, null],
    ceilings: const [null, 6.0],
    ttss: const [null, 600],
    tankPressures: {
      't1': [
        TankPressurePoint(timestamp: 0, pressure: 200),
        TankPressurePoint(timestamp: 100, pressure: 100),
      ],
    },
    gasSwitches: const [],
    bookmarkEvents: const [],
    photos: const [],
    durationSeconds: 100,
    maxDepthMeters: 20,
  );

  test('rows at mid-dive, tank row and emphasis', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final rows = diveReadoutRows(
      data: data,
      timestampSeconds: 50,
      units: const UnitFormatter(AppSettings()),
      l10n: l10n,
      emphasize: SceneMetric.temperature,
    );
    final byLabel = {for (final r in rows) r.label: r};
    expect(rows.first.label, 'Run time');
    expect(rows.first.value, '0:50');
    expect(byLabel['Depth']!.value, startsWith('10.0'));
    expect(byLabel['Temp']!.value, startsWith('15.0'));
    expect(byLabel['Temp']!.emphasized, isTrue);
    expect(byLabel['Depth']!.emphasized, isFalse);
    expect(byLabel['ppO2']!.value, '0.42');
    expect(byLabel['CNS']!.value, '5%');
    expect(byLabel['Tank 1']!.value, startsWith('150'));
    // Ceiling and TTS are null at t=0 so interpolation yields nothing.
    expect(byLabel.containsKey('Ceiling'), isFalse);
    expect(byLabel.containsKey('Ascent'), isFalse);
  });

  test('ceiling and tts appear once both neighbors carry values', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final rows = diveReadoutRows(
      data: data,
      timestampSeconds: 100,
      units: const UnitFormatter(AppSettings()),
      l10n: l10n,
    );
    final byLabel = {for (final r in rows) r.label: r};
    expect(byLabel['Ceiling']!.value, startsWith('6.0'));
    expect(byLabel['TTS']!.value, '10 min');
  });
}
```

```dart
// test/features/dive_3d/presentation/widgets/dive_hover_tooltip_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_hover_tooltip.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/mock_providers.dart';
import 'scene_readout_panel_test.dart' show readoutSceneData;

void main() {
  testWidgets('tooltip shows the readout rows at the timestamp', (tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: DiveHoverTooltip(
          data: readoutSceneData(),
          timestampSeconds: 50,
          emphasize: SceneMetric.temperature,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('0:50'), findsOneWidget);
    expect(find.textContaining('10.0'), findsOneWidget);
    expect(find.textContaining('15.0'), findsOneWidget);
  });
}
```

`scene_readout_panel_test.dart`: keep the existing test unchanged. Each value is its own `Text`, so `textContaining('10.0')` at position 0.5 matches only the depth (temperature there is 15.0) and `textContaining('20.0')` at 1.0 matches only the depth (temperature there is 10.0).

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_3d/presentation/widgets/dive_readout_rows_test.dart test/features/dive_3d/presentation/widgets/dive_hover_tooltip_test.dart`
Expected: FAIL (missing files).

- [ ] **Step 3: Implement**

```dart
// lib/features/dive_3d/presentation/widgets/dive_readout_rows.dart
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/domain/profile_lookup.dart';
import 'package:submersion/features/dive_3d/domain/scene_geometry_service.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// One line of the dive readout: a localized label and a unit-formatted
/// value. [emphasized] marks the row of the metric on the Z axis.
class ReadoutRow {
  final String label;
  final String value;
  final bool emphasized;
  const ReadoutRow(this.label, this.value, {this.emphasized = false});
}

/// The single source of truth for what the tooltip, the scrub readout
/// panel, and the marker sheet show at an instant. Interpolates the
/// FULL-resolution series so geometry decimation never affects readouts.
List<ReadoutRow> diveReadoutRows({
  required Dive3dSceneData data,
  required double timestampSeconds,
  required UnitFormatter units,
  required AppLocalizations l10n,
  SceneMetric? emphasize,
}) {
  final t = timestampSeconds;
  final lookup = ProfileLookup(data.times);
  double? at(List<double?> series) => lookup.interpolate(series, t);
  final total = t.round();
  final clock = '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';

  final rows = <ReadoutRow>[ReadoutRow(l10n.dive3d_readout_runTime, clock)];
  void add(SceneMetric? metric, String label, String? value) {
    if (value == null) return;
    rows.add(ReadoutRow(label, value, emphasized: metric != null && metric == emphasize));
  }

  final depth = at(data.depths.cast<double?>());
  add(SceneMetric.depth, l10n.dive3d_metric_depth, depth == null ? null : units.formatDepth(depth));
  final temp = at(data.temperatures);
  add(SceneMetric.temperature, l10n.dive3d_metric_temperature, temp == null ? null : units.formatTemperature(temp));
  final rate = at(data.ascentRates);
  add(
    SceneMetric.ascentRate,
    l10n.dive3d_metric_ascentRate,
    rate == null ? null : '${units.convertDepth(rate).toStringAsFixed(1)} ${units.depthSymbol}/min',
  );
  final ppO2 = at(data.ppO2s);
  add(SceneMetric.ppO2, l10n.dive3d_metric_ppO2, ppO2?.toStringAsFixed(2));
  final cns = at(data.cnss);
  add(SceneMetric.cns, l10n.dive3d_metric_cns, cns == null ? null : '${cns.round()}%');
  final hr = at(data.heartRates);
  add(SceneMetric.heartRate, l10n.dive3d_metric_heartRate, hr == null ? null : '${hr.round()} bpm');
  final ceiling = at(data.ceilings);
  add(null, l10n.dive3d_readout_ceiling, ceiling == null || ceiling <= 0 ? null : units.formatDepth(ceiling));
  final tts = at(data.ttsSeconds);
  add(SceneMetric.tts, l10n.dive3d_metric_tts, tts == null ? null : '${(tts / 60).round()} min');
  var n = 0;
  for (final points in data.tankPressures.values) {
    n++;
    if (points.isEmpty) continue;
    final bar = ProfileLookupOverPressure(points).at(t);
    add(SceneMetric.tankPressure, l10n.dive3d_readout_tank(n), bar == null ? null : units.formatPressure(bar));
  }
  return rows;
}
```

```dart
// lib/features/dive_3d/presentation/widgets/dive_hover_tooltip.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_readout_rows.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Compact readout for a hovered or tapped path sample: every metric the
/// dive carries at that instant, with the Z-axis metric emphasized.
class DiveHoverTooltip extends ConsumerWidget {
  final Dive3dSceneData data;
  final double timestampSeconds;
  final SceneMetric? emphasize;

  const DiveHoverTooltip({
    super.key,
    required this.data,
    required this.timestampSeconds,
    this.emphasize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final rows = diveReadoutRows(
      data: data,
      timestampSeconds: timestampSeconds,
      units: units,
      l10n: context.l10n,
      emphasize: emphasize,
    );
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.labelSmall;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Table(
          defaultColumnWidth: const IntrinsicColumnWidth(),
          children: [
            for (final row in rows)
              TableRow(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Text(row.label, style: text?.copyWith(color: scheme.onSurfaceVariant)),
                  ),
                  Text(
                    row.value,
                    style: text?.copyWith(
                      fontWeight: row.emphasized ? FontWeight.w700 : FontWeight.w500,
                      color: row.emphasized ? scheme.primary : null,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
```

`scene_readout_panel.dart`: replace the class with

```dart
/// Live metric readout at the scrub instant. Listens to the frame-rate
/// ValueListenable directly (NOT via Riverpod) so playback never rebuilds
/// the page tree above it. Shares its rows with the hover tooltip.
class SceneReadoutPanel extends ConsumerWidget {
  final Dive3dSceneData data;
  final ValueListenable<double> position;
  final SceneMetric? emphasize;

  const SceneReadoutPanel({
    super.key,
    required this.data,
    required this.position,
    this.emphasize,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = UnitFormatter(ref.watch(settingsProvider));
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.bodySmall;
    return ValueListenableBuilder<double>(
      valueListenable: position,
      builder: (context, value, _) {
        final rows = diveReadoutRows(
          data: data,
          timestampSeconds: value * data.durationSeconds,
          units: units,
          l10n: l10n,
          emphasize: emphasize,
        );
        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Wrap(
              spacing: 14,
              runSpacing: 4,
              children: [
                for (final row in rows)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${row.label} ', style: text?.copyWith(color: scheme.onSurfaceVariant)),
                      Text(
                        row.value,
                        style: text?.copyWith(
                          fontWeight: row.emphasized ? FontWeight.w700 : FontWeight.w600,
                          color: row.emphasized ? scheme.primary : null,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
```

(imports: add `metric_palette.dart`, `dive_readout_rows.dart`, `l10n_extension.dart`; drop `profile_lookup.dart`.)

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/dive_3d/presentation/widgets`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_3d test/features/dive_3d
git add -A lib/features/dive_3d test/features/dive_3d
git commit -m "feat(dive_3d): shared readout rows, hover tooltip, richer readout panel"
```

---

### Task 17: `Dive3dPage`: Z menu, color chips, overlays, axes, tooltip, marker sheet

**Files:**
- Create: `lib/features/dive_3d/presentation/dive_chrome.dart`
- Modify: `lib/features/dive_3d/presentation/pages/dive_3d_page.dart`
- Test: `test/features/dive_3d/presentation/pages/dive_3d_page_test.dart`

**Interfaces:**
- Consumes: everything from Tasks 10-16.
- Produces: `TissueChromeStyle diveChromeStyle(BuildContext context)`; page state `_colorMetric`, `_zMetric`, `_colorFollowsZ`; Z menu `key: ValueKey('dive3dZAxisMenu')` (a `PopupMenuButton<String>` whose values are `'none'` or `SceneMetric.name`); `_overlays` defaults to `{ceiling, markers, shadows}`.

- [ ] **Step 1: Write the failing tests**

Append to `dive_3d_page_test.dart` (inside `main`; `readoutSceneData` has depth + temperature, two finite temperatures, no tanks):

```dart
  testWidgets('Z menu lists None plus Z-capable metrics, temperature is the default', (
    tester,
  ) async {
    await pumpPage(tester);
    expect(find.text('Z axis: Temp'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dive3dZAxisMenu')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(CheckedPopupMenuItem<String>), findsNWidgets(2));
    await tester.tap(find.text('None'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Z axis: None'), findsOneWidget);
  });

  testWidgets('overlay defaults: ceiling, markers, shadows on; strata, curtain off', (
    tester,
  ) async {
    await pumpPage(tester);
    await tester.tap(find.byIcon(Icons.layers));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    bool checked(String label) => tester
        .widget<CheckedPopupMenuItem<SceneOverlay>>(
          find.ancestor(of: find.text(label), matching: find.byType(CheckedPopupMenuItem<SceneOverlay>)),
        )
        .checked;
    expect(checked('Deco ceiling'), isTrue);
    expect(checked('Markers'), isTrue);
    expect(checked('Wall shadows'), isTrue);
    expect(checked('Temperature layers'), isFalse);
    expect(checked('Depth curtain'), isFalse);
  });

  testWidgets('viewport is framed with pose presets and unit-aware axis titles', (
    tester,
  ) async {
    await pumpPage(tester);
    final viewport = tester.widget<Dive3dInteractiveViewport>(find.byType(Dive3dInteractiveViewport));
    expect(viewport.chromeMode, SceneChromeMode.framed);
    expect(viewport.showPosePresets, isTrue);
    final titles = viewport.axisLabels!.labels.where((l) => l.kind == AxisLabelKind.title).map((l) => l.text).toList();
    expect(titles, ['Depth (m)', 'Run time (min)', 'Temp (°C)']);
  });

  testWidgets('imperial settings relabel the axes', (tester) async {
    final overrides = await getBaseOverrides(
      settingsNotifier: MockSettingsNotifier(
        const AppSettings(depthUnit: DepthUnit.feet, temperatureUnit: TemperatureUnit.fahrenheit),
      ),
    );
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          dive3dSceneDataProvider('d1').overrideWith((ref) async => readoutSceneData()),
        ],
        child: const Dive3dPage(diveId: 'd1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));
    final viewport = tester.widget<Dive3dInteractiveViewport>(find.byType(Dive3dInteractiveViewport));
    final titles = viewport.axisLabels!.labels.where((l) => l.kind == AxisLabelKind.title).map((l) => l.text).toList();
    expect(titles, ['Depth (ft)', 'Run time (min)', 'Temp (°F)']);
  });

  testWidgets('hovering the path shows the dive tooltip', (tester) async {
    await pumpPage(tester);
    final viewportFinder = find.byType(Dive3dInteractiveViewport);
    final viewport = tester.widget<Dive3dInteractiveViewport>(viewportFinder);
    final path = viewport.scene.scrubPath!;
    final projector = SceneProjector(size: tester.getSize(viewportFinder), bounds: viewport.scene.bounds);
    final target = tester.getTopLeft(viewportFinder) + projector.project(path.xs[1], path.ys[1], path.zs![1]);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(target);
    await tester.pump();
    expect(find.byType(DiveHoverTooltip), findsOneWidget);
    expect(find.text('1:40'), findsOneWidget); // sample 1 of 2 = t = 100 s
  });
```

Also update the existing `'overlay menu toggles an overlay entry'` test: the temperature layers entry now starts unchecked, so after the toggle assert `expect(item.checked, isTrue);` and the `findsNWidgets(4)` becomes `findsNWidgets(5)` if Task 9 did not already change it. Add imports: `core/constants/units.dart`, `presentation/renderer/axis_labels.dart`, `presentation/widgets/dive_hover_tooltip.dart`, and `AppSettings` comes from `settings_providers.dart`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_3d/presentation/pages/dive_3d_page_test.dart`
Expected: FAIL (`showPosePresets`, Z menu, titles missing).

- [ ] **Step 3: Implement**

```dart
// lib/features/dive_3d/presentation/dive_chrome.dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart';

/// Theme-derived colors for the path scene's chrome: one neutral tone for
/// all three axes (this is a measurement frame, not a color-coded triad),
/// a faint grid, theme label color. Red stays reserved for the ceiling
/// violation inside the scene.
TissueChromeStyle diveChromeStyle(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  final axis = scheme.onSurface.withValues(alpha: 0.8);
  return TissueChromeStyle(
    axisX: axis,
    axisY: axis,
    axisZ: axis,
    grid: scheme.outline.withValues(alpha: 0.22),
    wireframe: Colors.transparent,
    marker: scheme.onSurface,
    markerOutline: scheme.surface,
    label: scheme.onSurface,
  );
}
```

`dive_3d_page.dart`:
- State fields: replace `SceneMetric _metric = SceneMetric.depth;` and the `_overlays` initializer with

```dart
  SceneMetric _colorMetric = SceneMetric.depth;
  SceneMetric? _zMetric;
  bool _zInitialized = false;
  // Color follows the Z metric until the diver picks a color chip.
  bool _colorFollowsZ = true;
  Set<SceneOverlay> _overlays = {
    SceneOverlay.ceiling,
    SceneOverlay.markers,
    SceneOverlay.shadows,
  };

  void _initZ(Dive3dSceneData data) {
    if (_zInitialized) return;
    _zInitialized = true;
    final z = data.zAxisMetrics.contains(SceneMetric.temperature)
        ? SceneMetric.temperature
        : null;
    _zMetric = z;
    if (_colorFollowsZ) _colorMetric = z ?? SceneMetric.depth;
  }

  void _selectZ(SceneMetric? z) {
    setState(() {
      _zMetric = z;
      if (_colorFollowsZ) _colorMetric = z ?? SceneMetric.depth;
    });
  }

  String _zTitle(ZAxisInput z) {
    final name = _metricLabel(z.metric);
    return z.spec.symbol.isEmpty ? name : '$name (${z.spec.symbol})';
  }
```

- `_buildDiveBody`:

```dart
  Widget _buildDiveBody() {
    final sceneData = ref.watch(dive3dSceneDataProvider(widget.diveId)).value;
    if (sceneData == null) {
      return const Center(child: CircularProgressIndicator());
    }
    _initZ(sceneData);
    final scene = ref
        .watch(
          dive3dGeometryProvider((
            diveId: widget.diveId,
            colorMetric: _colorMetric,
            zMetric: _zMetric,
          )),
        )
        .value;
    if (scene == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final zAxis = ref.watch(
      dive3dZAxisProvider((diveId: widget.diveId, zMetric: _zMetric)),
    );
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final l10n = context.l10n;
    final axes = buildDiveAxes(
      bounds: scene.bounds,
      depthTicks: depthAxisTicks(
        maxDepthMeters: sceneData.maxDepthMeters,
        stepMeters: settings.depthUnit == DepthUnit.feet ? 7.62 : 10.0,
        toDisplay: units.convertDepth,
      ),
      timeTicks: timeAxisTicks(sceneData.durationSeconds),
      zAxis: zAxis?.spec,
      depthTitle: l10n.dive3d_axis_depth(units.depthSymbol),
      timeTitle: l10n.dive3d_axis_time,
      zTitle: zAxis == null ? null : _zTitle(zAxis),
    );
    final scrubPath = scene.scrubPath!;
    return _sceneScaffold(
      scene: scene,
      readout: SceneReadoutPanel(
        data: sceneData,
        position: _position,
        emphasize: _zMetric,
      ),
      controls: _buildDiveControls(sceneData),
      onMarkerTap: (marker) => _showMarkerSheet(context, sceneData, marker),
      chromeMode: SceneChromeMode.framed,
      picker: PathHoverPicker(scrubPath),
      axisFrame: axes.frame,
      axisLabels: axes.labels,
      chromeStyle: diveChromeStyle(context),
      showPosePresets: true,
      tooltip: ValueListenableBuilder<ScenePick?>(
        valueListenable: _hoverPick,
        builder: (context, pick, _) {
          final payload = pick?.payload;
          if (pick == null || payload is! PathPick) {
            return const SizedBox.shrink();
          }
          final t =
              scrubPath.normalizedTimes[payload.index] *
              sceneData.durationSeconds;
          return CustomSingleChildLayout(
            delegate: TissueTooltipLayoutDelegate(pick.screenPos),
            child: DiveHoverTooltip(
              data: sceneData,
              timestampSeconds: t,
              emphasize: _zMetric,
            ),
          );
        },
      ),
    );
  }
```

- `_sceneScaffold`: add parameters `TissueChromeStyle? chromeStyle, bool showPosePresets = false,` and pass `chromeStyle: chromeStyle, showPosePresets: showPosePresets,` to the viewport (the tissue body passes `chromeStyle: _chromeStyle(context)`).
- `_buildDiveControls`: replace the chips block with

```dart
        PopupMenuButton<String>(
          key: const ValueKey('dive3dZAxisMenu'),
          tooltip: context.l10n.dive3d_zAxis,
          onSelected: (v) =>
              _selectZ(v == 'none' ? null : SceneMetric.values.byName(v)),
          itemBuilder: (context) => [
            CheckedPopupMenuItem(
              value: 'none',
              checked: _zMetric == null,
              child: Text(context.l10n.dive3d_zAxis_none),
            ),
            for (final metric in sceneData.zAxisMetrics)
              CheckedPopupMenuItem(
                value: metric.name,
                checked: _zMetric == metric,
                child: Text(_metricLabel(metric)),
              ),
          ],
          child: Chip(
            avatar: const Icon(Icons.swap_vert, size: 16),
            label: Text(
              '${context.l10n.dive3d_zAxis}: '
              '${_zMetric == null ? context.l10n.dive3d_zAxis_none : _metricLabel(_zMetric!)}',
            ),
          ),
        ),
        for (final metric in sceneData.availableMetrics)
          ChoiceChip(
            label: Text(_metricLabel(metric)),
            selected: _colorMetric == metric,
            onSelected: (_) => setState(() {
              _colorMetric = metric;
              _colorFollowsZ = false;
            }),
          ),
```

- `_showMarkerSheet` becomes:

```dart
  void _showMarkerSheet(
    BuildContext context,
    Dive3dSceneData data,
    SceneMarker marker,
  ) {
    final rows = diveReadoutRows(
      data: data,
      timestampSeconds: marker.timestampSeconds.toDouble(),
      units: UnitFormatter(ref.read(settingsProvider)),
      l10n: context.l10n,
      emphasize: _zMetric,
    );
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              marker.label.isEmpty ? marker.kind.name : marker.label,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Expanded(child: Text(row.label)),
                    Text(
                      row.value,
                      style: TextStyle(
                        fontWeight: row.emphasized ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
```

- Imports to add: `core/constants/units.dart`, `core/utils/unit_formatter.dart`, `application/z_axis_input.dart` (for `ZAxisInput`, or import `domain/geometry/z_axis_spec.dart`), `domain/geometry/dive_axes.dart`, `presentation/dive_chrome.dart`, `presentation/renderer/hover_picker.dart`, `presentation/widgets/dive_hover_tooltip.dart`, `presentation/widgets/dive_readout_rows.dart`, `settings/presentation/providers/settings_providers.dart`.

- [ ] **Step 4: Run the tests**

Run: `flutter test test/features/dive_3d`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/dive_3d test/features/dive_3d
git add -A lib/features/dive_3d test/features/dive_3d
git commit -m "feat(dive_3d): Z-axis picker, framed chrome, tooltip and readout on the dive page"
```

---

### Task 18: Headless pixel probes for the framed chrome

**Files:**
- Test: `test/features/dive_3d/presentation/renderer/axis_chrome_framed_test.dart`

**Interfaces:**
- Consumes: `AxisChromePainter(hoverGuides:, markerLabels:, showCompass:)`, `TissueFramePainter`, `Dive3dScenePainter`, `buildDiveAxes`.

- [ ] **Step 1: Write the probe test**

```dart
// test/features/dive_3d/presentation/renderer/axis_chrome_framed_test.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/dive_axes.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/hover_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart';

Future<ui.Color> pixelAt(ui.Image image, Offset at) async {
  final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawStraightRgba))!;
  final i = ((at.dy.round() * image.width) + at.dx.round()) * 4;
  return ui.Color.fromARGB(
    bytes.getUint8(i + 3), bytes.getUint8(i), bytes.getUint8(i + 1), bytes.getUint8(i + 2),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const size = Size(400, 300);
  const bounds = SceneBounds(
    durationSeconds: 100,
    maxDepthMeters: 20,
    sceneMinZ: -SceneBounds.zPathHalfSpan,
    sceneMaxZ: SceneBounds.zPathHalfSpan,
  );
  const style = TissueChromeStyle(
    axisX: Color(0xFFFFFFFF), axisY: Color(0xFFFFFFFF), axisZ: Color(0xFFFFFFFF),
    grid: Color(0xFF808080), wireframe: Color(0x00000000),
    marker: Color(0xFFFFFFFF), markerOutline: Color(0xFF000000), label: Color(0xFFFF00FF),
  );

  test('hover guides and marker chips paint in framed mode', () async {
    final axes = buildDiveAxes(
      bounds: bounds,
      depthTicks: depthAxisTicks(maxDepthMeters: 20, stepMeters: 10, toDisplay: (m) => m),
      timeTicks: timeAxisTicks(100),
      depthTitle: 'D',
      timeTitle: 'T',
    );
    final pick = ValueNotifier<ScenePick?>(
      const ScenePick(x: 5, y: -3, z: 0, screenPos: Offset.zero, payload: PathPick(0)),
    );
    const marker = SceneMarker(
      kind: SceneMarkerKind.gasSwitch, refId: 'g', label: 'EAN50', x: 2.5, y: -1, z: 0, timestampSeconds: 25,
    );
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF000000));
    AxisChromePainter(
      bounds: bounds, frame: axes.frame, labels: axes.labels, style: style,
      yawDegrees: -32, pitchDegrees: 22, zoom: 1,
      hoverPick: pick, hoverGuides: true, showCompass: false, markerLabels: const [marker],
    ).paint(canvas, size);
    final image = await recorder.endRecording().toImage(size.width.toInt(), size.height.toInt());
    addTearDown(image.dispose);

    final p = SceneProjector(size: size, bounds: bounds, yawDegrees: -32, pitchDegrees: 22);
    // A point a quarter of the way down the floor guide is on a dash or a gap;
    // sample along the guide and require at least one label-colored pixel.
    final from = p.project(5, -3, 0);
    final to = p.project(5, bounds.sceneMinY, 0);
    var guideHits = 0;
    for (var k = 1; k < 20; k++) {
      final c = await pixelAt(image, from + (to - from) * (k / 20));
      if (c.r > 200 && c.b > 200 && c.g < 80) guideHits++;
    }
    expect(guideHits, greaterThan(0));
    // The marker chip sits 14 px above the marker anchor and is drawn with
    // the markerOutline color at 0.85 alpha over black: still black-ish,
    // but the label glyphs (magenta) render around its center.
    final chipCenter = p.project(marker.x, marker.y, marker.z) - const Offset(0, 14);
    var chipHits = 0;
    for (var dx = -12; dx <= 12; dx += 2) {
      final c = await pixelAt(image, chipCenter + Offset(dx.toDouble(), 0));
      if (c.r > 200 && c.b > 200 && c.g < 80) chipHits++;
    }
    expect(chipHits, greaterThan(0));
  });

  test('frame painter draws only grid roles', () {
    final axes = buildDiveAxes(
      bounds: bounds,
      depthTicks: depthAxisTicks(maxDepthMeters: 20, stepMeters: 10, toDisplay: (m) => m),
      timeTicks: timeAxisTicks(100),
      depthTitle: 'D',
      timeTitle: 'T',
    );
    final recorder = ui.PictureRecorder();
    TissueFramePainter(
      bounds: bounds, frame: axes.frame, style: style, yawDegrees: -32, pitchDegrees: 22, zoom: 1,
    ).paint(Canvas(recorder), size);
    recorder.endRecording(); // no throw is the assertion; ordering is covered by the viewport widget test
  });
}
```

Note: under `flutter test` the label text renders as glyph boxes (the test font has no real glyphs) but still in the label color, which is what the chip probe relies on. If the chip probe is flaky on a given font, widen the sampled row to `dy` in `-4..4` before weakening the assertion.

- [ ] **Step 2: Run the test**

Run: `flutter test test/features/dive_3d/presentation/renderer/axis_chrome_framed_test.dart`
Expected: PASS.

- [ ] **Step 3: Commit**

```bash
dart format test/features/dive_3d
git add test/features/dive_3d/presentation/renderer/axis_chrome_framed_test.dart
git commit -m "test(dive_3d): pixel probes for framed hover guides and marker chips"
```

---

### Task 19: Whole-project verification and smoke

**Files:** none new.

- [ ] **Step 1: Format and analyze the whole project**

```bash
dart format .
flutter analyze
```

Expected: `No issues found!`. Infos count as failures in CI; fix every one (typical: unused imports left behind in `providers.dart`, `dive_3d_page.dart`, `tissue_chrome_painters.dart`, `dive_3d_interactive_viewport.dart`; `unnecessary_import` of `dart:ui` next to `material.dart` in tests).

- [ ] **Step 2: Confirm the l10n generation is honest**

```bash
flutter gen-l10n
git status --short lib/l10n
grep -A1 "get dive3d_pose_side " lib/l10n/arb/app_localizations_fr.dart
```

Expected: `git status` shows no changes under `lib/l10n` (the generated files were committed in Task 12) and the French getter returns the French string.

- [ ] **Step 3: Run the dive_3d and site_scape suites, then the full suite once**

```bash
flutter test test/features/dive_3d test/features/site_scape
flutter test
```

Expected: all green. A lone failure elsewhere in the full run is usually a known flake; rerun that one file alone before concluding anything.

- [ ] **Step 4: macOS smoke on a real dive**

```bash
flutter run -d macos
```

Open a deco dive that has temperature and tank pressure; open the 3D view from the profile card. Check: Z defaults to Temp; the axis titles carry the unit; switching Z to Pressure re-fits the axis; None flattens the path and hides shadows; hover shows the tooltip with the Z row emphasized; the Side preset shows depth vs metric front-on; the marker chip labels read; switch settings to imperial and confirm ft, psi, and °F on the titles. Then open the tissue view and a site seascape to confirm their hover tooltips still work.

- [ ] **Step 5: Commit any fixes and hand off**

```bash
git status
git log --oneline origin/main..HEAD
```

Then use the `superpowers:finishing-a-development-branch` skill (PR body: substantive summary only, no attribution line, no session link).
