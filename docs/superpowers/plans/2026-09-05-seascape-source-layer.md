# Seascape Source Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the bathymetry resolver choose the best available grid rather than the first tier that answers, and add a NOAA CUDEM tier that delivers 3 m to 10 m terrain on US coasts.

**Architecture:** `BathymetrySource.covers()` becomes `probe()`, returning a declared cell size or null for "not covered". The resolver orders sources by materially better resolution (more than 2x finer preempts declared order), fetches in that order, and accepts the first grid passing both a wet-cell floor and a new known-cell floor. A new `NoaaDemSource` probes the NOAA NCEI DEM mosaic ImageServer catalogue and fetches an uncompressed tiled float32 GeoTIFF. `BathymetryGrid.downsampleTo` averages blocks instead of striding.

**Tech Stack:** Dart, Flutter, `package:http` with `MockClient` from `package:http/testing.dart` for tests, `dart:typed_data` for the GeoTIFF reader.

**Spec:** `docs/superpowers/specs/2026-09-05-seascape-extent-and-detail-design.md`

## Global Constraints

- No em-dashes (U+2014) in any output, including code, comments, commit messages and docs. No en-dashes as sentence punctuation either. See the repository CLAUDE.md.
- No mention of Claude, Claude Code or Anthropic in commits, PR bodies or any file.
- No emojis in code, comments or documentation.
- Immutability: never mutate objects or arrays in place.
- TDD: the failing test comes first, always.
- Run `dart format .` before the final commit of the PR.
- Files stay in the 200-400 line range, 800 maximum.
- This plan is PR 1 of 3. It must ship and be useful on its own. Do not implement nested LOD, nodata holes, or the depth window here; those are PRs 2 and 3.

## Files

**Modify:**
- `lib/features/bathymetry/domain/bathymetry_source.dart` - add `SourceCapability`, replace `covers()` with `probe()`
- `lib/features/bathymetry/domain/bathymetry_grid.dart` - add `knownFraction`, make `downsampleTo` average
- `lib/features/bathymetry/data/sources/emodnet_source.dart` - implement `probe()`
- `lib/features/bathymetry/data/sources/gmrt_source.dart` - implement `probe()`
- `lib/features/bathymetry/data/sources/etopo_erddap_source.dart` - implement `probe()`
- `lib/features/bathymetry/data/bathymetry_resolver.dart` - capability ordering, known-cell floor
- `lib/features/bathymetry/data/bathymetry_repository.dart` - cache key generation token
- `lib/features/bathymetry/application/bathymetry_providers.dart` - register `NoaaDemSource`
- `lib/features/bathymetry/presentation/bathymetry_labels.dart` - display name for the new tier
- `lib/l10n/arb/app_*.arb` (all eleven) - add the tier to the about-screen credit

**Create:**
- `lib/features/bathymetry/data/sources/arcgis_float32_tiff_parser.dart` - tiled float32 GeoTIFF reader
- `lib/features/bathymetry/data/sources/noaa_dem_source.dart` - the CUDEM tier

**Test:**
- `test/features/bathymetry/domain/bathymetry_grid_test.dart` (modify)
- `test/features/bathymetry/data/bathymetry_resolver_test.dart` (modify)
- `test/features/bathymetry/data/bathymetry_repository_test.dart` (modify)
- `test/features/bathymetry/data/emodnet_source_test.dart` (modify)
- `test/features/bathymetry/data/gmrt_source_test.dart` (modify)
- `test/features/bathymetry/data/etopo_erddap_source_test.dart` (modify)
- `test/features/bathymetry/data/arcgis_float32_tiff_parser_test.dart` (create)
- `test/features/bathymetry/data/noaa_dem_source_test.dart` (create)
- `test/features/bathymetry/presentation/bathymetry_labels_test.dart` (create)

---

### Task 1: Grid quality metric and averaging downsample

`BathymetryGrid` gains the metric the resolver needs to reject a mostly-empty grid, and stops throwing away detail when it downsamples.

**Files:**
- Modify: `lib/features/bathymetry/domain/bathymetry_grid.dart`
- Test: `test/features/bathymetry/domain/bathymetry_grid_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `double get knownFraction` on `BathymetryGrid`; `BathymetryGrid downsampleTo(int maxDim)` with unchanged signature but averaging semantics.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/bathymetry/domain/bathymetry_grid_test.dart`:

```dart
  group('knownFraction', () {
    test('is the fraction of non-null cells', () {
      final g = BathymetryGrid(
        originLat: 12.0,
        originLon: -68.0,
        cellSizeLatDeg: 0.001,
        cellSizeLonDeg: 0.001,
        rows: 1,
        cols: 4,
        depthsMeters: const [10.0, null, 30.0, null],
        sourceId: 'test',
        resolutionMeters: 100,
        fetchedAt: DateTime.utc(2026, 9, 5),
      );
      expect(g.knownFraction, 0.5);
    });

    test('is zero for an entirely empty grid', () {
      final g = BathymetryGrid(
        originLat: 12.0,
        originLon: -68.0,
        cellSizeLatDeg: 0.001,
        cellSizeLonDeg: 0.001,
        rows: 1,
        cols: 2,
        depthsMeters: const [null, null],
        sourceId: 'test',
        resolutionMeters: 100,
        fetchedAt: DateTime.utc(2026, 9, 5),
      );
      expect(g.knownFraction, 0.0);
    });
  });

  group('downsampleTo averaging', () {
    BathymetryGrid grid(int rows, int cols, List<double?> depths) =>
        BathymetryGrid(
          originLat: 12.0,
          originLon: -68.0,
          cellSizeLatDeg: 0.001,
          cellSizeLonDeg: 0.001,
          rows: rows,
          cols: cols,
          depthsMeters: depths,
          sourceId: 'test',
          resolutionMeters: 60,
          fetchedAt: DateTime.utc(2026, 9, 5),
        );

    test('averages each block instead of picking its first sample', () {
      // 4x4 halved to 2x2: each output cell is the mean of a 2x2 block.
      final g = grid(4, 4, const [
        1.0, 3.0, 10.0, 20.0, //
        5.0, 7.0, 30.0, 40.0, //
        100.0, 100.0, 0.0, 0.0, //
        100.0, 100.0, 0.0, 0.0, //
      ]);
      final d = g.downsampleTo(2);
      expect(d.rows, 2);
      expect(d.cols, 2);
      expect(d.depthAt(0, 0), closeTo(4.0, 1e-9));
      expect(d.depthAt(0, 1), closeTo(25.0, 1e-9));
      expect(d.depthAt(1, 0), closeTo(100.0, 1e-9));
      expect(d.depthAt(1, 1), closeTo(0.0, 1e-9));
    });

    test('averages only the known cells in a block', () {
      final g = grid(2, 2, const [10.0, null, null, 20.0]);
      expect(g.downsampleTo(1).depthAt(0, 0), closeTo(15.0, 1e-9));
    });

    test('an all-nodata block stays nodata', () {
      final g = grid(2, 4, const [
        null, null, 8.0, 8.0, //
        null, null, 8.0, 8.0, //
      ]);
      final d = g.downsampleTo(2);
      expect(d.depthAt(0, 0), isNull);
      expect(d.depthAt(0, 1), closeTo(8.0, 1e-9));
    });

    test('returns the same instance when already within the cap', () {
      final g = grid(2, 2, const [1.0, 2.0, 3.0, 4.0]);
      expect(identical(g.downsampleTo(4), g), isTrue);
    });

    test('scales the resolution claim by the coarser stride', () {
      final g = grid(4, 4, List<double?>.filled(16, 5.0));
      expect(g.downsampleTo(2).resolutionMeters, closeTo(120.0, 1e-9));
    });
  });
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/bathymetry/domain/bathymetry_grid_test.dart`

Expected: FAIL. `knownFraction` is not defined; the averaging tests fail because the current implementation picks `depthsMeters[(r * stepR) * cols + (c * stepC)]`, so `depthAt(0, 0)` returns 1.0 rather than 4.0.

- [ ] **Step 3: Implement**

In `lib/features/bathymetry/domain/bathymetry_grid.dart`, add next to `wetFraction`:

```dart
  /// Fraction of cells that carry a reading at all. A grid can be almost
  /// entirely wet and still be mostly holes: EMODnet's Caribbean tile
  /// answers 99.96% wet on 48% coverage. The resolver needs both numbers.
  double get knownFraction {
    if (depthsMeters.isEmpty) return 0;
    var known = 0;
    for (final d in depthsMeters) {
      if (d != null) known++;
    }
    return known / depthsMeters.length;
  }
```

Replace the body of `downsampleTo`, keeping its signature and its early return:

