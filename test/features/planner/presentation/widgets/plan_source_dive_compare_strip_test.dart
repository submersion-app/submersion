import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/providers/source_dive_deco_provider.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_source_dive_compare_strip.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

PlanOutcome _outcome() {
  return const PlanOutcome(
    runtimeSeconds: 1800,
    maxDepth: 30,
    ndlAtBottom: -1,
    ttsAtBottom: 300,
    stops: [
      PlanStop(
        depthMeters: 6,
        durationSeconds: 240,
        gasFO2: 0.21,
        gasFHe: 0,
        arrivalRuntimeSeconds: 1500,
      ),
    ],
    segmentOutcomes: [],
    tankUsages: [
      PlanTankUsage(tankId: 'back', litersUsed: 1800, percentUsed: 60),
    ],
    cnsEnd: 15,
    otuTotal: 20,
    issues: [],
    endTissue: BuhlmannState(compartments: [], gfLowCeilingAnchor: 0),
    tissueTimeline: [],
    ceilingTrace: [],
  );
}

void main() {
  testWidgets('renders nothing when the plan has no source dive', (
    tester,
  ) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          sourceDiveForPlanProvider.overrideWith((ref) async => null),
          sourceDiveTtsSecondsProvider.overrideWith((ref) async => null),
          sourceDiveDecoSecondsProvider.overrideWith((ref) async => null),
        ],
        child: const PlanSourceDiveCompareStrip(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PlanSourceDiveCompareStrip), findsOneWidget);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('shows runtime/depth/gas diffs against the source dive', (
    tester,
  ) async {
    final dive = Dive(
      id: 'd1',
      dateTime: DateTime(2026, 1, 1),
      maxDepth: 28,
      entryTime: DateTime(2026, 1, 1, 9),
      exitTime: DateTime(2026, 1, 1, 9, 32),
      tanks: [
        const DiveTank(
          id: 'back',
          name: 'Primary',
          volume: 11.1,
          startPressure: 200,
          endPressure: 60,
        ),
      ],
    );

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          sourceDiveForPlanProvider.overrideWith((ref) async => dive),
          sourceDiveTtsSecondsProvider.overrideWith((ref) async => 28 * 60),
          sourceDiveDecoSecondsProvider.overrideWith((ref) async => 22 * 60),
          activePlanOutcomeProvider.overrideWithValue(_outcome()),
        ],
        child: const PlanSourceDiveCompareStrip(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('vs. original dive'), findsOneWidget);
    expect(find.textContaining('30′'), findsOneWidget); // planned runtime
    expect(find.textContaining('32′'), findsOneWidget); // actual runtime
    expect(find.text('TTS'), findsOneWidget);
    expect(find.text('5′'), findsOneWidget); // planned TTS
    expect(find.text('28′'), findsOneWidget); // actual computer TTS
    // TTS is the whole tail to the surface; deco time is only the hanging in
    // it, so the two are separate rows rather than one standing in for the
    // other.
    expect(find.text('Deco time'), findsOneWidget);
    expect(find.text('4′'), findsOneWidget); // planned: the 240 s stop
    expect(find.text('22′'), findsOneWidget); // actual, from the profile
  });

  // Issue #2545: computers such as the OSTC log CNS only every few samples,
  // so the last sample of the dive usually carries none. The actual CNS is
  // the last reading the computer logged.
  testWidgets('shows the last computer CNS reading when the final sample '
      'has none', (tester) async {
    final dive = Dive(
      id: 'd1',
      dateTime: DateTime(2026, 1, 1),
      maxDepth: 28,
      profile: const [
        DiveProfilePoint(timestamp: 0, depth: 0, cns: 3.0),
        DiveProfilePoint(timestamp: 60, depth: 20),
        DiveProfilePoint(timestamp: 120, depth: 20, cns: 21.6),
        DiveProfilePoint(timestamp: 180, depth: 0),
      ],
    );

    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          sourceDiveForPlanProvider.overrideWith((ref) async => dive),
          sourceDiveTtsSecondsProvider.overrideWith((ref) async => null),
          sourceDiveDecoSecondsProvider.overrideWith((ref) async => null),
          diveAnalysisSeriesProvider('d1').overrideWith(
            (ref) async =>
                (points: dive.profile, sourceProfile: null, source: null),
          ),
          activePlanOutcomeProvider.overrideWithValue(_outcome()),
        ],
        child: const PlanSourceDiveCompareStrip(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CNS'), findsOneWidget);
    expect(find.text('15%'), findsOneWidget); // planned
    expect(find.text('22%'), findsOneWidget); // actual: the last reading
  });
}
