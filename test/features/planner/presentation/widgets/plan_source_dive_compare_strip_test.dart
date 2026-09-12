import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
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
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          sourceDiveForPlanProvider.overrideWith((ref) async => null),
          sourceDiveTtsSecondsProvider.overrideWith((ref) async => null),
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
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          sourceDiveForPlanProvider.overrideWith((ref) async => dive),
          sourceDiveTtsSecondsProvider.overrideWith((ref) async => 28 * 60),
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
  });
}
