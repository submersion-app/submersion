import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/planner/domain/services/logged_deco_time.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/source_dive_deco_provider.dart';

import '../../../dive_log/domain/services/safety_review_fixtures.dart';

/// One computer's reading of a decompression dive, a sample every 10 s from
/// [offset] seconds, stamped by a clock [lag] seconds behind.
List<DiveProfilePoint> _computer({
  required List<double> depths,
  required List<int> timestamps,
  int offset = 0,
  int lag = 0,
}) => [
  for (var i = 0; i < depths.length; i++)
    DiveProfilePoint(
      timestamp: timestamps[i] + offset,
      depth: depths[(i - lag ~/ 10).clamp(0, depths.length - 1)],
    ),
];

void main() {
  // The deco curves are indexed like the samples the dive-level analysis
  // replayed. On a dive with several computers those are the primary's own,
  // while dive.profile holds every computer's samples interleaved, so
  // pairing the curves with dive.profile reads them at the wrong samples.
  test('the source dive deco readouts pair the analysis curves with the '
      'samples it replayed, not dive.profile', () async {
    final shape = buildProfile([
      (40.0, 120),
      (40.0, 1800),
      (6.0, 240),
      (6.0, 900),
      (3.0, 60),
      (3.0, 900),
      (0.0, 60),
    ]);
    final primary = _computer(
      depths: shape.depths,
      timestamps: shape.timestamps,
    );
    final secondary = _computer(
      depths: shape.depths,
      timestamps: shape.timestamps,
      offset: 1,
      lag: 120,
    );
    final interleaved = [...primary, ...secondary]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final dive = Dive(
      id: 'dive-1',
      dateTime: DateTime(2026, 9, 14),
      profile: interleaved,
    );
    final analysis = analyzeFixture(
      depths: [for (final p in primary) p.depth],
      timestamps: [for (final p in primary) p.timestamp],
    );
    final container = ProviderContainer(
      overrides: [
        sourceDiveForPlanProvider.overrideWith((ref) async => dive),
        profileAnalysisProvider('dive-1').overrideWith((ref) async => analysis),
        diveAnalysisSeriesProvider('dive-1').overrideWith(
          (ref) async => (points: primary, sourceProfile: null, source: null),
        ),
      ],
    );
    addTearDown(container.dispose);

    final expectedDeco = loggedDecoSeconds(
      profile: primary,
      decoStopCurve: analysis.decoStopCurve,
    );
    expect(expectedDeco, greaterThan(0), reason: 'the fixture holds stops');
    expect(
      await container.read(sourceDiveDecoSecondsProvider.future),
      expectedDeco,
    );
    expect(
      await container.read(sourceDiveTtsSecondsProvider.future),
      loggedTtsSeconds(profile: primary, ttsCurve: analysis.ttsCurve),
    );
  });

  // dive.profile interleaves every computer's samples, so its last CNS
  // reading may be another computer's. The actual CNS is the last reading of
  // the series the analysis replayed (#2545).
  test('the source dive CNS is the last reading of the analysed series, not '
      'of dive.profile', () async {
    final dive = Dive(
      id: 'dive-1',
      dateTime: DateTime(2026, 9, 14),
      profile: const [
        DiveProfilePoint(timestamp: 0, depth: 0, cns: 5.0),
        DiveProfilePoint(timestamp: 60, depth: 20, cns: 18.0),
        DiveProfilePoint(timestamp: 61, depth: 20, cns: 31.0),
        DiveProfilePoint(timestamp: 120, depth: 0),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        sourceDiveForPlanProvider.overrideWith((ref) async => dive),
        diveAnalysisSeriesProvider('dive-1').overrideWith(
          (ref) async => (
            points: const [
              DiveProfilePoint(timestamp: 0, depth: 0, cns: 5.0),
              DiveProfilePoint(timestamp: 60, depth: 20, cns: 18.0),
              DiveProfilePoint(timestamp: 120, depth: 0),
            ],
            sourceProfile: null,
            source: null,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(sourceDiveCnsEndProvider.future), 18.0);
  });

  // A null series is an interleaved dive with no one recording to analyse;
  // dive.profile there mixes the computers' CNS readings.
  test(
    'the source dive CNS is null when there is no analysed series',
    () async {
      final dive = Dive(
        id: 'dive-1',
        dateTime: DateTime(2026, 9, 14),
        profile: const [
          DiveProfilePoint(timestamp: 0, depth: 0, cns: 5.0),
          DiveProfilePoint(timestamp: 1, depth: 0, cns: 6.0),
          DiveProfilePoint(timestamp: 60, depth: 20, cns: 18.0),
          DiveProfilePoint(timestamp: 61, depth: 20, cns: 31.0),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          sourceDiveForPlanProvider.overrideWith((ref) async => dive),
          diveAnalysisSeriesProvider(
            'dive-1',
          ).overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);

      expect(await container.read(sourceDiveCnsEndProvider.future), isNull);
    },
  );

  test('the source dive CNS is null without a computer CNS series', () async {
    final dive = Dive(
      id: 'dive-1',
      dateTime: DateTime(2026, 9, 14),
      profile: const [
        DiveProfilePoint(timestamp: 0, depth: 0, cns: 5.0),
        DiveProfilePoint(timestamp: 60, depth: 20),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        sourceDiveForPlanProvider.overrideWith((ref) async => dive),
        diveAnalysisSeriesProvider('dive-1').overrideWith(
          (ref) async =>
              (points: dive.profile, sourceProfile: null, source: null),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(await container.read(sourceDiveCnsEndProvider.future), isNull);
  });
}