```dart
  /// Block-mean downsample so neither dimension exceeds [maxDim]. Averaging
  /// rather than striding keeps the information in the discarded cells: a
  /// stride of 2 throws away three quarters of a grid outright.
  BathymetryGrid downsampleTo(int maxDim) {
    if (rows <= maxDim && cols <= maxDim) return this;
    final stepR = (rows / maxDim).ceil();
    final stepC = (cols / maxDim).ceil();
    final newRows = (rows + stepR - 1) ~/ stepR;
    final newCols = (cols + stepC - 1) ~/ stepC;
    final out = List<double?>.filled(newRows * newCols, null);
    for (var r = 0; r < newRows; r++) {
      for (var c = 0; c < newCols; c++) {
        var sum = 0.0;
        var n = 0;
        final r1 = math.min((r + 1) * stepR, rows);
        final c1 = math.min((c + 1) * stepC, cols);
        for (var sr = r * stepR; sr < r1; sr++) {
          for (var sc = c * stepC; sc < c1; sc++) {
            final v = depthsMeters[sr * cols + sc];
            if (v == null) continue;
            sum += v;
            n++;
          }
        }
        // An entirely unmeasured block stays unmeasured: averaging must
        // never invent a reading where the source had none.
        out[r * newCols + c] = n == 0 ? null : sum / n;
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
      // The coarser stride sets the effective spacing: never claim more
      // detail than the downsampled grid actually has.
      resolutionMeters: resolutionMeters * (stepR > stepC ? stepR : stepC),
      fetchedAt: fetchedAt,
    );
  }
```

Add `import 'dart:math' as math;` at the top of the file if it is not already there.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/bathymetry/domain/bathymetry_grid_test.dart`

Expected: PASS.

Then run the consumers, because averaging changes cell values that other suites may assert on:

Run: `flutter test test/features/bathymetry test/features/dive_3d`

Expected: PASS. If a dive_3d golden or geometry test asserts a specific downsampled depth, update the expected value to the block mean and note why in the test.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bathymetry/domain/bathymetry_grid.dart test/features/bathymetry/domain/bathymetry_grid_test.dart
git commit -m "feat(bathymetry): add knownFraction and average when downsampling

A strided downsample discards up to three quarters of a fetched grid; a
block mean keeps that information and suppresses single-cell noise. An
all-nodata block stays nodata so averaging never invents a reading.

knownFraction is the metric the resolver needs to tell a genuinely wet
grid from one that is mostly holes."
```

---

### Task 2: SourceCapability and probe on the source interface

`covers()` cannot express "I cover this, and here is how good my data is", and it cannot make a network call. It becomes `probe()`.

**Files:**
- Modify: `lib/features/bathymetry/domain/bathymetry_source.dart`
- Modify: `lib/features/bathymetry/data/sources/emodnet_source.dart`
- Modify: `lib/features/bathymetry/data/sources/gmrt_source.dart`
- Modify: `lib/features/bathymetry/data/sources/etopo_erddap_source.dart`
- Test: `test/features/bathymetry/data/emodnet_source_test.dart`
- Test: `test/features/bathymetry/data/gmrt_source_test.dart`
- Test: `test/features/bathymetry/data/etopo_erddap_source_test.dart`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `class SourceCapability { final double cellSizeMeters; final String detail; }` and `Future<SourceCapability?> probe(GeoPoint center)` on `BathymetrySource`. `bool covers(GeoPoint)` is removed. `EmodnetSource.declaredCellSizeMeters` = 115, `GmrtSource.declaredCellSizeMeters` = 60, `EtopoErddapSource.declaredCellSizeMeters` = 450.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/bathymetry/data/emodnet_source_test.dart`, inside `void main()`:

```dart
  group('probe', () {
    test('returns 115 m inside the Caribbean tile', () async {
      final cap = await EmodnetSource().probe(const GeoPoint(12.16, -68.29));
      expect(cap, isNotNull);
      expect(cap!.cellSizeMeters, 115);
      expect(cap.detail, 'bathymetry_dtm_carib_2024');
    });

    test('returns 115 m inside the European box', () async {
      final cap = await EmodnetSource().probe(const GeoPoint(42.048, 3.223));
      expect(cap!.detail, 'bathymetry_dtm_2024');
    });

    test('returns null outside every box', () async {
      expect(
        await EmodnetSource().probe(const GeoPoint(-33.9, 151.2)),
        isNull,
      );
    });
  });
```

Append to `test/features/bathymetry/data/gmrt_source_test.dart`, inside `void main()`:

```dart
  group('probe', () {
    test('covers everywhere at its declared 60 m', () async {
      final cap = await GmrtSource().probe(const GeoPoint(-33.9, 151.2));
      expect(cap, isNotNull);
      expect(cap!.cellSizeMeters, 60);
    });
  });
```

Append to `test/features/bathymetry/data/etopo_erddap_source_test.dart`, inside `void main()`:

```dart
  group('probe', () {
    test('covers everywhere at its declared 450 m', () async {
      final cap = await EtopoErddapSource().probe(const GeoPoint(12.16, -68.29));
      expect(cap!.cellSizeMeters, 450);
    });
  });
```

Each of these test files needs `import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';` for `GeoPoint` if it is not already imported.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/bathymetry/data/emodnet_source_test.dart test/features/bathymetry/data/gmrt_source_test.dart test/features/bathymetry/data/etopo_erddap_source_test.dart`

Expected: FAIL, compile error: the method `probe` is not defined.

- [ ] **Step 3: Implement**

In `lib/features/bathymetry/domain/bathymetry_source.dart`, add above the interface:

```dart
/// What a source claims it can deliver at one coordinate. Declared, not
/// measured: a source reports the finest grid it believes it holds there,
/// which the resolver uses only to order candidates. The wet-cell and
/// known-cell floors in [BathymetryResolver] are what actually reject bad
/// data after a fetch.
class SourceCapability {
  /// Best available cell size in meters at the probed point.
  final double cellSizeMeters;

  /// Provenance detail for the caption, e.g. the dataset or DEM name.
  final String detail;

  const SourceCapability({
    required this.cellSizeMeters,
    required this.detail,
  });
}
```

Replace `bool covers(GeoPoint center);` with:

```dart
  /// What this source can deliver at [center], or null when it does not
  /// cover the point. May make a network call; a probe that fails for any
  /// reason must return null rather than throw, so one unreachable source
  /// never blocks the others.
  Future<SourceCapability?> probe(GeoPoint center);
```

In `emodnet_source.dart`, replace the `covers` override with:

```dart
  static const double declaredCellSizeMeters = _resolutionMeters;

  @override
  Future<SourceCapability?> probe(GeoPoint center) async {
    if (_inBox(center, _carib)) {
      return const SourceCapability(
        cellSizeMeters: _resolutionMeters,
        detail: _carib.dataset,
      );
    }
    if (_inBox(center, _europe)) {
      return const SourceCapability(
        cellSizeMeters: _resolutionMeters,
        detail: _europe.dataset,
      );
    }
    return null;
  }
```

Note: `_carib.dataset` inside a `const` expression requires `_carib` to stay a `const` record, which it already is. If the analyzer rejects the const context, drop `const` from the two returns.

In `gmrt_source.dart`, replace the `covers` override with:

```dart
  /// GMRT's global tiles run to roughly 60 m where ship multibeam exists.
  /// This is a nominal figure: elsewhere the same grid spacing carries
  /// upsampled GEBCO. The resolver's preemption factor exists so this
  /// number cannot demote a genuinely surveyed regional source.
  static const double declaredCellSizeMeters = 60;

  @override
  Future<SourceCapability?> probe(GeoPoint center) async =>
      const SourceCapability(
        cellSizeMeters: declaredCellSizeMeters,
        detail: 'GMRT GridServer',
      );
```

In `etopo_erddap_source.dart`, replace the `covers` override with:

```dart
  static const double declaredCellSizeMeters = _resolutionMeters;

  @override
  Future<SourceCapability?> probe(GeoPoint center) async =>
      const SourceCapability(
        cellSizeMeters: _resolutionMeters,
        detail: _dataset,
      );
```

Each source file needs `SourceCapability` in scope; it comes from the already-imported `bathymetry_source.dart`.

The resolver still calls `source.covers(center)` at this point and will not compile. Fix it minimally here so the tree builds, replacing the `if (!source.covers(center)) continue;` line in `BathymetryResolver.resolve` with:

```dart
      if (await source.probe(center) == null) continue;
```

Task 3 replaces that loop wholesale.

Also fix the two fakes in `test/features/bathymetry/data/bathymetry_resolver_test.dart`, replacing each `covers` override:

```dart
  @override
  Future<SourceCapability?> probe(GeoPoint center) async => coversIt
      ? const SourceCapability(cellSizeMeters: 100, detail: 'fake')
      : null;
```

and in `_ErrorSource`:

```dart
  @override
  Future<SourceCapability?> probe(GeoPoint center) async =>
      const SourceCapability(cellSizeMeters: 100, detail: 'boom');
```

Search the whole tree for any other implementer or caller:

```bash
grep -rn "covers(" lib test
```

