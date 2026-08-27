# 2D Depth Overlay Implementation Plan (Site Scape PR 1)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drape the selected site's bathymetry (depth ramp + contour lines, transparent land) over the 2D maps as a toggleable, appearance-synced overlay.

**Architecture:** A pure builder renders a `BathymetryGrid` to PNG bytes honoring `SeascapeAppearance`; a family provider caches the bytes (identity-stable for `MemoryImage`); flutter_map's `OverlayImageLayer` positions them at the grid's `LatLngBounds`; an app-bar toggle persists `SeascapeAppearance.mapDepthOverlay` through the synced settings lane.

**Tech Stack:** Flutter, flutter_map 8.x (`OverlayImageLayer`, unused so far), Riverpod, `dart:ui` PictureRecorder/PNG encode, latlong2.

**Spec:** `docs/superpowers/specs/2026-08-15-site-scape-unification-design.md` (PR 1 section)

## Global Constraints

- Working tree: a NEW worktree `site-scape-depth-overlay`, branched from `worktree-seascape-contours` (PR #1073's branch, NOT main: this PR stacks on it). Task 1 creates it. Never touch the main checkout; after entering the worktree, prefix every Read/Edit/Write path with its root.
- NEVER use the em-dash character (U+2014) anywhere. No `--` or spaced-hyphen prose punctuation. No emojis. Files max 800 lines. Immutability always.
- New l10n keys go into ALL 11 arb files under `lib/l10n/arb/` (en, ar, de, es, fr, he, hu, it, nl, pt, zh); run `flutter gen-l10n` from the project root and commit the regenerated `app_localizations*.dart`.
- `dart format .` before every commit; commit messages conventional, NO `Co-Authored-By:` trailer.
- Widget tests: bounded pumps on pages hosting maps (never `pumpAndSettle`); pages watching `settingsProvider` use the `MockSettingsNotifier`/`_TestSettingsNotifier` override pattern.
- MemoryImage caches by `Uint8List` REFERENCE identity: the provider must return the same bytes instance per (grid, appearance) or the image cache never hits. Never re-encode per build.
- Depth convention: meters positive DOWN; null = nodata; negative = land. Grid rows run SOUTH to NORTH; image y grows DOWN, so row r paints at image row (rows-1-r).
- `flutter analyze` must be clean including infos (CI-fatal).

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/features/bathymetry/presentation/bathymetry_overlay_image.dart` (new) | Pure async builder: grid + appearance to PNG bytes; `BathymetryOverlayData` (bytes + bounds); `bathymetryGridBounds` |
| `lib/features/bathymetry/presentation/bathymetry_overlay_providers.dart` (new) | `bathymetryOverlayProvider` family caching `BathymetryOverlayData?` per quantized cell |
| `lib/features/bathymetry/presentation/depth_overlay_toggle_button.dart` (new) | App-bar toggle writing `SeascapeAppearance.mapDepthOverlay`, with no-bathymetry feedback |
| `lib/features/dive_3d/domain/spatial/seascape_appearance.dart` | gains `mapDepthOverlay: bool` |
| `lib/features/dive_sites/presentation/widgets/site_map_content.dart` | overlay layer above tiles, below markers |
| `lib/features/dive_sites/presentation/pages/site_map_page.dart:130-144` | toggle in app-bar actions when a site is selected |
| `lib/features/dive_sites/presentation/pages/site_detail_page.dart:536-544, 637-645` | overlay layer in the embedded and fullscreen maps |
| `lib/l10n/arb/app_*.arb` | 2 keys: show/hide depth overlay |

---

### Task 1: Stacked worktree setup

**Files:** none (environment).

**Interfaces:**
- Produces: worktree at `.claude/worktrees/site-scape-depth-overlay` on branch `worktree-site-scape-depth-overlay`, branched from `worktree-seascape-contours`, toolchain initialized.

- [ ] **Step 1: Create the stacked worktree**

From the current worktree (or main checkout), with the base branch up to date:

```bash
git fetch origin
git worktree add ../site-scape-depth-overlay -b worktree-site-scape-depth-overlay worktree-seascape-contours
```

(The relative path lands it beside the current worktree inside `.claude/worktrees/`. If running from the main checkout use `.claude/worktrees/site-scape-depth-overlay` as the path.) Then switch the session into it with the EnterWorktree tool's `path` parameter.

- [ ] **Step 2: Initialize the toolchain (required before ANY test)**

```bash
git submodule update --init --recursive
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

Expected: all succeed; codegen writes outputs.

---

### Task 2: `SeascapeAppearance.mapDepthOverlay`

**Files:**
- Modify: `lib/features/dive_3d/domain/spatial/seascape_appearance.dart`
- Test: `test/features/dive_3d/domain/spatial/seascape_appearance_test.dart` (extend)

**Interfaces:**
- Consumes: the existing `SeascapeAppearance` (fields `rampMaxDepthMeters`, `rampBanded`, `contourMode`, `customLevels`, `wallAngleDeg`; `copyWith` with `clearRampMax`; `encode()`/`decode()`; Equatable `props`).
- Produces: `final bool mapDepthOverlay;` (default `false`), threaded through constructor, `copyWith(bool? mapDepthOverlay)`, `encode`, `decode` (defensive: non-bool falls back to false), and `props`. Tasks 4, 5, 6, 7 read `settingsProvider.select((s) => s.seascapeAppearance.mapDepthOverlay)`; Task 5 writes it via `setSeascapeAppearance` (which already persists per-diver and syncs, v151).

- [ ] **Step 1: Write the failing test**

Append to `seascape_appearance_test.dart`:

```dart
  test('mapDepthOverlay defaults off, round-trips, and decodes defensively', () {
    expect(const SeascapeAppearance().mapDepthOverlay, isFalse);
    const on = SeascapeAppearance(mapDepthOverlay: true);
    expect(SeascapeAppearance.decode(on.encode()).mapDepthOverlay, isTrue);
    expect(
      const SeascapeAppearance().copyWith(mapDepthOverlay: true).mapDepthOverlay,
      isTrue,
    );
    // Defensive decode: wrong type falls back to the default.
    expect(
      SeascapeAppearance.decode('{"mapDepthOverlay":"yes"}').mapDepthOverlay,
      isFalse,
    );
    // Equality includes the new field.
    expect(on, isNot(const SeascapeAppearance()));
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dive_3d/domain/spatial/seascape_appearance_test.dart`
Expected: compile FAIL (`mapDepthOverlay` undefined).

- [ ] **Step 3: Implement**

In `seascape_appearance.dart`, add after `wallAngleDeg`:

```dart
  /// Whether the 2D maps drape the selected site's bathymetry (ramp +
  /// contours) as a translucent overlay. Synced per-diver like the rest.
  final bool mapDepthOverlay;
```

Constructor: `this.mapDepthOverlay = false,`. copyWith: parameter `bool? mapDepthOverlay,` and `mapDepthOverlay: mapDepthOverlay ?? this.mapDepthOverlay,`. encode map: `'mapDepthOverlay': mapDepthOverlay,`. decode: read `final overlayFlag = parsed['mapDepthOverlay'];` and construct with `mapDepthOverlay: overlayFlag is bool ? overlayFlag : defaults.mapDepthOverlay,`. props: append `mapDepthOverlay`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dive_3d/domain/spatial/seascape_appearance_test.dart test/features/settings/seascape_appearance_setting_test.dart`
Expected: PASS (the settings suite proves persistence still round-trips).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_3d/domain/spatial/seascape_appearance.dart test/features/dive_3d/domain/spatial/seascape_appearance_test.dart
git commit -m "feat(bathymetry): mapDepthOverlay appearance flag"
```

---

### Task 3: Overlay image builder + grid bounds

**Files:**
- Create: `lib/features/bathymetry/presentation/bathymetry_overlay_image.dart`
- Test: `test/features/bathymetry/presentation/bathymetry_overlay_image_test.dart`

**Interfaces:**
- Consumes: `BathymetryGrid` (`depthAt(row, col)`, `maxDepthMeters`, `originLat/originLon` = CELL CENTERS, `cellSizeLatDeg/cellSizeLonDeg`, rows south to north), `BathymetryTerrainBuilder.depthColor(t, banded:)`, `resolvedContourLevels(...)` and `marchGrid(...)` from `contour_builder.dart`, `SeascapeAppearance`.
- Produces:
  - `class BathymetryOverlayData { final Uint8List pngBytes; final LatLngBounds bounds; const BathymetryOverlayData({required this.pngBytes, required this.bounds}); }`
  - `LatLngBounds bathymetryGridBounds(BathymetryGrid grid)` (cell-EDGE extents: half a cell beyond the center grid on every side)
  - `Future<BathymetryOverlayData?> buildBathymetryOverlay({required BathymetryGrid grid, required SeascapeAppearance appearance, required double displayUnitInMeters, required String depthSymbol, int pixelsPerCell = 4})` returning null for degenerate grids (fewer than 2 rows or cols).
  Tasks 4, 6, 7 consume all three.

- [ ] **Step 1: Write the failing test**

Create `test/features/bathymetry/presentation/bathymetry_overlay_image_test.dart`:

```dart
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_overlay_image.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';

BathymetryGrid gridOf(List<List<double?>> rowsSouthToNorth) {
  final rows = rowsSouthToNorth.length;
  final cols = rowsSouthToNorth.first.length;
  return BathymetryGrid(
    originLat: 10.0,
    originLon: 20.0,
    cellSizeLatDeg: 0.001,
    cellSizeLonDeg: 0.002,
    rows: rows,
    cols: cols,
    depthsMeters: [for (final r in rowsSouthToNorth) ...r],
    sourceId: 'test',
    resolutionMeters: 100,
    fetchedAt: DateTime.utc(2026, 8, 15),
  );
}

/// Decodes PNG bytes and reads the RGBA pixel at (x, y).
Future<ui.Color> pixelAt(Uint8List png, int x, int y) async {
  final codec = await ui.instantiateImageCodec(png);
  final image = (await codec.getNextFrame()).image;
  final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  final i = (y * image.width + x) * 4;
  final bytes = data.buffer.asUint8List();
  return ui.Color.fromARGB(
    bytes[i + 3],
    bytes[i],
    bytes[i + 1],
    bytes[i + 2],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bounds extend half a cell beyond the center grid', () {
    final grid = gridOf([
      [10.0, 20.0],
      [30.0, 40.0],
    ]);
    final b = bathymetryGridBounds(grid);
    // Origin is the CENTER of the south-west cell.
    expect(b.southWest, const LatLng(10.0 - 0.0005, 20.0 - 0.001));
    expect(b.northEast, const LatLng(10.0 + 0.001 + 0.0005, 20.0 + 0.002 + 0.001));
  });

  test('wet cells carry the ramp color, land and nodata are transparent',
      () async {
    // South row wet (10 m, 40 m), north row land + nodata. maxDepth 40.
    final grid = gridOf([
      [10.0, 40.0],
      [-2.0, null],
    ]);
    final data = await buildBathymetryOverlay(
      grid: grid,
      appearance: const SeascapeAppearance(),
      displayUnitInMeters: 1.0,
      depthSymbol: 'm',
      pixelsPerCell: 4,
    );
    expect(data, isNotNull);
    // Image is 8x8 (2x2 cells at 4 px). Rows flip: grid row 0 (south) is
    // the BOTTOM image row. Sample cell centers away from contour strokes:
    // land cell (grid r1,c0) = image top-left quadrant.
    final land = await pixelAt(data!.pngBytes, 1, 1);
    expect(land.a, 0.0); // fully transparent
    final nodata = await pixelAt(data.pngBytes, 6, 1);
    expect(nodata.a, 0.0);
    // Wet 40 m cell (grid r0,c1) = image bottom-right; ramp t = 1.0.
    final deep = await pixelAt(data.pngBytes, 6, 6);
    expect(deep.a, greaterThan(0.5)); // translucent fill, not opaque
    final expected = BathymetryTerrainBuilder.depthColor(1.0);
    expect((deep.r - expected.r).abs(), lessThan(0.05));
    expect((deep.g - expected.g).abs(), lessThan(0.05));
    expect((deep.b - expected.b).abs(), lessThan(0.05));
  });

  test('contour strokes appear between wet cells', () async {
    // 3x3 sloping grid 5 -> 45 m: auto levels include 25 m crossing the
    // middle. A pixel on the horizontal midline should be the light
    // contour ink, brighter than the ramp around it.
    final grid = gridOf([
      [5.0, 5.0, 5.0],
      [25.0, 25.0, 25.0],
      [45.0, 45.0, 45.0],
    ]);
    final data = await buildBathymetryOverlay(
      grid: grid,
      appearance: const SeascapeAppearance(),
      displayUnitInMeters: 1.0,
      depthSymbol: 'm',
      pixelsPerCell: 8,
    );
    // Image 24x24. The 25 m contour runs along the middle row of cell
    // centers: image y = 24 - (1 + 0.5) * 8 = 12. Sample at x=12.
    final ink = await pixelAt(data!.pngBytes, 12, 12);
    // Contour ink is near-white (0xFFF8FAFC family), far brighter than any
    // ramp color.
    expect(ink.r, greaterThan(0.8));
    expect(ink.g, greaterThan(0.8));
    expect(ink.a, greaterThan(0.7));
  });

  test('degenerate grids return null', () async {
    final grid = gridOf([
      [10.0, 20.0],
    ]);
    expect(
      await buildBathymetryOverlay(
        grid: grid,
        appearance: const SeascapeAppearance(),
        displayUnitInMeters: 1.0,
        depthSymbol: 'm',
      ),
      isNull,
    );
  });
}
```

Add `import 'dart:typed_data';` if the analyzer asks for `Uint8List`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/bathymetry/presentation/bathymetry_overlay_image_test.dart`
Expected: FAIL (file does not exist).

- [ ] **Step 3: Implement the builder**

Create `lib/features/bathymetry/presentation/bathymetry_overlay_image.dart`:

```dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:latlong2/latlong.dart';

import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/contour_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/seascape_appearance.dart';

/// Fill alpha for wet cells: translucent so the basemap reads through.
const double _fillOpacity = 0.72;
const double _contourOpacity = 0.9;
const double _minorStrokeCells = 0.25;
const double _majorStrokeCells = 0.45;
const Color _contourInk = Color(0xFFF8FAFC);

/// The rendered overlay plus where it sits on the map.
class BathymetryOverlayData {
  final Uint8List pngBytes;
  final LatLngBounds bounds;
  const BathymetryOverlayData({required this.pngBytes, required this.bounds});
}

/// The grid's footprint as cell-EDGE extents: origin coordinates are cell
/// CENTERS, so the image reaches half a cell beyond them on every side.
LatLngBounds bathymetryGridBounds(BathymetryGrid grid) {
  final halfLat = grid.cellSizeLatDeg / 2;
  final halfLon = grid.cellSizeLonDeg / 2;
  return LatLngBounds(
    LatLng(grid.originLat - halfLat, grid.originLon - halfLon),
    LatLng(
      grid.originLat + grid.cellSizeLatDeg * (grid.rows - 1) + halfLat,
      grid.originLon + grid.cellSizeLonDeg * (grid.cols - 1) + halfLon,
    ),
  );
}

/// Renders [grid] to a translucent PNG: wet cells tinted by the depth ramp
/// (honoring the ramp range and banding in [appearance]), land and nodata
/// cells FULLY TRANSPARENT so the basemap's real cartography shows
/// through, and contour lines stroked on top (majors heavier, custom
/// colors respected). Returns null for degenerate grids.
Future<BathymetryOverlayData?> buildBathymetryOverlay({
  required BathymetryGrid grid,
  required SeascapeAppearance appearance,
  required double displayUnitInMeters,
  required String depthSymbol,
  int pixelsPerCell = 4,
}) async {
  if (grid.rows < 2 || grid.cols < 2) return null;
  final ppc = pixelsPerCell.toDouble();
  final width = grid.cols * pixelsPerCell;
  final height = grid.rows * pixelsPerCell;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final rampMax = math.max(
    appearance.rampMaxDepthMeters ?? grid.maxDepthMeters,
    1.0,
  );

  // Cell fills. Grid rows run south to north; image y grows down, so grid
  // row r paints at image row (rows - 1 - r).
  final fill = ui.Paint();
  for (var r = 0; r < grid.rows; r++) {
    for (var c = 0; c < grid.cols; c++) {
      final depth = grid.depthAt(r, c);
      if (depth == null || depth <= 0) continue; // transparent window
      final t = (depth / rampMax).clamp(0.0, 1.0);
      fill.color = BathymetryTerrainBuilder.depthColor(
        t,
        banded: appearance.rampBanded,
      ).withValues(alpha: _fillOpacity);
      canvas.drawRect(
        ui.Rect.fromLTWH(c * ppc, (grid.rows - 1 - r) * ppc, ppc, ppc),
        fill,
      );
    }
  }

  // Contours: march in image space. Cell centers sit at (c + 0.5, r + 0.5)
  // cell units; y flips to image coordinates.
  final levels = resolvedContourLevels(
    maxDepthMeters: grid.maxDepthMeters,
    displayUnitInMeters: displayUnitInMeters,
    depthSymbol: depthSymbol,
    appearance: appearance,
  );
  for (final level in levels) {
    final polylines = marchGrid(
      rows: grid.rows,
      cols: grid.cols,
      depthAt: grid.depthAt,
      eastOf: (c) => (c + 0.5) * ppc,
      northOf: (r) => (r + 0.5) * ppc,
      levelMeters: level.depthMeters,
    );
    if (polylines.isEmpty) continue;
    final stroke = ui.Paint()
      ..style = ui.PaintingStyle.stroke
      ..strokeWidth =
          (level.isMajor ? _majorStrokeCells : _minorStrokeCells) * ppc
      ..color = (level.colorArgb != null ? Color(level.colorArgb!) : _contourInk)
          .withValues(alpha: _contourOpacity);
    for (final line in polylines) {
      final pts = line.pointsEastNorth;
      final path = ui.Path();
      for (var i = 0; i < pts.length ~/ 2; i++) {
        final x = pts[i * 2];
        final y = height - pts[i * 2 + 1];
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(path, stroke);
    }
  }

  final image = await recorder.endRecording().toImage(width, height);
  try {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;
    return BathymetryOverlayData(
      pngBytes: byteData.buffer.asUint8List(),
      bounds: bathymetryGridBounds(grid),
    );
  } finally {
    image.dispose();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/bathymetry/presentation/bathymetry_overlay_image_test.dart`
Expected: PASS. If a pixel assertion misses, print the sampled color and re-derive the coordinate by hand (row flip and half-cell offsets are the two likely mistakes) before touching tolerances.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/bathymetry/presentation/bathymetry_overlay_image.dart test/features/bathymetry/presentation/bathymetry_overlay_image_test.dart
git commit -m "feat(bathymetry): overlay image builder for the 2D depth drape"
```

### Task 4: Overlay provider (identity-stable cache)

**Files:**
- Create: `lib/features/bathymetry/presentation/bathymetry_overlay_providers.dart`
- Test: `test/features/bathymetry/presentation/bathymetry_overlay_providers_test.dart`

**Interfaces:**
- Consumes: `buildBathymetryOverlay` / `BathymetryOverlayData` (Task 3), `bathymetryGridProvider` (family keyed by the quantized cell record `({double lat, double lon})`, see `bathymetry_providers.dart`), `settingsProvider` selects, `DepthUnit` from `core/constants/units.dart`.
- Produces: `final bathymetryOverlayProvider = FutureProvider.family<BathymetryOverlayData?, ({double lat, double lon})>(...)`. Because FutureProvider caches the SAME `BathymetryOverlayData` (hence the same `Uint8List`) per key until a dependency changes, `MemoryImage(data.pngBytes)` hits Flutter's ImageCache (reference-identity key). Tasks 6 and 7 consume this provider.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_overlay_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class _TestSettingsNotifier extends StateNotifier<AppSettings>
    implements SettingsNotifier {
  _TestSettingsNotifier() : super(const AppSettings());

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

BathymetryGrid grid() => BathymetryGrid(
  originLat: 10,
  originLon: 20,
  cellSizeLatDeg: 0.001,
  cellSizeLonDeg: 0.001,
  rows: 3,
  cols: 3,
  depthsMeters: const [5, 5, 5, 25, 25, 25, 45, 45, 45],
  sourceId: 'test',
  resolutionMeters: 100,
  fetchedAt: DateTime.utc(2026, 8, 15),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const cell = (lat: 10.0, lon: 20.0);

  ProviderContainer container({BathymetryGrid? g}) {
    final c = ProviderContainer(
      overrides: [
        bathymetryGridProvider.overrideWith((ref, cell) async => g),
        settingsProvider.overrideWith((ref) => _TestSettingsNotifier()),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('renders and caches the identical bytes instance per cell', () async {
    final c = container(g: grid());
    final first = await c.read(bathymetryOverlayProvider(cell).future);
    final second = await c.read(bathymetryOverlayProvider(cell).future);
    expect(first, isNotNull);
    // Reference identity is load-bearing: MemoryImage keys the ImageCache
    // by Uint8List identity, so a fresh allocation per read never caches.
    expect(identical(first!.pngBytes, second!.pngBytes), isTrue);
  });

  test('null grid yields null overlay', () async {
    final c = container(g: null);
    expect(await c.read(bathymetryOverlayProvider(cell).future), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/bathymetry/presentation/bathymetry_overlay_providers_test.dart`
Expected: FAIL (provider file missing).

- [ ] **Step 3: Implement**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_overlay_image.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The rendered depth overlay for a quantized bathymetry cell, or null
/// when no grid resolves there. FutureProvider memoizes the value per key,
/// which keeps the SAME Uint8List instance alive across reads: that
/// reference identity is what lets MemoryImage hit Flutter's ImageCache.
/// Appearance or unit changes invalidate and re-render.
final bathymetryOverlayProvider =
    FutureProvider.family<BathymetryOverlayData?, ({double lat, double lon})>((
      ref,
      cell,
    ) async {
      final grid = await ref.watch(bathymetryGridProvider(cell).future);
      if (grid == null) return null;
      final appearance = ref.watch(
        settingsProvider.select((s) => s.seascapeAppearance),
      );
      final depthUnit = ref.watch(settingsProvider.select((s) => s.depthUnit));
      return buildBathymetryOverlay(
        grid: grid,
        appearance: appearance,
        displayUnitInMeters: depthUnit == DepthUnit.feet ? 0.3048 : 1.0,
        depthSymbol: depthUnit.symbol,
      );
    });
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/bathymetry/presentation/bathymetry_overlay_providers_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/bathymetry/presentation/bathymetry_overlay_providers.dart test/features/bathymetry/presentation/bathymetry_overlay_providers_test.dart
git commit -m "feat(bathymetry): cached depth-overlay provider"
```

---

### Task 5: Toggle button + l10n

**Files:**
- Create: `lib/features/bathymetry/presentation/depth_overlay_toggle_button.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Test: `test/features/bathymetry/presentation/depth_overlay_toggle_button_test.dart`

**Interfaces:**
- Consumes: `settingsProvider` + `SettingsNotifier.setSeascapeAppearance`, `bathymetryGridProvider`, `GeoPoint` (dive_site entity), `BathymetryRepository.quantize`.
- Produces: `DepthOverlayToggleButton({required GeoPoint? siteLocation})`: an app-bar `IconButton` mirroring `HeatMapToggleButton` (`heat_map_controls.dart:7` is the template). Toggling ON when the site's grid is known-null shows a SnackBar with the existing `dive3d_seascape_noData` string and still records the setting (the layer simply stays absent). Task 6 places it.
- l10n keys (all 11 locales; translations below): `maps_depthOverlay_show` "Show depth overlay", `maps_depthOverlay_hide` "Hide depth overlay".

Translations (show / hide): de "Tiefen-Overlay anzeigen" / "Tiefen-Overlay ausblenden"; es "Mostrar capa de profundidad" / "Ocultar capa de profundidad"; fr "Afficher la surcouche de profondeur" / "Masquer la surcouche de profondeur"; it "Mostra sovrapposizione di profondità" / "Nascondi sovrapposizione di profondità"; nl "Diepte-overlay tonen" / "Diepte-overlay verbergen"; pt "Mostrar camada de profundidade" / "Ocultar camada de profundidade"; hu "Mélységréteg megjelenítése" / "Mélységréteg elrejtése"; ar "إظهار طبقة العمق" / "إخفاء طبقة العمق"; he "הצגת שכבת עומק" / "הסתרת שכבת עומק"; zh "显示深度叠加层" / "隐藏深度叠加层".

- [ ] **Step 1: Add the l10n keys and regenerate**

Insert both keys (plus their `"@key": {}` lines) next to the `maps_heatMap_*` keys in each arb file, then run `flutter gen-l10n` from the project root.

- [ ] **Step 2: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/presentation/depth_overlay_toggle_button.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/mock_providers.dart';

void main() {
  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = ProviderContainer(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        bathymetryGridProvider.overrideWith((ref, cell) async => null),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            appBar: null,
            body: DepthOverlayToggleButton(
              siteLocation: GeoPoint(10, 20),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    return container;
  }

  testWidgets('toggles the synced appearance flag', (tester) async {
    final container = await pump(tester);
    expect(
      container.read(settingsProvider).seascapeAppearance.mapDepthOverlay,
      isFalse,
    );
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(
      container.read(settingsProvider).seascapeAppearance.mapDepthOverlay,
      isTrue,
    );
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(
      container.read(settingsProvider).seascapeAppearance.mapDepthOverlay,
      isFalse,
    );
  });

  testWidgets('enabling with a known-null grid shows the no-data notice', (
    tester,
  ) async {
    await pump(tester);
    await tester.pump(); // let the null grid future resolve
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(
      find.text('No bathymetry available for this location'),
      findsOneWidget,
    );
  });
}
```

- [ ] **Step 3: Run to verify failure, then implement**

Run the test (FAIL: file missing). Then create `depth_overlay_toggle_button.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// App-bar toggle for the 2D depth overlay. The flag lives on the synced
/// SeascapeAppearance, so the choice follows the diver across devices.
/// Enabling while the selected site's grid is known to be absent shows the
/// standard no-bathymetry notice (the layer simply stays away).
class DepthOverlayToggleButton extends ConsumerWidget {
  final GeoPoint? siteLocation;

  const DepthOverlayToggleButton({super.key, required this.siteLocation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(
      settingsProvider.select((s) => s.seascapeAppearance),
    );
    final on = appearance.mapDepthOverlay;
    final colorScheme = Theme.of(context).colorScheme;
    final location = siteLocation;
    final gridAsync = location == null
        ? null
        : ref.watch(
            bathymetryGridProvider(BathymetryRepository.quantize(location)),
          );

    return Semantics(
      toggled: on,
      child: IconButton(
        icon: Icon(Icons.water, color: on ? colorScheme.primary : null),
        tooltip: on
            ? context.l10n.maps_depthOverlay_hide
            : context.l10n.maps_depthOverlay_show,
        onPressed: () {
          final turningOn = !on;
          ref
              .read(settingsProvider.notifier)
              .setSeascapeAppearance(
                appearance.copyWith(mapDepthOverlay: turningOn),
              );
          final gridKnownAbsent =
              gridAsync != null && gridAsync.hasValue && gridAsync.value == null;
          if (turningOn && gridKnownAbsent) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.dive3d_seascape_noData)),
            );
          }
        },
      ),
    );
  }
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `flutter test test/features/bathymetry/presentation/depth_overlay_toggle_button_test.dart`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/bathymetry/presentation/depth_overlay_toggle_button.dart test/features/bathymetry/presentation/depth_overlay_toggle_button_test.dart lib/l10n/arb/
git commit -m "feat(bathymetry): depth overlay toggle button"
```

---

### Task 6: Sites map integration

**Files:**
- Modify: `lib/features/dive_sites/presentation/widgets/site_map_content.dart` (layer after the `TileLayer` at `:305-312`)
- Modify: `lib/features/dive_sites/presentation/pages/site_map_page.dart:130-144` (actions)
- Test: locate with `grep -rln "SiteMapContent\|site_map" test/features/dive_sites/` and extend, or create `test/features/dive_sites/presentation/widgets/site_map_depth_overlay_test.dart`

**Interfaces:**
- Consumes: `bathymetryOverlayProvider`, `bathymetryGridBounds` (via `BathymetryOverlayData.bounds`), `DepthOverlayToggleButton`, `BathymetryRepository.quantize`, the widget's existing `selectedSite` lookup (`site_map_content.dart:255-262`).
- Produces: the overlay rendered above tiles and below the built-in/user markers when the flag is on and a selected site's grid resolves.

- [ ] **Step 1: Add the layer**

In `site_map_content.dart`, immediately after the `TileLayer` entry in the `FlutterMap` children (`:312`), insert (imports: `bathymetry_overlay_providers.dart`, `bathymetry_repository.dart`, `settings_providers.dart` if absent):

```dart
              // Depth overlay: the selected site's bathymetry as a
              // translucent ramp + contours, above tiles, below markers.
              Consumer(
                builder: (context, ref, _) {
                  final on = ref.watch(
                    settingsProvider.select(
                      (s) => s.seascapeAppearance.mapDepthOverlay,
                    ),
                  );
                  final location = selectedSite?.location;
                  if (!on || location == null) return const SizedBox.shrink();
                  final overlayAsync = ref.watch(
                    bathymetryOverlayProvider(
                      BathymetryRepository.quantize(location),
                    ),
                  );
                  final overlay = overlayAsync.valueOrNull;
                  if (overlay == null) return const SizedBox.shrink();
                  return OverlayImageLayer(
                    overlayImages: [
                      OverlayImage(
                        bounds: overlay.bounds,
                        imageProvider: MemoryImage(overlay.pngBytes),
                      ),
                    ],
                  );
                },
              ),
```

`selectedSite` must be visible at that point: it is computed in `_buildMap`'s caller scope (`:255`); pass it into `_buildMap` as a parameter if it is not already in scope there.

- [ ] **Step 2: Add the toggle to the app bar**

In `site_map_page.dart` actions (`:130-144`), after `const HeatMapToggleButton(),`:

```dart
        if (selectedSite != null)
          DepthOverlayToggleButton(siteLocation: selectedSite.location),
```

(`selectedSite` is already computed at `:122`.)

- [ ] **Step 3: Write and run the widget test**

Assert three states by pumping the sites-map content with overrides (settings notifier mock seeded with `mapDepthOverlay: true`, `bathymetryGridProvider` overridden to the 3x3 sloping grid from Task 4's test, a selected site at the grid center):

```dart
    expect(find.byType(OverlayImageLayer), findsOneWidget);
```

and with the flag off, or no selection, `findsNothing`. Reuse the existing sites-map test harness if one exists (locate it first); otherwise pump the smallest widget that hosts `_buildMap`'s `FlutterMap` with the required constructor parameters, using bounded pumps only. `MockSettingsNotifier` accepts an initial `AppSettings`, so seed the flag via `AppSettings(seascapeAppearance: SeascapeAppearance(mapDepthOverlay: true))`.

Run: the new test plus `flutter test test/features/dive_sites/`
Expected: PASS.

- [ ] **Step 4: Format and commit**

```bash
dart format .
git add lib/features/dive_sites/ test/features/dive_sites/
git commit -m "feat(sites-map): selected-site depth overlay layer and toggle"
```

---

### Task 7: Site detail maps integration

**Files:**
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart` (embedded map children `:536-544`; fullscreen map children `:637-645`)
- Test: extend the existing site detail page test (locate with `grep -rln "SiteDetailPage" test/`)

**Interfaces:**
- Consumes: same as Task 6; the site's own `site.location` replaces the selected-site lookup.
- Produces: the same overlay on both site-detail maps, driven by the same synced flag (no extra toggle on the 200px card; the app-bar/actions surface stays as-is this PR).

- [ ] **Step 1: Add the layer to both maps**

In BOTH `FlutterMap` children lists (embedded at `:536`, fullscreen at `:637`), insert after the `TileLayer` the same `Consumer` block as Task 6 with `final location = site.location;`. Extract it into a small private helper in the same file to avoid duplicating the block:

```dart
  /// Depth overlay for [site], shown when the synced appearance flag is on
  /// and bathymetry resolves. Above tiles, below the site marker.
  Widget _depthOverlayLayer(DiveSite site) {
    return Consumer(
      builder: (context, ref, _) {
        final on = ref.watch(
          settingsProvider.select(
            (s) => s.seascapeAppearance.mapDepthOverlay,
          ),
        );
        final location = site.location;
        if (!on || location == null) return const SizedBox.shrink();
        final overlayAsync = ref.watch(
          bathymetryOverlayProvider(BathymetryRepository.quantize(location)),
        );
        final overlay = overlayAsync.valueOrNull;
        if (overlay == null) return const SizedBox.shrink();
        return OverlayImageLayer(
          overlayImages: [
            OverlayImage(
              bounds: overlay.bounds,
              imageProvider: MemoryImage(overlay.pngBytes),
            ),
          ],
        );
      },
    );
  }
```

- [ ] **Step 2: Write and run the test**

Extend the site detail page test: pump with the settings mock seeded `mapDepthOverlay: true` plus the grid override; assert `find.byType(OverlayImageLayer)` finds one on the embedded map, and `findsNothing` when the flag is off. Bounded pumps (the page hosts a map). Run the page's suite.
Expected: PASS.

- [ ] **Step 3: Format and commit**

```bash
dart format .
git add lib/features/dive_sites/presentation/pages/site_detail_page.dart test/
git commit -m "feat(sites): depth overlay on the site detail maps"
```

---

### Task 8: Full verification + stacked PR

- [ ] **Step 1: Verify**

```bash
dart format .
flutter analyze
flutter test
flutter gen-l10n
git status --short
```

Expected: no format changes on the second run, zero analyze issues, full suite green, no l10n drift.

- [ ] **Step 2: Push and open the stacked PR**

```bash
git push -u origin worktree-site-scape-depth-overlay
gh pr create --repo submersion-app/submersion --base worktree-seascape-contours --head worktree-site-scape-depth-overlay --title "feat(bathymetry): 2D depth overlay on the site maps" --body-file <body file>
```

PR body: summarize per the repo's conventions (no attribution line, no session URL). Base is `worktree-seascape-contours` while #1073 is open; retarget to `main` after it merges (GitHub does this automatically on base-branch merge).

## Execution notes

- Tasks 2 through 5 are sequential (each consumes the previous task's interface); 6 and 7 both depend on 5 and are independent of each other.
- The pre-push hook may resolve against the main checkout; verify locally and push from the worktree after Task 8's verification.
- Never commit `database.g.dart` (gitignored); `app_localizations*.dart` ARE committed.

