# 3D Tissue View — Axes, Grid, and Hover Tooltips — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add X/Y/Z axis lines with ticks, a draped-surface-plus-floor/wall grid, and hover/tap tooltips to the 3D tissue saturation view.

**Architecture:** Build one topology-preserving `TissueSurfaceGrid` in the same pass as the existing mesh; feed it plus a pure `AxisFrame` geometry to two new `CustomPainter`s layered around the existing surface painter inside `Dive3dInteractiveViewport`; hover/tap runs a pure nearest-vertex picker whose result rides a `ValueNotifier<TissuePick?>` (like the scrub notifier) that a `Positioned` tooltip overlay observes. All new chrome is opt-in via nullable viewport params, so the dive/computers scenes are untouched.

**Tech Stack:** Flutter, Dart, Riverpod, `CustomPaint`/`Canvas`, the repo's `SceneProjector` (orthographic), Drift-backed providers.

**Spec:** `docs/superpowers/specs/2026-07-12-tissue-3d-axes-grid-tooltips-design.md`

## Global Constraints

- Tissue *chrome* (axes/grid/labels/tooltip) is scoped to the `SceneKind.tissue` scene via nullable opt-in params. (Revised post-review: camera controls — rotate/pan/zoom + on-screen buttons — were later made a general viewport capability shared by the dive scene; the computers scene uses a different widget. See the spec's "Post-review revisions".)
- ~~No on-canvas text in the 3D subsystem~~ (Revised post-review, per user request): the tissue scene now draws on-canvas axis titles + tick values via `TextPainter`; the hover tooltip carries the exact per-point value. The dive/computers scenes remain text-free.
- All new colors derived from the active `Theme`/`ColorScheme`, legible in light and dark. Axis colors avoid red (reserved for the M-value plane).
- New user-facing strings: add to `lib/l10n/arb/app_en.arb` AND all 10 non-en ARBs (`ar, de, es, fr, he, hu, it, nl, pt, zh`) with real translations, then regenerate localizations. No English placeholders in non-en ARBs.
- Immutability; no emojis in code/comments; files stay focused (200-400 lines typical).
- Run `dart format .` (whole project) and `flutter analyze` (whole project, never piped to `tail`) before each commit; both must be clean.
- Commit messages: conventional prefixes (`feat:`/`test:`/`refactor:`/`chore:`), no co-author trailer, no session URL.
- Work on a dedicated branch/worktree, not `main`. Keep the existing `SubsurfaceTissueBuilder.build(...) -> Scene3d` signature (existing tests depend on it).

## File Structure

New:
- `lib/features/dive_3d/domain/tissue/tissue_surface_grid.dart` — `TissueSurfaceGrid` value object.
- `lib/features/dive_3d/domain/geometry/axis_frame.dart` — `AxisRole`, `AxisSegment`, `AxisFrame.build`.
- `lib/features/dive_3d/domain/tissue/tissue_surface_picker.dart` — `TissuePick`, `TissueSaturationState`, `tissueSaturationStateForPercent`, `pickNearestTissueVertex`.
- `lib/features/dive_3d/presentation/renderer/scrub_cursor.dart` — shared `paintScrubCursor(canvas, center)`.
- `lib/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart` — `TissueChromeStyle`, `TissueFramePainter`, `TissueChromePainter`.
- `lib/features/dive_3d/presentation/widgets/tissue_hover_tooltip.dart` — `TissueHoverTooltip`.
- Tests mirroring each of the above.

Modified:
- `lib/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart` — add `TissueSurfaceResult` + `buildResult`; `build` delegates.
- `lib/features/dive_3d/application/tissue_providers.dart` — `tissueSurfaceProvider`, derived `tissue3dSceneProvider`, `tissueSurfaceGridProvider`, `tissueRuntimeSecondsProvider`.
- `lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart` — nullable chrome params, `MouseRegion`, layered painters, picking cache; extract cursor drawing.
- `lib/features/dive_3d/presentation/pages/dive_3d_page.dart` — build `AxisFrame`, own `_hoverPick`, pass chrome to the viewport, add tooltip overlay.
- `lib/l10n/arb/*.arb` (+ regenerated `app_localizations*.dart`).

## Canonical interfaces (used across tasks)

```dart
// tissue_surface_grid.dart
class TissueSurfaceGrid {
  final int columns;               // n
  final int compartments;          // k
  final Float32List positions;     // n*k*3 world coords, same order as the mesh
  final List<double> normalizedTimes;   // length n, 0..1
  final List<int> compartmentNumbers;   // length k
  final List<double> halfTimesN2;       // length k, minutes
  final Float32List saturationPct;      // length n*k
  bool get isEmpty;
  (double, double, double) positionAt(int col, int comp);
  double percentAt(int col, int comp);
}

// subsurface_tissue_builder.dart
typedef TissueSurfaceResult = ({Scene3d scene, TissueSurfaceGrid grid});
static TissueSurfaceResult SubsurfaceTissueBuilder.buildResult(
    List<DecoStatus> statuses, {required TissueColorFn colorFn});

// axis_frame.dart
enum AxisRole { axisX, axisY, axisZ, tick, frameGrid }
class AxisSegment { final AxisRole role; final double x1,y1,z1,x2,y2,z2; }
class AxisFrame {
  final List<AxisSegment> segments;
  factory AxisFrame.build(SceneBounds bounds,
      {double referenceY, int compartments, int timeDivs, int zDivs});
}

// tissue_surface_picker.dart
enum TissueSaturationState { onGassing, equilibrium, offGassing, pastMValue }
TissueSaturationState tissueSaturationStateForPercent(double percent);
class TissuePick { final int col; final int comp; final Offset screenPos; }
TissuePick? pickNearestTissueVertex({
  required Offset cursor,
  required List<Offset> projected,     // length columns*compartments
  required List<double> viewDepths,    // same length
  required int columns,
  required int compartments,
  double thresholdPx = 20,
});

// tissue_providers.dart
final tissueSurfaceProvider;        // FutureProvider.family<TissueSurfaceResult?, String>
final tissueSurfaceGridProvider;    // FutureProvider.family<TissueSurfaceGrid?, String>
final tissueRuntimeSecondsProvider; // FutureProvider.family<int?, String>

// scrub_cursor.dart
void paintScrubCursor(Canvas canvas, Offset center);

// tissue_chrome_painters.dart
class TissueChromeStyle { final Color axisX, axisY, axisZ, grid, wireframe, marker, markerOutline; }
class TissueFramePainter extends CustomPainter { /* draws role==frameGrid */ }
class TissueChromePainter extends CustomPainter { /* wireframe + axes/ticks + marker + scrub cursor */ }

// dive_3d_interactive_viewport.dart (added params)
final TissueSurfaceGrid? surfaceGrid;
final AxisFrame? axisFrame;
final TissueChromeStyle? chromeStyle;
final ValueNotifier<TissuePick?>? hoverPick;
```

---

### Task 1: `TissueSurfaceGrid` + builder emits it

**Files:**
- Create: `lib/features/dive_3d/domain/tissue/tissue_surface_grid.dart`
- Modify: `lib/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart`
- Test: `test/features/dive_3d/domain/tissue/tissue_surface_grid_test.dart`

**Interfaces:**
- Produces: `TissueSurfaceGrid`, `typedef TissueSurfaceResult = ({Scene3d scene, TissueSurfaceGrid grid})`, `SubsurfaceTissueBuilder.buildResult(...)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_3d/domain/tissue/tissue_surface_grid_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';

List<DecoStatus> statusesForDive() => BuhlmannAlgorithm().processProfile(
  depths: const [0, 30, 30, 30, 15, 0],
  timestamps: const [0, 120, 600, 1200, 1320, 1400],
);

void main() {
  test('buildResult grid matches the mesh dimensions and values', () {
    final statuses = statusesForDive();
    final result = SubsurfaceTissueBuilder.buildResult(
      statuses,
      colorFn: thermalColor,
    );
    final grid = result.grid;
    final k = statuses.first.compartments.length;

    expect(grid.compartments, k);
    expect(grid.columns, greaterThan(1));
    expect(grid.positions.length, grid.columns * grid.compartments * 3);
    expect(grid.saturationPct.length, grid.columns * grid.compartments);
    expect(grid.normalizedTimes.length, grid.columns);
    expect(grid.compartmentNumbers.length, k);
    expect(grid.halfTimesN2.length, k);

    // Grid positions are the exact mesh vertex positions.
    final surface = result.scene.layers.first.mesh;
    expect(grid.positions.length, surface.positions.length);
    for (var i = 0; i < grid.positions.length; i++) {
      expect(grid.positions[i], surface.positions[i]);
    }

    // normalizedTimes is 0..1 monotonic.
    expect(grid.normalizedTimes.first, 0.0);
    expect(grid.normalizedTimes.last, 1.0);

    // percentAt equals subsurfacePercentage of the corresponding status.
    final cols = grid.columns;
    final midCol = cols ~/ 2;
    final y = grid.positionAt(midCol, 0).$2;
    expect(y, greaterThanOrEqualTo(0));
    expect(grid.percentAt(midCol, 0), greaterThanOrEqualTo(0));
  });

  test('build still returns just the Scene3d (back-compat)', () {
    final scene = SubsurfaceTissueBuilder.build(
      statusesForDive(),
      colorFn: thermalColor,
    );
    expect(scene.layers.length, 2);
  });

  test('empty input yields an empty grid', () {
    final result = SubsurfaceTissueBuilder.buildResult(
      const [],
      colorFn: thermalColor,
    );
    expect(result.grid.isEmpty, isTrue);
    expect(result.scene.layers, isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/domain/tissue/tissue_surface_grid_test.dart`
Expected: FAIL — `buildResult` and `TissueSurfaceGrid` are undefined.

- [ ] **Step 3: Create `TissueSurfaceGrid`**

```dart
// lib/features/dive_3d/domain/tissue/tissue_surface_grid.dart
import 'dart:typed_data';

/// The n x k tissue surface as a topology-preserving grid. Its [positions]
/// are the exact vertices (and order) of the drawn mesh, so the draped
/// wireframe and the hover picker align pixel-for-pixel with what is rendered.
/// Built once, in the same pass as the Scene3d, by SubsurfaceTissueBuilder.
class TissueSurfaceGrid {
  /// Number of (decimated) time columns.
  final int columns;

  /// Number of compartments (16).
  final int compartments;

  /// n*k*3 world coordinates: (x = time, y = height/percent, z = compartment).
  final Float32List positions;

  /// Length [columns]; 0..1 progress per column.
  final List<double> normalizedTimes;

  /// Length [compartments]; Buhlmann compartment numbers (1..16, fast -> slow).
  final List<int> compartmentNumbers;

  /// Length [compartments]; nitrogen half-times in minutes.
  final List<double> halfTimesN2;

  /// Length n*k; subsurfacePercentage per cell (matches height and color).
  final Float32List saturationPct;

  const TissueSurfaceGrid({
    required this.columns,
    required this.compartments,
    required this.positions,
    required this.normalizedTimes,
    required this.compartmentNumbers,
    required this.halfTimesN2,
    required this.saturationPct,
  });

  /// An empty grid (no samples). The chrome/picker treat this as "draw nothing".
  static final TissueSurfaceGrid empty = TissueSurfaceGrid(
    columns: 0,
    compartments: 0,
    positions: Float32List(0),
    normalizedTimes: const [],
    compartmentNumbers: const [],
    halfTimesN2: const [],
    saturationPct: Float32List(0),
  );

  bool get isEmpty => columns == 0 || compartments == 0;

  int _index(int col, int comp) => col * compartments + comp;

  /// World position (x, y, z) of the vertex at (col, comp).
  (double, double, double) positionAt(int col, int comp) {
    final i = _index(col, comp) * 3;
    return (positions[i], positions[i + 1], positions[i + 2]);
  }

  /// subsurfacePercentage at (col, comp).
  double percentAt(int col, int comp) => saturationPct[_index(col, comp)];
}
```

- [ ] **Step 4: Add `buildResult` to the builder; make `build` delegate**

In `lib/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart`:

Add the import at the top (after the existing imports):

```dart
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_grid.dart';
```

Add the typedef above the class (below the imports):

```dart
/// The Scene3d plus the topology-preserving grid, built in one pass.
typedef TissueSurfaceResult = ({Scene3d scene, TissueSurfaceGrid grid});
```

Replace the existing `static Scene3d build(...) { ... }` method body so `build`
delegates and a new `buildResult` does the work. The loop is the original loop
with three added collectors (`saturationPct`, `compartmentNumbers`,
`halfTimesN2`) and the grid assembled from the same `positions`/`normalizedTimes`:

```dart
  static Scene3d build(
    List<DecoStatus> statuses, {
    required TissueColorFn colorFn,
  }) => buildResult(statuses, colorFn: colorFn).scene;

  static TissueSurfaceResult buildResult(
    List<DecoStatus> statuses, {
    required TissueColorFn colorFn,
  }) {
    if (statuses.length < 2 || statuses.first.compartments.isEmpty) {
      return (
        scene: const Scene3d(
          layers: [],
          markers: [],
          bounds: SceneBounds(durationSeconds: 1, maxDepthMeters: 1),
        ),
        grid: TissueSurfaceGrid.empty,
      );
    }

    final cols = _columnIndices(statuses.length);
    final k = statuses.first.compartments.length;
    final n = cols.length;

    final positions = Float32List(n * k * 3);
    final colors = Float32List(n * k * 3);
    final saturationPct = Float32List(n * k);
    final cursorXs = <double>[];
    final cursorYs = <double>[];
    final cursorZs = <double>[];
    final normalizedTimes = <double>[];

    for (var ci = 0; ci < n; ci++) {
      final status = statuses[cols[ci]];
      final ambient = status.ambientPressureBar;
      final x = (ci / (n - 1)) * SceneBounds.xSpan;
      var hotPct = -1.0;
      var hotZ = 0.0;
      for (var c = 0; c < k; c++) {
        final pct = subsurfacePercentage(status.compartments[c], ambient);
        final vi = (ci * k + c) * 3;
        final z = _zOf(c, k);
        positions[vi] = x;
        positions[vi + 1] = _height(pct);
        positions[vi + 2] = z;
        saturationPct[ci * k + c] = pct;
        final color = colorFn(pct);
        colors[vi] = color.r;
        colors[vi + 1] = color.g;
        colors[vi + 2] = color.b;
        if (pct > hotPct) {
          hotPct = pct;
          hotZ = z;
        }
      }
      cursorXs.add(x);
      cursorYs.add(_height(hotPct));
      cursorZs.add(hotZ);
      normalizedTimes.add(n == 1 ? 0 : ci / (n - 1));
    }

    final surface = MeshData(
      positions: positions,
      indices: _gridIndices(n, k),
      colors: colors,
    );

    const bounds = SceneBounds(
      durationSeconds: 1,
      maxDepthMeters: 1,
      sceneMinY: 0,
      sceneMaxY: referenceHeight * (maxPercent / 100.0),
    );

    final firstComps = statuses.first.compartments;
    final grid = TissueSurfaceGrid(
      columns: n,
      compartments: k,
      positions: positions,
      normalizedTimes: normalizedTimes,
      compartmentNumbers: [for (final c in firstComps) c.compartmentNumber],
      halfTimesN2: [for (final c in firstComps) c.halfTimeN2],
      saturationPct: saturationPct,
    );

    return (
      scene: Scene3d(
        layers: [SceneLayer(surface), SceneLayer(_mValuePlane())],
        markers: const [],
        bounds: bounds,
        scrubPath: ScrubPath(
          normalizedTimes: normalizedTimes,
          xs: cursorXs,
          ys: cursorYs,
          zs: cursorZs,
        ),
      ),
      grid: grid,
    );
  }
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/dive_3d/domain/tissue/tissue_surface_grid_test.dart test/features/dive_3d/domain/tissue/subsurface_tissue_builder_test.dart`
Expected: PASS (both the new grid test and the untouched builder test).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_3d/domain/tissue/tissue_surface_grid.dart \
        lib/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart \
        test/features/dive_3d/domain/tissue/tissue_surface_grid_test.dart
git commit -m "feat(dive-3d): emit TissueSurfaceGrid alongside the tissue mesh"
```

---

### Task 2: Tissue providers (surface result, grid, runtime)

**Files:**
- Modify: `lib/features/dive_3d/application/tissue_providers.dart`
- Test: `test/features/dive_3d/application/tissue_providers_test.dart`

**Interfaces:**
- Consumes: `SubsurfaceTissueBuilder.buildResult`, `diveProvider` (`FutureProvider.family<Dive?, String>` in `dive_providers.dart`), `Dive.effectiveRuntime` (`Duration?`).
- Produces: `tissueSurfaceProvider`, `tissueSurfaceGridProvider`, `tissueRuntimeSecondsProvider`; `tissue3dSceneProvider` now derived.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_3d/application/tissue_providers_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/features/dive_3d/application/tissue_providers.dart';

List<DecoStatus> statuses() => BuhlmannAlgorithm().processProfile(
  depths: const [0, 30, 30, 30, 0],
  timestamps: const [0, 120, 600, 1200, 1400],
);

void main() {
  test('tissueSurfaceProvider builds scene and grid from statuses', () async {
    final container = ProviderContainer(
      overrides: [
        tissueDecoStatusesProvider(
          'd1',
        ).overrideWith((ref) async => statuses()),
      ],
    );
    addTearDown(container.dispose);

    final result = await container.read(tissueSurfaceProvider('d1').future);
    expect(result, isNotNull);
    expect(result!.scene.layers.length, 2);
    expect(result.grid.columns, greaterThan(1));

    final grid = await container.read(tissueSurfaceGridProvider('d1').future);
    expect(grid, isNotNull);
    expect(grid!.compartments, 16);
  });

  test('tissueSurfaceProvider is null for < 2 statuses', () async {
    final container = ProviderContainer(
      overrides: [
        tissueDecoStatusesProvider('d1').overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);
    expect(await container.read(tissueSurfaceProvider('d1').future), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/application/tissue_providers_test.dart`
Expected: FAIL — `tissueSurfaceProvider`/`tissueSurfaceGridProvider` undefined.

- [ ] **Step 3: Add the providers**

In `lib/features/dive_3d/application/tissue_providers.dart`, add imports:

```dart
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_grid.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
```

Replace the existing `tissue3dSceneProvider` definition with the surface
provider plus derived providers:

```dart
/// The Scene3d + TissueSurfaceGrid for a dive, built in a single pass so the
/// mesh, the draped wireframe, and the hover picker never drift apart.
/// Null when no analysis exists (< 2 statuses).
final tissueSurfaceProvider =
    FutureProvider.family<TissueSurfaceResult?, String>((ref, diveId) async {
      final statuses = await ref.watch(
        tissueDecoStatusesProvider(diveId).future,
      );
      if (statuses.length < 2) return null;
      final colorFn = colorFnForScheme(ref.watch(tissueColorSchemeProvider));
      return SubsurfaceTissueBuilder.buildResult(statuses, colorFn: colorFn);
    });

/// The 3D extrusion of the tissue heat map (derived from [tissueSurfaceProvider]).
final tissue3dSceneProvider = FutureProvider.family<Scene3d?, String>((
  ref,
  diveId,
) async =>
    (await ref.watch(tissueSurfaceProvider(diveId).future))?.scene);

/// The topology-preserving grid for wireframe + hover picking.
final tissueSurfaceGridProvider =
    FutureProvider.family<TissueSurfaceGrid?, String>((ref, diveId) async =>
        (await ref.watch(tissueSurfaceProvider(diveId).future))?.grid);

/// Dive runtime in seconds, used to convert the tissue X axis (0..1 progress)
/// into a wall-clock mm:ss in the hover tooltip. Null when unknown (the
/// tooltip then shows "% of dive").
final tissueRuntimeSecondsProvider = FutureProvider.family<int?, String>((
  ref,
  diveId,
) async {
  final dive = await ref.watch(diveProvider(diveId).future);
  return dive?.effectiveRuntime?.inSeconds;
});
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_3d/application/tissue_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_3d/application/tissue_providers.dart \
        test/features/dive_3d/application/tissue_providers_test.dart
git commit -m "feat(dive-3d): expose tissue surface grid and runtime providers"
```

---

### Task 3: `AxisFrame` geometry

**Files:**
- Create: `lib/features/dive_3d/domain/geometry/axis_frame.dart`
- Test: `test/features/dive_3d/domain/geometry/axis_frame_test.dart`

**Interfaces:**
- Consumes: `SceneBounds`.
- Produces: `AxisRole`, `AxisSegment`, `AxisFrame.build(...)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_3d/domain/geometry/axis_frame_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/axis_frame.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

void main() {
  const bounds = SceneBounds(
    durationSeconds: 1,
    maxDepthMeters: 1,
    sceneMinY: 0,
    sceneMaxY: 3.9,
  );

  test('produces exactly one segment per axis', () {
    final frame = AxisFrame.build(bounds, referenceY: 3.0);
    expect(frame.segments.where((s) => s.role == AxisRole.axisX).length, 1);
    expect(frame.segments.where((s) => s.role == AxisRole.axisY).length, 1);
    expect(frame.segments.where((s) => s.role == AxisRole.axisZ).length, 1);
  });

  test('axes originate at the (0, sceneMinY, sceneMinZ) corner', () {
    final frame = AxisFrame.build(bounds, referenceY: 3.0);
    final x = frame.segments.firstWhere((s) => s.role == AxisRole.axisX);
    expect(x.x1, 0);
    expect(x.y1, bounds.sceneMinY);
    expect(x.z1, bounds.sceneMinZ);
    expect(x.x2, SceneBounds.xSpan); // X axis spans the full time extent
  });

  test('has a Y tick at the reference (100%) height', () {
    final frame = AxisFrame.build(bounds, referenceY: 3.0);
    final ticks = frame.segments.where((s) => s.role == AxisRole.tick);
    expect(ticks.any((t) => (t.y1 - 3.0).abs() < 1e-9), isTrue);
    // 0% and 50% ticks too.
    expect(ticks.any((t) => t.y1.abs() < 1e-9), isTrue);
    expect(ticks.any((t) => (t.y1 - 1.5).abs() < 1e-9), isTrue);
  });

  test('emits floor and wall grid segments', () {
    final frame = AxisFrame.build(bounds, referenceY: 3.0);
    expect(
      frame.segments.where((s) => s.role == AxisRole.frameGrid).length,
      greaterThan(4),
    );
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/domain/geometry/axis_frame_test.dart`
Expected: FAIL — `AxisFrame` undefined.

- [ ] **Step 3: Implement `AxisFrame`**

```dart
// lib/features/dive_3d/domain/geometry/axis_frame.dart
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';

/// The role of a line segment so the renderer can color axes, ticks, and the
/// reference grid distinctly.
enum AxisRole { axisX, axisY, axisZ, tick, frameGrid }

/// A line segment in world (scene) coordinates.
class AxisSegment {
  final AxisRole role;
  final double x1, y1, z1, x2, y2, z2;
  const AxisSegment(
    this.role,
    this.x1,
    this.y1,
    this.z1,
    this.x2,
    this.y2,
    this.z2,
  );
}

/// Axis lines (X = time, Y = saturation %, Z = compartment), tick marks, and a
/// floor + back-wall reference grid for a tissue [SceneBounds]. Pure geometry;
/// no Canvas dependency. Values are read out by the hover tooltip, so ticks
/// carry no text (the 3D subsystem paints no on-canvas numbers).
class AxisFrame {
  final List<AxisSegment> segments;
  const AxisFrame(this.segments);

  /// [referenceY] is the scene-Y of 100% (the M-value plane height), so the Y
  /// ticks land at 0 / 50 / 100%. [timeDivs] divisions along X (and the floor
  /// and back wall), [zDivs] divisions along Z for the floor/wall grid.
  factory AxisFrame.build(
    SceneBounds bounds, {
    double referenceY = 3.0,
    int compartments = 16,
    int timeDivs = 4,
    int zDivs = 4,
  }) {
    final segments = <AxisSegment>[];
    final x0 = 0.0;
    final x1 = SceneBounds.xSpan;
    final y0 = bounds.sceneMinY;
    final y1 = bounds.sceneMaxY;
    final z0 = bounds.sceneMinZ;
    final z1 = bounds.sceneMaxZ;
    final tick = SceneBounds.xSpan * 0.02; // short mark length in world units

    // --- Axes, from the origin corner (x0, y0, z0). ---
    segments.add(AxisSegment(AxisRole.axisX, x0, y0, z0, x1, y0, z0));
    segments.add(AxisSegment(AxisRole.axisY, x0, y0, z0, x0, y1, z0));
    segments.add(AxisSegment(AxisRole.axisZ, x0, y0, z0, x0, y0, z1));

    // --- X ticks (into +z on the floor). ---
    for (var i = 1; i <= timeDivs; i++) {
      final x = x0 + (x1 - x0) * i / timeDivs;
      segments.add(AxisSegment(AxisRole.tick, x, y0, z0, x, y0, z0 + tick));
    }

    // --- Y ticks at 0 / 50 / 100% (into +x on the back wall). ---
    for (final y in [y0, y0 + (referenceY - y0) * 0.5, referenceY]) {
      segments.add(AxisSegment(AxisRole.tick, x0, y, z0, x0 + tick, y, z0));
    }

    // --- Z ticks per compartment (into +x on the floor). ---
    for (var c = 0; c < compartments; c++) {
      final t = compartments <= 1 ? 0.0 : c / (compartments - 1);
      final z = z0 + (z1 - z0) * t;
      segments.add(AxisSegment(AxisRole.tick, x0, y0, z, x0 + tick, y0, z));
    }

    // --- Floor grid (y = y0): lines along X at each z-div, along Z at each x-div. ---
    for (var i = 0; i <= zDivs; i++) {
      final z = z0 + (z1 - z0) * i / zDivs;
      segments.add(AxisSegment(AxisRole.frameGrid, x0, y0, z, x1, y0, z));
    }
    for (var i = 0; i <= timeDivs; i++) {
      final x = x0 + (x1 - x0) * i / timeDivs;
      segments.add(AxisSegment(AxisRole.frameGrid, x, y0, z0, x, y0, z1));
    }

    // --- Back wall (z = z1): verticals at each x-div, horizontals at each y-tick. ---
    for (var i = 0; i <= timeDivs; i++) {
      final x = x0 + (x1 - x0) * i / timeDivs;
      segments.add(AxisSegment(AxisRole.frameGrid, x, y0, z1, x, y1, z1));
    }
    for (final y in [y0, y0 + (referenceY - y0) * 0.5, referenceY]) {
      segments.add(AxisSegment(AxisRole.frameGrid, x0, y, z1, x1, y, z1));
    }

    // --- Left wall (x = x0): verticals at each z-div, horizontals at each y-tick. ---
    for (var i = 0; i <= zDivs; i++) {
      final z = z0 + (z1 - z0) * i / zDivs;
      segments.add(AxisSegment(AxisRole.frameGrid, x0, y0, z, x0, y1, z));
    }
    for (final y in [y0, y0 + (referenceY - y0) * 0.5, referenceY]) {
      segments.add(AxisSegment(AxisRole.frameGrid, x0, y, z0, x0, y, z1));
    }

    return AxisFrame(segments);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_3d/domain/geometry/axis_frame_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_3d/domain/geometry/axis_frame.dart \
        test/features/dive_3d/domain/geometry/axis_frame_test.dart
git commit -m "feat(dive-3d): add AxisFrame geometry for tissue axes and grid"
```

---

### Task 4: Surface picker + saturation state

**Files:**
- Create: `lib/features/dive_3d/domain/tissue/tissue_surface_picker.dart`
- Test: `test/features/dive_3d/domain/tissue/tissue_surface_picker_test.dart`

**Interfaces:**
- Produces: `TissuePick`, `TissueSaturationState`, `tissueSaturationStateForPercent`, `pickNearestTissueVertex`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_3d/domain/tissue/tissue_surface_picker_test.dart
import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';

void main() {
  group('pickNearestTissueVertex', () {
    // 2 columns x 2 compartments at known screen points.
    final projected = <Offset>[
      const Offset(0, 0),    // (col0, comp0)
      const Offset(0, 10),   // (col0, comp1)
      const Offset(10, 0),   // (col1, comp0)
      const Offset(10, 10),  // (col1, comp1)
    ];
    final depths = <double>[0, 0, 0, 0];

    test('returns the nearest vertex within threshold', () {
      final pick = pickNearestTissueVertex(
        cursor: const Offset(9, 1),
        projected: projected,
        viewDepths: depths,
        columns: 2,
        compartments: 2,
      );
      expect(pick, isNotNull);
      expect(pick!.col, 1);
      expect(pick.comp, 0);
    });

    test('returns null when nothing is within threshold', () {
      final pick = pickNearestTissueVertex(
        cursor: const Offset(500, 500),
        projected: projected,
        viewDepths: depths,
        columns: 2,
        compartments: 2,
      );
      expect(pick, isNull);
    });

    test('on a near-tie prefers the front-most (greater viewDepth)', () {
      final overlap = <Offset>[const Offset(0, 0), const Offset(0, 0)];
      final pick = pickNearestTissueVertex(
        cursor: const Offset(0, 0),
        projected: overlap,
        viewDepths: const [1.0, 5.0], // second is nearer the camera
        columns: 1,
        compartments: 2,
      );
      expect(pick!.comp, 1);
    });

    test('empty grid returns null', () {
      expect(
        pickNearestTissueVertex(
          cursor: Offset.zero,
          projected: const [],
          viewDepths: const [],
          columns: 0,
          compartments: 0,
        ),
        isNull,
      );
    });
  });

  group('tissueSaturationStateForPercent', () {
    test('maps percent to state on half-open intervals', () {
      expect(tissueSaturationStateForPercent(44), TissueSaturationState.onGassing);
      expect(tissueSaturationStateForPercent(45), TissueSaturationState.equilibrium);
      expect(tissueSaturationStateForPercent(54.9), TissueSaturationState.equilibrium);
      expect(tissueSaturationStateForPercent(55), TissueSaturationState.offGassing);
      expect(tissueSaturationStateForPercent(100), TissueSaturationState.offGassing);
      expect(tissueSaturationStateForPercent(100.1), TissueSaturationState.pastMValue);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/domain/tissue/tissue_surface_picker_test.dart`
Expected: FAIL — symbols undefined.

- [ ] **Step 3: Implement the picker**

```dart
// lib/features/dive_3d/domain/tissue/tissue_surface_picker.dart
import 'dart:ui';

/// Where a compartment sits relative to ambient-equilibrium (the Subsurface
/// convention: 50% = at ambient). Thresholds are half-open.
enum TissueSaturationState { onGassing, equilibrium, offGassing, pastMValue }

TissueSaturationState tissueSaturationStateForPercent(double percent) {
  if (percent < 45) return TissueSaturationState.onGassing;
  if (percent < 55) return TissueSaturationState.equilibrium;
  if (percent <= 100) return TissueSaturationState.offGassing;
  return TissueSaturationState.pastMValue;
}

/// A picked surface vertex: its grid coordinates and where it landed on screen.
class TissuePick {
  final int col;
  final int comp;
  final Offset screenPos;
  const TissuePick({
    required this.col,
    required this.comp,
    required this.screenPos,
  });
}

const double _tiePx = 4.0;

/// Nearest projected surface vertex to [cursor] within [thresholdPx]. On a
/// near-tie (within [_tiePx]) prefers the greater [viewDepths] value so the
/// cursor picks the visible front surface, not a vertex hidden behind it.
/// Returns null if nothing qualifies. [projected]/[viewDepths] are indexed
/// col*compartments + comp.
TissuePick? pickNearestTissueVertex({
  required Offset cursor,
  required List<Offset> projected,
  required List<double> viewDepths,
  required int columns,
  required int compartments,
  double thresholdPx = 20,
}) {
  var bestIndex = -1;
  var bestDist = thresholdPx;
  var bestDepth = double.negativeInfinity;
  for (var i = 0; i < projected.length; i++) {
    final d = (projected[i] - cursor).distance;
    if (d > thresholdPx) continue;
    final better =
        bestIndex < 0 ||
        d < bestDist - _tiePx ||
        ((d - bestDist).abs() <= _tiePx && viewDepths[i] > bestDepth);
    if (better) {
      bestIndex = i;
      bestDist = d < bestDist ? d : bestDist;
      bestDepth = viewDepths[i];
    }
  }
  if (bestIndex < 0) return null;
  return TissuePick(
    col: bestIndex ~/ compartments,
    comp: bestIndex % compartments,
    screenPos: projected[bestIndex],
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_3d/domain/tissue/tissue_surface_picker_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_3d/domain/tissue/tissue_surface_picker.dart \
        test/features/dive_3d/domain/tissue/tissue_surface_picker_test.dart
git commit -m "feat(dive-3d): add nearest-vertex tissue surface picker"
```

---

### Task 5: Localization strings

**Files:**
- Modify: `lib/l10n/arb/app_en.arb` and all 10 non-en ARBs.
- Regenerate: `lib/l10n/arb/app_localizations*.dart`.

**Interfaces:**
- Produces: `context.l10n.dive3d_tissue_tooltipCompartment(number)`,
  `..._tooltipHalfTime(minutes)`, `..._tooltipSaturation(percent)`,
  `..._tooltipProgress(percent)`, and state strings `..._stateOnGassing`,
  `..._stateEquilibrium`, `..._stateOffGassing`, `..._statePastMValue`.

- [ ] **Step 1: Add keys to `app_en.arb`**

Insert alongside the other `dive3d_tissue_*` keys (values shown; keep the ARB's
`@`-metadata style consistent with neighbors, including placeholders):

```json
  "dive3d_tissue_tooltipCompartment": "Comp {number}",
  "@dive3d_tissue_tooltipCompartment": {
    "placeholders": { "number": { "type": "int" } }
  },
  "dive3d_tissue_tooltipHalfTime": "{minutes} min N2",
  "@dive3d_tissue_tooltipHalfTime": {
    "placeholders": { "minutes": { "type": "String" } }
  },
  "dive3d_tissue_tooltipSaturation": "Saturation {percent}%",
  "@dive3d_tissue_tooltipSaturation": {
    "placeholders": { "percent": { "type": "int" } }
  },
  "dive3d_tissue_tooltipProgress": "{percent}% of dive",
  "@dive3d_tissue_tooltipProgress": {
    "placeholders": { "percent": { "type": "int" } }
  },
  "dive3d_tissue_stateOnGassing": "On-gassing",
  "@dive3d_tissue_stateOnGassing": {},
  "dive3d_tissue_stateEquilibrium": "Equilibrium",
  "@dive3d_tissue_stateEquilibrium": {},
  "dive3d_tissue_stateOffGassing": "Off-gassing",
  "@dive3d_tissue_stateOffGassing": {},
  "dive3d_tissue_statePastMValue": "Past M-value",
  "@dive3d_tissue_statePastMValue": {}
```

- [ ] **Step 2: Add translated equivalents to all 10 non-en ARBs**

Add the same keys (no `@`-metadata needed in non-template ARBs) with correct
translations for each of `app_ar.arb, app_de.arb, app_es.arb, app_fr.arb,
app_he.arb, app_hu.arb, app_it.arb, app_nl.arb, app_pt.arb, app_zh.arb`. Keep
the `{number}`/`{minutes}`/`{percent}` placeholders verbatim. Do not leave
English text in non-en files.

- [ ] **Step 3: Regenerate localizations**

Run: `flutter gen-l10n` (or `flutter pub get` if the project generates l10n via
build). Confirm `AppLocalizations` now exposes the new getters/methods.

- [ ] **Step 4: Verify analyze is clean**

Run: `flutter analyze`
Expected: no errors referencing the new keys.

- [ ] **Step 5: Format, commit**

```bash
dart format .
git add lib/l10n
git commit -m "feat(l10n): add 3D tissue tooltip and saturation-state strings"
```

---

### Task 6: `TissueHoverTooltip` widget

**Files:**
- Create: `lib/features/dive_3d/presentation/widgets/tissue_hover_tooltip.dart`
- Test: `test/features/dive_3d/presentation/widgets/tissue_hover_tooltip_test.dart`

**Interfaces:**
- Consumes: `TissuePick`, `TissueSurfaceGrid`, `tissueSaturationStateForPercent`, `TissueColorFn`, the l10n keys from Task 5.
- Produces: `TissueHoverTooltip`.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_3d/presentation/widgets/tissue_hover_tooltip_test.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_grid.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/tissue_hover_tooltip.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';

import '../../../../helpers/test_app.dart';

TissueSurfaceGrid gridFixture() {
  // 2 columns x 1 compartment; percent 84 at (col1, comp0).
  final positions = Float32List.fromList([0, 0, 0, 10, 2.5, 0]);
  final pct = Float32List.fromList([10, 84]);
  return TissueSurfaceGrid(
    columns: 2,
    compartments: 1,
    positions: positions,
    normalizedTimes: const [0, 1],
    compartmentNumbers: const [6],
    halfTimesN2: const [27],
    saturationPct: pct,
  );
}

void main() {
  testWidgets('renders time, compartment, and saturation', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: const [],
        child: TissueHoverTooltip(
          pick: const TissuePick(col: 1, comp: 0, screenPos: Offset.zero),
          grid: gridFixture(),
          runtimeSeconds: 1500, // 25:00 total -> col1 (progress 1.0) = 25:00
          colorFn: thermalColor,
        ),
      ),
    );
    await tester.pump();

    expect(find.textContaining('Comp 6'), findsOneWidget);
    expect(find.textContaining('Saturation 84%'), findsOneWidget);
    expect(find.textContaining('Off-gassing'), findsOneWidget);
    expect(find.textContaining('25:00'), findsOneWidget);
  });

  testWidgets('falls back to percent-of-dive when runtime is null', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        overrides: const [],
        child: TissueHoverTooltip(
          pick: const TissuePick(col: 0, comp: 0, screenPos: Offset.zero),
          grid: gridFixture(),
          runtimeSeconds: null,
          colorFn: thermalColor,
        ),
      ),
    );
    await tester.pump();
    expect(find.textContaining('% of dive'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/presentation/widgets/tissue_hover_tooltip_test.dart`
Expected: FAIL — `TissueHoverTooltip` undefined.

- [ ] **Step 3: Implement the widget**

```dart
// lib/features/dive_3d/presentation/widgets/tissue_hover_tooltip.dart
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_grid.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Compact readout for a hovered/tapped surface cell: time, compartment (with
/// N2 half-time), and saturation % with its state word. The values that the
/// tick-only axes deliberately omit live here.
class TissueHoverTooltip extends StatelessWidget {
  final TissuePick pick;
  final TissueSurfaceGrid grid;
  final int? runtimeSeconds;
  final TissueColorFn colorFn;

  const TissueHoverTooltip({
    super.key,
    required this.pick,
    required this.grid,
    required this.runtimeSeconds,
    required this.colorFn,
  });

  String _timeLabel(BuildContext context, double progress) {
    if (runtimeSeconds == null) {
      return context.l10n.dive3d_tissue_tooltipProgress((progress * 100).round());
    }
    final total = (progress * runtimeSeconds!).round();
    final m = total ~/ 60;
    final s = total % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _stateLabel(BuildContext context, TissueSaturationState state) {
    return switch (state) {
      TissueSaturationState.onGassing => context.l10n.dive3d_tissue_stateOnGassing,
      TissueSaturationState.equilibrium =>
        context.l10n.dive3d_tissue_stateEquilibrium,
      TissueSaturationState.offGassing =>
        context.l10n.dive3d_tissue_stateOffGassing,
      TissueSaturationState.pastMValue =>
        context.l10n.dive3d_tissue_statePastMValue,
    };
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme.labelSmall;
    final progress = grid.normalizedTimes[pick.col];
    final percent = grid.percentAt(pick.col, pick.comp);
    final state = tissueSaturationStateForPercent(percent);
    final swatch = colorFn(percent);
    final l10n = context.l10n;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_timeLabel(context, progress)}  ·  '
              '${l10n.dive3d_tissue_tooltipCompartment(grid.compartmentNumbers[pick.comp])}'
              '  ·  '
              '${l10n.dive3d_tissue_tooltipHalfTime(grid.halfTimesN2[pick.comp].round().toString())}',
              style: text,
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, color: swatch),
                const SizedBox(width: 6),
                Text(
                  '${l10n.dive3d_tissue_tooltipSaturation(percent.round())}'
                  '  —  ${_stateLabel(context, state)}',
                  style: text,
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

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_3d/presentation/widgets/tissue_hover_tooltip_test.dart`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_3d/presentation/widgets/tissue_hover_tooltip.dart \
        test/features/dive_3d/presentation/widgets/tissue_hover_tooltip_test.dart
git commit -m "feat(dive-3d): add tissue hover tooltip widget"
```

---

### Task 7: Chrome painters + shared scrub cursor

**Files:**
- Create: `lib/features/dive_3d/presentation/renderer/scrub_cursor.dart`
- Create: `lib/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart`
- Modify: `lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart` (use the shared cursor helper in `_ScrubCursorPainter`)
- Test: `test/features/dive_3d/presentation/renderer/tissue_chrome_painters_test.dart`

**Interfaces:**
- Consumes: `SceneProjector`, `Scene3d`, `TissueSurfaceGrid`, `AxisFrame`, `TissuePick`.
- Produces: `paintScrubCursor`, `TissueChromeStyle`, `TissueFramePainter`, `TissueChromePainter`.

- [ ] **Step 1: Write the failing test (painters don't throw and are camera-reactive)**

```dart
// test/features/dive_3d/presentation/renderer/tissue_chrome_painters_test.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/features/dive_3d/domain/geometry/axis_frame.dart';
import 'package:submersion/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';

void main() {
  final result = SubsurfaceTissueBuilder.buildResult(
    BuhlmannAlgorithm().processProfile(
      depths: const [0, 30, 30, 30, 0],
      timestamps: const [0, 120, 600, 1200, 1400],
    ),
    colorFn: thermalColor,
  );
  const style = TissueChromeStyle(
    axisX: Colors.amber,
    axisY: Colors.green,
    axisZ: Colors.blue,
    grid: Colors.white24,
    wireframe: Colors.white24,
    marker: Colors.white,
    markerOutline: Colors.black,
  );

  ui.Image paint(CustomPainter painter) {
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Size(400, 300));
    return recorder.endRecording().toImageSync(400, 300);
  }

  test('frame painter paints without throwing', () {
    final frame = AxisFrame.build(result.scene.bounds, referenceY: 3.0);
    expect(
      () => paint(
        TissueFramePainter(
          bounds: result.scene.bounds,
          frame: frame,
          style: style,
          yawDegrees: -32,
          pitchDegrees: 22,
          zoom: 1,
        ),
      ),
      returnsNormally,
    );
  });

  test('chrome painter paints (with a hover pick) without throwing', () {
    final frame = AxisFrame.build(result.scene.bounds, referenceY: 3.0);
    final pick = ValueNotifier<TissuePick?>(
      const TissuePick(col: 1, comp: 3, screenPos: Offset(200, 150)),
    );
    final painter = TissueChromePainter(
      scene: result.scene,
      grid: result.grid,
      frame: frame,
      style: style,
      yawDegrees: -32,
      pitchDegrees: 22,
      zoom: 1,
      scrubPosition: ValueNotifier<double>(0.5),
      hoverPick: pick,
    );
    expect(() => paint(painter), returnsNormally);
  });

  test('chrome painter repaints when the camera changes', () {
    final frame = AxisFrame.build(result.scene.bounds, referenceY: 3.0);
    TissueChromePainter make(double yaw) => TissueChromePainter(
      scene: result.scene,
      grid: result.grid,
      frame: frame,
      style: style,
      yawDegrees: yaw,
      pitchDegrees: 22,
      zoom: 1,
      scrubPosition: ValueNotifier<double>(0),
      hoverPick: ValueNotifier<TissuePick?>(null),
    );
    expect(make(-32).shouldRepaint(make(10)), isTrue);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/presentation/renderer/tissue_chrome_painters_test.dart`
Expected: FAIL — symbols undefined.

- [ ] **Step 3: Extract the shared scrub cursor**

```dart
// lib/features/dive_3d/presentation/renderer/scrub_cursor.dart
import 'package:flutter/material.dart';

/// Draws the scrub cursor dot (light fill + dark outline) at [center].
/// Shared by the default scrub-cursor painter and the tissue chrome painter so
/// both scenes draw an identical cursor.
void paintScrubCursor(Canvas canvas, Offset center) {
  canvas.drawCircle(
    center,
    7,
    Paint()
      ..color = Colors.white.withValues(alpha: 0.9)
      ..style = PaintingStyle.fill,
  );
  canvas.drawCircle(
    center,
    7,
    Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5,
  );
}
```

In `dive_3d_interactive_viewport.dart`, add the import and replace the two
`canvas.drawCircle(center, 7, ...)` calls at the end of `_ScrubCursorPainter.paint`
(the fill + stroke pair) with a single `paintScrubCursor(canvas, center);`.

```dart
import 'package:submersion/features/dive_3d/presentation/renderer/scrub_cursor.dart';
```

- [ ] **Step 4: Implement the chrome painters**

```dart
// lib/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/features/dive_3d/domain/geometry/axis_frame.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_grid.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scrub_cursor.dart';

/// Theme-resolved colors for the tissue chrome (built by the viewport, which
/// owns the BuildContext; painters never read Theme directly).
class TissueChromeStyle {
  final Color axisX, axisY, axisZ, grid, wireframe, marker, markerOutline;
  const TissueChromeStyle({
    required this.axisX,
    required this.axisY,
    required this.axisZ,
    required this.grid,
    required this.wireframe,
    required this.marker,
    required this.markerOutline,
  });
}

/// Background layer: the floor + back-wall reference grid, drawn BEHIND the
/// surface so the opaque mesh occludes it via paint order.
class TissueFramePainter extends CustomPainter {
  final SceneBounds bounds;
  final AxisFrame frame;
  final TissueChromeStyle style;
  final double yawDegrees, pitchDegrees, zoom;

  TissueFramePainter({
    required this.bounds,
    required this.frame,
    required this.style,
    required this.yawDegrees,
    required this.pitchDegrees,
    required this.zoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final projector = SceneProjector(
      size: size,
      bounds: bounds,
      yawDegrees: yawDegrees,
      pitchDegrees: pitchDegrees,
      zoom: zoom,
    );
    final paint = Paint()
      ..color = style.grid
      ..strokeWidth = 0.75
      ..style = PaintingStyle.stroke;
    for (final s in frame.segments) {
      if (s.role != AxisRole.frameGrid) continue;
      canvas.drawLine(
        projector.project(s.x1, s.y1, s.z1),
        projector.project(s.x2, s.y2, s.z2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TissueFramePainter old) =>
      old.yawDegrees != yawDegrees ||
      old.pitchDegrees != pitchDegrees ||
      old.zoom != zoom ||
      !identical(old.frame, frame);
}

/// Foreground layer: draped wireframe on the surface, then the axis lines +
/// ticks, then the hover marker, then the scrub cursor. Repaints on camera
/// changes and on the scrub/hover listenables.
class TissueChromePainter extends CustomPainter {
  final Scene3d scene;
  final TissueSurfaceGrid grid;
  final AxisFrame frame;
  final TissueChromeStyle style;
  final double yawDegrees, pitchDegrees, zoom;
  final ValueListenable<double> scrubPosition;
  final ValueListenable<TissuePick?> hoverPick;

  /// ~12 iso-time lines is enough to read structure without clutter.
  static const int _maxWireColumns = 12;

  TissueChromePainter({
    required this.scene,
    required this.grid,
    required this.frame,
    required this.style,
    required this.yawDegrees,
    required this.pitchDegrees,
    required this.zoom,
    required this.scrubPosition,
    required this.hoverPick,
  }) : super(repaint: Listenable.merge([scrubPosition, hoverPick]));

  SceneProjector _projector(Size size) => SceneProjector(
    size: size,
    bounds: scene.bounds,
    yawDegrees: yawDegrees,
    pitchDegrees: pitchDegrees,
    zoom: zoom,
  );

  Offset _projectVertex(SceneProjector p, int col, int comp) {
    final (x, y, z) = grid.positionAt(col, comp);
    return p.project(x, y, z);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = _projector(size);
    if (!grid.isEmpty) _paintWireframe(canvas, p);
    _paintAxes(canvas, p);
    _paintMarker(canvas, p);
    _paintCursor(canvas, p);
  }

  void _paintWireframe(Canvas canvas, SceneProjector p) {
    final paint = Paint()
      ..color = style.wireframe
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;
    // Iso-compartment lines (along time) for every compartment row.
    for (var comp = 0; comp < grid.compartments; comp++) {
      final path = Path();
      for (var col = 0; col < grid.columns; col++) {
        final o = _projectVertex(p, col, comp);
        col == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, paint);
    }
    // Iso-time lines (along compartments) for a decimated set of columns.
    final step = (grid.columns / _maxWireColumns).ceil().clamp(1, grid.columns);
    for (var col = 0; col < grid.columns; col += step) {
      final path = Path();
      for (var comp = 0; comp < grid.compartments; comp++) {
        final o = _projectVertex(p, col, comp);
        comp == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  void _paintAxes(Canvas canvas, SceneProjector p) {
    Paint stroke(Color c, double w) => Paint()
      ..color = c
      ..strokeWidth = w
      ..style = PaintingStyle.stroke;
    for (final s in frame.segments) {
      final a = p.project(s.x1, s.y1, s.z1);
      final b = p.project(s.x2, s.y2, s.z2);
      switch (s.role) {
        case AxisRole.axisX:
          canvas.drawLine(a, b, stroke(style.axisX, 2));
        case AxisRole.axisY:
          canvas.drawLine(a, b, stroke(style.axisY, 2));
        case AxisRole.axisZ:
          canvas.drawLine(a, b, stroke(style.axisZ, 2));
        case AxisRole.tick:
          canvas.drawLine(a, b, stroke(style.axisY.withValues(alpha: 0.9), 1.5));
        case AxisRole.frameGrid:
          break; // drawn by TissueFramePainter
      }
    }
  }

  void _paintMarker(Canvas canvas, SceneProjector p) {
    final pick = hoverPick.value;
    if (pick == null || grid.isEmpty) return;
    if (pick.col >= grid.columns || pick.comp >= grid.compartments) return;
    final center = _projectVertex(p, pick.col, pick.comp);
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = style.marker.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      center,
      6,
      Paint()
        ..color = style.markerOutline.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5,
    );
  }

  void _paintCursor(Canvas canvas, SceneProjector p) {
    final path = scene.scrubPath;
    if (path == null) return;
    final pt = path.sceneAt(scrubPosition.value);
    if (pt == null) return;
    paintScrubCursor(canvas, p.project(pt.x, pt.y, pt.z));
  }

  @override
  bool shouldRepaint(covariant TissueChromePainter old) =>
      old.yawDegrees != yawDegrees ||
      old.pitchDegrees != pitchDegrees ||
      old.zoom != zoom ||
      !identical(old.scene, scene) ||
      !identical(old.grid, grid) ||
      !identical(old.frame, frame);
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/dive_3d/presentation/renderer/tissue_chrome_painters_test.dart test/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport_test.dart`
Expected: PASS (painters work; the cursor extraction did not change viewport behavior).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_3d/presentation/renderer/scrub_cursor.dart \
        lib/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart \
        lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart \
        test/features/dive_3d/presentation/renderer/tissue_chrome_painters_test.dart
git commit -m "feat(dive-3d): add tissue frame and chrome painters"
```

---

### Task 8: Wire the viewport (optional chrome + picking)

**Files:**
- Modify: `lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart`
- Test: `test/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport_test.dart`

**Interfaces:**
- Consumes: `TissueSurfaceGrid`, `AxisFrame`, `TissueChromeStyle`, `pickNearestTissueVertex`, `TissuePick`, `TissueFramePainter`, `TissueChromePainter`.
- Produces: `Dive3dInteractiveViewport` with `surfaceGrid`, `axisFrame`, `chromeStyle`, `hoverPick` params; publishes picks to `hoverPick`.

- [ ] **Step 1: Write the failing test (deterministic hover using the real projector)**

```dart
// add to test/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport_test.dart
// (new test; keep existing tests intact)
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/features/dive_3d/domain/geometry/axis_frame.dart';
import 'package:submersion/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/scene_projector.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_color_schemes.dart';
import 'package:flutter/gestures.dart';

// Inside main():
testWidgets('hover over a surface vertex publishes a pick', (tester) async {
  const size = Size(400, 300);
  final result = SubsurfaceTissueBuilder.buildResult(
    BuhlmannAlgorithm().processProfile(
      depths: const [0, 30, 30, 30, 0],
      timestamps: const [0, 120, 600, 1200, 1400],
    ),
    colorFn: thermalColor,
  );
  final frame = AxisFrame.build(result.scene.bounds, referenceY: 3.0);
  final hoverPick = ValueNotifier<TissuePick?>(null);
  const style = TissueChromeStyle(
    axisX: Color(0xFFFFB300), axisY: Color(0xFF66BB6A), axisZ: Color(0xFF42A5F5),
    grid: Color(0x33FFFFFF), wireframe: Color(0x33FFFFFF),
    marker: Color(0xFFFFFFFF), markerOutline: Color(0xFF000000),
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SizedBox.fromSize(
          size: size,
          child: Dive3dInteractiveViewport(
            scene: result.scene,
            scrubPosition: ValueNotifier<double>(0),
            visibleOverlays: const {},
            surfaceGrid: result.grid,
            axisFrame: frame,
            chromeStyle: style,
            hoverPick: hoverPick,
          ),
        ),
      ),
    ),
  );
  await tester.pump();

  // Compute where vertex (col, comp) lands at the default camera, then hover there.
  final projector = SceneProjector(size: size, bounds: result.scene.bounds);
  const col = 1, comp = 5;
  final (x, y, z) = result.grid.positionAt(col, comp);
  final target = projector.project(x, y, z);

  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await mouse.moveTo(target);
  await tester.pump();

  expect(hoverPick.value, isNotNull);
  expect(hoverPick.value!.col, col);
  expect(hoverPick.value!.comp, comp);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport_test.dart`
Expected: FAIL — the new constructor params don't exist.

- [ ] **Step 3: Add params, projection cache, MouseRegion, and layered painters**

In `dive_3d_interactive_viewport.dart`, add imports:

```dart
import 'package:submersion/features/dive_3d/domain/geometry/axis_frame.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_grid.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart';
```

Add fields to the widget (after `scrubCursor`):

```dart
  /// Tissue-only chrome. All null for the dive/computers scenes.
  final TissueSurfaceGrid? surfaceGrid;
  final AxisFrame? axisFrame;
  final TissueChromeStyle? chromeStyle;
  final ValueNotifier<TissuePick?>? hoverPick;
```

Add them to the constructor:

```dart
    this.surfaceGrid,
    this.axisFrame,
    this.chromeStyle,
    this.hoverPick,
```

In `_Dive3dInteractiveViewportState`, add a projection cache and picking:

```dart
  // Cached screen projections of the surface grid, keyed by camera + size.
  List<Offset>? _projected;
  List<double>? _viewDepths;
  double? _cacheYaw, _cachePitch, _cacheZoom;
  Size? _cacheSize;

  void _ensureProjection(Size size) {
    final grid = widget.surfaceGrid;
    if (grid == null || grid.isEmpty) {
      _projected = null;
      _viewDepths = null;
      return;
    }
    if (_projected != null &&
        _cacheYaw == _yaw &&
        _cachePitch == _pitch &&
        _cacheZoom == _zoom &&
        _cacheSize == size) {
      return;
    }
    final p = _projectorFor(size);
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
    _projected = proj;
    _viewDepths = depths;
    _cacheYaw = _yaw;
    _cachePitch = _pitch;
    _cacheZoom = _zoom;
    _cacheSize = size;
  }

  void _pickAt(Size size, Offset local) {
    final notifier = widget.hoverPick;
    final grid = widget.surfaceGrid;
    if (notifier == null || grid == null || grid.isEmpty) return;
    _ensureProjection(size);
    notifier.value = pickNearestTissueVertex(
      cursor: local,
      projected: _projected!,
      viewDepths: _viewDepths!,
      columns: grid.columns,
      compartments: grid.compartments,
    );
  }
```

Replace the `build` method's returned widget tree so that: (a) when tissue
chrome is present the surface picking is wired via `MouseRegion` and the two
painters are layered; (b) otherwise behavior is unchanged. Replace the
`CustomPaint(...)` (currently the `GestureDetector`'s child) as follows, and
wrap the `GestureDetector` in a `MouseRegion`:

```dart
        final hasChrome =
            widget.surfaceGrid != null &&
            widget.axisFrame != null &&
            widget.chromeStyle != null;

        final scenePaint = CustomPaint(
          painter: Dive3dScenePainter(
            scene: widget.scene,
            yawDegrees: _yaw,
            pitchDegrees: _pitch,
            zoom: _zoom,
            visibleOverlays: widget.visibleOverlays,
          ),
          foregroundPainter: hasChrome
              ? TissueChromePainter(
                  scene: widget.scene,
                  grid: widget.surfaceGrid!,
                  frame: widget.axisFrame!,
                  style: widget.chromeStyle!,
                  yawDegrees: _yaw,
                  pitchDegrees: _pitch,
                  zoom: _zoom,
                  scrubPosition: widget.scrubPosition,
                  hoverPick: widget.hoverPick ?? ValueNotifier<TissuePick?>(null),
                )
              : _ScrubCursorPainter(
                  scene: widget.scene,
                  yawDegrees: _yaw,
                  pitchDegrees: _pitch,
                  zoom: _zoom,
                  scrubPosition: widget.scrubPosition,
                  style: widget.scrubCursor,
                ),
          child: const SizedBox.expand(),
        );

        final painted = hasChrome
            ? CustomPaint(
                painter: TissueFramePainter(
                  bounds: widget.scene.bounds,
                  frame: widget.axisFrame!,
                  style: widget.chromeStyle!,
                  yawDegrees: _yaw,
                  pitchDegrees: _pitch,
                  zoom: _zoom,
                ),
                child: scenePaint,
              )
            : scenePaint;

        final gestures = GestureDetector(
          onPanUpdate: _onPanUpdate,
          onDoubleTap: _resetCamera,
          onTapUp: (details) {
            _handleTapUp(size, details);
            _pickAt(size, details.localPosition);
          },
          child: painted,
        );

        return Listener(
          onPointerSignal: (signal) {
            if (signal is PointerScrollEvent) {
              _zoomBy(signal.scrollDelta.dy < 0 ? 1.1 : 1 / 1.1);
            }
          },
          child: hasChrome
              ? MouseRegion(
                  onHover: (e) => _pickAt(size, e.localPosition),
                  onExit: (_) => widget.hoverPick?.value = null,
                  child: gestures,
                )
              : gestures,
        );
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport_test.dart`
Expected: PASS (new hover test + all existing viewport tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format .
flutter analyze
git add lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart \
        test/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport_test.dart
git commit -m "feat(dive-3d): wire tissue chrome and hover picking into the viewport"
```

---

### Task 9: Page wiring + tooltip overlay (integration)

**Files:**
- Modify: `lib/features/dive_3d/presentation/pages/dive_3d_page.dart`
- Test: `test/features/dive_3d/presentation/pages/dive_3d_page_test.dart`

**Interfaces:**
- Consumes: `tissueSurfaceProvider`, `tissueRuntimeSecondsProvider`, `AxisFrame`, `TissueChromeStyle`, `TissueHoverTooltip`, `ValueNotifier<TissuePick?>`.

- [ ] **Step 1: Update the existing tissue test + add a hover-tooltip test**

In `test/features/dive_3d/presentation/pages/dive_3d_page_test.dart`:

Replace the `tissue3dSceneProvider('d1').overrideWith(...)` override in the
`'switching to the tissue scene shows the tissue readout'` test with a
`tissueSurfaceProvider` override (import `subsurface_tissue_builder.dart` is
already present; add the `tissue_surface_grid` import is not needed — the record
comes from `buildResult`):

```dart
          tissueSurfaceProvider('d1').overrideWith(
            (ref) async =>
                SubsurfaceTissueBuilder.buildResult(statuses, colorFn: thermalColor),
          ),
```

Add a new test after it:

```dart
  testWidgets('hovering the tissue surface shows the value tooltip', (
    tester,
  ) async {
    final overrides = await getBaseOverrides();
    final statuses = tissueStatuses();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          dive3dSceneDataProvider('d1').overrideWith((ref) async => readoutSceneData()),
          tissueDecoStatusesProvider('d1').overrideWith((ref) async => statuses),
          tissueSurfaceProvider('d1').overrideWith(
            (ref) async =>
                SubsurfaceTissueBuilder.buildResult(statuses, colorFn: thermalColor),
          ),
          tissueRuntimeSecondsProvider('d1').overrideWith((ref) async => 1400),
        ],
        child: const Dive3dPage(diveId: 'd1'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.text('Tissues'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Hover the center of the viewport; a vertex should be within threshold.
    final center = tester.getCenter(find.byType(Dive3dInteractiveViewport));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(center);
    await tester.pump();

    expect(find.byType(TissueHoverTooltip), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 1));
  });
```

Add imports to the test file:

```dart
import 'package:flutter/gestures.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/tissue_hover_tooltip.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/presentation/pages/dive_3d_page_test.dart`
Expected: FAIL — page does not yet build chrome or render a tooltip.

- [ ] **Step 3: Wire the page**

In `dive_3d_page.dart`, add imports:

```dart
import 'package:submersion/features/dive_3d/domain/geometry/axis_frame.dart';
import 'package:submersion/features/dive_3d/domain/tissue/subsurface_tissue_builder.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_grid.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_picker.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/tissue_chrome_painters.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/tissue_hover_tooltip.dart';
```

Add a hover notifier field to `_Dive3dPageState` and dispose it:

```dart
  final ValueNotifier<TissuePick?> _hoverPick = ValueNotifier(null);
```
```dart
  @override
  void dispose() {
    _player.dispose();
    _position.dispose();
    _hoverPick.dispose();
    super.dispose();
  }
```

Build a theme-resolved `TissueChromeStyle`:

```dart
  TissueChromeStyle _chromeStyle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TissueChromeStyle(
      axisX: const Color(0xFFFFB300), // time (amber)
      axisY: const Color(0xFF66BB6A), // saturation % (green)
      axisZ: const Color(0xFF42A5F5), // compartment (blue)
      grid: scheme.outline.withValues(alpha: 0.18),
      wireframe: scheme.onSurface.withValues(alpha: 0.16),
      marker: scheme.onSurface,
      markerOutline: scheme.surface,
    );
  }
```

Rewrite `_buildTissueBody` to read the surface record + grid + runtime and pass
chrome through, plus a tooltip overlay:

```dart
  Widget _buildTissueBody() {
    final surface = ref.watch(tissueSurfaceProvider(widget.diveId)).value;
    final statuses = ref.watch(tissueDecoStatusesProvider(widget.diveId)).value;
    if (surface == null || statuses == null || statuses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final runtime = ref.watch(tissueRuntimeSecondsProvider(widget.diveId)).value;
    final colorFn = colorFnForScheme(ref.watch(tissueColorSchemeProvider));
    final frame = AxisFrame.build(
      surface.scene.bounds,
      referenceY: SubsurfaceTissueBuilder.referenceHeight,
      compartments: surface.grid.compartments,
    );
    return _sceneScaffold(
      scene: surface.scene,
      readout: TissueReadoutPanel(statuses: statuses, position: _position),
      controls: _buildTissueControls(),
      onMarkerTap: null,
      cornerOverlay: TissueLegend(colorFn: colorFn),
      surfaceGrid: surface.grid,
      axisFrame: frame,
      tooltip: ValueListenableBuilder<TissuePick?>(
        valueListenable: _hoverPick,
        builder: (context, pick, _) {
          if (pick == null) return const SizedBox.shrink();
          return _positionedTooltip(
            pick,
            surface.grid,
            runtime,
            colorFn,
          );
        },
      ),
    );
  }

  /// Places the tooltip near the pick, clamped inside the viewport.
  Widget _positionedTooltip(
    TissuePick pick,
    TissueSurfaceGrid grid,
    int? runtimeSeconds,
    TissueColorFn colorFn,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const w = 210.0;
        final left = (pick.screenPos.dx + 14).clamp(0.0, constraints.maxWidth - w);
        final top = (pick.screenPos.dy + 14).clamp(0.0, constraints.maxHeight - 60);
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: w,
              child: TissueHoverTooltip(
                pick: pick,
                grid: grid,
                runtimeSeconds: runtimeSeconds,
                colorFn: colorFn,
              ),
            ),
          ],
        );
      },
    );
  }
```

Extend `_sceneScaffold` to accept and place the tissue chrome + tooltip:

```dart
  Widget _sceneScaffold({
    required Scene3d scene,
    required Widget readout,
    required Widget controls,
    required void Function(SceneMarker)? onMarkerTap,
    Widget? cornerOverlay,
    TissueSurfaceGrid? surfaceGrid,
    AxisFrame? axisFrame,
    Widget? tooltip,
  }) {
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: Dive3dInteractiveViewport(
                  scene: scene,
                  scrubPosition: _position,
                  visibleOverlays: _overlays,
                  onMarkerTap: onMarkerTap,
                  surfaceGrid: surfaceGrid,
                  axisFrame: axisFrame,
                  chromeStyle: axisFrame == null ? null : _chromeStyle(context),
                  hoverPick: axisFrame == null ? null : _hoverPick,
                ),
              ),
              if (tooltip != null) Positioned.fill(child: tooltip),
              if (cornerOverlay != null)
                Positioned(top: 56, left: 8, child: cornerOverlay),
              Positioned(left: 12, right: 12, bottom: 12, child: readout),
              Positioned(top: 8, left: 8, right: 8, child: controls),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: TimeScrubBar(
            position: _position,
            playing: _player.isAnimating,
            onPlayPause: _togglePlay,
            onScrubStart: () {
              if (_player.isAnimating) setState(() => _player.stop());
            },
          ),
        ),
      ],
    );
  }
```

(The dive/computers callers of `_sceneScaffold` omit the new named params, so
they pass null and are unaffected.)

- [ ] **Step 4: Run the tissue page tests**

Run: `flutter test test/features/dive_3d/presentation/pages/dive_3d_page_test.dart`
Expected: PASS (updated tissue-readout test + new hover-tooltip test + the
dive/computers tests unchanged).

- [ ] **Step 5: Run the full dive_3d suite + analyze**

Run: `flutter test test/features/dive_3d/`
Run: `flutter analyze`
Expected: all green; no analyzer issues.

- [ ] **Step 6: Format, commit**

```bash
dart format .
git add lib/features/dive_3d/presentation/pages/dive_3d_page.dart \
        test/features/dive_3d/presentation/pages/dive_3d_page_test.dart
git commit -m "feat(dive-3d): show tissue axes, grid, and hover tooltip on the tissue scene"
```

---

### Task 10: Manual verification on macOS

**Files:** none (verification only).

- [ ] **Step 1: Launch the app and open a dive with a profile**

Run: `flutter run -d macos`
Open a dive that has a depth profile (so `decoStatuses` is non-empty), open the
3D view, and switch to the **Tissues** segment.

- [ ] **Step 2: Verify the three deliverables**

- Axis lines: amber X (time, front-bottom edge), green Y (saturation, vertical),
  blue Z (compartment, side-bottom edge), each with tick marks; the Y 100% tick
  aligns with the red M-value plane.
- Grid: a faint floor/back-wall reference frame occluded correctly by the
  surface, plus a draped wireframe following the surface.
- Tooltip: hovering the surface shows time / compartment / saturation % + state;
  the marker ring tracks the hovered vertex; moving off the surface hides it.
- Rotate (drag), zoom (scroll), double-tap reset: chrome and tooltip stay
  correct; no jank.

- [ ] **Step 3: Confirm no regressions**

Switch to the Dive and Computers scenes; confirm they look and behave exactly as
before (no axes/grid/tooltip, scrub cursor intact).

- [ ] **Step 4: Final full-suite gate**

Run: `flutter test`
Run: `flutter analyze`
Expected: all green.

---

## Self-Review

**Spec coverage:**
- Axis lines + ticks (no numbers) -> Task 3 (geometry) + Task 7 (`_paintAxes`).
- Grid = Both (frame + draped wireframe) -> Task 3 (frameGrid segments) + Task 7 (`TissueFramePainter` background, `_paintWireframe` foreground).
- Hover + tap tooltip -> Task 4 (picker) + Task 6 (widget) + Task 8 (MouseRegion/tap + cache) + Task 9 (overlay).
- `TissueSurfaceGrid` single-pass artifact -> Task 1.
- Providers (surface, grid, runtime) -> Task 2.
- Honest time (progress x runtime, `% of dive` fallback) -> Task 6 `_timeLabel`, Task 2 `tissueRuntimeSecondsProvider`.
- State words tied to 50%-equilibrium -> Task 4 thresholds + Task 5 strings.
- No-canvas-text convention -> ticks only; numbers only in the tooltip widget.
- Zero blast radius -> nullable viewport params; dive/computers untouched (Task 8/9).
- l10n across all locales -> Task 5.
- Theme-aware colors -> Task 9 `_chromeStyle`, painters take colors as inputs.
- Tests (unit + widget) -> every task; manual macOS pass -> Task 10.

**Placeholder scan:** No TBD/TODO; every code step shows complete code. (Non-en
ARB translation text in Task 5 Step 2 is content for a translator, not a code
placeholder — the keys, values, and placeholders are fully specified.)

**Type consistency:** `TissueSurfaceResult` record (`scene`, `grid`) used
identically in Tasks 1/2/7/8/9. `pickNearestTissueVertex` signature matches
between Task 4 and its callers in Task 8. `TissueChromeStyle` field names match
across Tasks 7/8/9. `TissueHoverTooltip` constructor (`pick`, `grid`,
`runtimeSeconds`, `colorFn`) matches Tasks 6 and 9. `AxisFrame.build`
(`referenceY`, `compartments`) matches Tasks 3 and 9.
```