Every hit must be gone before Step 4 passes.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/bathymetry`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bathymetry test/features/bathymetry
git commit -m "feat(bathymetry): sources declare a capability instead of a bool

covers() could only say yes or no, and could not make a network call. A
source now reports the finest cell size it believes it holds at a point,
or null when it does not cover it, which lets the resolver order
candidates by what they can actually deliver.

Declared, not measured. The wet-cell and known-cell floors remain the
things that reject bad data after a fetch."
```

---

### Task 3: Capability ordering and the known-cell floor

The resolver stops taking the first tier that answers.

**Files:**
- Modify: `lib/features/bathymetry/data/bathymetry_resolver.dart`
- Test: `test/features/bathymetry/data/bathymetry_resolver_test.dart`

**Interfaces:**
- Consumes: `SourceCapability` and `probe()` from Task 2; `knownFraction` from Task 1.
- Produces: `BathymetryResolver.minKnownFraction` (0.60) and `BathymetryResolver.preemptionFactor` (2.0). `BathymetryResolution` is unchanged.

- [ ] **Step 1: Write the failing tests**

In `test/features/bathymetry/data/bathymetry_resolver_test.dart`, extend `FakeSource` with a declarable cell size. Replace the class with:

```dart
class FakeSource implements BathymetrySource {
  @override
  final String id;
  @override
  final bool global;
  final bool coversIt;
  final BathymetryGrid? result; // null => throw transient
  final double cellSizeMeters;
  int fetchCount = 0;
  double? lastSpanMeters;

  FakeSource(
    this.id, {
    this.global = true,
    this.coversIt = true,
    this.result,
    this.cellSizeMeters = 100,
  });

  @override
  Future<SourceCapability?> probe(GeoPoint center) async => coversIt
      ? SourceCapability(cellSizeMeters: cellSizeMeters, detail: id)
      : null;

  @override
  Future<BathymetryGrid> fetch(GeoPoint c, {required double spanMeters}) async {
    fetchCount++;
    lastSpanMeters = spanMeters;
    final r = result;
    if (r == null) throw const BathymetryFetchException('down');
    return r;
  }
}
```

Add a helper next to `gridWith` that can produce holes:

```dart
BathymetryGrid gridOf(
  List<double?> depths,
  String sourceId, {
  double resolutionMeters = 100,
}) => BathymetryGrid(
  originLat: 12.14,
  originLon: -68.31,
  cellSizeLatDeg: 0.004,
  cellSizeLonDeg: 0.004,
  rows: 1,
  cols: depths.length,
  depthsMeters: depths,
  sourceId: sourceId,
  resolutionMeters: resolutionMeters,
  fetchedAt: DateTime.utc(2026, 7, 28),
);
```

Append these tests inside `void main()`:

```dart
  test('a mostly-empty grid fails the known-cell floor and falls through',
      () async {
    // 4 known of 10 cells is 40%, below the 60% floor, even though every
    // known cell is wet. This is EMODnet's Bonaire tile in miniature.
    final holey = <double?>[
      50.0, null, 50.0, null, 50.0, null, 50.0, null, null, null,
    ];
    final a = FakeSource('emodnet-like', result: gridOf(holey, 'a'));
    final b = FakeSource('gmrt-like', result: gridWith(wet, 'b'));
    final res = await BathymetryResolver(sources: [a, b]).resolve(p);
    expect(res.grid!.sourceId, 'b');
    expect(a.fetchCount, 1);
    expect(b.fetchCount, 1);
  });

  test('a grid at exactly the known-cell floor is accepted', () async {
    final atFloor = <double?>[
      50.0, 50.0, 50.0, 50.0, 50.0, 50.0, null, null, null, null,
    ];
    final a = FakeSource('a', result: gridOf(atFloor, 'a'));
    final res = await BathymetryResolver(sources: [a]).resolve(p);
    expect(res.grid!.sourceId, 'a');
  });

  test('a materially finer source preempts the declared order', () async {
    // 10 m against 100 m is a factor of 10, well past preemptionFactor.
    final coarse = FakeSource('coarse', result: gridWith(wet, 'coarse'));
    final fine = FakeSource(
      'fine',
      result: gridWith(wet, 'fine'),
      cellSizeMeters: 10,
    );
    final res = await BathymetryResolver(sources: [coarse, fine]).resolve(p);
    expect(res.grid!.sourceId, 'fine');
    expect(coarse.fetchCount, 0);
  });

  test('a marginally finer source does not preempt the declared order',
      () async {
    // 60 m against 115 m is a factor of 1.9, inside preemptionFactor, so
    // the declared regional-first order stands. This is EMODnet vs GMRT
    // in Europe.
    final regional = FakeSource(
      'emodnet',
      result: gridWith(wet, 'emodnet'),
      cellSizeMeters: 115,
    );
    final global = FakeSource(
      'gmrt',
      result: gridWith(wet, 'gmrt'),
      cellSizeMeters: 60,
    );
    final res = await BathymetryResolver(sources: [regional, global]).resolve(p);
    expect(res.grid!.sourceId, 'emodnet');
    expect(global.fetchCount, 0);
  });

  test('an uncovered source is never fetched', () async {
    final a = FakeSource('a', coversIt: false, result: gridWith(wet, 'a'));
    final b = FakeSource('b', result: gridWith(wet, 'b'));
    final res = await BathymetryResolver(sources: [a, b]).resolve(p);
    expect(res.grid!.sourceId, 'b');
    expect(a.fetchCount, 0);
  });

  test('a probe that throws is treated as not covering', () async {
    final res = await BathymetryResolver(
      sources: [_ThrowingProbeSource(), FakeSource('b', result: gridWith(wet, 'b'))],
    ).resolve(p);
    expect(res.grid!.sourceId, 'b');
  });
```

Add the throwing-probe fake next to `_ErrorSource`:

```dart
class _ThrowingProbeSource implements BathymetrySource {
  @override
  String get id => 'probe-boom';
  @override
  bool get global => false;
  @override
  Future<SourceCapability?> probe(GeoPoint center) async =>
      throw StateError('probe exploded');
  @override
  Future<BathymetryGrid> fetch(GeoPoint c, {required double spanMeters}) async =>
      throw StateError('should never be fetched');
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/features/bathymetry/data/bathymetry_resolver_test.dart`

Expected: FAIL. `minKnownFraction` and `preemptionFactor` are undefined; the holey-grid test currently returns source 'a' because nothing checks coverage density; the preemption tests currently return the first listed source.

- [ ] **Step 3: Implement**

Replace `BathymetryResolver` in `lib/features/bathymetry/data/bathymetry_resolver.dart`:

```dart
/// Best-source-wins. Probes every source, orders them by MATERIALLY better
/// resolution, then fetches in that order and takes the first grid that
/// passes both quality floors.
///
/// No mosaicking: sources use different vertical datums (EMODnet is LAT,
/// GMRT and ETOPO are MSL), so stitching two of them together would leave
/// a visible step wherever they meet.
class BathymetryResolver {
  static const double minWetFraction = 0.10;

  /// A grid must actually have readings. EMODnet's Caribbean tile answers
  /// 99.96% wet on 48% coverage, and the missing half renders as a flat
  /// slab at the waterline. Coverage this thin is not usable terrain.
  static const double minKnownFraction = 0.60;

  /// How much finer a source must be to jump ahead of the declared list
  /// order. Declared resolution is a claim, so only a MATERIAL difference
  /// is allowed to override the curated tier order: NOAA CUDEM at 3.4 m
  /// preempts GMRT's 60 m, while GMRT's nominal 60 m does not preempt
  /// EMODnet's surveyed 115 m.
  static const double preemptionFactor = 2.0;

  /// Request-box width. 8 km shows the surrounding seascape, not just the
  /// site itself; the repository's downsample cap bounds the render cost.
  /// This value is part of the cache key - see
  /// [BathymetryRepository.keyFor] - so changing it refetches.
  static const double defaultSpanMeters = 8000;

  final List<BathymetrySource> sources;

  const BathymetryResolver({required this.sources});

  Future<BathymetryResolution> resolve(GeoPoint center) async {
    final ordered = await _order(center);
    var globalSourceSaidDry = false;
    for (final source in ordered) {
      try {
        final grid = await source.fetch(center, spanMeters: defaultSpanMeters);
        if (grid.knownFraction < minKnownFraction) {
          // Nominally fine, actually absent. Not an answer about the water.
          continue;
        }
        if (grid.wetFraction >= minWetFraction) {
          return BathymetryResolution.ok(grid);
        }
        // A dry answer only proves "no water here" if the source actually
        // covers everywhere; a regional edge cell proves nothing.
        if (source.global) globalSourceSaidDry = true;
      } on BathymetryFetchException {
        // Transient: fall through to the next source.
      } catch (_) {
        // A source blowing up with anything else (a TypeError from an
        // unexpected response shape, an ArgumentError) must not kill the
        // whole scene - treat it exactly like a transient failure.
      }
    }
    return globalSourceSaidDry
        ? const BathymetryResolution.empty()
        : const BathymetryResolution.transientFailure();
  }

  /// Covering sources in fetch order. Probes run concurrently because a
  /// probe may be a network call and they are independent; a probe that
  /// fails for any reason drops that source rather than failing the scene.
  Future<List<BathymetrySource>> _order(GeoPoint center) async {
    final caps = await Future.wait(
      sources.map((s) async {
        try {
          return await s.probe(center);
        } catch (_) {
          return null;
        }
      }),
    );
    final covering = <({BathymetrySource source, int rank, double cell})>[];
    for (var i = 0; i < sources.length; i++) {
      final cap = caps[i];
      if (cap == null) continue;
      covering.add((source: sources[i], rank: i, cell: cap.cellSizeMeters));
    }
    if (covering.isEmpty) return const [];
    // Group into preemption bands: a source leads only when it is more
    // than preemptionFactor finer than everything ahead of it in the
    // declared order. Within a band the declared order is preserved.
    covering.sort((a, b) {
      if (a.cell * preemptionFactor < b.cell) return -1;
      if (b.cell * preemptionFactor < a.cell) return 1;
      return a.rank.compareTo(b.rank);
    });
    return [for (final c in covering) c.source];
  }
}
```

