import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/deco/ascent_rate_calculator.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/instrument_tiles.dart';

/// Recreational dive: depth/temperature only, no deco/gas data.
Dive _recDive() => Dive(
  id: 'd1',
  dateTime: DateTime(2026, 1, 1, 10),
  profile: List.generate(
    61,
    (i) => DiveProfilePoint(
      timestamp: i * 10,
      depth: 10,
      temperature: i.isEven ? 20 : null,
    ),
  ),
);

/// Recreational dive with no temperature data at all.
Dive _recDiveNoTemp() => Dive(
  id: 'd3',
  dateTime: DateTime(2026, 1, 1, 10),
  profile: List.generate(
    7,
    (i) => DiveProfilePoint(timestamp: i * 10, depth: 10),
  ),
);

/// Tech dive: 61 points spanning 0-600s. Deco obligation starts at 300s
/// (decoType 2) so timestamp 300 doubles as the "in deco" sample.
Dive _techDive() => Dive(
  id: 'd2',
  dateTime: DateTime(2026, 1, 1, 10),
  tanks: const [DiveTank(id: 't1')],
  profile: List.generate(
    61,
    (i) => DiveProfilePoint(
      timestamp: i * 10,
      depth: 20,
      decoType: i >= 30 ? 2 : 0,
    ),
  ),
);

ProfileAnalysis _techAnalysis() {
  final ndlCurve = List.generate(61, (i) => i < 30 ? 600 - i * 10 : -1);
  final ceilingCurve = List.generate(61, (i) => i < 30 ? 0.0 : 3.0);
  final ttsCurve = List.generate(61, (i) => i < 30 ? 0 : (60 - i) * 10);
  final ppO2Curve = List.generate(61, (_) => 1.2);
  final gfCurve = List.generate(61, (i) => i.toDouble());

  return ProfileAnalysis(
    ascentRates: const [],
    ascentRateStats: const AscentRateStats(
      maxAscentRate: 0,
      maxDescentRate: 0,
      averageAscentRate: 0,
      averageDescentRate: 0,
      violationCount: 0,
      criticalViolationCount: 0,
      timeInViolation: 0,
    ),
    ascentRateViolations: const [],
    events: const [],
    ceilingCurve: ceilingCurve,
    ndlCurve: ndlCurve,
    decoStatuses: const [],
    o2Exposure: const O2Exposure(),
    ppO2Curve: ppO2Curve,
    ttsCurve: ttsCurve,
    gfCurve: gfCurve,
    maxDepth: 20,
    averageDepth: 20,
    maxDepthTimestamp: 0,
    durationSeconds: 600,
  );
}

Map<String, List<TankPressurePoint>> _techTankPressures() => {
  't1': const [
    TankPressurePoint(id: 'p1', tankId: 't1', timestamp: 0, pressure: 200),
    TankPressurePoint(id: 'p2', tankId: 't1', timestamp: 600, pressure: 50),
  ],
};

void main() {
  group('computeCandidateTiles', () {
    test('rec dive: depth, runtime, temperature only', () {
      final dive = _recDive();
      final tiles = computeCandidateTiles(dive: dive, analysis: null);
      expect(tiles, [
        InstrumentTileId.depth,
        InstrumentTileId.runtime,
        InstrumentTileId.temperature,
      ]);
    });

    test('tech dive adds deco and gas tiles in priority order', () {
      final techDive = _techDive();
      final techAnalysis = _techAnalysis();
      final tiles = computeCandidateTiles(
        dive: techDive,
        analysis: techAnalysis,
        tankPressures: _techTankPressures(),
      );
      expect(
        tiles,
        containsAllInOrder([
          InstrumentTileId.depth,
          InstrumentTileId.runtime,
          InstrumentTileId.ndl,
          InstrumentTileId.tankPressure,
          InstrumentTileId.ppO2,
          InstrumentTileId.gf,
        ]),
      );
    });

    test('empty dive yields no candidates', () {
      final dive = Dive(id: 'empty', dateTime: DateTime(2026, 1, 1, 10));
      final tiles = computeCandidateTiles(dive: dive, analysis: null);
      expect(tiles, isEmpty);
    });
  });

  group('applyTilePreferences', () {
    final candidates = [
      InstrumentTileId.depth,
      InstrumentTileId.runtime,
      InstrumentTileId.temperature,
      InstrumentTileId.ppO2,
    ];

    test('empty prefs keep candidate order', () {
      expect(
        applyTilePreferences(candidates: candidates, order: [], hidden: []),
        candidates,
      );
    });

    test('hidden tiles are removed', () {
      final result = applyTilePreferences(
        candidates: candidates,
        order: [],
        hidden: ['temperature'],
      );
      expect(result, isNot(contains(InstrumentTileId.temperature)));
      expect(result.length, candidates.length - 1);
    });

    test('custom order applies, unknown keys ignored, unlisted appended', () {
      final result = applyTilePreferences(
        candidates: candidates,
        order: ['ppO2', 'depth', 'bogus'],
        hidden: [],
      );
      expect(result.take(2), [InstrumentTileId.ppO2, InstrumentTileId.depth]);
      expect(result.length, candidates.length);
    });
  });

  group('applyDecoSwap', () {
    final all = [
      InstrumentTileId.depth,
      InstrumentTileId.ndl,
      InstrumentTileId.ceiling,
      InstrumentTileId.tts,
    ];
    test('no deco: keep NDL, drop ceiling and TTS', () {
      expect(applyDecoSwap(tiles: all, inDeco: false), [
        InstrumentTileId.depth,
        InstrumentTileId.ndl,
      ]);
    });
    test('in deco: drop NDL, keep ceiling and TTS', () {
      expect(applyDecoSwap(tiles: all, inDeco: true), [
        InstrumentTileId.depth,
        InstrumentTileId.ceiling,
        InstrumentTileId.tts,
      ]);
    });
  });

  group('resolveSample', () {
    test('reads point fields and curve values at the derived index', () {
      final sample = resolveSample(
        dive: _techDive(),
        analysis: _techAnalysis(),
        tankPressures: _techTankPressures(),
        timestamp: 300,
      );
      expect(sample.depthMeters, isNotNull);
      expect(sample.runtimeSeconds, 300);
      expect(sample.tankPressuresBar, isNotEmpty);
      expect(sample.ppO2Bar, 1.2);
      expect(sample.ceilingMeters, 3.0);
      expect(sample.ttsSeconds, (60 - 30) * 10);
    });

    test('null-at-position values stay null (temperature gap)', () {
      final sample = resolveSample(
        dive: _recDiveNoTemp(),
        analysis: null,
        timestamp: 60,
      );
      expect(sample.temperatureCelsius, isNull);
    });

    test('inDeco reflects decoType at the position', () {
      final sample = resolveSample(
        dive: _techDive(),
        analysis: _techAnalysis(),
        timestamp: 300,
      );
      expect(sample.inDeco, isTrue);
    });

    test('not in deco before the deco boundary', () {
      final sample = resolveSample(
        dive: _techDive(),
        analysis: _techAnalysis(),
        timestamp: 0,
      );
      expect(sample.inDeco, isFalse);
      expect(sample.ndlSeconds, 600);
    });

    test('empty profile returns a bare sample keyed on the timestamp', () {
      final dive = Dive(id: 'empty', dateTime: DateTime(2026, 1, 1, 10));
      final sample = resolveSample(dive: dive, analysis: null, timestamp: 42);
      expect(sample.runtimeSeconds, 42);
      expect(sample.depthMeters, isNull);
      expect(sample.tankPressuresBar, isEmpty);
      expect(sample.inDeco, isFalse);
    });
  });
}
