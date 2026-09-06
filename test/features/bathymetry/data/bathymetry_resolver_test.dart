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

BathymetryGrid gridOf(List<double?> depths, String sourceId) => BathymetryGrid(
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

class _ErrorSource implements BathymetrySource {
  @override
  String get id => 'boom';
  @override
  bool get global => true;
  @override
  Future<SourceCapability?> probe(GeoPoint center) async =>
      const SourceCapability(cellSizeMeters: 100, detail: 'boom');
  @override
  Future<BathymetryGrid> fetch(GeoPoint c, {required double spanMeters}) async {
    throw ArgumentError('unexpected parser blow-up');
  }
}

class _ThrowingProbeSource implements BathymetrySource {
  @override
  String get id => 'probe-boom';
  @override
  bool get global => false;
  @override
  Future<SourceCapability?> probe(GeoPoint center) async =>
      throw StateError('probe exploded');
  @override
  Future<BathymetryGrid> fetch(
    GeoPoint c, {
    required double spanMeters,
  }) async => throw StateError('should never be fetched');
}

void main() {
  const p = GeoPoint(12.16, -68.29);
  final wet = [for (var i = 0; i < 10; i++) 50.0];
  final dry = [for (var i = 0; i < 10; i++) -5.0];

  test(
    'first covering source with a wet grid wins; later tiers untouched',
    () async {
      final a = FakeSource('a', result: gridWith(wet, 'a'));
      final b = FakeSource('b', result: gridWith(wet, 'b'));
      final res = await BathymetryResolver(sources: [a, b]).resolve(p);
      expect(res.grid!.sourceId, 'a');
      expect(res.definitive, isTrue);
      expect(b.fetchCount, 0);
      // The 8 km extended-extent span reaches the source.
      expect(a.lastSpanMeters, 8000);
    },
  );

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
    final regional = FakeSource('r', global: false, result: gridWith(dry, 'r'));
    final globalDown = FakeSource('g'); // throws
    final res = await BathymetryResolver(
      sources: [regional, globalDown],
    ).resolve(p);
    expect(res.grid, isNull);
    expect(res.definitive, isFalse);
  });

  test('all sources failing is transient', () async {
    final res = await BathymetryResolver(
      sources: [FakeSource('a'), FakeSource('b')],
    ).resolve(p);
    expect(res.grid, isNull);
    expect(res.definitive, isFalse);
  });

  test(
    'a source throwing a non-Exception Error is treated as transient',
    () async {
      // e.g. a TypeError/ArgumentError escaping a parser: must not kill the
      // scene — fall through like any transient failure.
      final blowsUp = _ErrorSource();
      final b = FakeSource('b', result: gridWith(wet, 'b'));
      final res = await BathymetryResolver(sources: [blowsUp, b]).resolve(p);
      expect(res.grid!.sourceId, 'b');
    },
  );

  test('a barely-wet grid below 10% is treated as dry', () async {
    // 1 wet cell of 11 known => ~9%.
    final depths = [50.0, ...List<double?>.filled(10, -1.0)];
    final a = FakeSource('a', result: gridWith(depths, 'a'));
    final res = await BathymetryResolver(sources: [a]).resolve(p);
    expect(res.grid, isNull);
    expect(res.definitive, isTrue);
  });

  test(
    'a mostly-empty grid fails the known-cell floor and falls through',
    () async {
      // 4 known of 10 cells is 40%, below the 60% floor, even though every
      // known cell is wet. This is EMODnet's Bonaire tile in miniature.
      final holey = <double?>[
        50.0, null, 50.0, null, 50.0, null, 50.0, null, null, null, //
      ];
      final a = FakeSource('emodnet-like', result: gridOf(holey, 'a'));
      final b = FakeSource('gmrt-like', result: gridWith(wet, 'b'));
      final res = await BathymetryResolver(sources: [a, b]).resolve(p);
      expect(res.grid!.sourceId, 'b');
      expect(a.fetchCount, 1);
      expect(b.fetchCount, 1);
    },
  );

  test('a grid at exactly the known-cell floor is accepted', () async {
    final atFloor = <double?>[
      50.0, 50.0, 50.0, 50.0, 50.0, 50.0, null, null, null, null, //
    ];
    final a = FakeSource('a', result: gridOf(atFloor, 'a'));
    final res = await BathymetryResolver(sources: [a]).resolve(p);
    expect(res.grid!.sourceId, 'a');
  });

  test(
    'a mostly-empty grid from a global source is not a definitive empty',
    () async {
      // Falling through on coverage must not be mistaken for "no water here":
      // an empty answer would cache and pin the cell forever.
      final holey = <double?>[50.0, null, null, null, null];
      final a = FakeSource('a', result: gridOf(holey, 'a'));
      final res = await BathymetryResolver(sources: [a]).resolve(p);
      expect(res.grid, isNull);
      expect(res.definitive, isFalse);
    },
  );

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

  test(
    'a marginally finer source does not preempt the declared order',
    () async {
      // 60 m against 115 m is a factor of 1.9, inside preemptionFactor, so
      // the declared regional-first order stands. This is EMODnet vs GMRT
      // in Europe, where GMRT's fine nominal grid may be upsampled GEBCO.
      final regional = FakeSource(
        'emodnet',
        result: gridWith(wet, 'emodnet'),
        cellSizeMeters: 115,
      );
      final globalSource = FakeSource(
        'gmrt',
        result: gridWith(wet, 'gmrt'),
        cellSizeMeters: 60,
      );
      final res = await BathymetryResolver(
        sources: [regional, globalSource],
      ).resolve(p);
      expect(res.grid!.sourceId, 'emodnet');
      expect(globalSource.fetchCount, 0);
    },
  );

  test('a probe that throws is treated as not covering', () async {
    final res = await BathymetryResolver(
      sources: [
        _ThrowingProbeSource(),
        FakeSource('b', result: gridWith(wet, 'b')),
      ],
    ).resolve(p);
    expect(res.grid!.sourceId, 'b');
  });
}