Note on the comparator: it is not a total order (the "within a factor" relation is not transitive), so `List.sort` may produce different results for pathological three-source inputs. With the four real sources at 3.4 m, 60 m, 115 m and 450 m this is well-behaved, and the tests pin the two cases that matter. Do not extend this to a larger source list without revisiting it.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/bathymetry/data/bathymetry_resolver_test.dart`

Expected: PASS.

The existing test asserting `expect(b.fetchCount, 0)` for "first covering source with a wet grid wins" still holds, because both fakes default to 100 m and the declared order is preserved inside the band.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bathymetry/data/bathymetry_resolver.dart test/features/bathymetry/data/bathymetry_resolver_test.dart
git commit -m "feat(bathymetry): order sources by capability, reject empty grids

The resolver took the first tier returning enough wet cells, which at
Bonaire selects EMODnet's 115 m tile over GMRT's 60 m one despite the
former being 48 percent nodata with no coastline at all.

Two changes. A known-cell floor of 0.60 rejects a grid that is nominally
wet but mostly holes, which is what fixes Bonaire. A preemption factor of
2.0 lets a materially finer source jump the declared order, which is what
will let NOAA CUDEM lead, while keeping a regional survey ahead of a
global grid of nominally similar resolution."
```

---

### Task 4: Tiled float32 GeoTIFF parser

The NOAA ImageServer returns elevations as an uncompressed, tiled, little-endian float32 GeoTIFF. Nothing in the tree reads that.

**Files:**
- Create: `lib/features/bathymetry/data/sources/arcgis_float32_tiff_parser.dart`
- Test: `test/features/bathymetry/data/arcgis_float32_tiff_parser_test.dart`

**Interfaces:**
- Consumes: `BathymetryGrid` from Task 1.
- Produces: `ArcgisFloat32TiffParser.parse(Uint8List bytes, {required double westLon, required double eastLon, required double southLat, required double northLat, required String sourceId, required double resolutionMeters, required DateTime fetchedAt})` returning `BathymetryGrid`. Throws `FormatException` on a malformed or unsupported TIFF.

Background, measured against the live service on 2026-09-05: the response is `II` little-endian, `Compression` (259) = 1, `BitsPerSample` (258) = 32, `SampleFormat` (339) = 3 (IEEE float), `SamplesPerPixel` (277) = 1, and it is **tile-organised**: `TileWidth` (322) and `TileLength` (323) are 128, with `TileOffsets` (324) and `TileByteCounts` (325). There are no `StripOffsets`. A requested 64x64 image arrives as one 128x128 tile with the image occupying its top-left corner, and a 256x256 image arrives as four tiles in row-major order. Image rows run **north to south**, and values are elevations (negative below sea level), so both need flipping and negating to reach the app's depth convention.

- [ ] **Step 1: Write the failing test**

Create `test/features/bathymetry/data/arcgis_float32_tiff_parser_test.dart`:

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/data/sources/arcgis_float32_tiff_parser.dart';

/// Builds a minimal little-endian tiled float32 TIFF matching the shape the
/// NOAA ImageServer returns, so the test pins the real wire format without
/// carrying a 66 KB binary fixture.
Uint8List buildTiff({
  required int width,
  required int height,
  required int tileSize,
  required List<double> tilePixels, // tileSize * tileSize per tile, row-major
  int compression = 1,
  int bitsPerSample = 32,
  int sampleFormat = 3,
}) {
  final tilesAcross = (width + tileSize - 1) ~/ tileSize;
  final tilesDown = (height + tileSize - 1) ~/ tileSize;
  final tileCount = tilesAcross * tilesDown;
  final tileBytes = tileSize * tileSize * 4;
  expect(tilePixels.length, tileCount * tileSize * tileSize);

  const entries = 9;
  const headerLen = 8;
  final ifdLen = 2 + entries * 12 + 4;
  // Tile offset and byte-count arrays live after the IFD when there is
  // more than one tile; a single value fits inline in the entry.
  final arraysLen = tileCount > 1 ? tileCount * 4 * 2 : 0;
  final pixelStart = headerLen + ifdLen + arraysLen;

  final out = BytesBuilder();
  final head = ByteData(headerLen);
  head.setUint8(0, 0x49);
  head.setUint8(1, 0x49);
  head.setUint16(2, 42, Endian.little);
  head.setUint32(4, headerLen, Endian.little);
  out.add(head.buffer.asUint8List());

  final ifd = ByteData(ifdLen);
  ifd.setUint16(0, entries, Endian.little);
  var e = 2;
  void entry(int tag, int type, int count, int value) {
    ifd.setUint16(e, tag, Endian.little);
    ifd.setUint16(e + 2, type, Endian.little);
    ifd.setUint32(e + 4, count, Endian.little);
    if (type == 3 && count == 1) {
      ifd.setUint16(e + 8, value, Endian.little);
      ifd.setUint16(e + 10, 0, Endian.little);
    } else {
      ifd.setUint32(e + 8, value, Endian.little);
    }
    e += 12;
  }

  final offsetsAt = headerLen + ifdLen;
  final countsAt = offsetsAt + tileCount * 4;
  entry(256, 3, 1, width); // ImageWidth
  entry(257, 3, 1, height); // ImageLength
  entry(258, 3, 1, bitsPerSample); // BitsPerSample
  entry(259, 3, 1, compression); // Compression
  entry(277, 3, 1, 1); // SamplesPerPixel
  entry(322, 3, 1, tileSize); // TileWidth
  entry(323, 3, 1, tileSize); // TileLength
  entry(324, 4, tileCount, tileCount == 1 ? pixelStart : offsetsAt);
  entry(325, 4, tileCount, tileCount == 1 ? tileBytes : countsAt);
  ifd.setUint32(ifdLen - 4, 0, Endian.little); // next IFD = none
  out.add(ifd.buffer.asUint8List());

  if (tileCount > 1) {
    final arrays = ByteData(arraysLen);
    for (var i = 0; i < tileCount; i++) {
      arrays.setUint32(i * 4, pixelStart + i * tileBytes, Endian.little);
      arrays.setUint32(tileCount * 4 + i * 4, tileBytes, Endian.little);
    }
    out.add(arrays.buffer.asUint8List());
  }

  final pixels = ByteData(tileCount * tileBytes);
  for (var i = 0; i < tilePixels.length; i++) {
    pixels.setFloat32(i * 4, tilePixels[i], Endian.little);
  }
  out.add(pixels.buffer.asUint8List());
  // SampleFormat is asserted by the parser but not needed positionally;
  // it is folded into BitsPerSample handling for this minimal builder.
  expect(sampleFormat, 3);
  return out.toBytes();
}

