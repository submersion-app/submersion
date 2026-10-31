import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// GTR through the analysis service: the curve rides alongside the SAC curve
/// (same pressure track) and is blanked by the service's own calculated
/// ceiling, so the two never disagree about whether deco was in force.
void main() {
  late ProfileAnalysisService service;

  setUp(() {
    service = ProfileAnalysisService(gfLow: 1.0, gfHigh: 1.0);
  });

  /// [minutes] at [depth], sampled every 10 s, draining 3 bar/min at depth
  /// from 230 bar (SAC 1.0 bar/min at 20 m).
  ({List<double> depths, List<int> timestamps, List<double> pressures}) square({
    required double depth,
    required int minutes,
  }) {
    final timestamps = List<int>.generate(minutes * 6 + 1, (i) => i * 10);
    return (
      depths: List<double>.filled(timestamps.length, depth),
      timestamps: timestamps,
      pressures: timestamps.map((t) => 230.0 - 3.0 * t / 60).toList(),
    );
  }

  group('ProfileAnalysisService GTR curve', () {
    test('is aligned with the profile and uses the given reserve', () {
      final p = square(depth: 20.0, minutes: 15);
      final result = service.analyze(
        diveId: 'gtr',
        depths: p.depths,
        timestamps: p.timestamps,
        pressures: p.pressures,
        gtrReserveBar: 50.0,
      );

      expect(result.hasGtrData, isTrue);
      expect(result.gtrCurve!.length, p.depths.length);
      // 200 bar at t = 600 s: 2920 s (see gas_time_remaining_test.dart).
      expect(result.gtrCurve![60], closeTo(2920, 1));

      final bigger = service.analyze(
        diveId: 'gtr-reserve',
        depths: p.depths,
        timestamps: p.timestamps,
        pressures: p.pressures,
        gtrReserveBar: 80.0,
      );
      // 30 bar more reserve at 3 bar/min is 10 min less.
      expect(bigger.gtrCurve![60], closeTo(2920 - 600, 1));
    });

    test('reads the same when the same dive is sampled more densely', () {
      // 15 m time-weighted mean over the window: see gas_time_remaining_test.
      final sparse = service.analyze(
        diveId: 'gtr-sparse',
        depths: const [10.0, 10.0, 30.0],
        timestamps: const [0, 60, 120],
        pressures: const [200.0, 190.0, 180.0],
        gtrReserveBar: 50.0,
      );
      final dense = service.analyze(
        diveId: 'gtr-dense',
        depths: const [10.0, 10.0, 10.0, 30.0],
        timestamps: const [0, 10, 60, 120],
        pressures: const [200.0, 198.33333333333334, 190.0, 180.0],
        gtrReserveBar: 50.0,
      );

      expect(sparse.gtrCurve!.last, 375);
      expect(dense.gtrCurve!.last, 375);
    });

    test('reports no GTR data when every sample is blank', () {
      // A curve of nothing but blanks is not GTR data, and the chart's own
      // availability check agrees; the two must not disagree.
      final analysis = ProfileAnalysis.empty().copyWith(
        gtrCurve: const [null, null, null],
      );

      expect(analysis.hasGtrData, isFalse);
    });

    test('is absent without pressure data', () {
      final p = square(depth: 20.0, minutes: 15);
      final result = service.analyze(
        diveId: 'gtr-no-pressure',
        depths: p.depths,
        timestamps: p.timestamps,
      );

      expect(result.gtrCurve, isNull);
      expect(result.hasGtrData, isFalse);
    });

    test('is blank wherever the calculated ceiling is above zero', () {
      // 40 m on air for 40 min puts the diver well into deco.
      final p = square(depth: 40.0, minutes: 40);
      final result = service.analyze(
        diveId: 'gtr-deco',
        depths: p.depths,
        timestamps: p.timestamps,
        pressures: p.pressures,
      );

      final inDeco = <int>[];
      for (var i = 0; i < p.depths.length; i++) {
        if (result.ceilingCurve[i] > 0) inDeco.add(i);
      }
      expect(inDeco, isNotEmpty, reason: 'fixture must reach deco');
      for (final i in inDeco) {
        expect(result.gtrCurve![i], isNull, reason: 'sample $i is in deco');
      }
      // Before deco and after the SAC window fills, GTR is present.
      expect(result.gtrCurve![12], isNotNull);
    });
  });
}
