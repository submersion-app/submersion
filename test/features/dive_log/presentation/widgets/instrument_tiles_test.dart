import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
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
      final tiles = computeCandidateTiles(
        profile: dive.profile,
        analysis: null,
      );
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
        profile: techDive.profile,
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

    test('empty profile yields no candidates', () {
      final tiles = computeCandidateTiles(profile: const [], analysis: null);
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

    test('a repeated valid key in order does not duplicate the tile', () {
      final result = applyTilePreferences(
        candidates: candidates,
        order: ['ppO2', 'ppO2', 'depth'],
        hidden: [],
      );
      expect(
        result.where((id) => id == InstrumentTileId.ppO2).length,
        1,
        reason: 'ppO2 must appear exactly once despite the duplicate key',
      );
      expect(result.length, candidates.length);
    });
  });

  group('mergeTileOrder', () {
    test('appends stored keys not in candidates, preserving their order', () {
      final result = mergeTileOrder(
        reordered: ['ppO2', 'depth'],
        stored: ['depth', 'ppO2', 'heartRate', 'sac'],
        candidates: {'ppO2', 'depth'},
      );
      expect(result, ['ppO2', 'depth', 'heartRate', 'sac']);
    });

    test('empty stored order yields just the reordered keys', () {
      final result = mergeTileOrder(
        reordered: ['depth', 'ppO2'],
        stored: [],
        candidates: {'depth', 'ppO2'},
      );
      expect(result, ['depth', 'ppO2']);
    });

    test('stored keys fully covered by candidates append nothing', () {
      final result = mergeTileOrder(
        reordered: ['ppO2', 'depth'],
        stored: ['depth', 'ppO2'],
        candidates: {'depth', 'ppO2'},
      );
      expect(result, ['ppO2', 'depth']);
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
        profile: _techDive().profile,
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
        profile: _recDiveNoTemp().profile,
        analysis: null,
        timestamp: 60,
      );
      expect(sample.temperatureCelsius, isNull);
    });

    test('inDeco reflects decoType at the position', () {
      final sample = resolveSample(
        profile: _techDive().profile,
        analysis: _techAnalysis(),
        timestamp: 300,
      );
      expect(sample.inDeco, isTrue);
    });

    test('not in deco before the deco boundary', () {
      final sample = resolveSample(
        profile: _techDive().profile,
        analysis: _techAnalysis(),
        timestamp: 0,
      );
      expect(sample.inDeco, isFalse);
      expect(sample.ndlSeconds, 600);
    });

    test('empty profile returns a bare sample keyed on the timestamp', () {
      final sample = resolveSample(
        profile: const [],
        analysis: null,
        timestamp: 42,
      );
      expect(sample.runtimeSeconds, 42);
      expect(sample.depthMeters, isNull);
      expect(sample.tankPressuresBar, isEmpty);
      expect(sample.inDeco, isFalse);
    });

    test('curve values align to the passed profile late in the dive '
        '(the profile must be the analysis basis, not dive.profile)', () {
      // A short, coarsely-sampled active-source profile: 5 points at 60s
      // intervals. The analysis curves are index-aligned to THIS array.
      final profile = List.generate(
        5,
        (i) => DiveProfilePoint(timestamp: i * 60, depth: 10),
      );
      final analysis = ProfileAnalysis.empty().copyWith(
        cnsCurve: [1.0, 2.0, 3.0, 4.0, 5.0],
        ascentRates: [
          for (var i = 0; i < 5; i++)
            AscentRatePoint(
              timestamp: i * 60,
              depth: 10,
              rateMetersPerMin: i.toDouble(),
              category: AscentRateCategory.safe,
            ),
        ],
      );

      // Late in the dive: index 4 of the profile. Before the fix the index
      // came from dive.profile (a longer, differently-sampled array), which
      // read wrong values here and null past the curves' end.
      final sample = resolveSample(
        profile: profile,
        analysis: analysis,
        timestamp: 240,
      );
      expect(sample.cnsPercent, 5.0);
      expect(sample.ascentRateMetersPerMin, 4.0);
    });
  });
}