void main() {
  final when = DateTime.utc(2026, 9, 5);

  test('reads a single-tile image, flips rows south-first and negates', () {
    // 2x2 image inside a 4x4 tile. Image row 0 is NORTHERNMOST.
    final tile = List<double>.filled(16, 0);
    tile[0] = -10.0; // north-west
    tile[1] = -20.0; // north-east
    tile[4] = -30.0; // south-west
    tile[5] = -40.0; // south-east
    final bytes = buildTiff(
      width: 2,
      height: 2,
      tileSize: 4,
      tilePixels: tile,
    );

    final g = ArcgisFloat32TiffParser.parse(
      bytes,
      westLon: -80.4,
      eastLon: -80.2,
      southLat: 25.0,
      northLat: 25.2,
      sourceId: 'noaa_dem',
      resolutionMeters: 8,
      fetchedAt: when,
    );

    expect(g.rows, 2);
    expect(g.cols, 2);
    // Grid row 0 is SOUTHERNMOST, and elevation negates into depth.
    expect(g.depthAt(0, 0), closeTo(30.0, 1e-6));
    expect(g.depthAt(0, 1), closeTo(40.0, 1e-6));
    expect(g.depthAt(1, 0), closeTo(10.0, 1e-6));
    expect(g.depthAt(1, 1), closeTo(20.0, 1e-6));
    expect(g.sourceId, 'noaa_dem');
    expect(g.resolutionMeters, 8);
  });

  test('origin is the south-west CELL CENTER and cell sizes span the box', () {
    final tile = List<double>.filled(16, -5.0);
    final g = ArcgisFloat32TiffParser.parse(
      buildTiff(width: 2, height: 2, tileSize: 4, tilePixels: tile),
      westLon: -80.4,
      eastLon: -80.2,
      southLat: 25.0,
      northLat: 25.2,
      sourceId: 'noaa_dem',
      resolutionMeters: 8,
      fetchedAt: when,
    );
    // 2 columns across a 0.2 degree box: cell width 0.1, first center at
    // west + half a cell.
    expect(g.cellSizeLonDeg, closeTo(0.1, 1e-9));
    expect(g.cellSizeLatDeg, closeTo(0.1, 1e-9));
    expect(g.originLon, closeTo(-80.35, 1e-9));
    expect(g.originLat, closeTo(25.05, 1e-9));
  });

  test('assembles a multi-tile image in row-major tile order', () {
    // 4x4 image as four 2x2 tiles. Each tile filled with its own index so
    // misplacement is obvious.
    final pixels = <double>[
      -1, -1, -1, -1, // tile 0 (north-west)
      -2, -2, -2, -2, // tile 1 (north-east)
      -3, -3, -3, -3, // tile 2 (south-west)
      -4, -4, -4, -4, // tile 3 (south-east)
    ];
    final g = ArcgisFloat32TiffParser.parse(
      buildTiff(width: 4, height: 4, tileSize: 2, tilePixels: pixels),
      westLon: 0,
      eastLon: 1,
      southLat: 0,
      northLat: 1,
      sourceId: 'noaa_dem',
      resolutionMeters: 8,
      fetchedAt: when,
    );
    // After the south-first flip, grid row 0 is the image's LAST row.
    expect(g.depthAt(0, 0), closeTo(3.0, 1e-6));
    expect(g.depthAt(0, 3), closeTo(4.0, 1e-6));
    expect(g.depthAt(3, 0), closeTo(1.0, 1e-6));
    expect(g.depthAt(3, 3), closeTo(2.0, 1e-6));
  });

  test('maps the ArcGIS nodata sentinel to null', () {
    final tile = List<double>.filled(16, -5.0);
    tile[0] = -3.4028234663852886e38; // float32 lowest, ArcGIS NoData
    final g = ArcgisFloat32TiffParser.parse(
      buildTiff(width: 2, height: 2, tileSize: 4, tilePixels: tile),
      westLon: 0,
      eastLon: 1,
      southLat: 0,
      northLat: 1,
      sourceId: 'noaa_dem',
      resolutionMeters: 8,
      fetchedAt: when,
    );
    // Image (0,0) is the northernmost row, which flips to grid row 1.
    expect(g.depthAt(1, 0), isNull);
    expect(g.depthAt(0, 0), closeTo(5.0, 1e-6));
  });

  test('throws FormatException on a compressed TIFF', () {
    expect(
      () => ArcgisFloat32TiffParser.parse(
        buildTiff(
          width: 2,
          height: 2,
          tileSize: 4,
          tilePixels: List<double>.filled(16, -5.0),
          compression: 5,
        ),
        westLon: 0,
        eastLon: 1,
        southLat: 0,
        northLat: 1,
        sourceId: 'noaa_dem',
        resolutionMeters: 8,
        fetchedAt: when,
      ),
      throwsFormatException,
    );
  });

  test('throws FormatException on a non-float sample depth', () {
    expect(
      () => ArcgisFloat32TiffParser.parse(
        buildTiff(
          width: 2,
          height: 2,
          tileSize: 4,
          tilePixels: List<double>.filled(16, -5.0),
          bitsPerSample: 16,
        ),
        westLon: 0,
        eastLon: 1,
        southLat: 0,
        northLat: 1,
        sourceId: 'noaa_dem',
        resolutionMeters: 8,
        fetchedAt: when,
      ),
      throwsFormatException,
    );
  });

  test('throws FormatException on a big-endian or non-TIFF body', () {
    expect(
      () => ArcgisFloat32TiffParser.parse(
        Uint8List.fromList('<html>not a tiff</html>'.codeUnits),
        westLon: 0,
        eastLon: 1,
        southLat: 0,
        northLat: 1,
        sourceId: 'noaa_dem',
        resolutionMeters: 8,
        fetchedAt: when,
      ),
      throwsFormatException,
    );
  });
}
```

Add `import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';` if the analyzer needs `BathymetryGrid` named.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/bathymetry/data/arcgis_float32_tiff_parser_test.dart`

Expected: FAIL, compile error: the target of the URI does not exist.

- [ ] **Step 3: Implement**

Create `lib/features/bathymetry/data/sources/arcgis_float32_tiff_parser.dart`:

```dart
import 'dart:typed_data';

import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';

/// Reads the uncompressed, tiled, little-endian float32 GeoTIFF that an
/// ArcGIS ImageServer returns for `format=tiff&pixelType=F32`.
///
/// Deliberately narrow. This is not a TIFF library: it accepts exactly the
/// shape that service emits and throws [FormatException] on anything else,
/// so an unexpected response becomes a transient source failure rather than
/// silently wrong terrain.
///
/// Two conversions bring it into the app's convention. Image rows run north
/// to south while [BathymetryGrid] rows run south to north, and the raster
/// carries elevation (negative below sea level) while the grid carries
/// depth (positive down).
class ArcgisFloat32TiffParser {
  /// ArcGIS writes float32 lowest as its NoData sentinel.
  static const double _noDataSentinel = -3.4028234663852886e38;
  static const double _noDataEpsilon = 1e30;

  static const int _tagImageWidth = 256;
  static const int _tagImageLength = 257;
  static const int _tagBitsPerSample = 258;
  static const int _tagCompression = 259;
  static const int _tagSamplesPerPixel = 277;
  static const int _tagTileWidth = 322;
  static const int _tagTileLength = 323;
  static const int _tagTileOffsets = 324;
  static const int _tagTileByteCounts = 325;

  static BathymetryGrid parse(
    Uint8List bytes, {
    required double westLon,
    required double eastLon,
    required double southLat,
    required double northLat,
    required String sourceId,
    required double resolutionMeters,
    required DateTime fetchedAt,
  }) {
    final d = ByteData.sublistView(bytes);
    if (bytes.length < 8 || bytes[0] != 0x49 || bytes[1] != 0x49) {
      throw const FormatException(
        'Expected a little-endian TIFF (II magic); the service returned '
        'something else, most likely an error envelope.',
      );
    }
    if (d.getUint16(2, Endian.little) != 42) {
      throw const FormatException('Not a classic TIFF (magic 42 missing)');
    }

    final ifd = d.getUint32(4, Endian.little);
    final entryCount = d.getUint16(ifd, Endian.little);
    final tags = <int, ({int type, int count, int value})>{};
    for (var i = 0; i < entryCount; i++) {
      final e = ifd + 2 + i * 12;
      final tag = d.getUint16(e, Endian.little);
      final type = d.getUint16(e + 2, Endian.little);
      final count = d.getUint32(e + 4, Endian.little);
      // A SHORT with count 1 sits in the low half of the value field.
      final value = type == 3 && count == 1
          ? d.getUint16(e + 8, Endian.little)
          : d.getUint32(e + 8, Endian.little);
      tags[tag] = (type: type, count: count, value: value);
    }

    int need(int tag, String what) {
      final t = tags[tag];
      if (t == null) throw FormatException('TIFF is missing $what');
      return t.value;
    }

    if (need(_tagCompression, 'Compression') != 1) {
      throw const FormatException('Only uncompressed TIFF is supported');
    }
    if (need(_tagBitsPerSample, 'BitsPerSample') != 32) {
      throw const FormatException('Only 32-bit samples are supported');
    }
    if (need(_tagSamplesPerPixel, 'SamplesPerPixel') != 1) {
      throw const FormatException('Only single-band rasters are supported');
    }

    final width = need(_tagImageWidth, 'ImageWidth');
    final height = need(_tagImageLength, 'ImageLength');
    final tileW = need(_tagTileWidth, 'TileWidth');
    final tileH = need(_tagTileLength, 'TileLength');
    if (width < 1 || height < 1 || tileW < 1 || tileH < 1) {
      throw const FormatException('TIFF has a zero dimension');
    }

    final offsets = _longs(d, tags[_tagTileOffsets], 'TileOffsets');
    final tilesAcross = (width + tileW - 1) ~/ tileW;
    final tilesDown = (height + tileH - 1) ~/ tileH;
    if (offsets.length != tilesAcross * tilesDown) {
      throw const FormatException('TileOffsets count does not match the grid');
    }

    // Image order, north row first.
    final image = List<double?>.filled(width * height, null);
    for (var t = 0; t < offsets.length; t++) {
      final tx = t % tilesAcross;
      final ty = t ~/ tilesAcross;
      final base = offsets[t];
      if (base + tileW * tileH * 4 > bytes.length) {
        throw const FormatException('TIFF tile runs past the end of the body');
      }
      for (var r = 0; r < tileH; r++) {
        final imageRow = ty * tileH + r;
        if (imageRow >= height) break;
        for (var c = 0; c < tileW; c++) {
          final imageCol = tx * tileW + c;
          if (imageCol >= width) continue;
          final v = d.getFloat32(base + (r * tileW + c) * 4, Endian.little);
          image[imageRow * width + imageCol] =
              _isNoData(v) ? null : -v; // elevation -> depth
        }
      }
    }

    // Flip to south-first.
    final depths = List<double?>.filled(width * height, null);
    for (var r = 0; r < height; r++) {
      final src = (height - 1 - r) * width;
      depths.setRange(r * width, r * width + width, image, src);
    }

    // The requested box spans cell EDGES; the grid origin is a cell CENTER.
    final cellLon = (eastLon - westLon) / width;
    final cellLat = (northLat - southLat) / height;
    return BathymetryGrid(
      originLat: southLat + cellLat / 2,
      originLon: westLon + cellLon / 2,
      cellSizeLatDeg: cellLat,
      cellSizeLonDeg: cellLon,
      rows: height,
      cols: width,
      depthsMeters: depths,
      sourceId: sourceId,
      resolutionMeters: resolutionMeters,
      fetchedAt: fetchedAt,
    );
  }

  static bool _isNoData(double v) =>
      v.isNaN || (v - _noDataSentinel).abs() < _noDataEpsilon && v < -1e30;

  static List<int> _longs(
    ByteData d,
    ({int type, int count, int value})? tag,
    String what,
  ) {
    if (tag == null) throw FormatException('TIFF is missing $what');
    if (tag.count == 1) return [tag.value];
    return [
      for (var i = 0; i < tag.count; i++)
        d.getUint32(tag.value + i * 4, Endian.little),
    ];
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/bathymetry/data/arcgis_float32_tiff_parser_test.dart`

