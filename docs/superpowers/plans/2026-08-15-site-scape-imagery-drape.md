# 3D Imagery Drape Implementation Plan (Site Scape PR 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Drape map/satellite imagery onto the 3D seascape terrain with a Depth / Imagery / Blend surface mode, textured through drawVertices while keeping the draped-merge occlusion intact.

**Architecture:** A tile service stitches keyless map tiles into one mosaic `ui.Image` plus a SENDABLE mercator frame; geometry (which runs in compute() isolates where `ui.Image` cannot travel) bakes normalized UVs from the frame only, while the image reaches the painter through a UI-side provider. The painter textures the merged terrain soup with an ImageShader, giving UV-less draped meshes (contours, walls) a reserved white texel so modulation leaves their colors intact.

**Tech Stack:** Flutter drawVertices + ImageShader, dart:ui image codecs, http (injectable client), Riverpod, the existing keyless tile endpoints (`MapTileConfig`).

**Spec:** `docs/superpowers/specs/2026-08-15-site-scape-unification-design.md` (PR 2 section)

## Global Constraints

- Working tree: a NEW worktree `site-scape-imagery`, branched from `worktree-site-scape-depth-overlay` (PR #1076's branch; this PR stacks third in the chain and its base auto-retargets as the stack merges). Task 1 creates it; never touch other checkouts; prefix every file path with the new worktree root after entering it.
- NEVER use the em-dash character (U+2014) anywhere; no `--` or spaced-hyphen prose punctuation; no emojis; files max 800 lines; immutability always.
- New l10n keys go into ALL 11 arb files under `lib/l10n/arb/` (en, ar, de, es, fr, he, hu, it, nl, pt, zh); `flutter gen-l10n` runs from the project root; regenerated `app_localizations*.dart` are committed.
- `dart format .` before every commit; conventional commit messages; NO `Co-Authored-By:` trailer.
- `ui.Image` is NOT isolate-sendable: anything consumed by the geometry services (which run under `compute()` above 4000 cells) must be plain data. The `TerrainImageryFrame` record exists for exactly this reason; never pass the image itself into a geometry input.
- The draped merge group MUST remain one drawVertices call (one Paint, one shader): that is what preserves the contours/walls occlusion fix. The white-texel mechanism exists to keep it so.
- Riverpod: import providers via `package:submersion/core/providers/provider.dart` (the raw flutter_riverpod import lacks `valueOrNull` and `StateNotifier` under Riverpod 3).
- Tile fetches use the injectable client pattern (`weatherHttpClientProvider` at `lib/features/weather/presentation/providers/weather_providers.dart:11` is the template); tests use `MockClient`, never the network.
- Widget tests: bounded pumps on map/3D pages; engine-async work (image decode/encode) needs a `tester.runAsync` delay window before asserting.
- `flutter analyze` clean including infos.

## File Structure

| File | Responsibility |
| --- | --- |
| `lib/core/utils/slippy_tiles.dart` (new) | Pure mercator + slippy math: `mercatorX/Y`, `slippyTileOf`, `imageryZoomFor` |
| `lib/features/bathymetry/data/terrain_imagery_service.dart` (new) | Fetch + stitch tiles into `TerrainImagery { ui.Image image; TerrainImageryFrame frame; }` |
| `lib/features/bathymetry/presentation/terrain_imagery_providers.dart` (new) | `terrainImageryHttpClientProvider`, `terrainImageryProvider` family keyed by (cell, style) |
| `lib/features/dive_3d/domain/spatial/seascape_appearance.dart` | gains `SeascapeSurfaceMode surfaceMode` |
| `lib/features/bathymetry/presentation/bathymetry_overlay_providers.dart` | normalizes `surfaceMode` too (2D overlay ignores it) |
| `lib/features/dive_3d/domain/entities/mesh_data.dart` | gains `Float32List? textureCoordinates` |
| `lib/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart` | UVs from the frame; white colors in imagery mode |
| both geometry services + providers | thread `TerrainImageryFrame?` and surface mode |
| `lib/features/dive_3d/presentation/renderer/preview_painter.dart` | textured merged-soup path |
| `lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart` | `terrainImagery` / `imageryWhiteTexel` passthrough |
| `lib/features/dive_3d/presentation/widgets/terrain_appearance_sheet.dart` | surface-mode segmented control |
| both seascape pages | imagery wiring, legend gating, attribution chip |
| `lib/features/dive_log/presentation/pages/dive_list_page.dart:50` | `_tileUrl` refactored onto the shared slippy helper |

---

### Task 1: Stacked worktree setup

**Files:** none (environment).

**Interfaces:**
- Produces: worktree at `.claude/worktrees/site-scape-imagery` on branch `worktree-site-scape-imagery`, branched from `worktree-site-scape-depth-overlay`, toolchain initialized.

- [ ] **Step 1: Create and enter the stacked worktree**

```bash
git fetch origin
git worktree add ../site-scape-imagery -b worktree-site-scape-imagery worktree-site-scape-depth-overlay
```

Then switch the session into it with the EnterWorktree tool's `path` parameter.

- [ ] **Step 2: Initialize the toolchain (required before ANY test)**

```bash
git submodule update --init --recursive
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

---

### Task 2: `SeascapeSurfaceMode` + 2D-provider normalization

**Files:**
- Modify: `lib/features/dive_3d/domain/spatial/seascape_appearance.dart`
- Modify: `lib/features/bathymetry/presentation/bathymetry_overlay_providers.dart` (the normalization `copyWith`)
- Test: `test/features/dive_3d/domain/spatial/seascape_appearance_test.dart`, `test/features/bathymetry/presentation/bathymetry_overlay_providers_test.dart` (extend both)

**Interfaces:**
- Consumes: existing `SeascapeAppearance` (constructor/copyWith/encode/decode/props; `mapDepthOverlay` landed in PR 1).
- Produces: `enum SeascapeSurfaceMode { depth, imagery, blend }`; `SeascapeAppearance.surfaceMode` (default `SeascapeSurfaceMode.depth`) threaded through constructor, `copyWith(SeascapeSurfaceMode? surfaceMode)`, `encode` (as `surfaceMode.name`), `decode` (unknown/wrong values fall back to depth), `props`. The 2D overlay provider's normalization gains `surfaceMode: SeascapeSurfaceMode.depth`. Tasks 5, 7, 8 consume the enum and field.

- [ ] **Step 1: Write the failing tests**

Append to `seascape_appearance_test.dart`:

```dart
  test('surfaceMode defaults to depth, round-trips, decodes defensively', () {
    expect(const SeascapeAppearance().surfaceMode, SeascapeSurfaceMode.depth);
    const blend = SeascapeAppearance(surfaceMode: SeascapeSurfaceMode.blend);
    expect(
      SeascapeAppearance.decode(blend.encode()).surfaceMode,
      SeascapeSurfaceMode.blend,
    );
    expect(
      SeascapeAppearance.decode('{"surfaceMode":"hologram"}').surfaceMode,
      SeascapeSurfaceMode.depth,
    );
    expect(blend, isNot(const SeascapeAppearance()));
  });
```

Append to `bathymetry_overlay_providers_test.dart` (inside `main`, using its existing `container`/`grid`/`cell` helpers):

```dart
  test('surface mode changes do not re-render the 2D overlay', () async {
    final c = container(g: grid());
    final before = await c.read(bathymetryOverlayProvider(cell).future);
    await c
        .read(settingsProvider.notifier)
        .setSeascapeAppearance(
          const SeascapeAppearance(surfaceMode: SeascapeSurfaceMode.imagery),
        );
    final after = await c.read(bathymetryOverlayProvider(cell).future);
    expect(identical(before!.pngBytes, after!.pngBytes), isTrue);
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_3d/domain/spatial/seascape_appearance_test.dart test/features/bathymetry/presentation/bathymetry_overlay_providers_test.dart`
Expected: compile FAIL (`SeascapeSurfaceMode` undefined).

- [ ] **Step 3: Implement**

In `seascape_appearance.dart`, above `SeascapeAppearance`:

```dart
/// What the 3D terrain surface shows: the depth ramp, draped map imagery,
/// or imagery tinted by the ramp.
enum SeascapeSurfaceMode { depth, imagery, blend }
```

Field after `mapDepthOverlay`:

```dart
  /// The 3D terrain surface: depth ramp, map imagery, or a blend.
  final SeascapeSurfaceMode surfaceMode;
```

Constructor: `this.surfaceMode = SeascapeSurfaceMode.depth,`. copyWith: `SeascapeSurfaceMode? surfaceMode,` and `surfaceMode: surfaceMode ?? this.surfaceMode,`. encode: `'surfaceMode': surfaceMode.name,`. decode: read `final surface = parsed['surfaceMode'];` and construct with:

```dart
      surfaceMode: SeascapeSurfaceMode.values.asNameMap()[surface] ??
          defaults.surfaceMode,
```

props: append `surfaceMode`.

In `bathymetry_overlay_providers.dart`, extend the normalization:

```dart
          (s) => s.seascapeAppearance.copyWith(
            mapDepthOverlay: false,
            wallAngleDeg: 0,
            surfaceMode: SeascapeSurfaceMode.depth,
          ),
```

(add the `seascape_appearance.dart` import if the enum is not already visible).

- [ ] **Step 4: Run to verify pass**

Run the same two test files plus `test/features/settings/seascape_appearance_setting_test.dart`.
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_3d/domain/spatial/seascape_appearance.dart lib/features/bathymetry/presentation/bathymetry_overlay_providers.dart test/features/dive_3d/domain/spatial/seascape_appearance_test.dart test/features/bathymetry/presentation/bathymetry_overlay_providers_test.dart
git commit -m "feat(seascape): surfaceMode appearance field"
```

---

### Task 3: Shared slippy/mercator math

**Files:**
- Create: `lib/core/utils/slippy_tiles.dart`
- Modify: `lib/features/dive_log/presentation/pages/dive_list_page.dart:45-60` (`_tileUrl` refactors onto the helper)
- Test: `test/core/utils/slippy_tiles_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces (Task 4 and 5 consume all four):
  - `double mercatorX(double lonDeg)` (normalized world x, 0..1)
  - `double mercatorY(double latDeg)` (normalized world y, 0 at the north mercator edge)
  - `({int x, int y}) slippyTileOf(double lat, double lon, int zoom)`
  - `int imageryZoomFor({required double lonSpanDeg, required int maxZoom, int targetTiles = 4, int minZoom = 10})`

- [ ] **Step 1: Write the failing test**

Create `test/core/utils/slippy_tiles_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/slippy_tiles.dart';

void main() {
  test('mercator normalization anchors', () {
    expect(mercatorX(-180), 0.0);
    expect(mercatorX(0), 0.5);
    expect(mercatorX(180), 1.0);
    expect(mercatorY(0), closeTo(0.5, 1e-12));
    // The mercator world edge (~85.0511 N) maps to y = 0.
    expect(mercatorY(85.05112878), closeTo(0.0, 1e-9));
  });

  test('slippyTileOf matches the standard formula', () {
    // At z=1 the world is 2x2; (0,0) sits in the SE quadrant tile (1,1).
    expect(slippyTileOf(0, 0, 1), (x: 1, y: 1));
    // Bonaire (12.15 N, -68.3 E) at z=14: x = floor((111.7/360)*16384)
    // = floor(0.310278 * 16384) = 5083; y from mercatorY(12.15) = 0.465995
    // -> floor(0.465995 * 16384) = 7634.
    expect(slippyTileOf(12.15, -68.3, 14), (x: 5083, y: 7634));
  });

  test('imageryZoomFor targets a handful of tiles and clamps', () {
    // 8 km box near the equator is ~0.0719 degrees of longitude:
    // z = round(log2(4 * 360 / 0.0719)) = round(14.29) = 14.
    expect(imageryZoomFor(lonSpanDeg: 0.0719, maxZoom: 18), 14);
    // A huge span clamps to the floor; a tiny one to the style's ceiling.
    expect(imageryZoomFor(lonSpanDeg: 300, maxZoom: 18), 10);
    expect(imageryZoomFor(lonSpanDeg: 0.00001, maxZoom: 18), 18);
  });
}
```

Before trusting the Bonaire vector, recompute by hand with the exact
formulas below; fix the TEST if the arithmetic was wrong, the CODE if the
formula deviates.

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/utils/slippy_tiles_test.dart`
Expected: FAIL (file missing).

- [ ] **Step 3: Implement**

Create `lib/core/utils/slippy_tiles.dart`:

```dart
import 'dart:math' as math;

/// Normalized Web Mercator world x for [lonDeg]: 0 at -180, 1 at +180.
double mercatorX(double lonDeg) => (lonDeg + 180.0) / 360.0;

/// Normalized Web Mercator world y for [latDeg]: 0 at the projection's
/// north edge (~85.05 N), 1 at its south edge.
double mercatorY(double latDeg) {
  final latRad = latDeg * math.pi / 180.0;
  return (1.0 -
          math.log(math.tan(latRad) + 1.0 / math.cos(latRad)) / math.pi) /
      2.0;
}

/// The slippy-map tile containing (lat, lon) at [zoom].
({int x, int y}) slippyTileOf(double lat, double lon, int zoom) {
  final n = 1 << zoom;
  return (
    x: (mercatorX(lon) * n).floor(),
    y: (mercatorY(lat) * n).floor(),
  );
}

/// The zoom where a box of [lonSpanDeg] spans about [targetTiles] tiles,
/// clamped to [minZoom]..[maxZoom]. Keeps terrain-drape mosaics at a
/// handful of fetches regardless of latitude or box size.
int imageryZoomFor({
  required double lonSpanDeg,
  required int maxZoom,
  int targetTiles = 4,
  int minZoom = 10,
}) {
  if (lonSpanDeg <= 0) return minZoom;
  final z = (math.log(targetTiles * 360.0 / lonSpanDeg) / math.ln2).round();
  return z.clamp(minZoom, maxZoom);
}
```

In `dive_list_page.dart`, `_tileUrl` (`:50`) becomes:

```dart
String _tileUrl(double lat, double lng, int zoom, MapStyle style) {
  final tile = slippyTileOf(lat, lng, zoom);
  return MapTileConfig.tileUrl(style, zoom, tile.x, tile.y);
}
```

(with `import 'package:submersion/core/utils/slippy_tiles.dart';` and the
now-unused `dart:math` import removed IF nothing else in the file uses it;
check before deleting).

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/core/utils/slippy_tiles_test.dart test/features/dive_log/presentation/pages/dive_list_tile_slots_test.dart`
Expected: PASS (the dive-list suite guards the refactor; if that file does not exercise `_tileUrl`, also run `flutter analyze` here to catch signature drift).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/core/utils/slippy_tiles.dart lib/features/dive_log/presentation/pages/dive_list_page.dart test/core/utils/slippy_tiles_test.dart
git commit -m "feat(core): shared slippy tile and mercator math"
```

### Task 4: Terrain imagery frame, service, and provider

**Files:**
- Create: `lib/features/bathymetry/domain/terrain_imagery_frame.dart`
- Create: `lib/features/bathymetry/data/terrain_imagery_service.dart`
- Create: `lib/features/bathymetry/presentation/terrain_imagery_providers.dart`
- Test: `test/features/bathymetry/data/terrain_imagery_service_test.dart`

**Interfaces:**
- Consumes: `slippyTileOf`, `mercatorX/Y`, `imageryZoomFor` (Task 3), `MapTileConfig.tileUrl/maxZoom`, `BathymetryGrid`, `http.Client`.
- Produces (Tasks 5, 6, 8 consume these exact names):
  - `class TerrainImageryFrame extends Equatable` (domain, SENDABLE across isolates): `final double u0MercX, u1MercX, v0MercY, v1MercY;` (normalized world-mercator coordinates that map to texture u/v 0 and 1; v1 sits BELOW the mosaic's true south edge because of the white strip) and `final double whiteU, whiteV;` (normalized UV of the reserved white texel). Const constructor, all six in `props`.
  - `class TerrainImagery { final ui.Image image; final TerrainImageryFrame frame; }`
  - `class TerrainImageryService { TerrainImageryService(this._client); Future<TerrainImagery?> fetch({required BathymetryGrid grid, required MapStyle style}) }` returning null on ANY tile failure, decode failure, degenerate grid, or a range wider than 16 tiles.
  - `final terrainImageryHttpClientProvider = Provider<http.Client>(...)` and `final terrainImageryProvider = FutureProvider.family<TerrainImagery?, ({double lat, double lon, MapStyle style})>(...)` where lat/lon is the quantized bathymetry cell and the provider watches `bathymetryGridProvider((lat: cell.lat, lon: cell.lon))`.

**Mosaic geometry (the heart of the task):**
- Grid corner extents match `bathymetryGridBounds` (half a cell beyond the origin-centered grid): west = `originLon - cellSizeLonDeg/2`, east = `originLon + cellSizeLonDeg*(cols-1) + cellSizeLonDeg/2`, and the analogous north/south for latitude.
- `z = imageryZoomFor(lonSpanDeg: east - west, maxZoom: MapTileConfig.maxZoom(style))`.
- Tile range: `xMin/xMax` from `slippyTileOf` at west/east, `yMin` from the NORTH latitude, `yMax` from the SOUTH (mercator y grows southward).
- Mosaic: `w = (xMax-xMin+1)*256`, `hTiles = (yMax-yMin+1)*256`, `hTotal = hTiles + 4`; each tile drawn at `((x-xMin)*256, (y-yMin)*256)`; a WHITE rect fills `(0, hTiles, w, 4)`.
- Frame: `u0MercX = xMin/2^z`, `u1MercX = (xMax+1)/2^z`, `v0MercY = yMin/2^z`, `v1MercY = yMin/2^z + (hTotal/256)/2^z` (the +4px strip stretches v=1 past the south tile edge, which is exactly what keeps a plain linear UV mapping correct), `whiteU = 0.5`, `whiteV = (hTiles + 2)/hTotal`.
- Requests carry a `User-Agent: app.submersion` header (OSM tile policy).

- [ ] **Step 1: Write the failing test**

Create `test/features/bathymetry/data/terrain_imagery_service_test.dart`:

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/features/bathymetry/data/terrain_imagery_service.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';

/// One reusable 256x256 PNG tile.
Future<Uint8List> tilePng() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 256, 256),
    ui.Paint()..color = const ui.Color(0xFF336699),
  );
  final image = await recorder.endRecording().toImage(256, 256);
  final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
  image.dispose();
  return data.buffer.asUint8List();
}

/// Grid whose cell-edge extents are exactly lon 0.1..0.5, lat -0.1..0.1:
/// lonSpan 0.4 -> z = round(log2(4*360/0.4)) = 12; tiles x 2049..2053,
/// y 2046..2049 (5 x 4 tiles).
BathymetryGrid grid() => BathymetryGrid(
  originLat: -0.05,
  originLon: 0.2,
  cellSizeLatDeg: 0.1,
  cellSizeLonDeg: 0.2,
  rows: 2,
  cols: 2,
  depthsMeters: const [10, 20, 30, 40],
  sourceId: 'test',
  resolutionMeters: 100,
  fetchedAt: DateTime.utc(2026, 8, 15),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('stitches the tile range with the white strip and honest frame', () async {
    final png = await tilePng();
    final requested = <String>[];
    final client = MockClient((request) async {
      requested.add(request.url.toString());
      expect(request.headers['User-Agent'], 'app.submersion');
      return http.Response.bytes(png, 200);
    });

    final result = await TerrainImageryService(
      client,
    ).fetch(grid: grid(), style: MapStyle.esriSatellite);

    expect(result, isNotNull);
    expect(requested, hasLength(20)); // 5 x 4 tiles at z12
    expect(result!.image.width, 5 * 256);
    expect(result.image.height, 4 * 256 + 4);
    final f = result.frame;
    expect(f.u0MercX, closeTo(2049 / 4096, 1e-12));
    expect(f.u1MercX, closeTo(2054 / 4096, 1e-12));
    expect(f.v0MercY, closeTo(2046 / 4096, 1e-12));
    // The 4px strip stretches v=1: (2046 + 1028/256) / 4096.
    expect(f.v1MercY, closeTo((2046 + 1028 / 256) / 4096, 1e-12));
    expect(f.whiteV, closeTo(1026 / 1028, 1e-12));
    // The reserved texel really is opaque white.
    final raw = (await result.image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    ))!;
    final bytes = raw.buffer.asUint8List();
    final i = ((4 * 256 + 2) * result.image.width + result.image.width ~/ 2) * 4;
    expect(bytes.sublist(i, i + 4), [255, 255, 255, 255]);
  });

  test('any tile failure yields null', () async {
    final client = MockClient((request) async => http.Response('nope', 404));
    expect(
      await TerrainImageryService(
        client,
      ).fetch(grid: grid(), style: MapStyle.openStreetMap),
      isNull,
    );
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/bathymetry/data/terrain_imagery_service_test.dart`
Expected: FAIL (files missing).

- [ ] **Step 3: Implement**

`lib/features/bathymetry/domain/terrain_imagery_frame.dart`:

```dart
import 'package:equatable/equatable.dart';

/// The mercator-space mapping of a stitched terrain-imagery mosaic. Plain
/// data ON PURPOSE: geometry builds UVs inside compute() isolates, where
/// the ui.Image itself cannot travel; this frame is everything the pure
/// math needs. u/v 0..1 map linearly to these world-mercator coordinates;
/// [v1MercY] deliberately sits below the mosaic's true south tile edge
/// because a 4px white strip is appended to the image (see
/// TerrainImageryService), and [whiteU]/[whiteV] point into that strip.
class TerrainImageryFrame extends Equatable {
  final double u0MercX;
  final double u1MercX;
  final double v0MercY;
  final double v1MercY;
  final double whiteU;
  final double whiteV;

  const TerrainImageryFrame({
    required this.u0MercX,
    required this.u1MercX,
    required this.v0MercY,
    required this.v1MercY,
    required this.whiteU,
    required this.whiteV,
  });

  @override
  List<Object?> get props => [
    u0MercX,
    u1MercX,
    v0MercY,
    v1MercY,
    whiteU,
    whiteV,
  ];
}
```

`lib/features/bathymetry/data/terrain_imagery_service.dart`:

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:http/http.dart' as http;

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/constants/map_tile_config.dart';
import 'package:submersion/core/utils/slippy_tiles.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/terrain_imagery_frame.dart';

/// A stitched tile mosaic plus the frame that maps it onto geometry.
class TerrainImagery {
  final ui.Image image;
  final TerrainImageryFrame frame;
  const TerrainImagery({required this.image, required this.frame});
}

const int _tileSizePx = 256;
const int _whiteStripPx = 4;
const int _maxTiles = 16;

/// Fetches and stitches keyless map tiles covering a bathymetry grid's
/// footprint into one mosaic image with a reserved white strip at the
/// bottom. Returns null on ANY failure (offline, HTTP error, decode
/// error, oversized range): the terrain then silently falls back to depth
/// colors, matching the seascape's no-spinner posture.
class TerrainImageryService {
  final http.Client _client;

  TerrainImageryService(this._client);

  Future<TerrainImagery?> fetch({
    required BathymetryGrid grid,
    required MapStyle style,
  }) async {
    if (grid.rows < 2 || grid.cols < 2) return null;
    final halfLat = grid.cellSizeLatDeg / 2;
    final halfLon = grid.cellSizeLonDeg / 2;
    final west = grid.originLon - halfLon;
    final east =
        grid.originLon + grid.cellSizeLonDeg * (grid.cols - 1) + halfLon;
    final south = grid.originLat - halfLat;
    final north =
        grid.originLat + grid.cellSizeLatDeg * (grid.rows - 1) + halfLat;

    final z = imageryZoomFor(
      lonSpanDeg: east - west,
      maxZoom: MapTileConfig.maxZoom(style),
    );
    final xMin = slippyTileOf(north, west, z).x;
    final xMax = slippyTileOf(north, east, z).x;
    final yMin = slippyTileOf(north, west, z).y; // mercator y grows south
    final yMax = slippyTileOf(south, west, z).y;
    final tilesX = xMax - xMin + 1;
    final tilesY = yMax - yMin + 1;
    if (tilesX <= 0 || tilesY <= 0 || tilesX * tilesY > _maxTiles + 4) {
      return null;
    }

    final width = tilesX * _tileSizePx;
    final tileAreaHeight = tilesY * _tileSizePx;
    final height = tileAreaHeight + _whiteStripPx;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint();
    final tileImages = <ui.Image>[];
    try {
      for (var x = xMin; x <= xMax; x++) {
        for (var y = yMin; y <= yMax; y++) {
          final bytes = await _fetchTile(style, z, x, y);
          if (bytes == null) return null;
          final ui.Image tile;
          try {
            final codec = await ui.instantiateImageCodec(bytes);
            try {
              tile = (await codec.getNextFrame()).image;
            } finally {
              codec.dispose();
            }
          } catch (_) {
            return null;
          }
          tileImages.add(tile);
          canvas.drawImage(
            tile,
            ui.Offset(
              ((x - xMin) * _tileSizePx).toDouble(),
              ((y - yMin) * _tileSizePx).toDouble(),
            ),
            paint,
          );
        }
      }
      // The reserved strip: an opaque white band UV-less draped meshes
      // sample so color modulation is the identity for them.
      canvas.drawRect(
        ui.Rect.fromLTWH(
          0,
          tileAreaHeight.toDouble(),
          width.toDouble(),
          _whiteStripPx.toDouble(),
        ),
        ui.Paint()..color = const ui.Color(0xFFFFFFFF),
      );
      final image = await recorder.endRecording().toImage(width, height);
      final scale = 1 << z;
      return TerrainImagery(
        image: image,
        frame: TerrainImageryFrame(
          u0MercX: xMin / scale,
          u1MercX: (xMax + 1) / scale,
          v0MercY: yMin / scale,
          v1MercY: yMin / scale + (height / _tileSizePx) / scale,
          whiteU: 0.5,
          whiteV: (tileAreaHeight + _whiteStripPx / 2) / height,
        ),
      );
    } finally {
      for (final tile in tileImages) {
        tile.dispose();
      }
    }
  }

  Future<Uint8List?> _fetchTile(MapStyle style, int z, int x, int y) async {
    try {
      final response = await _client.get(
        Uri.parse(MapTileConfig.tileUrl(style, z, x, y)),
        headers: const {'User-Agent': 'app.submersion'},
      );
      if (response.statusCode != 200) return null;
      return response.bodyBytes;
    } catch (_) {
      return null;
    }
  }
}
```

`lib/features/bathymetry/presentation/terrain_imagery_providers.dart`:

```dart
import 'package:http/http.dart' as http;

import 'package:submersion/core/constants/map_style.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/terrain_imagery_service.dart';

/// Injectable so tests never hit tile servers.
final terrainImageryHttpClientProvider = Provider<http.Client>((ref) {
  return http.Client();
});

/// The stitched terrain imagery for a quantized bathymetry cell and map
/// style, or null when the grid or any tile is unavailable. Session-cached
/// per key; a style change is a new key.
final terrainImageryProvider =
    FutureProvider.family<
      TerrainImagery?,
      ({double lat, double lon, MapStyle style})
    >((ref, key) async {
      final grid = await ref.watch(
        bathymetryGridProvider((lat: key.lat, lon: key.lon)).future,
      );
      if (grid == null) return null;
      final client = ref.watch(terrainImageryHttpClientProvider);
      return TerrainImageryService(client).fetch(grid: grid, style: key.style);
    });
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/bathymetry/data/terrain_imagery_service_test.dart`
Expected: PASS. If frame numbers miss, re-derive the tile range by hand from the mercator formulas before touching the constants; the test's comment shows the derivation.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/bathymetry/domain/terrain_imagery_frame.dart lib/features/bathymetry/data/terrain_imagery_service.dart lib/features/bathymetry/presentation/terrain_imagery_providers.dart test/features/bathymetry/data/terrain_imagery_service_test.dart
git commit -m "feat(bathymetry): terrain imagery tile mosaic service"
```

---

### Task 5: Mesh UVs, neutral colors, and geometry threading

**Files:**
- Modify: `lib/features/dive_3d/domain/entities/mesh_data.dart`
- Modify: `lib/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart`
- Modify: `lib/features/dive_3d/domain/spatial/site_seascape_geometry_service.dart`, `lib/features/dive_3d/domain/spatial/spatial_geometry_service.dart`
- Modify: `lib/features/dive_3d/application/site_seascape_providers.dart`, `lib/features/dive_3d/application/spatial_providers.dart`
- Test: `test/features/dive_3d/domain/spatial/bathymetry_terrain_builder_test.dart`, `test/features/dive_3d/domain/spatial/site_seascape_geometry_service_test.dart` (extend both)

**Interfaces:**
- Consumes: `TerrainImageryFrame` (Task 4), `SeascapeSurfaceMode` (Task 2), `mercatorX/Y` (Task 3).
- Produces:
  - `MeshData` gains `final Float32List? textureCoordinates;` (normalized uv pairs per vertex, optional ctor param, default null).
  - `BathymetryTerrainBuilder.build(...)` gains `TerrainImageryFrame? imageryFrame` and `SeascapeSurfaceMode surfaceMode = SeascapeSurfaceMode.depth`: when the frame is non-null the terrain mesh carries normalized UVs computed by projecting each vertex's lat/lon through `mercatorX/Y` into the frame's linear mapping; when `surfaceMode == imagery` every terrain vertex color is white (shading applies at paint time), otherwise the existing ramp/land colors stand.
  - `SiteSeascapeInput` gains `final TerrainImageryFrame? imageryFrame;` (optional named, default null); `SpatialGeometryService.build/buildWithFrame` gain the same optional named param; both services forward frame + `input.appearance.surfaceMode` to the terrain builder (bathymetry branch only in the spatial service).
  - Both geometry providers watch `settingsProvider.select((s) => s.mapStyle)` and, when `appearance.surfaceMode != SeascapeSurfaceMode.depth` and a center exists, read `final imagery = ref.watch(terrainImageryProvider((lat: cell.lat, lon: cell.lon, style: mapStyle))).valueOrNull;` non-blocking (while the mosaic loads the scene renders with depth colors and rebuilds when it lands); `imagery?.frame` goes into the geometry input.
  - `SiteSeascapeReady` gains `final TerrainImagery? imagery;` and `SpatialSceneResult` gains the same (optional ctor params, default null), attached UI-SIDE by the providers after the compute() call: the record hands pages the image + white texel without re-deriving the provider key. The `ui.Image` never crosses the isolate because only the INPUT records travel through compute().
  Task 6 relies on `MeshData.textureCoordinates`; Task 8 relies on the `imagery` result fields.

- [ ] **Step 1: Write the failing tests**

Append to `bathymetry_terrain_builder_test.dart` (imports: `terrain_imagery_frame.dart`, `seascape_appearance.dart`, `slippy_tiles.dart`):

```dart
  group('imagery drape inputs', () {
    TerrainImageryFrame frameFor(BathymetryGrid g) {
      // A frame that maps u/v 0..1 exactly onto the grid's VERTEX extent
      // (cell centers), so corner vertices land on 0 and 1.
      final west = g.originLon;
      final east = g.originLon + g.cellSizeLonDeg * (g.cols - 1);
      final north = g.originLat + g.cellSizeLatDeg * (g.rows - 1);
      final south = g.originLat;
      return TerrainImageryFrame(
        u0MercX: mercatorX(west),
        u1MercX: mercatorX(east),
        v0MercY: mercatorY(north),
        v1MercY: mercatorY(south),
        whiteU: 0.5,
        whiteV: 0.99,
      );
    }

    test('a frame yields normalized UVs with corners on 0 and 1', () {
      final t = BathymetryTerrainBuilder.build(
        grid: grid,
        center: center,
        projection: proj(),
        imageryFrame: frameFor(grid),
      );
      final uv = t.terrain.textureCoordinates;
      expect(uv, isNotNull);
      expect(uv!.length, grid.rows * grid.cols * 2);
      // Vertex 0 = row 0 (south), col 0 (west): u = 0, v = 1.
      expect(uv[0], closeTo(0.0, 1e-9));
      expect(uv[1], closeTo(1.0, 1e-9));
      // Last vertex = north-east corner: u = 1, v = 0.
      expect(uv[uv.length - 2], closeTo(1.0, 1e-9));
      expect(uv[uv.length - 1], closeTo(0.0, 1e-9));
    });

    test('no frame means no UVs (existing behavior untouched)', () {
      final t = BathymetryTerrainBuilder.build(
        grid: grid,
        center: center,
        projection: proj(),
      );
      expect(t.terrain.textureCoordinates, isNull);
    });

    test('imagery mode paints every terrain vertex white', () {
      final t = BathymetryTerrainBuilder.build(
        grid: grid,
        center: center,
        projection: proj(),
        imageryFrame: frameFor(grid),
        surfaceMode: SeascapeSurfaceMode.imagery,
      );
      for (var i = 0; i < t.terrain.colors.length; i++) {
        expect(t.terrain.colors[i], 1.0);
      }
    });

    test('blend mode keeps the ramp colors', () {
      final t = BathymetryTerrainBuilder.build(
        grid: grid,
        center: center,
        projection: proj(),
        imageryFrame: frameFor(grid),
        surfaceMode: SeascapeSurfaceMode.blend,
      );
      final plain = BathymetryTerrainBuilder.build(
        grid: grid,
        center: center,
        projection: proj(),
      );
      expect(t.terrain.colors, plain.terrain.colors);
    });
  });
```

Append to `site_seascape_geometry_service_test.dart` (reusing its 5-to-45 slope grid fixture):

```dart
  test('an imagery frame flows through to terrain UVs', () {
    final slopeGrid = BathymetryGrid(
      originLat: 0,
      originLon: 0,
      cellSizeLatDeg: 100.0 / 110540.0,
      cellSizeLonDeg: 100.0 / 111320.0,
      rows: 3,
      cols: 3,
      depthsMeters: const [5, 5, 5, 25, 25, 25, 45, 45, 45],
      sourceId: 'test',
      resolutionMeters: 100,
      fetchedAt: DateTime.utc(2026, 8, 15),
    );
    const frame = TerrainImageryFrame(
      u0MercX: 0.4,
      u1MercX: 0.6,
      v0MercY: 0.4,
      v1MercY: 0.6,
      whiteU: 0.5,
      whiteV: 0.99,
    );
    final result = service.buildWithLabels(
      SiteSeascapeInput(
        grid: slopeGrid,
        center: const GeoPoint(0, 0),
        siteName: 'Test',
        divePaths: const [],
        nearbySites: const [],
        imageryFrame: frame,
      ),
    );
    expect(result.scene.layers.first.mesh.textureCoordinates, isNotNull);
  });
```

- [ ] **Step 2: Run to verify failures**

Run both test files. Expected: compile FAIL (`textureCoordinates`, `imageryFrame` undefined).

- [ ] **Step 3: Implement**

1. `mesh_data.dart`: add `final Float32List? textureCoordinates;` with ctor param `this.textureCoordinates,` and a doc line: normalized uv pairs per vertex for renderers that texture the mesh; null for untextured meshes.
2. `bathymetry_terrain_builder.dart`: new params on `build`; inside the vertex loop, when `imageryFrame != null` fill `uvs[vi2] = (mercatorX(lon) - f.u0MercX) / (f.u1MercX - f.u0MercX)` and `uvs[vi2+1] = (mercatorY(lat) - f.v0MercY) / (f.v1MercY - f.v0MercY)` where `lat = grid.originLat + grid.cellSizeLatDeg * r` and `lon = grid.originLon + grid.cellSizeLonDeg * c` (both already computed for east/north); the color branch becomes: `surfaceMode == SeascapeSurfaceMode.imagery` writes 1.0/1.0/1.0 for every vertex (wet AND land), otherwise the existing land/ramp logic runs. Pass `textureCoordinates: imageryFrame == null ? null : uvs` into the terrain `MeshData`. Imports: `terrain_imagery_frame.dart`, `seascape_appearance.dart`, `slippy_tiles.dart`.
3. Both geometry services: thread `imageryFrame` from input/param into `BathymetryTerrainBuilder.build(..., imageryFrame: ..., surfaceMode: appearance.surfaceMode)` (the spatial service only in its bathymetry branch; its record input in `spatial_providers.dart` gains an `imageryFrame` field forwarded by `_buildSpatial`).
4. Both providers: after the existing appearance/depthUnit watches:

```dart
      final mapStyle = ref.watch(settingsProvider.select((s) => s.mapStyle));
      TerrainImageryFrame? imageryFrame;
      if (appearance.surfaceMode != SeascapeSurfaceMode.depth) {
        final cell = BathymetryRepository.quantize(center);
        imageryFrame = ref
            .watch(
              terrainImageryProvider((
                lat: cell.lat,
                lon: cell.lon,
                style: mapStyle,
              )),
            )
            .valueOrNull
            ?.frame;
      }
```

but capture the whole value: `final imagery = ref.watch(...).valueOrNull;` and `imageryFrame = imagery?.frame;` (site provider: `center` is the site location already in scope; spatial provider: guard on `center != null && grid != null`). Pass `imageryFrame: imageryFrame` into the input AND `imagery: imagery` into the result record (`SiteSeascapeReady` / `SpatialSceneResult` each gain the optional `TerrainImagery? imagery` field). NOTE: check `BathymetryRepository.quantize`'s return type field names against its declaration before writing `cell.lat` (it returns the same record the grid provider family is keyed by).

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/dive_3d/ test/features/bathymetry/`
Expected: PASS across both suites (existing geometry/provider tests keep passing because the new params default to null/off).

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/dive_3d/ test/features/dive_3d/
git commit -m "feat(seascape): terrain UVs and neutral colors for imagery"
```

### Task 6: Textured merged-soup painting + viewport passthrough

**Files:**
- Modify: `lib/features/dive_3d/presentation/renderer/preview_painter.dart`
- Modify: `lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart`
- Test: `test/features/dive_3d/presentation/renderer/preview_painter_texture_test.dart` (new)

**Interfaces:**
- Consumes: `MeshData.textureCoordinates` (Task 5), `partitionLayers` and `_paintMeshes` (the merged-soup path from PR #1073), `TerrainImagery` (Task 4).
- Produces:
  - `Dive3dScenePainter({..., ui.Image? terrainImagery, ({double u, double v})? imageryWhiteTexel})`, both in `shouldRepaint` (image by `identical`).
  - `@visibleForTesting static Float32List soupTextureCoords(List<MeshData> meshes, ({double u, double v}) whiteTexel, int imageWidth, int imageHeight)`: per-GLOBAL-VERTEX texture coordinates in IMAGE PIXELS (ImageShader's space under an identity matrix); meshes without `textureCoordinates` get the white texel for every vertex.
  - The MERGED group paints with `Paint()..shader = ImageShader(image, TileMode.clamp, TileMode.clamp, Matrix4.identity().storage)` and `BlendMode.modulate` when imagery + white texel are present and any merged mesh carries UVs; otherwise the existing untextured path (`BlendMode.dst`, bare Paint) runs. `rest` meshes NEVER texture.
  - `Dive3dInteractiveViewport({..., ui.Image? terrainImagery, ({double u, double v})? imageryWhiteTexel})` passed to its scene painter.
  Task 8 consumes the viewport params.

- [ ] **Step 1: Write the failing test**

Create `test/features/dive_3d/presentation/renderer/preview_painter_texture_test.dart`:

```dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/preview_painter.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';

MeshData texturedTri() => MeshData(
  positions: Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]),
  indices: Uint32List.fromList([0, 1, 2]),
  colors: Float32List.fromList([1, 1, 1, 1, 1, 1, 1, 1, 1]),
  textureCoordinates: Float32List.fromList([0, 0, 1, 0, 0, 1]),
);

MeshData plainTri() => MeshData(
  positions: Float32List.fromList([0, 0, 0, 1, 0, 0, 0, 1, 0]),
  indices: Uint32List.fromList([0, 1, 2]),
  colors: Float32List.fromList([1, 0, 0, 1, 0, 0, 1, 0, 0]),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('soupTextureCoords scales UVs to pixels and fills the white texel', () {
    final coords = Dive3dScenePainter.soupTextureCoords(
      [texturedTri(), plainTri()],
      (u: 0.5, v: 0.9),
      100,
      50,
    );
    // Terrain vertices: normalized UV times image dimensions.
    expect(coords.sublist(0, 6), [0, 0, 100, 0, 0, 50]);
    // UV-less mesh: every vertex samples the white texel.
    expect(coords.sublist(6, 12), [50, 45, 50, 45, 50, 45]);
  });

  test('textured merged paint runs without error', () async {
    final recorder = ui.PictureRecorder();
    final imageRecorder = ui.PictureRecorder();
    ui.Canvas(imageRecorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 4, 4),
      ui.Paint()..color = const ui.Color(0xFF00FF00),
    );
    final image = await imageRecorder.endRecording().toImage(4, 4);
    addTearDown(image.dispose);

    final scene = Scene3d(
      layers: [
        SceneLayer(texturedTri()),
        SceneLayer(
          plainTri(),
          overlay: SceneOverlay.contours,
          drapedOnTerrain: true,
        ),
      ],
      markers: const [],
      bounds: const SceneBounds(durationSeconds: 1, maxDepthMeters: 10),
    );
    Dive3dScenePainter(
      scene: scene,
      terrainImagery: image,
      imageryWhiteTexel: (u: 0.5, v: 0.9),
    ).paint(ui.Canvas(recorder), const ui.Size(200, 150));
    recorder.endRecording();
  });

  test('without imagery the painter still paints textured meshes', () {
    final recorder = ui.PictureRecorder();
    final scene = Scene3d(
      layers: [SceneLayer(texturedTri())],
      markers: const [],
      bounds: const SceneBounds(durationSeconds: 1, maxDepthMeters: 10),
    );
    Dive3dScenePainter(
      scene: scene,
    ).paint(ui.Canvas(recorder), const ui.Size(200, 150));
    recorder.endRecording();
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_3d/presentation/renderer/preview_painter_texture_test.dart`
Expected: compile FAIL (`soupTextureCoords`, `terrainImagery` undefined).

- [ ] **Step 3: Implement the painter**

In `preview_painter.dart`:

1. Fields + ctor params: `final ui.Image? terrainImagery;` and `final ({double u, double v})? imageryWhiteTexel;` (both default null). The file currently has an UNALIASED `import 'dart:ui';` alongside material, so a bare `Image` type would be ambiguous: change the import to `import 'dart:ui' as ui;` and prefix the file's existing dart:ui references (`Vertices.raw`, `VertexMode.triangles`, and any `Color`/`Offset` uses that came from dart:ui rather than material) with `ui.`. The analyzer flags every spot; fix them all in this step.
2. The helper:

```dart
  /// Per-global-vertex texture coordinates for a merged soup, in IMAGE
  /// PIXELS (ImageShader space under an identity matrix). Meshes without
  /// UVs sample the reserved white texel so BlendMode.modulate leaves
  /// their vertex colors untouched.
  @visibleForTesting
  static Float32List soupTextureCoords(
    List<MeshData> meshes,
    ({double u, double v}) whiteTexel,
    int imageWidth,
    int imageHeight,
  ) {
    var vn = 0;
    for (final mesh in meshes) {
      vn += mesh.vertexCount;
    }
    final coords = Float32List(vn * 2);
    var vOff = 0;
    for (final mesh in meshes) {
      final uv = mesh.textureCoordinates;
      for (var i = 0; i < mesh.vertexCount; i++) {
        final gi = (vOff + i) * 2;
        if (uv != null) {
          coords[gi] = uv[i * 2] * imageWidth;
          coords[gi + 1] = uv[i * 2 + 1] * imageHeight;
        } else {
          coords[gi] = whiteTexel.u * imageWidth;
          coords[gi + 1] = whiteTexel.v * imageHeight;
        }
      }
      vOff += mesh.vertexCount;
    }
    return coords;
  }
```

3. `paint()` passes the imagery ONLY to the merged call: `_paintMeshes(canvas, projector, parts.merged, imagery: terrainImagery, whiteTexel: imageryWhiteTexel);` and the `rest` loop stays untextured.
4. `_paintMeshes` gains `{ui.Image? imagery, ({double u, double v})? whiteTexel}`. Compute `final textured = imagery != null && whiteTexel != null && meshes.any((m) => m.textureCoordinates != null);`. When textured: build `final vertexTex = soupTextureCoords(meshes, whiteTexel, imagery.width, imagery.height);`, and in the de-indexed emit fill a `Float32List texOut(triCount * 3 * 2)` from `vertexTex` at each emitted global vertex index (mirror the two `screen` writes with `texOut[slot * 2] = vertexTex[vi * 2]; texOut[slot * 2 + 1] = vertexTex[vi * 2 + 1];`). Final draw:

```dart
    if (textured) {
      canvas.drawVertices(
        Vertices.raw(
          VertexMode.triangles,
          screen,
          colors: colors,
          textureCoordinates: texOut,
        ),
        BlendMode.modulate,
        Paint()
          ..shader = ImageShader(
            imagery,
            TileMode.clamp,
            TileMode.clamp,
            Matrix4.identity().storage,
          ),
      );
    } else {
      // existing drawVertices call unchanged
    }
```

5. `shouldRepaint` adds `|| !identical(oldDelegate.terrainImagery, terrainImagery) || oldDelegate.imageryWhiteTexel != imageryWhiteTexel`.

- [ ] **Step 4: Viewport passthrough**

`Dive3dInteractiveViewport` gains `final ui.Image? terrainImagery;` and `final ({double u, double v})? imageryWhiteTexel;` (optional ctor params) forwarded into its `Dive3dScenePainter` construction (`terrainImagery: widget.terrainImagery, imageryWhiteTexel: widget.imageryWhiteTexel`). No other painter needs them.

- [ ] **Step 5: Run, format, commit**

Run: `flutter test test/features/dive_3d/presentation/renderer/ test/features/dive_3d/presentation/widgets/`
Expected: PASS. Then:

```bash
dart format .
git add lib/features/dive_3d/presentation/renderer/preview_painter.dart lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart test/features/dive_3d/presentation/renderer/preview_painter_texture_test.dart
git commit -m "feat(seascape): textured merged-soup painting"
```

---

### Task 7: Surface-mode control in the appearance sheet + l10n

**Files:**
- Modify: `lib/features/dive_3d/presentation/widgets/terrain_appearance_sheet.dart`
- Modify: all 11 `lib/l10n/arb/app_*.arb`
- Test: `test/features/dive_3d/presentation/widgets/terrain_appearance_sheet_test.dart` (extend)

**Interfaces:**
- Consumes: `SeascapeSurfaceMode` (Task 2), the sheet's existing `update`/`appearance` plumbing.
- Produces: a three-way `SegmentedButton<SeascapeSurfaceMode>` with `key: ValueKey('seascapeSurfaceModeSegments')` at the TOP of the sheet (before the ramp-range switch); l10n keys `dive3d_seascape_appearance_surface`, `_surfaceDepth`, `_surfaceImagery`, `_surfaceBlend`.

English values: "Terrain surface" / "Depth colors" / "Map imagery" / "Blend". Translations (same order): de "Geländeoberfläche" / "Tiefenfarben" / "Kartenbilder" / "Mischung"; es "Superficie del terreno" / "Colores de profundidad" / "Imágenes del mapa" / "Mezcla"; fr "Surface du terrain" / "Couleurs de profondeur" / "Imagerie de la carte" / "Mélange"; it "Superficie del terreno" / "Colori di profondità" / "Immagini della mappa" / "Miscela"; nl "Terreinoppervlak" / "Dieptekleuren" / "Kaartbeelden" / "Mengeling"; pt "Superfície do terreno" / "Cores de profundidade" / "Imagens do mapa" / "Mistura"; hu "Terepfelszín" / "Mélységszínek" / "Térképi felvétel" / "Keverék"; ar "سطح التضاريس" / "ألوان العمق" / "صور الخريطة" / "مزيج"; he "פני הקרקע" / "צבעי עומק" / "תמונות מפה" / "שילוב"; zh "地形表面" / "深度配色" / "地图影像" / "混合".

- [ ] **Step 1: Add the four keys to all 11 arb files** (next to the other `dive3d_seascape_appearance_*` keys, matching each file's metadata style), then `flutter gen-l10n` from the project root.

- [ ] **Step 2: Write the failing test**

Append to `terrain_appearance_sheet_test.dart`:

```dart
  testWidgets('surface mode segmented control writes through', (tester) async {
    final container = await pumpSheet(tester);
    expect(
      container.read(settingsProvider).seascapeAppearance.surfaceMode,
      SeascapeSurfaceMode.depth,
    );
    await tester.tap(find.text('Map imagery'));
    await tester.pump();
    expect(
      container.read(settingsProvider).seascapeAppearance.surfaceMode,
      SeascapeSurfaceMode.imagery,
    );
    await tester.tap(find.text('Blend'));
    await tester.pump();
    expect(
      container.read(settingsProvider).seascapeAppearance.surfaceMode,
      SeascapeSurfaceMode.blend,
    );
  });
```

- [ ] **Step 3: Run to verify failure, then implement**

Run the sheet test (FAIL: no such control). Then insert, immediately after the sheet's title `Text` and before the ramp-range `SwitchListTile`:

```dart
          const SizedBox(height: 8),
          SegmentedButton<SeascapeSurfaceMode>(
            key: const ValueKey('seascapeSurfaceModeSegments'),
            segments: [
              ButtonSegment(
                value: SeascapeSurfaceMode.depth,
                label: Text(l10n.dive3d_seascape_appearance_surfaceDepth),
              ),
              ButtonSegment(
                value: SeascapeSurfaceMode.imagery,
                label: Text(l10n.dive3d_seascape_appearance_surfaceImagery),
              ),
              ButtonSegment(
                value: SeascapeSurfaceMode.blend,
                label: Text(l10n.dive3d_seascape_appearance_surfaceBlend),
              ),
            ],
            selected: {appearance.surfaceMode},
            onSelectionChanged: (sel) =>
                update(appearance.copyWith(surfaceMode: sel.single)),
          ),
```

with a `Text(l10n.dive3d_seascape_appearance_surface)` section label above it, mirroring the contour section's style.

- [ ] **Step 4: Run, format, commit**

Run: `flutter test test/features/dive_3d/presentation/widgets/terrain_appearance_sheet_test.dart`
Expected: PASS. Then:

```bash
dart format .
git add lib/features/dive_3d/presentation/widgets/terrain_appearance_sheet.dart test/features/dive_3d/presentation/widgets/terrain_appearance_sheet_test.dart lib/l10n/arb/
git commit -m "feat(seascape): surface mode control in the appearance sheet"
```

---

### Task 8: Page wiring: imagery to the viewport, legend gating, attribution

**Files:**
- Modify: `lib/features/dive_3d/presentation/pages/site_seascape_page.dart`, `lib/features/dive_3d/presentation/pages/spatial_site_page.dart`
- Test: `test/features/dive_3d/presentation/site_seascape_page_test.dart` (extend)

**Interfaces:**
- Consumes: `SiteSeascapeReady.imagery` / `SpatialSceneResult.imagery` (Task 5), viewport `terrainImagery`/`imageryWhiteTexel` (Task 6), `MapTileConfig.attribution`, `settingsProvider.select((s) => s.mapStyle)`.
- Produces: both pages pass `terrainImagery: state.imagery?.image` and `imageryWhiteTexel: state.imagery == null ? null : (u: state.imagery!.frame.whiteU, v: state.imagery!.frame.whiteV)` into the viewport; the legend renders only when `appearance.surfaceMode != SeascapeSurfaceMode.imagery`; whenever imagery is non-null an attribution chip with `MapTileConfig.attribution(mapStyle)` joins the provenance chrome (site page: alongside `_sourceChip`; spatial page: appended to `_captions`).

- [ ] **Step 1: Write the failing tests**

Extend `site_seascape_page_test.dart`. Its `readyState()` helper gains an optional `TerrainImagery? imagery` parameter threaded into `SiteSeascapeReady(..., imagery: imagery)`, and the `page(...)` host an optional seeded `AppSettings`. Build a tiny imagery fixture in the test:

```dart
Future<TerrainImagery> testImagery() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(
    const ui.Rect.fromLTWH(0, 0, 4, 4),
    ui.Paint()..color = const ui.Color(0xFF00FF00),
  );
  final image = await recorder.endRecording().toImage(4, 4);
  return TerrainImagery(
    image: image,
    frame: const TerrainImageryFrame(
      u0MercX: 0.4,
      u1MercX: 0.6,
      v0MercY: 0.4,
      v1MercY: 0.6,
      whiteU: 0.5,
      whiteV: 0.9,
    ),
  );
}
```

New tests:

```dart
  testWidgets('imagery reaches the viewport and shows attribution', (
    tester,
  ) async {
    final imagery = await testImagery();
    await tester.pumpWidget(
      page(
        readyState(imagery: imagery),
        settings: const AppSettings(
          seascapeAppearance: SeascapeAppearance(
            surfaceMode: SeascapeSurfaceMode.imagery,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final viewport = tester.widget<Dive3dInteractiveViewport>(
      find.byType(Dive3dInteractiveViewport),
    );
    expect(viewport.terrainImagery, isNotNull);
    expect(viewport.imageryWhiteTexel, (u: 0.5, v: 0.9));
    // Esri attribution rides the chrome; the legend hides in imagery mode.
    expect(find.textContaining('Esri'), findsOneWidget);
    expect(find.byKey(const ValueKey('seascapeDepthLegend')), findsNothing);
  });

  testWidgets('depth mode keeps the legend and skips attribution', (
    tester,
  ) async {
    await tester.pumpWidget(page(readyState()));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('seascapeDepthLegend')), findsOneWidget);
    expect(find.textContaining('Esri'), findsNothing);
  });
```

(The settings mock's default `mapStyle` should be `esriSatellite` for the first test OR seed it in the `AppSettings`; check `AppSettings`'s `mapStyle` default and seed explicitly to keep the assertion honest.)

- [ ] **Step 2: Run to verify failure, then implement both pages**

Site page: destructure `:final imagery` from `SiteSeascapeReady`; viewport gains the two params; wrap the legend `Positioned` in `if (appearance.surfaceMode != SeascapeSurfaceMode.imagery)`; below `_sourceChip` add, when `imagery != null`:

```dart
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: _attributionChip(
                          MapTileConfig.attribution(mapStyle),
                        ),
                      ),
```

where `mapStyle = ref.watch(settingsProvider.select((s) => s.mapStyle))` and `_attributionChip` reuses the `_sourceChip` container styling with `labelSmall` text. Spatial page: same viewport params from `result.imagery`, same legend gate, and `_captions` appends the attribution chip when `result.imagery != null`.

- [ ] **Step 3: Run, format, commit**

Run: `flutter test test/features/dive_3d/presentation/site_seascape_page_test.dart test/features/dive_3d/presentation/pages/spatial_site_page_test.dart test/features/dive_3d/presentation/spatial_site_page_caption_test.dart`
Expected: PASS. Then:

```bash
dart format .
git add lib/features/dive_3d/presentation/pages/ test/features/dive_3d/presentation/
git commit -m "feat(seascape): wire terrain imagery through the seascape pages"
```

---

### Task 9: Full verification + stacked PR

- [ ] **Step 1: Amend the spec's stitching sentence**

In `docs/superpowers/specs/2026-08-15-site-scape-unification-design.md` (PR 2 section), reword "stitch tiles ... onto one canvas cropped to the grid box in Web Mercator" to "stitch tiles onto one tile-aligned canvas; the UV frame maps the grid box into it (correction at planning time: cropping bought nothing the frame does not)".

- [ ] **Step 2: Verify**

```bash
dart format .
flutter analyze
flutter test
flutter gen-l10n
git status --short
```

Expected: no format changes, zero analyze issues (infos are CI-fatal), full suite green, no l10n drift.

- [ ] **Step 3: Push and open the stacked PR**

```bash
git push -u origin worktree-site-scape-imagery
gh pr create --repo submersion-app/submersion --base worktree-site-scape-depth-overlay --head worktree-site-scape-imagery --title "feat(seascape): drape map imagery onto the 3D terrain" --body-file <body file>
```

PR body per repo conventions (no attribution line, no session URL); note the surface modes, the frame/image isolate split, and the white-texel mechanism.

## Execution notes

- Planning-time simplification vs the spec: the mosaic is TILE-ALIGNED and never cropped to the grid box; the UV frame absorbs the difference (a crop would only save a few hundred kilobytes of texture and add a failure mode). Task 9's spec touch-up: reword the spec's "stitch onto one canvas cropped to the grid box" to "stitch onto one tile-aligned canvas; the UV frame maps the grid box into it".
- Task order is strict 1 to 9 except Task 7, which only needs Task 2 and can run any time after it.
- Manual visual pass before merge: `flutter run -d macos` from this worktree, a site with bathymetry, flip Depth / Imagery / Blend and orbit; check imagery registration against the compass and chart mode (chart + imagery should read like a satellite chart with contours).
- Never commit `database.g.dart`; `app_localizations*.dart` ARE committed.


