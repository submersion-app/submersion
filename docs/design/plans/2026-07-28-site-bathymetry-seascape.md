# Site Bathymetry Seascape Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render real seafloor bathymetry around a dive site's GPS pin in the 3D seascape, with a new site-level seascape page and an upgraded per-dive scene, backed by a three-tier keyless source resolver (EMODnet, GMRT, ETOPO 2022) and a local-only cache.

**Architecture:** New `lib/features/bathymetry/` feature owns fetching/parsing/caching depth grids (`BathymetryGrid`). The existing `Scene3d` CustomPainter pipeline in `lib/features/dive_3d/` gains a `BathymetryTerrainBuilder`, a `SiteSeascapeGeometryService` + `SiteSeascapePage`, and an upgraded `spatialGeometryProvider` that prefers real terrain and falls back to the existing synthesized `TerrainBuilder`.

**Tech Stack:** Flutter/Dart, Drift (local cache DB only), Riverpod, `http` ^1.2.2 (`MockClient` from `package:http/testing` for tests).

**Spec:** `docs/superpowers/specs/2026-07-28-site-bathymetry-seascape-design.md`

## Global Constraints

- Work happens in worktree `site-bathymetry-seascape` (branch `worktree-site-bathymetry-seascape`). Never touch the main checkout. Before trusting any shell result, remember the cwd can silently reset to the main checkout — use `pwd` / absolute paths when in doubt.
- **Local cache DB ladder:** this branch bumps `LocalCacheDatabase` `schemaVersion` 6 → 7. PR #728 (reef data, unmerged) ALSO claims v7 on its own branch. Whichever merges second renumbers its migration. Do not renumber preemptively.
- `*.g.dart` is gitignored — never commit generated files; run `dart run build_runner build --delete-conflicting-outputs` after Drift table changes.
- Every new user-facing string: add to `lib/l10n/arb/app_en.arb` AND all 10 non-English locales (`ar, de, es, fr, he, hu, it, nl, pt, zh`), then run `flutter gen-l10n` (generated `app_localizations*.dart` ARE committed).
- No live network in tests. HTTP sources take an injectable `http.Client`.
- Providers must never leave a permanent spinner: every terminal state renders a scene or an explicit message (PR #659 lesson).
- Depth convention: meters positive DOWN everywhere in the app. Bathymetry sources deliver elevation (negative under water) — parsers negate at the boundary. Land = negative depth; nodata = null.
- `compute()` isolates only above a size threshold; synchronous below (widget-test FakeAsync deadlock). Widget tests must use small grids.
- Before every commit: `dart format .` (whole project) and `flutter analyze` with zero issues (infos are fatal in CI). Never pipe analyze output through `tail`/`head`.
- Commits: conventional messages (`feat:`/`test:`/`docs:`), no Co-Authored-By line, no session URL.
- Test runs: run the specific file(s) for the task, plus the suites named in the task. Full `flutter test` once at the end (Task 16).

---

## Phase A — bathymetry data feature (PR 1)

### Task 1: BathymetryGrid entity

**Files:**
- Create: `lib/features/bathymetry/domain/bathymetry_grid.dart`
- Test: `test/features/bathymetry/domain/bathymetry_grid_test.dart`

**Interfaces:**
- Consumes: nothing (pure Dart).
- Produces: `BathymetryGrid` with fields `originLat, originLon, cellSizeLatDeg, cellSizeLonDeg, rows, cols, depthsMeters (List<double?>), sourceId, resolutionMeters, fetchedAt (DateTime)`; members `depthAt(int row, int col)`, `wetFraction`, `maxDepthMeters`, `downsampleTo(int maxDim)`, `toJson()`, `BathymetryGrid.fromJson(Map<String, dynamic>)`. Rows run south→north from `originLat`, cols west→east from `originLon`; origin is a CELL CENTER; `depthsMeters` is row-major, positive down, negative = land elevation, null = nodata.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/bathymetry/domain/bathymetry_grid_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';

BathymetryGrid grid(List<double?> depths, {int rows = 2, int cols = 3}) =>
    BathymetryGrid(
      originLat: 12.14,
      originLon: -68.31,
      cellSizeLatDeg: 0.004,
      cellSizeLonDeg: 0.004,
      rows: rows,
      cols: cols,
      depthsMeters: depths,
      sourceId: 'test',
      resolutionMeters: 450,
      fetchedAt: DateTime.utc(2026, 7, 28),
    );

void main() {
  test('depthAt reads row-major cells', () {
    final g = grid([1, 2, 3, 4, 5, 6]);
    expect(g.depthAt(0, 0), 1);
    expect(g.depthAt(1, 2), 6);
  });

  test('wetFraction counts wet cells among known cells only', () {
    // 2 wet (+), 1 land (-), 1 nodata, 2 wet => 4 wet / 5 known.
    final g = grid([10, 20, -5, null, 30, 40]);
    expect(g.wetFraction, closeTo(4 / 5, 1e-9));
  });

  test('wetFraction is 0 for an all-null grid', () {
    expect(grid([null, null, null, null, null, null]).wetFraction, 0);
  });

  test('maxDepthMeters ignores land and nodata', () {
    expect(grid([10, -50, null, 42, 7, 3]).maxDepthMeters, 42);
  });

  test('downsampleTo caps both dimensions with strided cells', () {
    final depths = List<double?>.generate(6 * 6, (i) => i.toDouble());
    final g = grid(depths, rows: 6, cols: 6);
    final d = g.downsampleTo(3);
    expect(d.rows, 3);
    expect(d.cols, 3);
    expect(d.depthAt(0, 0), 0); // stride 2 keeps cells 0,2,4
    expect(d.depthAt(1, 1), 14); // row 2, col 2 of original
    expect(d.cellSizeLatDeg, closeTo(0.008, 1e-12));
  });

  test('downsampleTo is identity when already small enough', () {
    final g = grid([1, 2, 3, 4, 5, 6]);
    expect(identical(g.downsampleTo(120), g), isTrue);
  });

  test('json round-trip preserves all fields including nulls', () {
    final g = grid([10.5, null, -3, 4, 5, 6]);
    final back = BathymetryGrid.fromJson(g.toJson());
    expect(back.depthsMeters, g.depthsMeters);
    expect(back.originLat, g.originLat);
    expect(back.cellSizeLonDeg, g.cellSizeLonDeg);
    expect(back.rows, g.rows);
    expect(back.cols, g.cols);
    expect(back.sourceId, 'test');
    expect(back.resolutionMeters, 450);
    expect(back.fetchedAt, DateTime.utc(2026, 7, 28));
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/bathymetry/domain/bathymetry_grid_test.dart`
Expected: FAIL — file/class does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/features/bathymetry/domain/bathymetry_grid.dart
/// A rectangular grid of seafloor depths around a coordinate, in the app's
/// depth convention: meters positive DOWN. Negative values are land
/// elevation above the waterline; null cells are nodata. Rows run
/// south -> north from [originLat], columns west -> east from [originLon];
/// the origin is a cell CENTER, not a corner.
class BathymetryGrid {
  final double originLat;
  final double originLon;
  final double cellSizeLatDeg;
  final double cellSizeLonDeg;
  final int rows;
  final int cols;
  final List<double?> depthsMeters; // row-major, length rows * cols
  final String sourceId;
  final double resolutionMeters;
  final DateTime fetchedAt;

  const BathymetryGrid({
    required this.originLat,
    required this.originLon,
    required this.cellSizeLatDeg,
    required this.cellSizeLonDeg,
    required this.rows,
    required this.cols,
    required this.depthsMeters,
    required this.sourceId,
    required this.resolutionMeters,
    required this.fetchedAt,
  });

  double? depthAt(int row, int col) => depthsMeters[row * cols + col];

  /// Fraction of known (non-null) cells that are under water.
  double get wetFraction {
    var wet = 0, known = 0;
    for (final d in depthsMeters) {
      if (d == null) continue;
      known++;
      if (d > 0) wet++;
    }
    return known == 0 ? 0 : wet / known;
  }

  double get maxDepthMeters {
    var m = 0.0;
    for (final d in depthsMeters) {
      if (d != null && d > m) m = d;
    }
    return m;
  }

  /// Strided downsample so neither dimension exceeds [maxDim].
  BathymetryGrid downsampleTo(int maxDim) {
    if (rows <= maxDim && cols <= maxDim) return this;
    final stepR = (rows / maxDim).ceil();
    final stepC = (cols / maxDim).ceil();
    final newRows = (rows + stepR - 1) ~/ stepR;
    final newCols = (cols + stepC - 1) ~/ stepC;
    final out = List<double?>.filled(newRows * newCols, null);
    for (var r = 0; r < newRows; r++) {
      for (var c = 0; c < newCols; c++) {
        out[r * newCols + c] = depthsMeters[(r * stepR) * cols + (c * stepC)];
      }
    }
    return BathymetryGrid(
      originLat: originLat,
      originLon: originLon,
      cellSizeLatDeg: cellSizeLatDeg * stepR,
      cellSizeLonDeg: cellSizeLonDeg * stepC,
      rows: newRows,
      cols: newCols,
      depthsMeters: out,
      sourceId: sourceId,
      resolutionMeters: resolutionMeters * stepC,
      fetchedAt: fetchedAt,
    );
  }

  Map<String, dynamic> toJson() => {
    'originLat': originLat,
    'originLon': originLon,
    'cellSizeLatDeg': cellSizeLatDeg,
    'cellSizeLonDeg': cellSizeLonDeg,
    'rows': rows,
    'cols': cols,
    'depths': depthsMeters,
    'sourceId': sourceId,
    'resolutionMeters': resolutionMeters,
    'fetchedAt': fetchedAt.toUtc().toIso8601String(),
  };

  factory BathymetryGrid.fromJson(Map<String, dynamic> json) => BathymetryGrid(
    originLat: (json['originLat'] as num).toDouble(),
    originLon: (json['originLon'] as num).toDouble(),
    cellSizeLatDeg: (json['cellSizeLatDeg'] as num).toDouble(),
    cellSizeLonDeg: (json['cellSizeLonDeg'] as num).toDouble(),
    rows: json['rows'] as int,
    cols: json['cols'] as int,
    depthsMeters: [
      for (final d in json['depths'] as List) (d as num?)?.toDouble(),
    ],
    sourceId: json['sourceId'] as String,
    resolutionMeters: (json['resolutionMeters'] as num).toDouble(),
    fetchedAt: DateTime.parse(json['fetchedAt'] as String),
  );
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/bathymetry/domain/bathymetry_grid_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/bathymetry test/features/bathymetry
git commit -m "feat(bathymetry): add BathymetryGrid entity"
```

---

### Task 2: ERDDAP griddap JSON parser + fixtures

**Files:**
- Create: `lib/features/bathymetry/data/sources/erddap_grid_parser.dart`
- Create: `test/fixtures/bathymetry/etopo_bonaire.json`
- Create: `test/fixtures/bathymetry/emodnet_carib.json`
- Test: `test/features/bathymetry/data/erddap_grid_parser_test.dart`

**Interfaces:**
- Consumes: `BathymetryGrid` (Task 1).
- Produces: `ErddapGridParser.parse(String body, {required String sourceId, required double resolutionMeters, required DateTime fetchedAt}) -> BathymetryGrid`. Throws `FormatException` on malformed/degenerate bodies.

- [ ] **Step 1: Write the fixtures**

`test/fixtures/bathymetry/etopo_bonaire.json` — NOAA shape: depth column named `z`, values mix int and float (real ERDDAP behavior):

```json
{"table": {"columnNames": ["latitude", "longitude", "z"], "columnTypes": ["double", "double", "double"], "rows": [
[12.139, -68.310, -291], [12.139, -68.306, -283.5], [12.139, -68.302, -270], [12.139, -68.298, -255],
[12.143, -68.310, -300], [12.143, -68.306, -288], [12.143, -68.302, -274.2], [12.143, -68.298, -260],
[12.147, -68.310, -310], [12.147, -68.306, -295], [12.147, -68.302, -280], [12.147, -68.298, 12]
]}}
```

`test/fixtures/bathymetry/emodnet_carib.json` — EMODnet shape: depth column named `elevation`, land cells null:

```json
{"table": {"columnNames": ["latitude", "longitude", "elevation"], "columnUnits": ["degrees_north", "degrees_east", "m"], "rows": [
[12.149, -68.299, null], [12.149, -68.293, -106.70838], [12.149, -68.287, -240.5],
[12.155, -68.299, -12.25], [12.155, -68.293, -130.0], [12.155, -68.287, -300],
[12.161, -68.299, -30], [12.161, -68.293, -155.75], [12.161, -68.287, -352.1]
]}}
```

- [ ] **Step 2: Write the failing tests**

```dart
// test/features/bathymetry/data/erddap_grid_parser_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/data/sources/erddap_grid_parser.dart';

String fixture(String name) =>
    File('test/fixtures/bathymetry/$name').readAsStringSync();

void main() {
  final when = DateTime.utc(2026, 7, 28);

  test('parses NOAA z-column body into a south-to-north grid', () {
    final g = ErddapGridParser.parse(
      fixture('etopo_bonaire.json'),
      sourceId: 'etopo2022',
      resolutionMeters: 450,
      fetchedAt: when,
    );
    expect(g.rows, 3);
    expect(g.cols, 4);
    expect(g.originLat, closeTo(12.139, 1e-9)); // southernmost first
    expect(g.originLon, closeTo(-68.310, 1e-9)); // westernmost first
    expect(g.cellSizeLatDeg, closeTo(0.004, 1e-9));
    expect(g.cellSizeLonDeg, closeTo(0.004, 1e-9));
    // Elevation -291 becomes depth +291 (positive down).
    expect(g.depthAt(0, 0), closeTo(291, 1e-9));
    // int and double values both parse.
    expect(g.depthAt(1, 2), closeTo(274.2, 1e-9));
    // Land cell: elevation +12 -> depth -12.
    expect(g.depthAt(2, 3), closeTo(-12, 1e-9));
    expect(g.sourceId, 'etopo2022');
  });

  test('parses EMODnet elevation-column body preserving nulls', () {
    final g = ErddapGridParser.parse(
      fixture('emodnet_carib.json'),
      sourceId: 'emodnet',
      resolutionMeters: 115,
      fetchedAt: when,
    );
    expect(g.rows, 3);
    expect(g.cols, 3);
    expect(g.depthAt(0, 0), isNull); // null stays null
    expect(g.depthAt(0, 1), closeTo(106.70838, 1e-6));
    expect(g.depthAt(2, 2), closeTo(352.1, 1e-9));
  });

  test('throws FormatException on empty table', () {
    expect(
      () => ErddapGridParser.parse(
        '{"table": {"columnNames": ["latitude","longitude","z"], "rows": []}}',
        sourceId: 's',
        resolutionMeters: 1,
        fetchedAt: when,
      ),
      throwsFormatException,
    );
  });

  test('throws FormatException when an axis has a single distinct value', () {
    expect(
      () => ErddapGridParser.parse(
        '{"table": {"columnNames": ["latitude","longitude","z"], "rows": '
        '[[12.1, -68.3, -10], [12.1, -68.2, -20]]}}',
        sourceId: 's',
        resolutionMeters: 1,
        fetchedAt: when,
      ),
      throwsFormatException,
    );
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/bathymetry/data/erddap_grid_parser_test.dart`
Expected: FAIL — parser does not exist.

- [ ] **Step 4: Implement**

```dart
// lib/features/bathymetry/data/sources/erddap_grid_parser.dart
import 'dart:collection';
import 'dart:convert';

import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';

/// Parses an ERDDAP griddap `.json` table response into a [BathymetryGrid].
///
/// The depth variable is the LAST column (`z` on NOAA servers, `elevation`
/// on EMODnet); values are elevation in meters (negative under water) and
/// arrive as int, double, or null — always read as `num?`. Rows iterate
/// latitude-major with both axes ascending on the dataset's fixed cell
/// centers, but this parser tolerates any ordering by indexing rows into
/// the sorted axis sets.
class ErddapGridParser {
  static BathymetryGrid parse(
    String body, {
    required String sourceId,
    required double resolutionMeters,
    required DateTime fetchedAt,
  }) {
    final root = jsonDecode(body) as Map<String, dynamic>;
    final table = root['table'] as Map<String, dynamic>;
    final rows = (table['rows'] as List).cast<List<dynamic>>();
    if (rows.isEmpty) {
      throw const FormatException('ERDDAP response has no rows');
    }

    final lats = SplayTreeSet<double>();
    final lons = SplayTreeSet<double>();
    for (final r in rows) {
      lats.add((r[0] as num).toDouble());
      lons.add((r[1] as num).toDouble());
    }
    if (lats.length < 2 || lons.length < 2) {
      throw const FormatException('ERDDAP grid is degenerate (single row/col)');
    }

    final latList = lats.toList();
    final lonList = lons.toList();
    final latIndex = {for (var i = 0; i < latList.length; i++) latList[i]: i};
    final lonIndex = {for (var i = 0; i < lonList.length; i++) lonList[i]: i};

    final depths = List<double?>.filled(latList.length * lonList.length, null);
    for (final r in rows) {
      final row = latIndex[(r[0] as num).toDouble()]!;
      final col = lonIndex[(r[1] as num).toDouble()]!;
      final elevation = (r[2] as num?)?.toDouble();
      depths[row * lonList.length + col] = elevation == null ? null : -elevation;
    }

    return BathymetryGrid(
      originLat: latList.first,
      originLon: lonList.first,
      cellSizeLatDeg: latList[1] - latList[0],
      cellSizeLonDeg: lonList[1] - lonList[0],
      rows: latList.length,
      cols: lonList.length,
      depthsMeters: depths,
      sourceId: sourceId,
      resolutionMeters: resolutionMeters,
      fetchedAt: fetchedAt,
    );
  }
}
```

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/bathymetry/data/erddap_grid_parser_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/bathymetry test/features/bathymetry test/fixtures/bathymetry
git commit -m "feat(bathymetry): parse ERDDAP griddap JSON responses"
```

---

### Task 3: BathymetrySource interface + ETOPO source with mirror failover

**Files:**
- Create: `lib/features/bathymetry/domain/bathymetry_source.dart`
- Create: `lib/features/bathymetry/data/sources/etopo_erddap_source.dart`
- Test: `test/features/bathymetry/data/etopo_erddap_source_test.dart`

**Interfaces:**
- Consumes: `BathymetryGrid` (Task 1), `ErddapGridParser` (Task 2), `GeoPoint` from `package:submersion/features/dive_sites/domain/entities/dive_site.dart`.
- Produces:
  - `abstract interface class BathymetrySource { String get id; bool get global; bool covers(GeoPoint center); Future<BathymetryGrid> fetch(GeoPoint center, {required double spanMeters}); }`
  - `class BathymetryFetchException implements Exception { final String message; }` — thrown on ANY transient failure (network error, timeout, non-200, unparseable body).
  - `EtopoErddapSource({http.Client? client, List<String> hosts})` with `id == 'etopo2022'`, `global == true`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/bathymetry/data/etopo_erddap_source_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/bathymetry/data/sources/etopo_erddap_source.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  final bonaire = const GeoPoint(12.16, -68.29);
  final body = File(
    'test/fixtures/bathymetry/etopo_bonaire.json',
  ).readAsStringSync();

  test('fetches and parses from the primary host', () async {
    final requested = <String>[];
    final source = EtopoErddapSource(
      client: MockClient((req) async {
        requested.add(req.url.toString());
        return http.Response(body, 200);
      }),
    );
    final grid = await source.fetch(bonaire, spanMeters: 4000);
    expect(grid.sourceId, 'etopo2022');
    expect(grid.rows, 3);
    expect(requested.single, contains('coastwatch.pfeg.noaa.gov'));
    expect(requested.single, contains('ETOPO_2022_v1_15s.json'));
  });

  test('fails over to the mirror when the primary errors', () async {
    final requested = <String>[];
    final source = EtopoErddapSource(
      client: MockClient((req) async {
        requested.add(req.url.host);
        if (req.url.host.contains('coastwatch')) {
          return http.Response('down', 500);
        }
        return http.Response(body, 200);
      }),
    );
    final grid = await source.fetch(bonaire, spanMeters: 4000);
    expect(grid.rows, 3);
    expect(requested, [
      'coastwatch.pfeg.noaa.gov',
      'oceanwatch.pifsc.noaa.gov',
    ]);
  });

  test('throws BathymetryFetchException when all hosts fail', () async {
    final source = EtopoErddapSource(
      client: MockClient((req) async => http.Response('down', 503)),
    );
    expect(
      () => source.fetch(bonaire, spanMeters: 4000),
      throwsA(isA<BathymetryFetchException>()),
    );
  });

  test('throws BathymetryFetchException on unparseable body', () async {
    final source = EtopoErddapSource(
      client: MockClient((req) async => http.Response('<html>oops</html>', 200)),
    );
    expect(
      () => source.fetch(bonaire, spanMeters: 4000),
      throwsA(isA<BathymetryFetchException>()),
    );
  });

  test('covers everywhere and is global', () {
    final source = EtopoErddapSource(client: MockClient((_) async => http.Response('', 500)));
    expect(source.covers(const GeoPoint(-80, 170)), isTrue);
    expect(source.global, isTrue);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/bathymetry/data/etopo_erddap_source_test.dart`
Expected: FAIL — classes do not exist.

- [ ] **Step 3: Implement the interface**

```dart
// lib/features/bathymetry/domain/bathymetry_source.dart
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Thrown on any TRANSIENT bathymetry failure (network error, timeout,
/// non-200, unparseable body). Callers must never cache this as an answer.
class BathymetryFetchException implements Exception {
  final String message;
  const BathymetryFetchException(this.message);

  @override
  String toString() => 'BathymetryFetchException: $message';
}

/// One bathymetry provider in the resolver tier.
abstract interface class BathymetrySource {
  String get id;

  /// Whether this source covers the whole globe. Only a dry grid from a
  /// global source proves a coordinate is definitively on land.
  bool get global;

  bool covers(GeoPoint center);

  /// Fetches a depth grid roughly [spanMeters] across centered on [center].
  /// Throws [BathymetryFetchException] on transient failure.
  Future<BathymetryGrid> fetch(GeoPoint center, {required double spanMeters});
}
```

- [ ] **Step 4: Implement the source**

```dart
// lib/features/bathymetry/data/sources/etopo_erddap_source.dart
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'package:submersion/features/bathymetry/data/sources/erddap_grid_parser.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Global fallback tier: NOAA ETOPO 2022 (15 arc-second, ~450 m cells,
/// US public domain) via ERDDAP griddap JSON, with mirror failover.
class EtopoErddapSource implements BathymetrySource {
  static const String sourceId = 'etopo2022';
  static const String _dataset = 'ETOPO_2022_v1_15s';
  static const double _resolutionMeters = 450;
  static const Duration _timeout = Duration(seconds: 10);

  final http.Client _client;
  final List<String> hosts;

  EtopoErddapSource({
    http.Client? client,
    this.hosts = const [
      'https://coastwatch.pfeg.noaa.gov',
      'https://oceanwatch.pifsc.noaa.gov',
    ],
  }) : _client = client ?? http.Client();

  @override
  String get id => sourceId;

  @override
  bool get global => true;

  @override
  bool covers(GeoPoint center) => true;

  @override
  Future<BathymetryGrid> fetch(
    GeoPoint center, {
    required double spanMeters,
  }) async {
    // ~450 m cells need a wide box for enough samples.
    final span = math.max(spanMeters, 10000.0);
    final dLat = span / 2 / 110540.0;
    final dLon =
        span / 2 / (111320.0 * math.cos(center.latitude * math.pi / 180.0));
    Object? lastError;
    for (final host in hosts) {
      final url = Uri.parse(
        '$host/erddap/griddap/$_dataset.json'
        '?z[(${center.latitude - dLat}):(${center.latitude + dLat})]'
        '[(${center.longitude - dLon}):(${center.longitude + dLon})]',
      );
      try {
        final resp = await _client.get(url).timeout(_timeout);
        if (resp.statusCode != 200) {
          lastError = 'HTTP ${resp.statusCode} from $host';
          continue;
        }
        return ErddapGridParser.parse(
          resp.body,
          sourceId: sourceId,
          resolutionMeters: _resolutionMeters,
          fetchedAt: DateTime.now(),
        );
      } on Exception catch (e) {
        lastError = e;
      }
    }
    throw BathymetryFetchException('ETOPO fetch failed: $lastError');
  }
}
```

Note: a `FormatException` from the parser is an `Exception`, so the catch converts unparseable bodies into failover/`BathymetryFetchException` automatically.

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/bathymetry/data/etopo_erddap_source_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/bathymetry test/features/bathymetry
git commit -m "feat(bathymetry): add BathymetrySource interface and ETOPO ERDDAP source"
```

---

### Task 4: EMODnet source with coverage boxes

**Files:**
- Create: `lib/features/bathymetry/data/sources/emodnet_source.dart`
- Test: `test/features/bathymetry/data/emodnet_source_test.dart`

**Interfaces:**
- Consumes: `BathymetrySource`, `BathymetryFetchException` (Task 3), `ErddapGridParser` (Task 2).
- Produces: `EmodnetSource({http.Client? client, String baseUrl = 'https://erddap.emodnet.eu'})` with `id == 'emodnet'`, `global == false`; `covers()` true only inside the European or Caribbean DTM boxes.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/bathymetry/data/emodnet_source_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/bathymetry/data/sources/emodnet_source.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  final body = File(
    'test/fixtures/bathymetry/emodnet_carib.json',
  ).readAsStringSync();

  EmodnetSource source(http.MockClientHandler handler) =>
      EmodnetSource(client: MockClient(handler));

  test('covers Europe and the Caribbean tile, nothing else', () {
    final s = source((_) async => http.Response('', 500));
    expect(s.covers(const GeoPoint(43.2, 4.5)), isTrue); // Mediterranean
    expect(s.covers(const GeoPoint(12.16, -68.29)), isTrue); // Bonaire
    expect(s.covers(const GeoPoint(36.6, -121.9)), isFalse); // Monterey
    expect(s.covers(const GeoPoint(-8.5, 115.5)), isFalse); // Bali
    expect(s.global, isFalse);
  });

  test('selects the Caribbean dataset for a Caribbean coordinate', () async {
    late Uri requested;
    final s = source((req) async {
      requested = req.url;
      return http.Response(body, 200);
    });
    final grid = await s.fetch(const GeoPoint(12.16, -68.29), spanMeters: 4000);
    expect(grid.sourceId, 'emodnet');
    expect(requested.path, contains('bathymetry_dtm_carib_2024'));
    expect(requested.query, contains('elevation'));
  });

  test('selects the European dataset for a European coordinate', () async {
    late Uri requested;
    final s = source((req) async {
      requested = req.url;
      return http.Response(body, 200);
    });
    await s.fetch(const GeoPoint(43.2, 4.5), spanMeters: 4000);
    expect(requested.path, contains('bathymetry_dtm_2024'));
    expect(requested.path, isNot(contains('carib')));
  });

  test('throws BathymetryFetchException on server error', () async {
    final s = source((_) async => http.Response('down', 502));
    expect(
      () => s.fetch(const GeoPoint(12.16, -68.29), spanMeters: 4000),
      throwsA(isA<BathymetryFetchException>()),
    );
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/bathymetry/data/emodnet_source_test.dart`
Expected: FAIL — class does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/features/bathymetry/data/sources/emodnet_source.dart
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'package:submersion/features/bathymetry/data/sources/erddap_grid_parser.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

typedef _Box = ({
  double minLat,
  double maxLat,
  double minLon,
  double maxLon,
  String dataset,
});

/// Regional tier: EMODnet Bathymetry DTM 2024 (~115 m surveyed, CC-BY 4.0)
/// via its ERDDAP server. Covers European seas plus one Caribbean tile.
/// Vertical datum is LAT (not MSL) — fine standalone, never mix its cells
/// into another source's grid.
class EmodnetSource implements BathymetrySource {
  static const String sourceId = 'emodnet';
  static const double _resolutionMeters = 115;
  static const Duration _timeout = Duration(seconds: 10);

  static const _Box _carib = (
    minLat: 11.0,
    maxLat: 19.0,
    minLon: -70.5,
    maxLon: -59.5,
    dataset: 'bathymetry_dtm_carib_2024',
  );
  static const _Box _europe = (
    minLat: 15.0,
    maxLat: 90.0,
    minLon: -36.0,
    maxLon: 43.0,
    dataset: 'bathymetry_dtm_2024',
  );

  final http.Client _client;
  final String baseUrl;

  EmodnetSource({http.Client? client, this.baseUrl = 'https://erddap.emodnet.eu'})
    : _client = client ?? http.Client();

  @override
  String get id => sourceId;

  @override
  bool get global => false;

  static bool _inBox(GeoPoint p, _Box b) =>
      p.latitude >= b.minLat &&
      p.latitude <= b.maxLat &&
      p.longitude >= b.minLon &&
      p.longitude <= b.maxLon;

  @override
  bool covers(GeoPoint center) =>
      _inBox(center, _carib) || _inBox(center, _europe);

  @override
  Future<BathymetryGrid> fetch(
    GeoPoint center, {
    required double spanMeters,
  }) async {
    final box = _inBox(center, _carib) ? _carib : _europe;
    final dLat = spanMeters / 2 / 110540.0;
    final dLon =
        spanMeters /
        2 /
        (111320.0 * math.cos(center.latitude * math.pi / 180.0));
    final url = Uri.parse(
      '$baseUrl/erddap/griddap/${box.dataset}.json'
      '?elevation[(${center.latitude - dLat}):(${center.latitude + dLat})]'
      '[(${center.longitude - dLon}):(${center.longitude + dLon})]',
    );
    try {
      final resp = await _client.get(url).timeout(_timeout);
      if (resp.statusCode != 200) {
        throw BathymetryFetchException('EMODnet HTTP ${resp.statusCode}');
      }
      return ErddapGridParser.parse(
        resp.body,
        sourceId: sourceId,
        resolutionMeters: _resolutionMeters,
        fetchedAt: DateTime.now(),
      );
    } on BathymetryFetchException {
      rethrow;
    } on Exception catch (e) {
      throw BathymetryFetchException('EMODnet fetch failed: $e');
    }
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/bathymetry/data/emodnet_source_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/bathymetry test/features/bathymetry
git commit -m "feat(bathymetry): add EMODnet DTM source with coverage boxes"
```

---

### Task 5: GMRT source + ESRI ASCII parser

**Files:**
- Create: `lib/features/bathymetry/data/sources/esri_ascii_parser.dart`
- Create: `lib/features/bathymetry/data/sources/gmrt_source.dart`
- Create: `test/fixtures/bathymetry/gmrt_bonaire.asc`
- Test: `test/features/bathymetry/data/gmrt_source_test.dart`

**Interfaces:**
- Consumes: `BathymetrySource`, `BathymetryFetchException` (Task 3), `BathymetryGrid` (Task 1).
- Produces:
  - `EsriAsciiGridParser.parse(String body, {required String sourceId, required DateTime fetchedAt}) -> BathymetryGrid` (throws `FormatException` on malformed bodies).
  - `GmrtSource({http.Client? client, String baseUrl = 'https://www.gmrt.org'})` with `id == 'gmrt'`, `global == true`.

Spec deviation note: the spec mentions calling GMRT's metadata endpoint to size requests. With a fixed ~4 km request box and `resolution=high` (~61 m cells → ~66×66 grid, under the 120 cap), the metadata round-trip adds a failure mode without changing the outcome, so it is omitted; the repository's `downsampleTo(120)` guards the cap regardless.

- [ ] **Step 1: Write the fixture**

`test/fixtures/bathymetry/gmrt_bonaire.asc` — real GMRT quirks: scientific-notation cellsize, literal nodata sentinel, first data line is the NORTHERNMOST row:

```
ncols 4
nrows 3
xllcorner -68.311
yllcorner 12.139
cellsize 5.4931640625E-4
nodata_value -2147483648
-348.48 -344.16 -339.85 -335.52
-352.10 -347.90 -2147483648 -339.00
-355.00 -351.25 12.5 -342.33
```

- [ ] **Step 2: Write the failing tests**

```dart
// test/features/bathymetry/data/gmrt_source_test.dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/bathymetry/data/sources/esri_ascii_parser.dart';
import 'package:submersion/features/bathymetry/data/sources/gmrt_source.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  final body = File(
    'test/fixtures/bathymetry/gmrt_bonaire.asc',
  ).readAsStringSync();
  final when = DateTime.utc(2026, 7, 28);

  group('EsriAsciiGridParser', () {
    test('parses header, flips rows to south-first, negates elevation', () {
      final g = EsriAsciiGridParser.parse(body, sourceId: 'gmrt', fetchedAt: when);
      expect(g.rows, 3);
      expect(g.cols, 4);
      // Origin is the CELL CENTER: corner + cellsize/2.
      expect(g.originLon, closeTo(-68.311 + 5.4931640625e-4 / 2, 1e-12));
      expect(g.originLat, closeTo(12.139 + 5.4931640625e-4 / 2, 1e-12));
      expect(g.cellSizeLatDeg, closeTo(5.4931640625e-4, 1e-15));
      // Last data line is the SOUTHERNMOST row -> grid row 0.
      expect(g.depthAt(0, 0), closeTo(355.00, 1e-9));
      // First data line is the northernmost -> grid row 2.
      expect(g.depthAt(2, 0), closeTo(348.48, 1e-9));
      // nodata sentinel becomes null.
      expect(g.depthAt(1, 2), isNull);
      // Land elevation +12.5 -> depth -12.5.
      expect(g.depthAt(0, 2), closeTo(-12.5, 1e-9));
      // Resolution derived from cellsize with the cos(latitude) factor:
      // 5.4931640625e-4 * 111320 * cos(12.14 deg) ~= 59.8 m.
      expect(g.resolutionMeters, closeTo(59.8, 1.0));
    });

    test('throws FormatException on a missing header field', () {
      expect(
        () => EsriAsciiGridParser.parse(
          'ncols 4\nnrows 3\n-1 -2 -3 -4',
          sourceId: 'gmrt',
          fetchedAt: when,
        ),
        throwsFormatException,
      );
    });
  });

  group('GmrtSource', () {
    test('requests esriascii at high resolution and parses the grid', () async {
      late Uri requested;
      final source = GmrtSource(
        client: MockClient((req) async {
          requested = req.url;
          return http.Response(body, 200);
        }),
      );
      final grid = await source.fetch(
        const GeoPoint(12.16, -68.29),
        spanMeters: 4000,
      );
      expect(grid.sourceId, 'gmrt');
      expect(requested.host, 'www.gmrt.org');
      expect(requested.queryParameters['format'], 'esriascii');
      expect(requested.queryParameters['resolution'], 'high');
      expect(double.parse(requested.queryParameters['north']!),
          greaterThan(double.parse(requested.queryParameters['south']!)));
    });

    test('throws BathymetryFetchException on server error or bad body', () async {
      final erroring = GmrtSource(
        client: MockClient((_) async => http.Response('oops', 500)),
      );
      expect(
        () => erroring.fetch(const GeoPoint(12.16, -68.29), spanMeters: 4000),
        throwsA(isA<BathymetryFetchException>()),
      );
      final garbled = GmrtSource(
        client: MockClient((_) async => http.Response('<html></html>', 200)),
      );
      expect(
        () => garbled.fetch(const GeoPoint(12.16, -68.29), spanMeters: 4000),
        throwsA(isA<BathymetryFetchException>()),
      );
    });
  });
}
```

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/features/bathymetry/data/gmrt_source_test.dart`
Expected: FAIL — classes do not exist.

- [ ] **Step 4: Implement the parser**

```dart
// lib/features/bathymetry/data/sources/esri_ascii_parser.dart
import 'dart:math' as math;

import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';

/// Parses an ESRI ASCII grid (GMRT `format=esriascii`). Quirks handled:
/// scientific-notation cellsize, literal `nodata_value` cells, and data
/// lines running NORTH to SOUTH (flipped here to the app's south-first
/// row order). Values are elevation meters — negated into positive-down
/// depths.
class EsriAsciiGridParser {
  static BathymetryGrid parse(
    String body, {
    required String sourceId,
    required DateTime fetchedAt,
  }) {
    final lines = body.trim().split(RegExp(r'\r?\n'));
    final header = <String, double>{};
    var i = 0;
    while (i < lines.length) {
      final parts = lines[i].trim().split(RegExp(r'\s+'));
      if (parts.length == 2 &&
          double.tryParse(parts[0]) == null &&
          double.tryParse(parts[1]) != null) {
        header[parts[0].toLowerCase()] = double.parse(parts[1]);
        i++;
      } else {
        break;
      }
    }
    double require(String key) =>
        header[key] ?? (throw FormatException('missing ESRI header: $key'));
    final ncols = require('ncols').toInt();
    final nrows = require('nrows').toInt();
    final xll = require('xllcorner');
    final yll = require('yllcorner');
    final cellsize = require('cellsize');
    final nodata = header['nodata_value'];
    if (lines.length - i < nrows) {
      throw const FormatException('ESRI grid has fewer data lines than nrows');
    }

    final depths = List<double?>.filled(nrows * ncols, null);
    for (var r = 0; r < nrows; r++) {
      final vals = lines[i + r].trim().split(RegExp(r'\s+'));
      if (vals.length < ncols) {
        throw const FormatException('ESRI data line shorter than ncols');
      }
      final gridRow = nrows - 1 - r; // flip: first line is northernmost
      for (var c = 0; c < ncols; c++) {
        final v = double.parse(vals[c]);
        depths[gridRow * ncols + c] = (nodata != null && v == nodata)
            ? null
            : -v;
      }
    }

    final centerLat = yll + cellsize * nrows / 2;
    return BathymetryGrid(
      originLat: yll + cellsize / 2,
      originLon: xll + cellsize / 2,
      cellSizeLatDeg: cellsize,
      cellSizeLonDeg: cellsize,
      rows: nrows,
      cols: ncols,
      depthsMeters: depths,
      sourceId: sourceId,
      resolutionMeters:
          cellsize * 111320.0 * math.cos(centerLat * math.pi / 180.0),
      fetchedAt: fetchedAt,
    );
  }
}
```

- [ ] **Step 5: Implement the source**

```dart
// lib/features/bathymetry/data/sources/gmrt_source.dart
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'package:submersion/features/bathymetry/data/sources/esri_ascii_parser.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Global primary tier: GMRT GridServer (CC-BY 4.0). Best-available
/// resolution everywhere (~61 m where ship multibeam exists, ~450 m
/// GEBCO-based background elsewhere).
class GmrtSource implements BathymetrySource {
  static const String sourceId = 'gmrt';
  static const Duration _timeout = Duration(seconds: 10);

  final http.Client _client;
  final String baseUrl;

  GmrtSource({http.Client? client, this.baseUrl = 'https://www.gmrt.org'})
    : _client = client ?? http.Client();

  @override
  String get id => sourceId;

  @override
  bool get global => true;

  @override
  bool covers(GeoPoint center) => true;

  @override
  Future<BathymetryGrid> fetch(
    GeoPoint center, {
    required double spanMeters,
  }) async {
    final dLat = spanMeters / 2 / 110540.0;
    final dLon =
        spanMeters /
        2 /
        (111320.0 * math.cos(center.latitude * math.pi / 180.0));
    final url = Uri.parse('$baseUrl/services/GridServer').replace(
      queryParameters: {
        'north': '${center.latitude + dLat}',
        'south': '${center.latitude - dLat}',
        'east': '${center.longitude + dLon}',
        'west': '${center.longitude - dLon}',
        'format': 'esriascii',
        'resolution': 'high',
      },
    );
    try {
      final resp = await _client.get(url).timeout(_timeout);
      if (resp.statusCode != 200) {
        throw BathymetryFetchException('GMRT HTTP ${resp.statusCode}');
      }
      return EsriAsciiGridParser.parse(
        resp.body,
        sourceId: sourceId,
        fetchedAt: DateTime.now(),
      );
    } on BathymetryFetchException {
      rethrow;
    } on Exception catch (e) {
      throw BathymetryFetchException('GMRT fetch failed: $e');
    }
  }
}
```

- [ ] **Step 6: Run to verify pass**

Run: `flutter test test/features/bathymetry/data/gmrt_source_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/bathymetry test/features/bathymetry test/fixtures/bathymetry
git commit -m "feat(bathymetry): add GMRT GridServer source with ESRI ASCII parser"
```

---

### Task 6: BathymetryResolver

**Files:**
- Create: `lib/features/bathymetry/data/bathymetry_resolver.dart`
- Test: `test/features/bathymetry/data/bathymetry_resolver_test.dart`

**Interfaces:**
- Consumes: `BathymetrySource`, `BathymetryFetchException` (Task 3), `BathymetryGrid` (Task 1).
- Produces:
  - `class BathymetryResolution { final BathymetryGrid? grid; final bool definitive; }` with named constructors `.ok(grid)` (definitive true), `.empty()` (grid null, definitive true — cacheable negative), `.transientFailure()` (grid null, definitive false — never cache).
  - `class BathymetryResolver { const BathymetryResolver({required List<BathymetrySource> sources}); Future<BathymetryResolution> resolve(GeoPoint center); }` with `static const double minWetFraction = 0.10;` and `static const double defaultSpanMeters = 4000;`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/bathymetry/data/bathymetry_resolver_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_resolver.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

BathymetryGrid gridWith(List<double?> depths, String sourceId) =>
    BathymetryGrid(
      originLat: 12.14,
      originLon: -68.31,
      cellSizeLatDeg: 0.004,
      cellSizeLonDeg: 0.004,
      rows: 1,
      cols: depths.length,
      depthsMeters: depths,
      sourceId: sourceId,
      resolutionMeters: 100,
      fetchedAt: DateTime.utc(2026, 7, 28),
    );

class FakeSource implements BathymetrySource {
  @override
  final String id;
  @override
  final bool global;
  final bool coversIt;
  final BathymetryGrid? result; // null => throw transient
  int fetchCount = 0;

  FakeSource(this.id, {this.global = true, this.coversIt = true, this.result});

  @override
  bool covers(GeoPoint center) => coversIt;

  @override
  Future<BathymetryGrid> fetch(GeoPoint c, {required double spanMeters}) async {
    fetchCount++;
    final r = result;
    if (r == null) throw BathymetryFetchException('down');
    return r;
  }
}

void main() {
  const p = GeoPoint(12.16, -68.29);
  final wet = [for (var i = 0; i < 10; i++) 50.0];
  final dry = [for (var i = 0; i < 10; i++) -5.0];

  test('first covering source with a wet grid wins; later tiers untouched',
      () async {
    final a = FakeSource('a', result: gridWith(wet, 'a'));
    final b = FakeSource('b', result: gridWith(wet, 'b'));
    final res = await BathymetryResolver(sources: [a, b]).resolve(p);
    expect(res.grid!.sourceId, 'a');
    expect(res.definitive, isTrue);
    expect(b.fetchCount, 0);
  });

  test('skips sources that do not cover the coordinate', () async {
    final a = FakeSource('a', coversIt: false, result: gridWith(wet, 'a'));
    final b = FakeSource('b', result: gridWith(wet, 'b'));
    final res = await BathymetryResolver(sources: [a, b]).resolve(p);
    expect(res.grid!.sourceId, 'b');
    expect(a.fetchCount, 0);
  });

  test('falls through a transient failure to the next tier', () async {
    final a = FakeSource('a'); // throws
    final b = FakeSource('b', result: gridWith(wet, 'b'));
    final res = await BathymetryResolver(sources: [a, b]).resolve(p);
    expect(res.grid!.sourceId, 'b');
  });

  test('dry grid from a GLOBAL source is a definitive empty', () async {
    final a = FakeSource('a', result: gridWith(dry, 'a'));
    final res = await BathymetryResolver(sources: [a]).resolve(p);
    expect(res.grid, isNull);
    expect(res.definitive, isTrue);
  });

  test('dry regional + failing global is transient, not empty', () async {
    final regional =
        FakeSource('r', global: false, result: gridWith(dry, 'r'));
    final globalDown = FakeSource('g'); // throws
    final res =
        await BathymetryResolver(sources: [regional, globalDown]).resolve(p);
    expect(res.grid, isNull);
    expect(res.definitive, isFalse);
  });

  test('all sources failing is transient', () async {
    final res =
        await BathymetryResolver(sources: [FakeSource('a'), FakeSource('b')])
            .resolve(p);
    expect(res.grid, isNull);
    expect(res.definitive, isFalse);
  });

  test('a barely-wet grid below 10% is treated as dry', () async {
    // 1 wet cell of 11 known => ~9%.
    final depths = [50.0, ...List<double?>.filled(10, -1.0)];
    final a = FakeSource('a', result: gridWith(depths, 'a'));
    final res = await BathymetryResolver(sources: [a]).resolve(p);
    expect(res.grid, isNull);
    expect(res.definitive, isTrue);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/bathymetry/data/bathymetry_resolver_test.dart`
Expected: FAIL — classes do not exist.

- [ ] **Step 3: Implement**

```dart
// lib/features/bathymetry/data/bathymetry_resolver.dart
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// The outcome of walking the source tiers for one coordinate.
///
/// - `grid != null`: usable terrain (definitive).
/// - `grid == null && definitive`: fetched fine, genuinely no water here —
///   cacheable as a negative answer.
/// - `grid == null && !definitive`: transient failure — must NOT be cached.
class BathymetryResolution {
  final BathymetryGrid? grid;
  final bool definitive;

  const BathymetryResolution.ok(BathymetryGrid this.grid) : definitive = true;
  const BathymetryResolution.empty() : grid = null, definitive = true;
  const BathymetryResolution.transientFailure()
    : grid = null,
      definitive = false;
}

/// Best-source-wins: walks the ordered tiers and returns the first grid
/// with enough wet cells. No mosaicking — sources use different vertical
/// datums (EMODnet is LAT, GMRT/ETOPO MSL) and stitching them seams.
class BathymetryResolver {
  static const double minWetFraction = 0.10;
  static const double defaultSpanMeters = 4000;

  final List<BathymetrySource> sources;

  const BathymetryResolver({required this.sources});

  Future<BathymetryResolution> resolve(GeoPoint center) async {
    var globalSourceSaidDry = false;
    for (final source in sources) {
      if (!source.covers(center)) continue;
      try {
        final grid = await source.fetch(
          center,
          spanMeters: defaultSpanMeters,
        );
        if (grid.wetFraction >= minWetFraction) {
          return BathymetryResolution.ok(grid);
        }
        // A dry answer only proves "no water here" if the source actually
        // covers everywhere; a regional edge cell proves nothing.
        if (source.global) globalSourceSaidDry = true;
      } on BathymetryFetchException {
        // Transient: fall through to the next tier.
      }
    }
    return globalSourceSaidDry
        ? const BathymetryResolution.empty()
        : const BathymetryResolution.transientFailure();
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/bathymetry/data/bathymetry_resolver_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/bathymetry test/features/bathymetry
git commit -m "feat(bathymetry): add best-source-wins resolver"
```

---

### Task 7: BathymetryCache table (local cache DB v6 → v7)

**Files:**
- Modify: `lib/core/database/local_cache_database.dart` (add table, bump `schemaVersion` to 7, add migration guard)
- Test: `test/core/database/local_cache_migration_v7_bathymetry_test.dart`

**Interfaces:**
- Consumes: existing `LocalCacheDatabase` (Drift).
- Produces: Drift table `BathymetryCache` with columns `cacheKey (text, PK)`, `centerLat (real)`, `centerLon (real)`, `status (text: 'ok' | 'empty' | 'unavailable')`, `sourceId (text?)`, `resolutionMeters (real?)`, `gridJson (text?)`, `fetchedAt (integer, epoch millis)`. Generated companion `BathymetryCacheCompanion`. `'unavailable'` is an allowed value reserved for future definitive-negative variants; v1 writes only `'ok'` and `'empty'`.

**LADDER WARNING:** PR #728 (reef data, unmerged branch `worktree-reef-data`) also claims local-DB v7 with its own `ReefDataCache` table. Whichever branch merges SECOND renumbers its bump to v8 (both migrations are a single guarded `createTable`, so the conflict is textual and simple). Do not renumber preemptively.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/database/local_cache_migration_v7_bathymetry_test.dart
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';

void main() {
  test('fresh database exposes bathymetry_cache at v7', () async {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(db.schemaVersion, 7);
    await db
        .into(db.bathymetryCache)
        .insert(
          BathymetryCacheCompanion.insert(
            cacheKey: '12.16,-68.30',
            centerLat: 12.17,
            centerLon: -68.29,
            status: 'ok',
            sourceId: const Value('gmrt'),
            resolutionMeters: const Value(61.0),
            gridJson: const Value('{}'),
            fetchedAt: 1753600000000,
          ),
        );
    final rows = await db.select(db.bathymetryCache).get();
    expect(rows.single.status, 'ok');
    expect(rows.single.sourceId, 'gmrt');
  });

  test('upgrade from a stored v6 schema creates bathymetry_cache', () async {
    final db = LocalCacheDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          // Minimal v6 shape: the migration only creates the new table, so
          // the pre-existing tables need to exist, not be column-perfect.
          raw
            ..execute('CREATE TABLE local_asset_cache '
                '(media_id TEXT PRIMARY KEY, local_asset_id TEXT, '
                'resolved_at INTEGER, resolution_method TEXT, '
                'attempt_count INTEGER)')
            ..execute('CREATE TABLE media_transfer_queue '
                '(id INTEGER PRIMARY KEY AUTOINCREMENT, media_id TEXT)')
            ..execute('CREATE TABLE media_cache_entries '
                '(content_hash TEXT, kind TEXT, PRIMARY KEY (content_hash, kind))')
            ..execute('PRAGMA user_version = 6');
        },
      ),
    );
    addTearDown(db.close);
    // Any query forces open + migration.
    final rows = await db.select(db.bathymetryCache).get();
    expect(rows, isEmpty);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/core/database/local_cache_migration_v7_bathymetry_test.dart`
Expected: FAIL — `bathymetryCache` getter does not exist (compile error).

- [ ] **Step 3: Implement**

In `lib/core/database/local_cache_database.dart`, add the table class after `MediaCacheEntries`:

```dart
/// Cached bathymetry grids keyed by quantized coordinate (0.02 degree
/// cells). Re-derivable third-party data: never synced, never backed up.
/// status semantics: 'ok' = usable grid in gridJson; 'empty' = fetched
/// fine, definitively no water here; 'unavailable' = reserved for future
/// definitive negatives. Transient failures write NO row.
class BathymetryCache extends Table {
  TextColumn get cacheKey => text()();
  RealColumn get centerLat => real()();
  RealColumn get centerLon => real()();
  TextColumn get status => text()();
  TextColumn get sourceId => text().nullable()();
  RealColumn get resolutionMeters => real().nullable()();
  TextColumn get gridJson => text().nullable()();
  IntColumn get fetchedAt => integer()();

  @override
  Set<Column> get primaryKey => {cacheKey};
}
```

Then three edits to the database class:

1. `@DriftDatabase(tables: [LocalAssetCache, MediaTransferQueue, MediaCacheEntries, BathymetryCache])`
2. `int get schemaVersion => 7;`
3. Append inside `onUpgrade`, after the `from < 6` block:

```dart
      // v7: bathymetry grid cache. NOTE: the reef-data branch (PR #728)
      // also claims v7 on its own branch — whichever merges second
      // renumbers. from < 7 covers both the v1 path and v2..v6 upgrades.
      if (from < 7) {
        await m.createTable(bathymetryCache);
      }
```

Then regenerate: `dart run build_runner build --delete-conflicting-outputs`

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/core/database/local_cache_migration_v7_bathymetry_test.dart`
Expected: PASS (2 tests).

Also run the existing local-cache consumers to catch regressions:
`flutter test test/core/database/ test/core/services/`
Expected: PASS.

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/core/database/local_cache_database.dart test/core/database/local_cache_migration_v7_bathymetry_test.dart
git commit -m "feat(bathymetry): add BathymetryCache table to local cache DB (v7)"
```

---

### Task 8: BathymetryRepository (cache-first, quantized keys, dedupe)

**Files:**
- Create: `lib/features/bathymetry/data/bathymetry_repository.dart`
- Test: `test/features/bathymetry/data/bathymetry_repository_test.dart`

**Interfaces:**
- Consumes: `LocalCacheDatabase` + `BathymetryCacheCompanion` (Task 7), `BathymetryResolver`/`BathymetryResolution` (Task 6), `BathymetryGrid` (Task 1), `GeoPoint`.
- Produces:
  - `BathymetryRepository({required LocalCacheDatabase db, required BathymetryResolver resolver})`
  - `static ({double lat, double lon}) quantize(GeoPoint c)` — floor to 0.02° cells.
  - `static String keyFor(GeoPoint c)` — e.g. `'12.16,-68.30'` (two decimals).
  - `Future<BathymetryGrid?> getGrid(GeoPoint center)` — never throws; null means "no real terrain" (empty, unavailable, or transient).
  - `static const int maxGridDim = 120;` `static const double quantumDeg = 0.02;`

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/bathymetry/data/bathymetry_repository_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_resolver.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

BathymetryGrid wetGrid() => BathymetryGrid(
  originLat: 12.14,
  originLon: -68.31,
  cellSizeLatDeg: 0.004,
  cellSizeLonDeg: 0.004,
  rows: 2,
  cols: 2,
  depthsMeters: const [10, 20, 30, 40],
  sourceId: 'gmrt',
  resolutionMeters: 61,
  fetchedAt: DateTime.utc(2026, 7, 28),
);

/// A resolver double: scripted resolutions, counts calls.
class ScriptedSource implements BathymetrySource {
  final BathymetryResolution Function() script;
  int calls = 0;
  ScriptedSource(this.script);

  @override
  String get id => 'scripted';
  @override
  bool get global => true;
  @override
  bool covers(GeoPoint center) => true;
  @override
  Future<BathymetryGrid> fetch(GeoPoint c, {required double spanMeters}) async {
    calls++;
    final r = script();
    final g = r.grid;
    if (g != null) return g;
    if (r.definitive) {
      // Definitive dry: return an all-land grid.
      return BathymetryGrid(
        originLat: 0,
        originLon: 0,
        cellSizeLatDeg: 0.004,
        cellSizeLonDeg: 0.004,
        rows: 1,
        cols: 4,
        depthsMeters: const [-1, -2, -3, -4],
        sourceId: 'scripted',
        resolutionMeters: 61,
        fetchedAt: DateTime.utc(2026, 7, 28),
      );
    }
    throw const BathymetryFetchException('down');
  }
}

void main() {
  const bonaire = GeoPoint(12.16, -68.29);

  late LocalCacheDatabase db;
  setUp(() => db = LocalCacheDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  BathymetryRepository repo(ScriptedSource source) => BathymetryRepository(
    db: db,
    resolver: BathymetryResolver(sources: [source]),
  );

  test('quantize floors onto 0.02 degree cells (negative coords too)', () {
    final q = BathymetryRepository.quantize(bonaire);
    expect(q.lat, closeTo(12.16, 1e-9));
    expect(q.lon, closeTo(-68.30, 1e-9)); // -68.29 floors DOWN to -68.30
    expect(BathymetryRepository.keyFor(bonaire), '12.16,-68.30');
    // Nearby coordinates share the key.
    expect(
      BathymetryRepository.keyFor(const GeoPoint(12.171, -68.281)),
      '12.16,-68.30',
    );
  });

  test('ok result is cached: second call does not re-resolve', () async {
    final source = ScriptedSource(() => BathymetryResolution.ok(wetGrid()));
    final r = repo(source);
    final first = await r.getGrid(bonaire);
    expect(first!.sourceId, 'gmrt');
    final second = await r.getGrid(bonaire);
    expect(second!.depthsMeters, first.depthsMeters);
    expect(source.calls, 1);
  });

  test('definitive empty is cached as a negative answer', () async {
    final source =
        ScriptedSource(() => const BathymetryResolution.empty());
    final r = repo(source);
    expect(await r.getGrid(bonaire), isNull);
    expect(await r.getGrid(bonaire), isNull);
    expect(source.calls, 1); // negative answer cached
    final row = await db.select(db.bathymetryCache).getSingle();
    expect(row.status, 'empty');
    expect(row.gridJson, isNull);
  });

  test('transient failure writes NO row and retries next call', () async {
    final source =
        ScriptedSource(() => const BathymetryResolution.transientFailure());
    final r = repo(source);
    expect(await r.getGrid(bonaire), isNull);
    expect(await db.select(db.bathymetryCache).get(), isEmpty);
    expect(await r.getGrid(bonaire), isNull);
    expect(source.calls, 2); // retried
  });

  test('concurrent calls for one key share a single resolve', () async {
    final source = ScriptedSource(() => BathymetryResolution.ok(wetGrid()));
    final r = repo(source);
    final results = await Future.wait([
      r.getGrid(bonaire),
      r.getGrid(const GeoPoint(12.171, -68.281)), // same quantized cell
    ]);
    expect(results[0], isNotNull);
    expect(results[1], isNotNull);
    expect(source.calls, 1);
  });

  test('oversized grids are downsampled before caching', () async {
    final big = BathymetryGrid(
      originLat: 12.14,
      originLon: -68.31,
      cellSizeLatDeg: 0.0001,
      cellSizeLonDeg: 0.0001,
      rows: 200,
      cols: 200,
      depthsMeters: List<double?>.filled(200 * 200, 10),
      sourceId: 'gmrt',
      resolutionMeters: 10,
      fetchedAt: DateTime.utc(2026, 7, 28),
    );
    final source = ScriptedSource(() => BathymetryResolution.ok(big));
    final grid = await repo(source).getGrid(bonaire);
    expect(grid!.rows, lessThanOrEqualTo(120));
    expect(grid.cols, lessThanOrEqualTo(120));
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/bathymetry/data/bathymetry_repository_test.dart`
Expected: FAIL — repository does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/features/bathymetry/data/bathymetry_repository.dart
import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_resolver.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Cache-first bathymetry access. Grids cache per quantized 0.02 degree
/// coordinate cell (nearby sites, re-pinned sites, and site-less GPS dives
/// share one fetch). Definitive negatives cache as 'empty'; transient
/// failures write NO row so the next visit retries. Never throws: null
/// simply means "no real terrain available right now".
class BathymetryRepository {
  static const int maxGridDim = 120;
  static const double quantumDeg = 0.02;

  final LocalCacheDatabase _db;
  final BathymetryResolver _resolver;
  final Map<String, Future<BathymetryGrid?>> _inFlight = {};

  BathymetryRepository({
    required LocalCacheDatabase db,
    required BathymetryResolver resolver,
  }) : _db = db,
       _resolver = resolver;

  static ({double lat, double lon}) quantize(GeoPoint c) {
    double q(double v) => (v / quantumDeg).floorToDouble() * quantumDeg;
    return (lat: q(c.latitude), lon: q(c.longitude));
  }

  static String keyFor(GeoPoint c) {
    final q = quantize(c);
    return '${q.lat.toStringAsFixed(2)},${q.lon.toStringAsFixed(2)}';
  }

  Future<BathymetryGrid?> getGrid(GeoPoint center) {
    final key = keyFor(center);
    return _inFlight[key] ??= _load(key, center)
      ..whenComplete(() => _inFlight.remove(key));
  }

  Future<BathymetryGrid?> _load(String key, GeoPoint center) async {
    final row = await (_db.select(
      _db.bathymetryCache,
    )..where((t) => t.cacheKey.equals(key))).getSingleOrNull();
    if (row != null) {
      final json = row.gridJson;
      if (row.status == 'ok' && json != null) {
        return BathymetryGrid.fromJson(
          jsonDecode(json) as Map<String, dynamic>,
        );
      }
      return null; // 'empty' / 'unavailable': definitive, no refetch
    }

    // Fetch centered on the quantized CELL CENTER so every coordinate in
    // the cell gets the same, fully covering grid.
    final q = quantize(center);
    final fetchCenter = GeoPoint(
      q.lat + quantumDeg / 2,
      q.lon + quantumDeg / 2,
    );
    final res = await _resolver.resolve(fetchCenter);
    final resolved = res.grid;
    if (resolved != null) {
      final grid = resolved.downsampleTo(maxGridDim);
      await _db
          .into(_db.bathymetryCache)
          .insertOnConflictUpdate(
            BathymetryCacheCompanion.insert(
              cacheKey: key,
              centerLat: fetchCenter.latitude,
              centerLon: fetchCenter.longitude,
              status: 'ok',
              sourceId: Value(grid.sourceId),
              resolutionMeters: Value(grid.resolutionMeters),
              gridJson: Value(jsonEncode(grid.toJson())),
              fetchedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
      return grid;
    }
    if (res.definitive) {
      await _db
          .into(_db.bathymetryCache)
          .insertOnConflictUpdate(
            BathymetryCacheCompanion.insert(
              cacheKey: key,
              centerLat: fetchCenter.latitude,
              centerLon: fetchCenter.longitude,
              status: 'empty',
              fetchedAt: DateTime.now().millisecondsSinceEpoch,
            ),
          );
    }
    return null; // transient: no row, next call retries
  }
}
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/bathymetry/data/bathymetry_repository_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/bathymetry test/features/bathymetry
git commit -m "feat(bathymetry): add cache-first repository with quantized keys"
```

---

### Task 9: Riverpod providers

**Files:**
- Create: `lib/features/bathymetry/application/bathymetry_providers.dart`
- Test: `test/features/bathymetry/application/bathymetry_providers_test.dart`

**Interfaces:**
- Consumes: `BathymetryRepository` (Task 8), sources (Tasks 3–5), `LocalCacheDatabaseService` (`lib/core/services/local_cache_database_service.dart`).
- Produces:
  - `final bathymetryRepositoryProvider = Provider<BathymetryRepository?>` — null when the local cache DB is not initialized (early startup, plain unit tests).
  - `final bathymetryGridProvider = FutureProvider.family<BathymetryGrid?, ({double lat, double lon})>` — family key MUST be the quantized pair from `BathymetryRepository.quantize` so equal cells share one provider entry.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/bathymetry/application/bathymetry_providers_test.dart
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  tearDown(() => LocalCacheDatabaseService.instance.resetForTesting());

  test('repository provider is null when the cache DB is uninitialized', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(bathymetryRepositoryProvider), isNull);
  });

  test('repository provider builds once the cache DB exists', () {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    LocalCacheDatabaseService.instance.setTestDatabase(db);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(
      container.read(bathymetryRepositoryProvider),
      isA<BathymetryRepository>(),
    );
  });

  test('grid provider yields null (not an error) without a repository',
      () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final grid = await container.read(
      bathymetryGridProvider(
        BathymetryRepository.quantize(const GeoPoint(12.16, -68.29)),
      ).future,
    );
    expect(grid, isNull);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/bathymetry/application/bathymetry_providers_test.dart`
Expected: FAIL — providers do not exist.

- [ ] **Step 3: Implement**

```dart
// lib/features/bathymetry/application/bathymetry_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_resolver.dart';
import 'package:submersion/features/bathymetry/data/sources/emodnet_source.dart';
import 'package:submersion/features/bathymetry/data/sources/etopo_erddap_source.dart';
import 'package:submersion/features/bathymetry/data/sources/gmrt_source.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Null when the local cache database is not initialized (early startup,
/// plain widget tests): bathymetry silently degrades to synthesized
/// terrain rather than erroring.
final bathymetryRepositoryProvider = Provider<BathymetryRepository?>((ref) {
  try {
    final db = LocalCacheDatabaseService.instance.database;
    return BathymetryRepository(
      db: db,
      resolver: BathymetryResolver(
        // Tier order: regional survey data first, then global GMRT, then
        // the coarse public-domain fallback.
        sources: [EmodnetSource(), GmrtSource(), EtopoErddapSource()],
      ),
    );
  } on StateError {
    return null;
  }
});

/// The cached/fetched grid for a QUANTIZED coordinate cell. Callers must
/// key the family with [BathymetryRepository.quantize] so every coordinate
/// in a cell shares one entry. Never errors: null means no real terrain.
final bathymetryGridProvider =
    FutureProvider.family<BathymetryGrid?, ({double lat, double lon})>((
      ref,
      cell,
    ) async {
      final repo = ref.watch(bathymetryRepositoryProvider);
      if (repo == null) return null;
      return repo.getGrid(GeoPoint(cell.lat, cell.lon));
    });
```

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/bathymetry/application/bathymetry_providers_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Format, analyze, commit — end of Phase A / PR 1**

```bash
dart format . && flutter analyze
flutter test test/features/bathymetry test/core/database/local_cache_migration_v7_bathymetry_test.dart
git add lib/features/bathymetry test/features/bathymetry
git commit -m "feat(bathymetry): expose repository and grid providers"
```

---

## Phase B — site seascape (PR 2)

### Task 10: 3D-positioned markers + paths overlay

**Files:**
- Modify: `lib/features/dive_3d/domain/geometry/marker_layout.dart` (add `z` field and two kinds to `SceneMarker`)
- Modify: `lib/features/dive_3d/presentation/scene_overlay.dart` (add `paths`)
- Modify: `lib/features/dive_3d/presentation/renderer/preview_painter.dart` (`_paintMarkers` uses `marker.z`; colors for new kinds)
- Modify: `lib/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart` (marker tap hit-test uses `marker.z`)
- Test: `test/features/dive_3d/domain/geometry/scene_marker_z_test.dart`

**Interfaces:**
- Consumes: existing `SceneMarker`, `SceneOverlay`, `SceneProjector.project(x, y, z)`.
- Produces: `SceneMarker` gains `final double z;` (constructor param `this.z = 0` — all existing call sites unaffected); `SceneMarkerKind` gains `site` and `nearbySite`; `SceneOverlay` gains `paths`. Nearby-site markers ride the existing `markers` overlay gate; `paths` gates dive-path ribbons in the site scene.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/dive_3d/domain/geometry/scene_marker_z_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';

void main() {
  test('SceneMarker carries z, defaulting to 0 for legacy scenes', () {
    const legacy = SceneMarker(
      kind: SceneMarkerKind.bookmark,
      refId: 'b1',
      label: 'note',
      x: 1,
      y: -2,
      timestampSeconds: 60,
    );
    expect(legacy.z, 0);
    const spatial = SceneMarker(
      kind: SceneMarkerKind.site,
      refId: null,
      label: 'Salt Pier',
      x: 5,
      y: 0.15,
      z: -1.25,
      timestampSeconds: 0,
    );
    expect(spatial.z, -1.25);
  });

  test('new marker kinds and paths overlay exist', () {
    expect(SceneMarkerKind.values, contains(SceneMarkerKind.site));
    expect(SceneMarkerKind.values, contains(SceneMarkerKind.nearbySite));
    expect(SceneOverlay.values, contains(SceneOverlay.paths));
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_3d/domain/geometry/scene_marker_z_test.dart`
Expected: FAIL — no `z`, no new enum values (compile error).

- [ ] **Step 3: Implement**

In `marker_layout.dart`:

```dart
enum SceneMarkerKind { gasSwitch, bookmark, photo, site, nearbySite }
```

and in `SceneMarker` add the field + constructor param (keep the doc comment honest — z is no longer always 0):

```dart
/// A tappable scene annotation. x/y/z are scene coordinates; depth-time
/// scenes leave z at 0 (renderers billboard), spatial scenes position
/// markers in full 3D.
class SceneMarker {
  final SceneMarkerKind kind;
  final String? refId;
  final String label;
  final double x;
  final double y;
  final double z;
  final int timestampSeconds;

  const SceneMarker({
    required this.kind,
    required this.refId,
    required this.label,
    required this.x,
    required this.y,
    this.z = 0,
    required this.timestampSeconds,
  });
}
```

In `scene_overlay.dart`:

```dart
enum SceneOverlay { strata, ceiling, curtain, markers, paths }
```

In `preview_painter.dart` `_paintMarkers` (line ~167): change the projection call and extend the color switch:

```dart
      paint.color = switch (marker.kind) {
        SceneMarkerKind.gasSwitch => const Color(0xFF22C55E),
        SceneMarkerKind.bookmark => const Color(0xFFF59E0B),
        SceneMarkerKind.photo => const Color(0xFF00D4FF),
        SceneMarkerKind.site => const Color(0xFFF43F5E),
        SceneMarkerKind.nearbySite => const Color(0xFF94A3B8),
      };
      canvas.drawCircle(projector.project(marker.x, marker.y, marker.z), 4, paint);
```

In `dive_3d_interactive_viewport.dart` (~line 240): find the marker hit-test loop and change any `project(marker.x, marker.y, 0)` to `project(marker.x, marker.y, marker.z)`. Verify with: `grep -n "marker.x, marker.y" lib/features/dive_3d/` — every hit must pass `marker.z`.

- [ ] **Step 4: Run to verify pass + no regressions**

Run: `flutter test test/features/dive_3d/`
Expected: PASS — the new test plus the entire existing dive_3d suite (marker layout, viewport, painter tests all still green; `z = 0` default keeps old behavior byte-identical).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/dive_3d test/features/dive_3d
git commit -m "feat(dive_3d): 3D marker positions, site marker kinds, paths overlay"
```

---

### Task 11: BathymetryTerrainBuilder

**Files:**
- Create: `lib/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart`
- Test: `test/features/dive_3d/domain/spatial/bathymetry_terrain_builder_test.dart`

**Interfaces:**
- Consumes: `BathymetryGrid` (Task 1), `SpatialProjection`, `SpatialTerrain` + `MeshData` (existing), `GeoPoint`.
- Produces:
  - `static ({double minEast, double maxEast, double minNorth, double maxNorth}) enuBounds(BathymetryGrid grid, GeoPoint center)` — grid extent in local east-north meters relative to `center`.
  - `static SpatialTerrain build({required BathymetryGrid grid, required GeoPoint center, required SpatialProjection projection})` — terrain mesh (rows×cols vertices) + water quad. Land cells (depth < 0) render sand-toned above the waterline, height capped at 15% of `projection.maxDepth`; nodata cells render as shoreline (depth 0, sand tone); wet cells use the existing teal→navy ramp.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/dive_3d/domain/spatial/bathymetry_terrain_builder_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  // 2x3 grid centered near the origin: wet, land, and nodata cells.
  final grid = BathymetryGrid(
    originLat: 12.15,
    originLon: -68.30,
    cellSizeLatDeg: 0.001,
    cellSizeLonDeg: 0.001,
    rows: 2,
    cols: 3,
    depthsMeters: const [30, 60, -8, 90, null, 15],
    sourceId: 'gmrt',
    resolutionMeters: 61,
    fetchedAt: DateTime.utc(2026, 7, 28),
  );
  const center = GeoPoint(12.1505, -68.299);

  SpatialProjection proj() {
    final b = BathymetryTerrainBuilder.enuBounds(grid, center);
    return SpatialProjection(
      minEast: b.minEast,
      maxEast: b.maxEast,
      minNorth: b.minNorth,
      maxNorth: b.maxNorth,
      maxDepth: 90,
    );
  }

  test('enuBounds spans the grid symmetrically around its cells', () {
    final b = BathymetryTerrainBuilder.enuBounds(grid, center);
    expect(b.minEast, lessThan(0)); // origin lon is west of center
    expect(b.maxEast, greaterThan(0));
    expect(b.maxEast - b.minEast,
        closeTo(0.002 * 111320 * 0.977, 20)); // 2 lon steps, cos ~12.15°
    expect(b.maxNorth - b.minNorth, closeTo(0.001 * 110540, 5));
  });

  test('terrain has one vertex per cell and full quad indices', () {
    final t = BathymetryTerrainBuilder.build(
      grid: grid,
      center: center,
      projection: proj(),
    );
    expect(t.terrain.vertexCount, 6);
    expect(t.terrain.indices.length, (2 - 1) * (3 - 1) * 6);
    expect(t.water.vertexCount, 4);
  });

  test('wet cells sit below the waterline, colored by the depth ramp', () {
    final t = BathymetryTerrainBuilder.build(
      grid: grid,
      center: center,
      projection: proj(),
    );
    // Vertex 0 = row 0, col 0 (depth 30): y must be negative.
    expect(t.terrain.positions[1], lessThan(0));
    // Deeper cell (90 m, vertex 3) is lower than shallower (30 m, vertex 0).
    expect(t.terrain.positions[3 * 3 + 1], lessThan(t.terrain.positions[1]));
  });

  test('land cells rise above the waterline with capped height', () {
    final t = BathymetryTerrainBuilder.build(
      grid: grid,
      center: center,
      projection: proj(),
    );
    // Vertex 2 = row 0, col 2 (depth -8 = land).
    final landY = t.terrain.positions[2 * 3 + 1];
    expect(landY, greaterThan(0));
    // Cap: never higher than 15% of maxDepth's scene height.
    expect(landY, lessThanOrEqualTo(0.15 * 6.0 + 1e-9));
  });

  test('nodata cells render as shoreline at y == 0', () {
    final t = BathymetryTerrainBuilder.build(
      grid: grid,
      center: center,
      projection: proj(),
    );
    // Vertex 4 = row 1, col 1 (null).
    expect(t.terrain.positions[4 * 3 + 1], 0);
  });

  test('water plane sits at y == 0', () {
    final t = BathymetryTerrainBuilder.build(
      grid: grid,
      center: center,
      projection: proj(),
    );
    for (var i = 0; i < 4; i++) {
      expect(t.water.positions[i * 3 + 1], 0);
    }
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_3d/domain/spatial/bathymetry_terrain_builder_test.dart`
Expected: FAIL — builder does not exist.

- [ ] **Step 3: Implement**

```dart
// lib/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/domain/spatial/terrain_builder.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Converts real bathymetry into the seascape terrain mesh. Unlike the
/// synthesized [TerrainBuilder], this surface is measured data: it never
/// bends to cradle a dive path. Land cells render sand-toned above the
/// waterline (height capped so shorelines read without dominating);
/// nodata cells fill as shoreline at the waterline.
class BathymetryTerrainBuilder {
  static const Color _shallow = Color(0xFF2DD4BF);
  static const Color _deep = Color(0xFF1E3A8A);
  static const Color _land = Color(0xFFC2A878);
  static const Color _water = Color(0xFF3B82F6);
  static const double _waterOpacity = 0.22;
  static const double _landHeightCapFraction = 0.15;

  static const double _metersPerDegLat = 110540.0;
  static const double _metersPerDegLonAtEquator = 111320.0;

  /// The grid's extent in local east-north meters relative to [center].
  static ({double minEast, double maxEast, double minNorth, double maxNorth})
  enuBounds(BathymetryGrid grid, GeoPoint center) {
    final mLon =
        _metersPerDegLonAtEquator *
        math.cos(center.latitude * math.pi / 180.0);
    final minEast = (grid.originLon - center.longitude) * mLon;
    final maxEast =
        (grid.originLon + grid.cellSizeLonDeg * (grid.cols - 1) -
                center.longitude) *
            mLon;
    final minNorth = (grid.originLat - center.latitude) * _metersPerDegLat;
    final maxNorth =
        (grid.originLat + grid.cellSizeLatDeg * (grid.rows - 1) -
                center.latitude) *
            _metersPerDegLat;
    return (
      minEast: minEast,
      maxEast: maxEast,
      minNorth: minNorth,
      maxNorth: maxNorth,
    );
  }

  static SpatialTerrain build({
    required BathymetryGrid grid,
    required GeoPoint center,
    required SpatialProjection projection,
  }) {
    final rows = grid.rows, cols = grid.cols;
    final mLon =
        _metersPerDegLonAtEquator *
        math.cos(center.latitude * math.pi / 180.0);
    final maxDepth = math.max(projection.maxDepth, 1.0);
    final landCap = _landHeightCapFraction * maxDepth;

    final positions = Float32List(rows * cols * 3);
    final colors = Float32List(rows * cols * 3);
    for (var r = 0; r < rows; r++) {
      final north =
          (grid.originLat + grid.cellSizeLatDeg * r - center.latitude) *
          _metersPerDegLat;
      for (var c = 0; c < cols; c++) {
        final east =
            (grid.originLon + grid.cellSizeLonDeg * c - center.longitude) *
            mLon;
        final raw = grid.depthAt(r, c);
        // nodata -> shoreline; land elevation capped so peaks stay modest.
        final depth = raw == null ? 0.0 : math.max(raw, -landCap);
        final vi = (r * cols + c) * 3;
        positions[vi] = projection.xOf(east);
        positions[vi + 1] = projection.yOf(depth);
        positions[vi + 2] = projection.zOf(north);
        final Color color;
        if (raw == null || raw <= 0) {
          color = _land;
        } else {
          final t = (depth / maxDepth).clamp(0.0, 1.0);
          color = Color.lerp(_shallow, _deep, t)!;
        }
        colors[vi] = color.r;
        colors[vi + 1] = color.g;
        colors[vi + 2] = color.b;
      }
    }
    final terrain = MeshData(
      positions: positions,
      indices: _gridIndices(rows, cols),
      colors: colors,
    );

    final b = enuBounds(grid, center);
    final wPos = Float32List(4 * 3);
    final wCol = Float32List(4 * 3);
    final corners = [
      [b.minEast, b.minNorth],
      [b.maxEast, b.minNorth],
      [b.minEast, b.maxNorth],
      [b.maxEast, b.maxNorth],
    ];
    for (var i = 0; i < 4; i++) {
      wPos[i * 3] = projection.xOf(corners[i][0]);
      wPos[i * 3 + 1] = 0;
      wPos[i * 3 + 2] = projection.zOf(corners[i][1]);
      wCol[i * 3] = _water.r;
      wCol[i * 3 + 1] = _water.g;
      wCol[i * 3 + 2] = _water.b;
    }
    final water = MeshData(
      positions: wPos,
      indices: Uint32List.fromList([0, 1, 2, 1, 3, 2]),
      colors: wCol,
      opacity: _waterOpacity,
    );

    return SpatialTerrain(terrain: terrain, water: water);
  }

  static Uint32List _gridIndices(int rows, int cols) {
    if (rows < 2 || cols < 2) return Uint32List(0);
    final indices = Uint32List((rows - 1) * (cols - 1) * 6);
    var q = 0;
    for (var r = 0; r < rows - 1; r++) {
      for (var c = 0; c < cols - 1; c++) {
        final a = r * cols + c;
        final b = r * cols + c + 1;
        final d = (r + 1) * cols + c;
        final e = (r + 1) * cols + c + 1;
        indices[q++] = a;
        indices[q++] = b;
        indices[q++] = d;
        indices[q++] = b;
        indices[q++] = e;
        indices[q++] = d;
      }
    }
    return indices;
  }
}
```

Note: `projection.yOf(depth)` with a NEGATIVE depth (land) naturally yields a positive Y above the waterline — the cap clamps the input depth, so the test's `0.15 * 6.0` ceiling holds because `yOf` maps `maxDepth → -6.0` linearly (`SceneBounds.ySpan == 6.0`).

- [ ] **Step 4: Run to verify pass**

Run: `flutter test test/features/dive_3d/domain/spatial/bathymetry_terrain_builder_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/dive_3d test/features/dive_3d
git commit -m "feat(dive_3d): build seascape terrain from real bathymetry grids"
```

---

### Task 12: SiteSeascapeGeometryService

**Files:**
- Modify: `lib/features/dive_3d/domain/spatial/reckoned_path.dart` (add top-level `offsetReckonedPath`)
- Create: `lib/features/dive_3d/domain/spatial/site_seascape_geometry_service.dart`
- Test: `test/features/dive_3d/domain/spatial/site_seascape_geometry_service_test.dart`

**Interfaces:**
- Consumes: `BathymetryTerrainBuilder` (Task 11), `SpatialPathBuilder.buildRibbon/buildPin`, `SpatialProjection`, `Scene3d`/`SceneLayer`/`SceneBounds`, `SceneMarker` with `z` + kinds `site`/`nearbySite` (Task 10), `SceneOverlay.paths`/`markers`.
- Produces:
  - `ReckonedPath offsetReckonedPath(ReckonedPath path, ({double east, double north}) anchor)` — shifts every point and the bounds; identity when anchor is (0, 0).
  - `class SiteDivePathInput { final String diveId; final ReckonedPath path; final ({double east, double north}) anchor; }`
  - `class NearbySiteInput { final String siteId; final String name; final ({double east, double north}) offset; }`
  - `class SiteSeascapeInput { final BathymetryGrid grid; final GeoPoint center; final String siteName; final double? siteMaxDepth; final List<SiteDivePathInput> divePaths; final List<NearbySiteInput> nearbySites; }` (all constructor params required except `siteMaxDepth`).
  - `class SiteSeascapeGeometryService { const SiteSeascapeGeometryService(); Scene3d build(SiteSeascapeInput input); }`

Scene composition (back-to-front): terrain → per-dive ribbons + entry/exit pins (`overlay: SceneOverlay.paths`) → site depth pin (structural) → water. Markers: one `site` marker at scene center (y = 0.15, above the surface), one `nearbySite` marker per nearby site at its offset. Bounds: `sceneMaxY = 0.6` so surface markers stay inside the projector's fit. The scene has no scrub path (no single timeline at site level).

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/dive_3d/domain/spatial/site_seascape_geometry_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/site_seascape_geometry_service.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

BathymetryGrid grid() => BathymetryGrid(
  originLat: 12.15,
  originLon: -68.30,
  cellSizeLatDeg: 0.001,
  cellSizeLonDeg: 0.001,
  rows: 3,
  cols: 3,
  depthsMeters: const [20, 25, 30, 25, 30, 35, 30, 35, 40],
  sourceId: 'gmrt',
  resolutionMeters: 61,
  fetchedAt: DateTime.utc(2026, 7, 28),
);

ReckonedPath path() => const ReckonedPath(
  points: [
    ReckonedPoint(east: 0, north: 0, depth: 5, timeSeconds: 0),
    ReckonedPoint(east: 40, north: 20, depth: 18, timeSeconds: 600),
  ],
  reconstructed: true,
  minEast: 0,
  maxEast: 40,
  minNorth: 0,
  maxNorth: 20,
  maxDepth: 18,
  durationSeconds: 600,
);

SiteSeascapeInput input({
  List<SiteDivePathInput> paths = const [],
  List<NearbySiteInput> nearby = const [],
}) => SiteSeascapeInput(
  grid: grid(),
  center: const GeoPoint(12.151, -68.299),
  siteName: 'Salt Pier',
  siteMaxDepth: 30,
  divePaths: paths,
  nearbySites: nearby,
);

void main() {
  const service = SiteSeascapeGeometryService();

  test('offsetReckonedPath shifts points and bounds; identity at zero', () {
    final p = path();
    expect(identical(offsetReckonedPath(p, (east: 0, north: 0)), p), isTrue);
    final moved = offsetReckonedPath(p, (east: 100, north: -50));
    expect(moved.points.first.east, 100);
    expect(moved.points.first.north, -50);
    expect(moved.maxEast, 140);
    expect(moved.minNorth, -50);
    expect(moved.maxDepth, p.maxDepth); // untouched
  });

  test('bare scene: terrain, site pin, water; a site marker; no scrub', () {
    final scene = service.build(input());
    expect(scene.layers.length, 3);
    expect(scene.scrubPath, isNull);
    final site = scene.markers.single;
    expect(site.kind, SceneMarkerKind.site);
    expect(site.label, 'Salt Pier');
    expect(site.y, greaterThan(0)); // floats above the surface
  });

  test('dive paths add ribbon + entry/exit pins gated by the paths overlay',
      () {
    final scene = service.build(
      input(
        paths: [
          SiteDivePathInput(
            diveId: 'd1',
            path: path(),
            anchor: (east: 10, north: 5),
          ),
        ],
      ),
    );
    // terrain + (ribbon + 2 pins) + site pin + water = 6.
    expect(scene.layers.length, 6);
    final gated = scene.layers
        .where((l) => l.overlay == SceneOverlay.paths)
        .length;
    expect(gated, 3);
  });

  test('nearby sites become nearbySite markers at their offsets', () {
    final scene = service.build(
      input(
        nearby: [
          const NearbySiteInput(
            siteId: 's2',
            name: 'Angel City',
            offset: (east: 80, north: -40),
          ),
        ],
      ),
    );
    final nearby = scene.markers
        .where((m) => m.kind == SceneMarkerKind.nearbySite)
        .single;
    expect(nearby.label, 'Angel City');
    expect(nearby.refId, 's2');
    expect(nearby.z, isNot(0)); // positioned in 3D, not billboarded at 0
  });

  test('bounds fit terrain depth and keep surface markers visible', () {
    final scene = service.build(input());
    expect(scene.bounds.maxDepthMeters, 40); // grid max beats siteMaxDepth
    expect(scene.bounds.sceneMaxY, greaterThan(0));
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_3d/domain/spatial/site_seascape_geometry_service_test.dart`
Expected: FAIL — service/types do not exist.

- [ ] **Step 3: Implement the path offset helper**

Append to `lib/features/dive_3d/domain/spatial/reckoned_path.dart`:

```dart
/// Shifts a path into a shared local frame (e.g. a dive's entry offset
/// from the site pin). Identity when the anchor is the origin.
ReckonedPath offsetReckonedPath(
  ReckonedPath path,
  ({double east, double north}) anchor,
) {
  if (anchor.east == 0 && anchor.north == 0) return path;
  return ReckonedPath(
    points: [
      for (final p in path.points)
        ReckonedPoint(
          east: p.east + anchor.east,
          north: p.north + anchor.north,
          depth: p.depth,
          timeSeconds: p.timeSeconds,
        ),
    ],
    reconstructed: path.reconstructed,
    minEast: path.minEast + anchor.east,
    maxEast: path.maxEast + anchor.east,
    minNorth: path.minNorth + anchor.north,
    maxNorth: path.maxNorth + anchor.north,
    maxDepth: path.maxDepth,
    durationSeconds: path.durationSeconds,
  );
}
```

- [ ] **Step 4: Implement the service**

```dart
// lib/features/dive_3d/domain/spatial/site_seascape_geometry_service.dart
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_path_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// One dive's reconstructed path placed in the site's local frame.
class SiteDivePathInput {
  final String diveId;
  final ReckonedPath path;
  final ({double east, double north}) anchor;

  const SiteDivePathInput({
    required this.diveId,
    required this.path,
    required this.anchor,
  });
}

/// Another site whose pin falls inside the fetched terrain.
class NearbySiteInput {
  final String siteId;
  final String name;
  final ({double east, double north}) offset;

  const NearbySiteInput({
    required this.siteId,
    required this.name,
    required this.offset,
  });
}

/// Everything the site seascape scene needs, in plain sendable data (the
/// whole input crosses the compute() isolate boundary for large grids).
class SiteSeascapeInput {
  final BathymetryGrid grid;
  final GeoPoint center;
  final String siteName;
  final double? siteMaxDepth;
  final List<SiteDivePathInput> divePaths;
  final List<NearbySiteInput> nearbySites;

  const SiteSeascapeInput({
    required this.grid,
    required this.center,
    required this.siteName,
    this.siteMaxDepth,
    required this.divePaths,
    required this.nearbySites,
  });
}

/// Assembles the site-level seascape: real terrain, every reconstructed
/// dive path draped in place (never deforming the measured seafloor),
/// the site pin with its recorded max depth, and nearby-site markers.
class SiteSeascapeGeometryService {
  static const Color _sitePinColor = Color(0xFFF43F5E);
  static const double _markerFloat = 0.15;
  static const double _surfaceHeadroom = 0.6;

  const SiteSeascapeGeometryService();

  Scene3d build(SiteSeascapeInput input) {
    final box = BathymetryTerrainBuilder.enuBounds(input.grid, input.center);
    final maxDepth = math.max(
      math.max(input.grid.maxDepthMeters, input.siteMaxDepth ?? 0),
      1.0,
    );
    final proj = SpatialProjection(
      minEast: box.minEast,
      maxEast: box.maxEast,
      minNorth: box.minNorth,
      maxNorth: box.maxNorth,
      maxDepth: maxDepth,
    );

    final terrain = BathymetryTerrainBuilder.build(
      grid: input.grid,
      center: input.center,
      projection: proj,
    );

    final layers = <SceneLayer>[SceneLayer(terrain.terrain)];
    for (final d in input.divePaths) {
      final placed = offsetReckonedPath(d.path, d.anchor);
      if (placed.points.length < 2) continue;
      layers
        ..add(
          SceneLayer(
            SpatialPathBuilder.buildRibbon(placed, proj),
            overlay: SceneOverlay.paths,
          ),
        )
        ..add(
          SceneLayer(
            SpatialPathBuilder.buildPin(placed.points.first, proj,
                isEntry: true),
            overlay: SceneOverlay.paths,
          ),
        )
        ..add(
          SceneLayer(
            SpatialPathBuilder.buildPin(placed.points.last, proj,
                isEntry: false),
            overlay: SceneOverlay.paths,
          ),
        );
    }
    layers
      ..add(SceneLayer(_sitePin(proj, input.siteMaxDepth ?? maxDepth)))
      ..add(SceneLayer(terrain.water));

    final markers = <SceneMarker>[
      SceneMarker(
        kind: SceneMarkerKind.site,
        refId: null,
        label: input.siteName,
        x: proj.xOf(0),
        y: _markerFloat,
        z: proj.zOf(0),
        timestampSeconds: 0,
      ),
      for (final n in input.nearbySites)
        SceneMarker(
          kind: SceneMarkerKind.nearbySite,
          refId: n.siteId,
          label: n.name,
          x: proj.xOf(n.offset.east),
          y: _markerFloat,
          z: proj.zOf(n.offset.north),
          timestampSeconds: 0,
        ),
    ];

    final zHalf = proj.zHalfExtent + SceneBounds.zHalfWidth;
    return Scene3d(
      layers: layers,
      markers: markers,
      bounds: SceneBounds(
        durationSeconds: 1,
        maxDepthMeters: maxDepth,
        sceneMinY: -SceneBounds.ySpan,
        sceneMaxY: _surfaceHeadroom,
        sceneMinZ: -zHalf,
        sceneMaxZ: zHalf,
      ),
    );
  }

  /// A thin vertical quad from the surface down to the site's recorded max
  /// depth at the scene center — the "you are here, this deep" pin.
  MeshData _sitePin(SpatialProjection proj, double pinDepth) {
    const halfWidth = 0.05;
    final x = proj.xOf(0);
    final z = proj.zOf(0);
    final yBottom = proj.yOf(pinDepth);
    final positions = Float32List.fromList([
      x - halfWidth, 0, z,
      x + halfWidth, 0, z,
      x - halfWidth, yBottom, z,
      x + halfWidth, yBottom, z,
    ]);
    final colors = Float32List(4 * 3);
    for (var i = 0; i < 4; i++) {
      colors[i * 3] = _sitePinColor.r;
      colors[i * 3 + 1] = _sitePinColor.g;
      colors[i * 3 + 2] = _sitePinColor.b;
    }
    return MeshData(
      positions: positions,
      indices: Uint32List.fromList([0, 1, 2, 1, 3, 2]),
      colors: colors,
      opacity: 0.85,
    );
  }
}
```

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/dive_3d/domain/spatial/site_seascape_geometry_service_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 6: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/dive_3d test/features/dive_3d
git commit -m "feat(dive_3d): assemble the site seascape scene"
```

---

### Task 13: enuOffsetMeters + site seascape providers

**Files:**
- Modify: `lib/core/utils/geo_math.dart` (add `enuOffsetMeters`)
- Create: `lib/features/dive_3d/application/site_seascape_providers.dart`
- Test: `test/core/utils/geo_math_enu_offset_test.dart`
- Test: `test/features/dive_3d/application/site_seascape_providers_test.dart`

**Interfaces:**
- Consumes: `siteProvider`/`sitesProvider` (`lib/features/dive_sites/presentation/providers/site_providers.dart`), `divesProvider` (`dive_providers.dart`), `spatialReckonedPathProvider` (`spatial_providers.dart`), `bathymetryGridProvider` + `BathymetryRepository.quantize` (Tasks 8–9), `SiteSeascapeGeometryService` + input types (Task 12), `BathymetryTerrainBuilder.enuBounds` (Task 11).
- Produces:
  - `({double east, double north}) enuOffsetMeters(GeoPoint from, GeoPoint to)` in `geo_math.dart`.
  - `sealed class SiteSeascapeState` with subclasses `SiteSeascapeReady { final Scene3d scene; final String sourceId; final double resolutionMeters; }`, `SiteSeascapeNoCoordinates`, `SiteSeascapeNoData` (all const-constructible).
  - `final siteSeascapeProvider = FutureProvider.family<SiteSeascapeState, String>` — ALWAYS returns a state, never a bare null (never-spinner rule).

- [ ] **Step 1: Write the failing geo_math test**

```dart
// test/core/utils/geo_math_enu_offset_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

void main() {
  test('enuOffsetMeters points due north/east correctly', () {
    const a = GeoPoint(12.16, -68.29);
    final north = enuOffsetMeters(a, const GeoPoint(12.17, -68.29));
    expect(north.north, closeTo(1110, 15)); // ~0.01 deg lat
    expect(north.east.abs(), lessThan(1));
    final east = enuOffsetMeters(a, const GeoPoint(12.16, -68.28));
    expect(east.east, closeTo(1088, 15)); // ~0.01 deg lon at 12 N
    expect(east.north.abs(), lessThan(5));
  });

  test('enuOffsetMeters is zero for identical points', () {
    const a = GeoPoint(12.16, -68.29);
    final o = enuOffsetMeters(a, a);
    expect(o.east, 0);
    expect(o.north, 0);
  });
}
```

- [ ] **Step 2: Implement `enuOffsetMeters`**

Append to `lib/core/utils/geo_math.dart`:

```dart
/// Offset of [to] relative to [from] in local east-north meters
/// (distance + bearing decomposition — the same math the spatial scene
/// uses for exit fixes).
({double east, double north}) enuOffsetMeters(GeoPoint from, GeoPoint to) {
  final d = distanceMeters(from, to);
  if (d == 0) return (east: 0, north: 0);
  final brg = initialBearingDegrees(from, to) * math.pi / 180.0;
  return (east: d * math.sin(brg), north: d * math.cos(brg));
}
```

Run: `flutter test test/core/utils/geo_math_enu_offset_test.dart` — expected PASS.

- [ ] **Step 3: Write the failing provider tests**

Provider tests avoid constructing `Dive` entities entirely: the ready-state test uses an empty dive list and empty site list, which still exercises grid + site + scene assembly.

```dart
// test/features/dive_3d/application/site_seascape_providers_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

BathymetryGrid smallGrid() => BathymetryGrid(
  originLat: 12.15,
  originLon: -68.30,
  cellSizeLatDeg: 0.001,
  cellSizeLonDeg: 0.001,
  rows: 2,
  cols: 2,
  depthsMeters: const [20, 30, 25, 35],
  sourceId: 'gmrt',
  resolutionMeters: 61,
  fetchedAt: DateTime.utc(2026, 7, 28),
);

void main() {
  const siteId = 'site-1';
  const withGps = DiveSite(
    id: siteId,
    name: 'Salt Pier',
    location: GeoPoint(12.151, -68.299),
    maxDepth: 30,
  );
  const noGps = DiveSite(id: siteId, name: 'Mystery Site');

  ProviderContainer container({
    DiveSite? site,
    BathymetryGrid? grid,
  }) {
    final c = ProviderContainer(
      overrides: [
        siteProvider(siteId).overrideWith((ref) async => site),
        sitesProvider.overrideWith((ref) async => [if (site != null) site]),
        divesProvider.overrideWith((ref) async => []),
        bathymetryGridProvider.overrideWith((ref, cell) async => grid),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('site without coordinates yields SiteSeascapeNoCoordinates', () async {
    final c = container(site: noGps, grid: smallGrid());
    final state = await c.read(siteSeascapeProvider(siteId).future);
    expect(state, isA<SiteSeascapeNoCoordinates>());
  });

  test('no grid (empty or transient) yields SiteSeascapeNoData', () async {
    final c = container(site: withGps, grid: null);
    final state = await c.read(siteSeascapeProvider(siteId).future);
    expect(state, isA<SiteSeascapeNoData>());
  });

  test('grid + site yields a ready scene with provenance', () async {
    final c = container(site: withGps, grid: smallGrid());
    final state = await c.read(siteSeascapeProvider(siteId).future);
    final ready = state as SiteSeascapeReady;
    expect(ready.sourceId, 'gmrt');
    expect(ready.resolutionMeters, 61);
    expect(ready.scene.layers, isNotEmpty);
    expect(ready.scene.markers.first.label, 'Salt Pier');
  });

  test('missing site yields SiteSeascapeNoCoordinates (never a throw)',
      () async {
    final c = container(site: null, grid: smallGrid());
    final state = await c.read(siteSeascapeProvider(siteId).future);
    expect(state, isA<SiteSeascapeNoCoordinates>());
  });
}
```

Note: if `overrideWith` on a family provider needs the Riverpod 3 form `siteProvider.overrideWith((ref, arg) async => ...)`, use that shape — match whatever the existing provider tests in `test/features/dive_3d/application/` do.

- [ ] **Step 4: Run to verify failure**

Run: `flutter test test/features/dive_3d/application/site_seascape_providers_test.dart`
Expected: FAIL — provider does not exist.

- [ ] **Step 5: Implement**

```dart
// lib/features/dive_3d/application/site_seascape_providers.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/bathymetry/application/bathymetry_providers.dart';
import 'package:submersion/features/bathymetry/data/bathymetry_repository.dart';
import 'package:submersion/features/dive_3d/application/spatial_providers.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/domain/spatial/bathymetry_terrain_builder.dart';
import 'package:submersion/features/dive_3d/domain/spatial/site_seascape_geometry_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

/// Terminal states for the site seascape. The provider ALWAYS resolves to
/// one of these — a null/silent-spinner path does not exist (PR #659).
sealed class SiteSeascapeState {
  const SiteSeascapeState();
}

class SiteSeascapeReady extends SiteSeascapeState {
  final Scene3d scene;
  final String sourceId;
  final double resolutionMeters;

  const SiteSeascapeReady({
    required this.scene,
    required this.sourceId,
    required this.resolutionMeters,
  });
}

class SiteSeascapeNoCoordinates extends SiteSeascapeState {
  const SiteSeascapeNoCoordinates();
}

class SiteSeascapeNoData extends SiteSeascapeState {
  const SiteSeascapeNoData();
}

/// Heaviest sites stay readable: newest dives first, capped.
const int _maxDivePaths = 30;

/// Below this cell count the scene builds synchronously (widget-test
/// FakeAsync deadlock rule); above it, in a compute() isolate.
const int _isolateCellThreshold = 4000;

final siteSeascapeProvider =
    FutureProvider.family<SiteSeascapeState, String>((ref, siteId) async {
      final site = await ref.watch(siteProvider(siteId).future);
      final center = site?.location;
      if (site == null || center == null) {
        return const SiteSeascapeNoCoordinates();
      }

      final grid = await ref.watch(
        bathymetryGridProvider(BathymetryRepository.quantize(center)).future,
      );
      if (grid == null) return const SiteSeascapeNoData();

      final allDives = await ref.watch(divesProvider.future);
      final atSite =
          allDives.where((d) => d.site?.id == siteId).toList()..sort(
            (a, b) => (b.entryTime ?? b.dateTime).compareTo(
              a.entryTime ?? a.dateTime,
            ),
          );
      final divePaths = <SiteDivePathInput>[];
      for (final dive in atSite.take(_maxDivePaths)) {
        final path = await ref.watch(
          spatialReckonedPathProvider(dive.id).future,
        );
        if (path == null || path.points.length < 2) continue;
        final entry = dive.entryLocation;
        divePaths.add(
          SiteDivePathInput(
            diveId: dive.id,
            path: path,
            anchor: entry == null
                ? (east: 0.0, north: 0.0)
                : enuOffsetMeters(center, entry),
          ),
        );
      }

      final box = BathymetryTerrainBuilder.enuBounds(grid, center);
      final sites = await ref.watch(sitesProvider.future);
      final nearby = <NearbySiteInput>[];
      for (final s in sites) {
        final sLoc = s.location;
        if (s.id == siteId || sLoc == null) continue;
        final off = enuOffsetMeters(center, sLoc);
        final inside =
            off.east >= box.minEast &&
            off.east <= box.maxEast &&
            off.north >= box.minNorth &&
            off.north <= box.maxNorth;
        if (inside) {
          nearby.add(
            NearbySiteInput(siteId: s.id, name: s.name, offset: off),
          );
        }
      }

      final input = SiteSeascapeInput(
        grid: grid,
        center: center,
        siteName: site.name,
        siteMaxDepth: site.maxDepth,
        divePaths: divePaths,
        nearbySites: nearby,
      );
      final scene = grid.rows * grid.cols > _isolateCellThreshold
          ? await compute(_buildScene, input)
          : const SiteSeascapeGeometryService().build(input);
      return SiteSeascapeReady(
        scene: scene,
        sourceId: grid.sourceId,
        resolutionMeters: grid.resolutionMeters,
      );
    });

Scene3d _buildScene(SiteSeascapeInput input) =>
    const SiteSeascapeGeometryService().build(input);
```

- [ ] **Step 6: Run to verify pass**

Run: `flutter test test/features/dive_3d/application/site_seascape_providers_test.dart test/core/utils/geo_math_enu_offset_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/core/utils/geo_math.dart lib/features/dive_3d test/core/utils test/features/dive_3d
git commit -m "feat(dive_3d): site seascape provider with typed terminal states"
```

---

### Task 14: SiteSeascapePage, site-detail entry point, l10n

**Files:**
- Create: `lib/features/bathymetry/presentation/bathymetry_labels.dart`
- Create: `lib/features/dive_3d/presentation/pages/site_seascape_page.dart`
- Modify: `lib/features/dive_sites/presentation/pages/site_detail_page.dart:244-262` (AppBar actions — add seascape button)
- Modify: `lib/l10n/arb/app_en.arb` + all 10 locale files (`app_ar.arb, app_de.arb, app_es.arb, app_fr.arb, app_he.arb, app_hu.arb, app_it.arb, app_nl.arb, app_pt.arb, app_zh.arb`)
- Test: `test/features/dive_3d/presentation/site_seascape_page_test.dart`

**Interfaces:**
- Consumes: `siteSeascapeProvider` + states (Task 13), `Dive3dInteractiveViewport` (requires `scene`, `scrubPosition`, `visibleOverlays`), `SceneOverlay.markers`/`paths`.
- Produces: `SiteSeascapePage({required String siteId})`; `String bathymetrySourceDisplayName(String id)` mapping `'gmrt' → 'GMRT'`, `'emodnet' → 'EMODnet'`, `'etopo2022' → 'ETOPO 2022'`, else the raw id.

- [ ] **Step 1: Add the l10n strings**

In `lib/l10n/arb/app_en.arb`, after the `dive3d_spatial_*` block (~line 13309):

```json
  "dive3d_seascape_siteTitle": "Site Seascape",
  "@dive3d_seascape_siteTitle": {},
  "dive3d_seascape_seafloorSource": "Seafloor: {source} (~{resolution} m)",
  "@dive3d_seascape_seafloorSource": {
    "placeholders": {
      "source": {"type": "String"},
      "resolution": {"type": "String"}
    }
  },
  "dive3d_seascape_noCoordinates": "This site has no GPS coordinates",
  "@dive3d_seascape_noCoordinates": {},
  "dive3d_seascape_noData": "No bathymetry available for this location",
  "@dive3d_seascape_noData": {},
  "dive3d_seascape_overlay_paths": "Dive paths",
  "@dive3d_seascape_overlay_paths": {},
  "dive3d_seascape_overlay_markers": "Markers",
  "@dive3d_seascape_overlay_markers": {},
```

Translate the values (not the keys) into ALL 10 locale files — e.g. de: "Standort-Seelandschaft" / "Meeresboden: {source} (~{resolution} m)" / "Dieser Tauchplatz hat keine GPS-Koordinaten" / "Keine Bathymetrie für diesen Ort verfügbar" / "Tauchgangspfade" / "Markierungen"; produce equivalent native translations for ar, es, fr, he, hu, it, nl, pt, zh. Then run `flutter gen-l10n` and commit the regenerated `app_localizations*.dart`.

- [ ] **Step 2: Implement the labels helper**

```dart
// lib/features/bathymetry/presentation/bathymetry_labels.dart
/// Display names for bathymetry source ids (used in provenance captions
/// and satisfying CC-BY attribution for GMRT/EMODnet).
String bathymetrySourceDisplayName(String id) => switch (id) {
  'gmrt' => 'GMRT',
  'emodnet' => 'EMODnet',
  'etopo2022' => 'ETOPO 2022',
  _ => id,
};
```

- [ ] **Step 3: Write the failing widget tests**

```dart
// test/features/dive_3d/presentation/site_seascape_page_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/site_seascape_geometry_service.dart';
import 'package:submersion/features/dive_3d/presentation/pages/site_seascape_page.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

SiteSeascapeReady readyState() {
  final grid = BathymetryGrid(
    originLat: 12.15,
    originLon: -68.30,
    cellSizeLatDeg: 0.001,
    cellSizeLonDeg: 0.001,
    rows: 2,
    cols: 2,
    depthsMeters: const [20, 30, 25, 35],
    sourceId: 'gmrt',
    resolutionMeters: 61,
    fetchedAt: DateTime.utc(2026, 7, 28),
  );
  final scene = const SiteSeascapeGeometryService().build(
    SiteSeascapeInput(
      grid: grid,
      center: const GeoPoint(12.151, -68.299),
      siteName: 'Salt Pier',
      siteMaxDepth: 30,
      divePaths: const [],
      nearbySites: const [],
    ),
  );
  return SiteSeascapeReady(scene: scene, sourceId: 'gmrt', resolutionMeters: 61);
}

Widget page(SiteSeascapeState state) => ProviderScope(
  overrides: [
    siteSeascapeProvider.overrideWith((ref, id) async => state),
  ],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SiteSeascapePage(siteId: 'site-1'),
  ),
);

void main() {
  testWidgets('ready state renders viewport and provenance caption',
      (tester) async {
    await tester.pumpWidget(page(readyState()));
    await tester.pump(); // resolve the future
    await tester.pump();
    expect(find.byType(Dive3dInteractiveViewport), findsOneWidget);
    expect(find.textContaining('GMRT'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('no-coordinates state shows the message, not a spinner',
      (tester) async {
    await tester.pumpWidget(page(const SiteSeascapeNoCoordinates()));
    await tester.pump();
    await tester.pump();
    expect(find.text('This site has no GPS coordinates'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('no-data state shows the message, not a spinner',
      (tester) async {
    await tester.pumpWidget(page(const SiteSeascapeNoData()));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('No bathymetry available for this location'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
```

(If family `overrideWith` needs a different arity in this Riverpod version, mirror the working form from Task 13's tests.)

- [ ] **Step 4: Run to verify failure**

Run: `flutter test test/features/dive_3d/presentation/site_seascape_page_test.dart`
Expected: FAIL — page does not exist.

- [ ] **Step 5: Implement the page**

```dart
// lib/features/dive_3d/presentation/pages/site_seascape_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/bathymetry/presentation/bathymetry_labels.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';
import 'package:submersion/features/dive_3d/presentation/widgets/dive_3d_interactive_viewport.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Fullscreen site seascape: real bathymetry around the site pin with the
/// site's dives draped in place. Every terminal state renders something —
/// a scene, or an explicit message; never a permanent spinner.
class SiteSeascapePage extends ConsumerStatefulWidget {
  final String siteId;

  const SiteSeascapePage({super.key, required this.siteId});

  @override
  ConsumerState<SiteSeascapePage> createState() => _SiteSeascapePageState();
}

class _SiteSeascapePageState extends ConsumerState<SiteSeascapePage> {
  // No timeline at site level: the scrub cursor stays parked.
  final ValueNotifier<double> _scrub = ValueNotifier(0);
  final Set<SceneOverlay> _visible = {SceneOverlay.markers, SceneOverlay.paths};

  @override
  void dispose() {
    _scrub.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stateAsync = ref.watch(siteSeascapeProvider(widget.siteId));
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.dive3d_seascape_siteTitle)),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            Center(child: Text(context.l10n.dive3d_seascape_noData)),
        data: (state) => switch (state) {
          SiteSeascapeNoCoordinates() => Center(
            child: Text(context.l10n.dive3d_seascape_noCoordinates),
          ),
          SiteSeascapeNoData() => Center(
            child: Text(context.l10n.dive3d_seascape_noData),
          ),
          SiteSeascapeReady(
            :final scene,
            :final sourceId,
            :final resolutionMeters,
          ) =>
            Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Dive3dInteractiveViewport(
                          scene: scene,
                          scrubPosition: _scrub,
                          visibleOverlays: _visible,
                        ),
                      ),
                      Positioned(
                        top: 8,
                        left: 8,
                        right: 8,
                        child: _sourceChip(sourceId, resolutionMeters),
                      ),
                    ],
                  ),
                ),
                SafeArea(top: false, child: _overlayChips()),
              ],
            ),
        },
      ),
    );
  }

  Widget _sourceChip(String sourceId, double resolutionMeters) {
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.info_outline, size: 14),
            const SizedBox(width: 4),
            Text(
              context.l10n.dive3d_seascape_seafloorSource(
                bathymetrySourceDisplayName(sourceId),
                resolutionMeters.round().toString(),
              ),
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _overlayChips() {
    FilterChip chip(SceneOverlay overlay, String label) => FilterChip(
      label: Text(label),
      selected: _visible.contains(overlay),
      onSelected: (on) => setState(() {
        on ? _visible.add(overlay) : _visible.remove(overlay);
      }),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 8,
        children: [
          chip(SceneOverlay.paths, context.l10n.dive3d_seascape_overlay_paths),
          chip(
            SceneOverlay.markers,
            context.l10n.dive3d_seascape_overlay_markers,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 6: Add the site-detail entry point**

In `lib/features/dive_sites/presentation/pages/site_detail_page.dart`, in the AppBar `actions` (line ~244), insert BEFORE the career-terrain button — only for sites with coordinates:

```dart
          if (site.hasCoordinates)
            IconButton(
              icon: const Icon(Icons.water),
              tooltip: context.l10n.dive3d_seascape_siteTitle,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SiteSeascapePage(siteId: siteId),
                ),
              ),
            ),
```

Add the import: `import 'package:submersion/features/dive_3d/presentation/pages/site_seascape_page.dart';`

- [ ] **Step 7: Run to verify pass + site page regression**

Run: `flutter test test/features/dive_3d/presentation/site_seascape_page_test.dart test/features/dive_sites/`
Expected: PASS.

- [ ] **Step 8: Format, analyze, commit — end of Phase B / PR 2**

```bash
dart format . && flutter analyze
flutter test test/features/dive_3d/ test/l10n/
git add lib test/features/dive_3d test/features/dive_sites
git commit -m "feat(dive_3d): add site seascape page with provenance captions"
```

---

## Phase C — per-dive seascape upgrade (PR 3)

### Task 15: Real terrain in the per-dive scene + provenance-carrying provider

**Files:**
- Modify: `lib/features/dive_3d/domain/spatial/spatial_geometry_service.dart` (optional bathymetry params)
- Modify: `lib/features/dive_3d/application/spatial_providers.dart` (`SpatialSceneResult`, grid lookup, new isolate payload)
- Modify: `lib/features/dive_3d/presentation/pages/spatial_site_page.dart` (mechanical only: read `result.scene` so the build compiles; captions change in Task 16)
- Test: `test/features/dive_3d/domain/spatial/spatial_geometry_service_bathymetry_test.dart` (new; if a `spatial_geometry_service_test.dart` already exists, leave it untouched — it covers the synthesized branch)

**Interfaces:**
- Consumes: `BathymetryGrid`, `bathymetryGridProvider`, `BathymetryRepository.quantize`, `BathymetryTerrainBuilder` (Tasks 1–11), `offsetReckonedPath` (Task 12), `enuOffsetMeters` (Task 13).
- Produces:
  - `SpatialGeometryService.build(ReckonedPath path, {double? siteMaxDepth, BathymetryGrid? grid, GeoPoint? gridCenter, ({double east, double north}) pathAnchor = (east: 0.0, north: 0.0)})` — when `grid` and `gridCenter` are non-null, terrain comes from bathymetry (never cradling the path) and the path is shifted by `pathAnchor` into the grid's frame; otherwise behavior is byte-identical to today.
  - `class SpatialSceneResult { final Scene3d scene; final String? bathymetrySourceId; final double? bathymetryResolutionMeters; }`
  - `spatialGeometryProvider` becomes `FutureProvider.family<SpatialSceneResult?, String>` — null ONLY when the dive has no usable path (page shows the existing no-path message; unchanged semantics).

- [ ] **Step 1: Write the failing service tests**

```dart
// test/features/dive_3d/domain/spatial/spatial_geometry_service_bathymetry_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_geometry_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

ReckonedPath path() => const ReckonedPath(
  points: [
    ReckonedPoint(east: 0, north: 0, depth: 5, timeSeconds: 0),
    ReckonedPoint(east: 30, north: 10, depth: 18, timeSeconds: 300),
    ReckonedPoint(east: 60, north: 20, depth: 12, timeSeconds: 600),
  ],
  reconstructed: true,
  minEast: 0,
  maxEast: 60,
  minNorth: 0,
  maxNorth: 20,
  maxDepth: 18,
  durationSeconds: 600,
);

BathymetryGrid grid() => BathymetryGrid(
  originLat: 12.15,
  originLon: -68.30,
  cellSizeLatDeg: 0.001,
  cellSizeLonDeg: 0.001,
  rows: 4,
  cols: 5,
  depthsMeters: List<double?>.generate(20, (i) => 30.0 + i),
  sourceId: 'gmrt',
  resolutionMeters: 61,
  fetchedAt: DateTime.utc(2026, 7, 28),
);

void main() {
  const service = SpatialGeometryService();
  const center = GeoPoint(12.1515, -68.298);

  test('without a grid the synthesized terrain is unchanged (28x28)', () {
    final scene = service.build(path(), siteMaxDepth: 30);
    // Layer 0 is the terrain: 28x28 synthesized heightmap.
    expect(scene.layers.first.mesh.vertexCount, 28 * 28);
    expect(scene.layers.length, 5);
  });

  test('with a grid the terrain is the bathymetry mesh, path intact', () {
    final scene = service.build(
      path(),
      siteMaxDepth: 30,
      grid: grid(),
      gridCenter: center,
      pathAnchor: (east: 15.0, north: -10.0),
    );
    // Terrain now has one vertex per grid cell.
    expect(scene.layers.first.mesh.vertexCount, 4 * 5);
    // Still terrain + ribbon + 2 pins + water.
    expect(scene.layers.length, 5);
    // Depth budget covers the deepest of path/grid/site.
    expect(scene.bounds.maxDepthMeters, 49); // grid max = 30 + 19
    // Scrub path still spans the dive's timeline.
    expect(scene.scrubPath, isNotNull);
    expect(scene.scrubPath!.normalizedTimes.last, closeTo(1.0, 1e-9));
  });

  test('grid without a center is ignored (falls back to synthesized)', () {
    final scene = service.build(path(), grid: grid());
    expect(scene.layers.first.mesh.vertexCount, 28 * 28);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_3d/domain/spatial/spatial_geometry_service_bathymetry_test.dart`
Expected: FAIL — `build` has no such parameters.

- [ ] **Step 3: Rework `SpatialGeometryService.build`**

Replace the body of `spatial_geometry_service.dart` with the two-branch version (new imports: `bathymetry_grid.dart`, `bathymetry_terrain_builder.dart`, `dive_site.dart`):

```dart
  Scene3d build(
    ReckonedPath path, {
    double? siteMaxDepth,
    BathymetryGrid? grid,
    GeoPoint? gridCenter,
    ({double east, double north}) pathAnchor = (east: 0.0, north: 0.0),
  }) {
    if (path.points.length < 2) {
      return const Scene3d(
        layers: [],
        markers: [],
        bounds: SceneBounds(durationSeconds: 1, maxDepthMeters: 1),
      );
    }

    final useBathymetry = grid != null && gridCenter != null;
    final placed = useBathymetry ? offsetReckonedPath(path, pathAnchor) : path;

    final double minE, maxE, minN, maxN, maxDepth;
    if (useBathymetry) {
      // The measured seafloor sets the frame; the path is a guest in it and
      // is never allowed to bend the terrain (honesty rule).
      final b = BathymetryTerrainBuilder.enuBounds(grid, gridCenter);
      final padE = math.max(placed.eastSpan * _padFraction, _minPadMeters);
      final padN = math.max(placed.northSpan * _padFraction, _minPadMeters);
      minE = math.min(b.minEast, placed.minEast - padE);
      maxE = math.max(b.maxEast, placed.maxEast + padE);
      minN = math.min(b.minNorth, placed.minNorth - padN);
      maxN = math.max(b.maxNorth, placed.maxNorth + padN);
      maxDepth = math.max(
        math.max(placed.maxDepth, grid.maxDepthMeters),
        math.max(siteMaxDepth ?? 0, 1.0),
      );
    } else {
      final padE = math.max(placed.eastSpan * _padFraction, _minPadMeters);
      final padN = math.max(placed.northSpan * _padFraction, _minPadMeters);
      minE = placed.minEast - padE;
      maxE = placed.maxEast + padE;
      minN = placed.minNorth - padN;
      maxN = placed.maxNorth + padN;
      maxDepth = math.max(
        math.max(placed.maxDepth, siteMaxDepth ?? 0),
        1.0,
      );
    }

    final proj = SpatialProjection(
      minEast: minE,
      maxEast: maxE,
      minNorth: minN,
      maxNorth: maxN,
      maxDepth: maxDepth,
    );

    final terrain = useBathymetry
        ? BathymetryTerrainBuilder.build(
            grid: grid,
            center: gridCenter,
            projection: proj,
          )
        : TerrainBuilder.build(
            path: placed,
            projection: proj,
            minEast: minE,
            maxEast: maxE,
            minNorth: minN,
            maxNorth: maxN,
          );
    final ribbon = SpatialPathBuilder.buildRibbon(placed, proj);
    final entryPin = SpatialPathBuilder.buildPin(
      placed.points.first,
      proj,
      isEntry: true,
    );
    final exitPin = SpatialPathBuilder.buildPin(
      placed.points.last,
      proj,
      isEntry: false,
    );

    final zHalf = proj.zHalfExtent + SceneBounds.zHalfWidth;
    final bounds = SceneBounds(
      durationSeconds: placed.durationSeconds,
      maxDepthMeters: maxDepth,
      sceneMinY: -SceneBounds.ySpan,
      sceneMaxY: 0,
      sceneMinZ: -zHalf,
      sceneMaxZ: zHalf,
    );

    final total = placed.durationSeconds <= 0 ? 1.0 : placed.durationSeconds;
    final scrub = ScrubPath(
      normalizedTimes: [
        for (final p in placed.points) p.timeSeconds / total,
      ],
      xs: [for (final p in placed.points) proj.xOf(p.east)],
      ys: [for (final p in placed.points) proj.yOf(p.depth)],
      zs: [for (final p in placed.points) proj.zOf(p.north)],
    );

    return Scene3d(
      layers: [
        SceneLayer(terrain.terrain),
        SceneLayer(ribbon),
        SceneLayer(entryPin),
        SceneLayer(exitPin),
        SceneLayer(terrain.water),
      ],
      markers: const [],
      bounds: bounds,
      scrubPath: scrub,
    );
  }
```

- [ ] **Step 4: Rework the provider**

Replace `spatialGeometryProvider` and the isolate function in `spatial_providers.dart` (new imports: `bathymetry_providers.dart`, `bathymetry_repository.dart`, `bathymetry_grid.dart`, `dive_site.dart`; `geo_math.dart` is already imported):

```dart
/// The renderable per-dive seascape plus terrain provenance (null source
/// means the synthesized fallback seafloor).
class SpatialSceneResult {
  final Scene3d scene;
  final String? bathymetrySourceId;
  final double? bathymetryResolutionMeters;

  const SpatialSceneResult({
    required this.scene,
    this.bathymetrySourceId,
    this.bathymetryResolutionMeters,
  });
}

typedef _SpatialBuildInput = ({
  ReckonedPath path,
  double? siteMaxDepth,
  BathymetryGrid? grid,
  GeoPoint? gridCenter,
  ({double east, double north}) pathAnchor,
});

final spatialGeometryProvider =
    FutureProvider.family<SpatialSceneResult?, String>((ref, diveId) async {
      final path = await ref.watch(spatialReckonedPathProvider(diveId).future);
      if (path == null || path.points.length < 2) return null;
      final dive = await ref.watch(diveProvider(diveId).future);
      final siteMaxDepth = dive?.site?.maxDepth;

      // Real terrain when any anchor coordinate exists: prefer the site
      // pin, else the dive's own entry fix. Null grid (no coordinates,
      // offline-and-uncached, definitive empty) falls back to synthesized.
      final center = dive?.site?.location ?? dive?.entryLocation;
      BathymetryGrid? grid;
      if (center != null) {
        grid = await ref.watch(
          bathymetryGridProvider(BathymetryRepository.quantize(center)).future,
        );
      }
      final entry = dive?.entryLocation;
      final anchor = (grid != null && center != null && entry != null)
          ? enuOffsetMeters(center, entry)
          : (east: 0.0, north: 0.0);

      final input = (
        path: path,
        siteMaxDepth: siteMaxDepth,
        grid: grid,
        gridCenter: grid == null ? null : center,
        pathAnchor: anchor,
      );
      final cells = grid == null ? 0 : grid.rows * grid.cols;
      final scene = (path.points.length < 4000 && cells < 4000)
          ? _buildSpatial(input)
          : await compute(_buildSpatial, input);
      return SpatialSceneResult(
        scene: scene,
        bathymetrySourceId: grid?.sourceId,
        bathymetryResolutionMeters: grid?.resolutionMeters,
      );
    });

Scene3d _buildSpatial(_SpatialBuildInput input) =>
    const SpatialGeometryService().build(
      input.path,
      siteMaxDepth: input.siteMaxDepth,
      grid: input.grid,
      gridCenter: input.gridCenter,
      pathAnchor: input.pathAnchor,
    );
```

Delete the old `_spatialIsolate` function and its `(ReckonedPath, double?)` record type.

- [ ] **Step 5: Mechanically adapt `SpatialSitePage`**

In `spatial_site_page.dart`'s `build`, the `data:` branch now receives a `SpatialSceneResult?`. Minimal compile fix for this task (captions change in Task 16):

```dart
        data: (result) {
          final scene = result?.scene;
          if (scene == null || scene.layers.isEmpty) {
            return Center(child: Text(context.l10n.dive3d_spatial_noPath));
          }
```

(then use `scene` where the old code used its local variable).

- [ ] **Step 6: Run to verify pass + regressions**

Run: `flutter test test/features/dive_3d/`
Expected: PASS — new tests plus the whole existing dive_3d suite. If existing tests read `spatialGeometryProvider` and expect a `Scene3d`, update them to unwrap `.scene` — the semantics (null = no path) are unchanged.

- [ ] **Step 7: Format, analyze, commit**

```bash
dart format . && flutter analyze
git add lib/features/dive_3d test/features/dive_3d
git commit -m "feat(dive_3d): drape the dive path over real bathymetry when available"
```

---

### Task 16: Provenance captions, About credit, final sweep

**Files:**
- Modify: `lib/features/dive_3d/presentation/pages/spatial_site_page.dart` (provenance caption)
- Modify: `lib/features/settings/presentation/pages/settings_page.dart` (`_AboutSectionContent` — data-attribution line)
- Modify: `lib/l10n/arb/app_en.arb` + all 10 locale files
- Test: `test/features/dive_3d/presentation/spatial_site_page_caption_test.dart`

**Interfaces:**
- Consumes: `SpatialSceneResult` (Task 15), `bathymetrySourceDisplayName` (Task 14), existing l10n keys `dive3d_spatial_estimatedPath` / `dive3d_spatial_synthesizedSeafloor` / `dive3d_seascape_seafloorSource`.
- Produces: l10n key `settings_about_bathymetryCredit` = `"Bathymetry data: GMRT (CC BY 4.0) · EMODnet Bathymetry (CC BY 4.0) · NOAA ETOPO 2022"`.

- [ ] **Step 1: Write the failing widget tests**

```dart
// test/features/dive_3d/presentation/spatial_site_page_caption_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/application/spatial_providers.dart';
import 'package:submersion/features/dive_3d/domain/spatial/reckoned_path.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_geometry_service.dart';
import 'package:submersion/features/dive_3d/presentation/pages/spatial_site_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

ReckonedPath _path() => const ReckonedPath(
  points: [
    ReckonedPoint(east: 0, north: 0, depth: 5, timeSeconds: 0),
    ReckonedPoint(east: 40, north: 20, depth: 18, timeSeconds: 600),
  ],
  reconstructed: true,
  minEast: 0,
  maxEast: 40,
  minNorth: 0,
  maxNorth: 20,
  maxDepth: 18,
  durationSeconds: 600,
);

Widget page(SpatialSceneResult? result) => ProviderScope(
  overrides: [
    spatialGeometryProvider.overrideWith((ref, id) async => result),
  ],
  child: const MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: SpatialSitePage(diveId: 'd1'),
  ),
);

void main() {
  final synthesized = SpatialSceneResult(
    scene: const SpatialGeometryService().build(_path(), siteMaxDepth: 30),
  );
  final real = SpatialSceneResult(
    scene: const SpatialGeometryService().build(_path(), siteMaxDepth: 30),
    bathymetrySourceId: 'gmrt',
    bathymetryResolutionMeters: 61,
  );

  testWidgets('real terrain shows the provenance chip, not synthesized',
      (tester) async {
    await tester.pumpWidget(page(real));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('GMRT'), findsOneWidget);
    expect(find.text('Synthesized seafloor'), findsNothing);
    expect(find.text('Estimated path (dead reckoning)'), findsOneWidget);
  });

  testWidgets('fallback shows the synthesized chip', (tester) async {
    await tester.pumpWidget(page(synthesized));
    await tester.pump();
    await tester.pump();
    expect(find.text('Synthesized seafloor'), findsOneWidget);
    expect(find.textContaining('GMRT'), findsNothing);
  });

  testWidgets('no path renders the message, never a spinner', (tester) async {
    await tester.pumpWidget(page(null));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Not enough data to reconstruct the dive path'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/features/dive_3d/presentation/spatial_site_page_caption_test.dart`
Expected: FAIL — the page still shows the synthesized chip unconditionally.

- [ ] **Step 3: Implement the caption switch**

In `spatial_site_page.dart`: thread the result into `_captions` and swap the seafloor chip (import `bathymetry_labels.dart`):

```dart
  Widget _captions(SpatialSceneResult result) {
    // chip(...) helper unchanged.
    final sourceId = result.bathymetrySourceId;
    final resolution = result.bathymetryResolutionMeters;
    return Wrap(
      children: [
        chip(context.l10n.dive3d_spatial_estimatedPath),
        if (sourceId != null && resolution != null)
          chip(
            context.l10n.dive3d_seascape_seafloorSource(
              bathymetrySourceDisplayName(sourceId),
              resolution.round().toString(),
            ),
          )
        else
          chip(context.l10n.dive3d_spatial_synthesizedSeafloor),
      ],
    );
  }
```

and pass the result at the call site: `child: _captions(result!)` (safe: that branch only renders when `result?.scene` is non-null).

- [ ] **Step 4: Add the l10n credit + About line**

`app_en.arb` (near the other `settings_about_*` keys if present, else after the seascape block):

```json
  "settings_about_bathymetryCredit": "Bathymetry data: GMRT (CC BY 4.0) · EMODnet Bathymetry (CC BY 4.0) · NOAA ETOPO 2022",
  "@settings_about_bathymetryCredit": {},
```

Translate into all 10 locales (proper nouns and license names stay untranslated; translate only "Bathymetry data"), run `flutter gen-l10n`.

In `settings_page.dart`, append to the About section's children (inside `_AboutSectionContentState.build`, after the existing version/update tiles):

```dart
        ListTile(
          leading: const Icon(Icons.water),
          title: Text(context.l10n.settings_about_bathymetryCredit),
          dense: true,
        ),
```

(match the surrounding tiles' style — if the section uses another row widget, mirror it).

- [ ] **Step 5: Run to verify pass**

Run: `flutter test test/features/dive_3d/presentation/spatial_site_page_caption_test.dart test/features/settings/`
Expected: PASS.

- [ ] **Step 6: Full-suite verification, format, analyze, commit — end of Phase C / PR 3**

```bash
dart format . && flutter analyze
flutter test
git add lib test
git commit -m "feat(dive_3d): provenance captions and bathymetry attribution"
```

Full-suite note: run the complete `flutter test` here (dive-detail section-count tests and other cross-feature suites have caught seascape regressions before). If any pre-existing flaky suites fail (backup/media-upload pipeline — known flaky in full runs), rerun just those files once before investigating.

---

## Delivery / PR boundaries

- **PR 1** = Tasks 1–9 (`feat: bathymetry data feature`) — pure data layer, no UI change.
- **PR 2** = Tasks 10–14 (`feat: site seascape`) — depends on PR 1.
- **PR 3** = Tasks 15–16 (`feat: per-dive real terrain`) — depends on PR 2.

Each phase ends green and shippable. Use the superpowers:finishing-a-development-branch skill when the work is complete.