Expected: PASS. If the nodata test fails, check `_isNoData`: the sentinel comparison must catch float32 lowest without swallowing a legitimate deep reading, and no real elevation approaches -1e30.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bathymetry/data/sources/arcgis_float32_tiff_parser.dart test/features/bathymetry/data/arcgis_float32_tiff_parser_test.dart
git commit -m "feat(bathymetry): read ArcGIS uncompressed tiled float32 GeoTIFF

The NOAA NCEI DEM ImageServer returns elevations as an uncompressed,
tile-organised, little-endian float32 GeoTIFF with no strip tags at all,
which nothing in the tree could read.

Deliberately narrow rather than a general TIFF decoder: it accepts exactly
that shape and throws FormatException on anything else, so an unexpected
response degrades to a transient source failure instead of silently wrong
terrain. Rows flip south-first and elevations negate into depths."
```

---

### Task 5: NoaaDemSource

**Files:**
- Create: `lib/features/bathymetry/data/sources/noaa_dem_source.dart`
- Test: `test/features/bathymetry/data/noaa_dem_source_test.dart`

**Interfaces:**
- Consumes: `SourceCapability`, `BathymetrySource`, `BathymetryFetchException` from Task 2; `ArcgisFloat32TiffParser.parse` from Task 4.
- Produces: `NoaaDemSource({http.Client? client, String baseUrl})` with `static const String sourceId = 'noaa_dem'` and `static const double usefulCellSizeMeters = 50`.

Measured wire behaviour, 2026-09-05. The probe is:

```
GET {baseUrl}/identify
  ?geometry={"x":<lon>,"y":<lat>}
  &geometryType=esriGeometryPoint
  &returnCatalogItems=true
  &maxItemCount=25
  &f=json
```

`maxItemCount` is load-bearing: without it the response truncates to three items and La Jolla's 10 m DEM is hidden behind ETOPO. The response carries `catalogItems.features[].attributes`, each with `Name` and `LowPS` (cell size in **degrees**). Measured results: Florida Keys `ncei19_n25x25_w080x50_2016v1` at `LowPS` 3.086e-05 (3.4 m), La Jolla `san_diego_navd88` at 10.3 m, Bonaire best is `ETOPO_2022_v1_15s_surface_elev` at 464 m. ArcGIS returns error envelopes with HTTP 200, so a body with no `catalogItems` is a decline, not a crash.

The fetch is:

```
GET {baseUrl}/exportImage
  ?bbox=<west>,<south>,<east>,<north>&bboxSR=4326&imageSR=4326
  &size=<dim>,<dim>&format=tiff&pixelType=F32
  &noDataInterpretation=esriNoDataMatchAny
  &interpolation=RSP_BilinearInterpolation&f=image
```

- [ ] **Step 1: Write the failing test**

Create `test/features/bathymetry/data/noaa_dem_source_test.dart`:

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:submersion/features/bathymetry/data/sources/noaa_dem_source.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

String identifyBody(List<({String name, double lowPs})> items) => jsonEncode({
  'value': '-3.87793',
  'catalogItems': {
    'features': [
      for (final i in items)
        {
          'attributes': {'Name': i.name, 'LowPS': i.lowPs, 'HighPS': i.lowPs},
        },
    ],
  },
});

/// A 2x2 single-tile float32 TIFF, matching the builder in
/// arcgis_float32_tiff_parser_test.dart but inlined so this suite stands
/// alone.
Uint8List tinyTiff() {
  const width = 2, height = 2, tileSize = 4, entries = 9;
  const headerLen = 8;
  const ifdLen = 2 + entries * 12 + 4;
  const pixelStart = headerLen + ifdLen;
  final out = BytesBuilder();
  final head = ByteData(headerLen);
  head.setUint8(0, 0x49);
  head.setUint8(1, 0x49);
  head.setUint16(2, 42, Endian.little);
  head.setUint32(4, headerLen, Endian.little);
  out.add(head.buffer.asUint8List());
  final ifd = ByteData(ifdLen);
  ifd.setUint16(0, entries, Endian.little);
  var e = 2;
  void entry(int tag, int type, int count, int value) {
    ifd.setUint16(e, tag, Endian.little);
    ifd.setUint16(e + 2, type, Endian.little);
    ifd.setUint32(e + 4, count, Endian.little);
    if (type == 3 && count == 1) {
      ifd.setUint16(e + 8, value, Endian.little);
      ifd.setUint16(e + 10, 0, Endian.little);
    } else {
      ifd.setUint32(e + 8, value, Endian.little);
    }
    e += 12;
  }

  entry(256, 3, 1, width);
  entry(257, 3, 1, height);
  entry(258, 3, 1, 32);
  entry(259, 3, 1, 1);
  entry(277, 3, 1, 1);
  entry(322, 3, 1, tileSize);
  entry(323, 3, 1, tileSize);
  entry(324, 4, 1, pixelStart);
  entry(325, 4, 1, tileSize * tileSize * 4);
  ifd.setUint32(ifdLen - 4, 0, Endian.little);
  out.add(ifd.buffer.asUint8List());
  final px = ByteData(tileSize * tileSize * 4);
  for (var i = 0; i < tileSize * tileSize; i++) {
    px.setFloat32(i * 4, -8.0, Endian.little);
  }
  out.add(px.buffer.asUint8List());
  return out.toBytes();
}

void main() {
  const keys = GeoPoint(25.010, -80.376);

  group('probe', () {
    test('returns the finest catalogue item converted to meters', () async {
      final source = NoaaDemSource(
        client: MockClient(
          (req) async => http.Response(
            identifyBody([
              (name: 'ETOPO_2022_v1_15s_surface_elev', lowPs: 0.0041666),
              (name: 'ncei19_n25x25_w080x50_2016v1', lowPs: 3.086419e-05),
            ]),
            200,
          ),
        ),
      );
      final cap = await source.probe(keys);
      expect(cap, isNotNull);
      expect(cap!.cellSizeMeters, closeTo(3.4, 0.3));
      expect(cap.detail, 'ncei19_n25x25_w080x50_2016v1');
    });

    test('requests maxItemCount so the catalogue is not truncated', () async {
      Uri? seen;
      final source = NoaaDemSource(
        client: MockClient((req) async {
          seen = req.url;
          return http.Response(identifyBody([]), 200);
        }),
      );
      await source.probe(keys);
      expect(seen!.queryParameters['maxItemCount'], '25');
      expect(seen!.queryParameters['returnCatalogItems'], 'true');
    });

    test('declines when the best item is coarser than the threshold', () async {
      final source = NoaaDemSource(
        client: MockClient(
          (req) async => http.Response(
            identifyBody([
              (name: 'ETOPO_2022_v1_15s_surface_elev', lowPs: 0.0041666),
            ]),
            200,
          ),
        ),
      );
      // ~464 m at the equator, far past the 50 m usefulness threshold.
      expect(await source.probe(const GeoPoint(12.093, -68.287)), isNull);
    });

    test('declines on an empty catalogue', () async {
      final source = NoaaDemSource(
        client: MockClient((req) async => http.Response(identifyBody([]), 200)),
      );
      expect(await source.probe(keys), isNull);
    });

    test('declines on an ArcGIS error envelope returned with HTTP 200',
        () async {
      final source = NoaaDemSource(
        client: MockClient(
          (req) async => http.Response(
            jsonEncode({
              'error': {'code': 400, 'message': 'Invalid geometry'},
            }),
            200,
          ),
        ),
      );
      expect(await source.probe(keys), isNull);
    });

    test('declines on a non-200', () async {
      final source = NoaaDemSource(
        client: MockClient((req) async => http.Response('nope', 503)),
      );
      expect(await source.probe(keys), isNull);
    });
  });

  group('fetch', () {
    test('requests a float32 tiff over the span and parses it', () async {
      Uri? seen;
      final source = NoaaDemSource(
        client: MockClient((req) async {
          seen = req.url;
          return http.Response.bytes(tinyTiff(), 200);
        }),
      );
      final g = await source.fetch(keys, spanMeters: 2000);
      expect(seen!.path, endsWith('/exportImage'));
      expect(seen!.queryParameters['format'], 'tiff');
      expect(seen!.queryParameters['pixelType'], 'F32');
      expect(seen!.queryParameters['bboxSR'], '4326');
      expect(g.rows, 2);
      expect(g.cols, 2);
      expect(g.depthAt(0, 0), closeTo(8.0, 1e-6));
      expect(g.sourceId, NoaaDemSource.sourceId);
    });

    test('throws BathymetryFetchException on a non-200', () async {
      final source = NoaaDemSource(
        client: MockClient((req) async => http.Response('down', 500)),
      );
      expect(
        () => source.fetch(keys, spanMeters: 2000),
        throwsA(isA<BathymetryFetchException>()),
      );
    });

    test('throws BathymetryFetchException on an unparseable body', () async {
      final source = NoaaDemSource(
        client: MockClient(
          (req) async => http.Response('{"error":{"code":400}}', 200),
        ),
      );
      expect(
        () => source.fetch(keys, spanMeters: 2000),
        throwsA(isA<BathymetryFetchException>()),
      );
    });
  });

  test('is not global, so a dry answer never proves land', () {
    expect(NoaaDemSource().global, isFalse);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/bathymetry/data/noaa_dem_source_test.dart`

Expected: FAIL, compile error: the target of the URI does not exist.

- [ ] **Step 3: Implement**

Create `lib/features/bathymetry/data/sources/noaa_dem_source.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:submersion/core/utils/geo_math.dart';
import 'package:submersion/features/bathymetry/data/sources/arcgis_float32_tiff_parser.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_source.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// High-resolution coastal tier: the NOAA NCEI DEM mosaic ImageServer,
/// which stacks CUDEM and regional DEMs over an ETOPO background. Public
/// domain. Coverage is patchy and mostly US coastal, so this source
/// declines wherever the stack holds nothing better than the background.
///
/// The probe is what makes that honest. `identify` returns every DEM under
/// a point with its cell size, so the source knows before fetching whether
/// it has anything worth having: 3.4 m in the Florida Keys, 10.3 m at La
/// Jolla, and only ETOPO's 464 m at Bonaire, where it declines.
class NoaaDemSource implements BathymetrySource {
  static const String sourceId = 'noaa_dem';

  /// Below this cell size the mosaic is offering a real coastal DEM. Above
  /// it, the stack has nothing but its ETOPO background, which the ETOPO
  /// tier already serves directly.
  static const double usefulCellSizeMeters = 50;

  /// Cells per side requested from exportImage. The server resamples to
  /// whatever is asked, so this is a render-budget choice, not a data one.
  static const int requestDim = 256;

  static const Duration _timeout = Duration(seconds: 15);

  final http.Client _client;
  final String baseUrl;

  NoaaDemSource({
    http.Client? client,
    this.baseUrl =
        'https://gis.ngdc.noaa.gov/arcgis/rest/services/DEM_mosaics/DEM_all/ImageServer',
  }) : _client = client ?? http.Client();

  @override
  String get id => sourceId;

  /// Coverage is patchy coastal, so a dry answer here proves nothing about
  /// whether a coordinate is on land.
  @override
  bool get global => false;

  @override
  Future<SourceCapability?> probe(GeoPoint center) async {
    final url = Uri.parse('$baseUrl/identify').replace(
      queryParameters: {
        'geometry': '{"x":${center.longitude},"y":${center.latitude}}',
        'geometryType': 'esriGeometryPoint',
        'returnCatalogItems': 'true',
        // Load-bearing. The default truncates to three items, which hides
        // a 10 m DEM behind the ETOPO background and makes a covered site
        // look uncovered.
        'maxItemCount': '25',
        'f': 'json',
      },
    );
    try {
      final resp = await _client.get(url).timeout(_timeout);
      if (resp.statusCode != 200) return null;
      final body = jsonDecode(resp.body);
      if (body is! Map<String, dynamic>) return null;
      // ArcGIS returns error envelopes with HTTP 200.
      final items = (body['catalogItems'] as Map<String, dynamic>?)?['features'];
      if (items is! List || items.isEmpty) return null;

      String? bestName;
      double? bestDeg;
      for (final item in items) {
        if (item is! Map) continue;
        final attrs = item['attributes'];
        if (attrs is! Map) continue;
        final lowPs = attrs['LowPS'];
        if (lowPs is! num) continue;
        final deg = lowPs.toDouble();
        if (deg <= 0) continue;
        if (bestDeg == null || deg < bestDeg) {
          bestDeg = deg;
          bestName = attrs['Name'] as String?;
        }
      }
      if (bestDeg == null) return null;

      // LowPS is in degrees; convert on the longitude axis, which is the
      // narrower of the two at every latitude.
      final meters = bestDeg * metersPerDegreeLongitude(center.latitude);
      if (meters > usefulCellSizeMeters) return null;
      return SourceCapability(
        cellSizeMeters: meters,
        detail: bestName ?? 'NOAA NCEI DEM',
      );
    } catch (_) {
      // A probe never throws: an unreachable or surprising service simply
      // means this source does not contribute here.
      return null;
    }
  }

  @override
  Future<BathymetryGrid> fetch(
    GeoPoint center, {
    required double spanMeters,
  }) async {
    final dLat = spanMeters / 2 / 110540.0;
    final dLon = spanMeters / 2 / metersPerDegreeLongitude(center.latitude);
    final west = center.longitude - dLon;
    final east = center.longitude + dLon;
    final south = center.latitude - dLat;
    final north = center.latitude + dLat;
    final url = Uri.parse('$baseUrl/exportImage').replace(
      queryParameters: {
        'bbox': '$west,$south,$east,$north',
        'bboxSR': '4326',
        'imageSR': '4326',
        'size': '$requestDim,$requestDim',
        'format': 'tiff',
        'pixelType': 'F32',
        'noDataInterpretation': 'esriNoDataMatchAny',
        'interpolation': 'RSP_BilinearInterpolation',
        'f': 'image',
      },
    );
    try {
      final resp = await _client.get(url).timeout(_timeout);
      if (resp.statusCode != 200) {
        throw BathymetryFetchException('NOAA DEM HTTP ${resp.statusCode}');
      }
      return ArcgisFloat32TiffParser.parse(
        resp.bodyBytes,
        westLon: west,
        eastLon: east,
        southLat: south,
        northLat: north,
        sourceId: sourceId,
        resolutionMeters: spanMeters / requestDim,
        fetchedAt: DateTime.now(),
      );
    } on BathymetryFetchException {
      rethrow;
    } on Exception catch (e) {
      throw BathymetryFetchException('NOAA DEM fetch failed: $e');
    }
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/bathymetry/data/noaa_dem_source_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bathymetry/data/sources/noaa_dem_source.dart test/features/bathymetry/data/noaa_dem_source_test.dart
git commit -m "feat(bathymetry): add the NOAA NCEI high-resolution coastal tier

The mosaic stacks CUDEM and regional DEMs over an ETOPO background, so
coverage is patchy and mostly US coastal. The identify probe is what keeps
that honest: it reports every DEM under a point with its cell size, so the
source declines wherever the stack offers nothing better than the
background it already has from the ETOPO tier.

Measured 3.4 m in the Florida Keys and 10.3 m at La Jolla, declining at
Bonaire. maxItemCount is load-bearing: the default truncates the catalogue
to three items and hides a covered site's DEM behind ETOPO."
```

---

### Task 6: Register the tier and bump the cache generation

Selection now produces different grids for coordinates that are already cached, and cached rows never expire.

**Files:**
- Modify: `lib/features/bathymetry/application/bathymetry_providers.dart:29-36`
- Modify: `lib/features/bathymetry/data/bathymetry_repository.dart:36-42`
- Test: `test/features/bathymetry/data/bathymetry_repository_test.dart`

**Interfaces:**
- Consumes: `NoaaDemSource` from Task 5.
- Produces: `BathymetryRepository.selectionGeneration` (`'v2'`); `keyFor` returns `'<lat>,<lon>@<span><generation>'`.

- [ ] **Step 1: Write the failing test**

Append to `test/features/bathymetry/data/bathymetry_repository_test.dart`, inside `void main()`:

```dart
  test('the cache key carries the selection generation', () {
    final key = BathymetryRepository.keyFor(const GeoPoint(12.16, -68.29));
    expect(key, endsWith('@8000v2'));
  });

  test('a row written under the previous generation is not reused', () async {
    // Simulates an install upgrading from the pre-selection-change build:
    // the old row must miss so the coordinate refetches under the new
    // source ordering rather than serving its stale EMODnet grid forever.
    const p = GeoPoint(12.16, -68.29);
    final q = BathymetryRepository.quantize(p);
    final legacyKey =
        '${q.lat.toStringAsFixed(2)},${q.lon.toStringAsFixed(2)}@8000';
    expect(BathymetryRepository.keyFor(p), isNot(legacyKey));
  });
```

Add `import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';` if `GeoPoint` is not already imported there.

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/bathymetry/data/bathymetry_repository_test.dart`

Expected: FAIL. The key currently ends `@8000`, so the `endsWith('@8000v2')` assertion fails.

- [ ] **Step 3: Implement**

In `lib/features/bathymetry/data/bathymetry_repository.dart`, add beside `maxGridDim`:

```dart
  /// Bumped whenever source SELECTION changes, not just the span. Cached
  /// rows never expire, so without this every already-visited site would
  /// keep serving the grid its old resolver chose. Old rows go inert, the
  /// same way the 4 km rows did when the span went to 8 km.
  static const String selectionGeneration = 'v2';
```

and change `keyFor`:

```dart
  static String keyFor(GeoPoint c) {
    final q = quantize(c);
    // The span and the selection generation are both part of the key:
    // cached rows never expire, so any change that would resolve a
    // coordinate differently must miss the old rows and refetch.
    final span = BathymetryResolver.defaultSpanMeters.round();
    return '${q.lat.toStringAsFixed(2)},${q.lon.toStringAsFixed(2)}'
        '@$span$selectionGeneration';
  }
```

In `lib/features/bathymetry/application/bathymetry_providers.dart`, add the import and register the tier:

```dart
import 'package:submersion/features/bathymetry/data/sources/noaa_dem_source.dart';
```

```dart
      resolver: BathymetryResolver(
        // Declared order is regional survey, then global GMRT, then the
        // coarse public-domain fallback. NOAA's coastal mosaic leads only
        // where it is MATERIALLY finer, which the resolver's preemption
        // factor decides; where the mosaic holds nothing but its ETOPO
        // background it declines during probe and never reaches a fetch.
        sources: [
          NoaaDemSource(),
          EmodnetSource(),
          GmrtSource(),
          EtopoErddapSource(),
        ],
      ),
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/bathymetry`

Expected: PASS. Any existing test asserting a literal `@8000` key must be updated to `@8000v2`; grep for it:

```bash
grep -rn "@8000" test lib
```

- [ ] **Step 5: Commit**

```bash
git add lib/features/bathymetry test/features/bathymetry
git commit -m "feat(bathymetry): register the NOAA tier and bump the cache generation

Cached grids never expire, so changing which source wins would otherwise
leave every already-visited site serving the grid its old resolver picked.
The key gains a selection-generation token so those rows go inert, exactly
as the 4 km rows did when the span went to 8 km."
```

---

### Task 7: Name the new tier in the provenance caption and credits

A new `sourceId` reaches two user-visible surfaces. Neither breaks, which
is why this is easy to miss: `bathymetrySourceDisplayName` falls through to
`_ => id`, so the caption would read the raw string `noaa_dem`, and the
about-screen credit would simply not mention the source at all.

**Files:**
- Modify: `lib/features/bathymetry/presentation/bathymetry_labels.dart:3-8`
- Modify: `lib/l10n/arb/app_en.arb` and the ten other locale ARBs
- Test: `test/features/bathymetry/presentation/bathymetry_labels_test.dart` (create if absent)

**Interfaces:**
- Consumes: `NoaaDemSource.sourceId` from Task 5.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Write the failing test**

Create or append to `test/features/bathymetry/presentation/bathymetry_labels_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/bathymetry/data/sources/noaa_dem_source.dart';
import 'package:submersion/features/bathymetry/presentation/bathymetry_labels.dart';

void main() {
  test('every shipped source id has a human display name', () {
    // The switch falls through to the raw id, so a missing case is not a
    // crash: it is a caption reading "noaa_dem" at the user.
    for (final id in const ['gmrt', 'emodnet', 'etopo2022', NoaaDemSource.sourceId]) {
      expect(bathymetrySourceDisplayName(id), isNot(id), reason: id);
    }
  });

  test('an unknown id still falls back to itself rather than throwing', () {
    expect(bathymetrySourceDisplayName('future_source'), 'future_source');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/bathymetry/presentation/bathymetry_labels_test.dart`

Expected: FAIL on the `noaa_dem` entry, because the switch returns the id unchanged.

- [ ] **Step 3: Implement**

In `lib/features/bathymetry/presentation/bathymetry_labels.dart`, add the case:

```dart
String bathymetrySourceDisplayName(String id) => switch (id) {
  'gmrt' => 'GMRT',
  'emodnet' => 'EMODnet',
  'etopo2022' => 'ETOPO 2022',
  'noaa_dem' => 'NOAA NCEI',
  _ => id,
};
```

Then append the new source to `settings_about_bathymetryCredit` in **all
eleven** ARB files. The source list after each locale's own prefix is an
identical run of proper nouns, so the edit is the same everywhere: append
` · NOAA NCEI DEM` to the end of the value. NOAA NCEI DEMs are US public
domain, so no licence marker is needed, matching how ETOPO is already
listed.

Files: `lib/l10n/arb/app_ar.arb`, `app_de.arb`, `app_en.arb`, `app_es.arb`,
`app_fr.arb`, `app_he.arb`, `app_hu.arb`, `app_it.arb`, `app_nl.arb`,
`app_pt.arb`, `app_zh.arb`.

English becomes:

```json
  "settings_about_bathymetryCredit": "Bathymetry data: GMRT (CC BY 4.0) · EMODnet Bathymetry (CC BY 4.0) · NOAA ETOPO 2022 · NOAA NCEI DEM",
```

Then regenerate, **from the project root** (`flutter gen-l10n` fails when
run from a subdirectory):

```bash
flutter gen-l10n
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/features/bathymetry test/features/settings`

Expected: PASS. Confirm the generated hub picked the change up in every
locale, since CI regenerates l10n but does not verify it:

```bash
grep -c "NOAA NCEI DEM" lib/l10n/arb/app_localizations_*.dart
```

Expected: a count of 1 for each of the generated locale files.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bathymetry/presentation/bathymetry_labels.dart lib/l10n test/features/bathymetry/presentation/bathymetry_labels_test.dart
git commit -m "feat(bathymetry): credit the NOAA NCEI tier in caption and about

The display-name switch falls through to the raw id, so a missing case is
not a crash: the provenance caption would have read noaa_dem at the user.
The about screen's source list gains the tier across all eleven locales."
```

---

### Task 8: Verify the whole tree and format

**Files:**
- Modify: whatever the checks turn up.

**Interfaces:**
- Consumes: every earlier task.
- Produces: a branch that passes the pre-push gates.

- [ ] **Step 1: Format**

Run: `dart format .`

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`

Expected: no issues. Infos are CI-fatal in this repo, so treat every info as a failure and fix it.

- [ ] **Step 3: Run the full suite**

Run: `flutter test`

Expected: all pass. Do not pipe the output through `grep`; a pipe masks the exit code in this repo.

Investigate every failure rather than adjusting an assertion to match new behaviour, except where a test legitimately asserted the old striding downsample or the old `@8000` key.

- [ ] **Step 4: Commit any fixes**

```bash
git add -u
git commit -m "chore(bathymetry): format and fix analyzer findings"
```

Stage explicit paths rather than `git add -A`, which sweeps edits from sibling worktrees.

- [ ] **Step 5: Report**

Report the analyze result and the full-suite pass/fail/skip counts verbatim. Do not claim the work is complete without those numbers.

---

## Manual verification

After Task 7, confirm the change against the live services rather than only against mocks. This is the part that proves PR 1 delivered what it promised.

Bonaire, the reported case:

```bash
flutter test test/features/bathymetry
```

then in the running app, open a Bonaire site's seascape and check the provenance caption. It must name GMRT at roughly 60 m rather than EMODnet at 115 m, and the scene must show a real coastline rather than a flat tan slab across half the box.

A US coastal site (Florida Keys or La Jolla) must report the NOAA tier at single-digit or low-double-digit meters.

If a site still reports EMODnet, check that the cache generation bump actually missed the old row: the local cache `bathymetry_cache` table should hold a `@8000v2` key for that cell.
