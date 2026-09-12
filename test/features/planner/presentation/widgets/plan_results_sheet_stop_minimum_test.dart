import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/features/dive_planner/data/services/plan_calculator_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/presentation/providers/plan_canvas_providers.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_results_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

PlanOutcome _outcomeWithStop() {
  return const PlanOutcome(
    runtimeSeconds: 1200,
    maxDepth: 21,
    ndlAtBottom: -1,
    ttsAtBottom: 300,
    stops: [
      PlanStop(
        depthMeters: 6,
        durationSeconds: 180,
        gasFO2: 0.21,
        gasFHe: 0,
        arrivalRuntimeSeconds: 900,
      ),
    ],
    schedule: [
      PlanScheduleRow(
        kind: PlanScheduleRowKind.stop,
        depthMeters: 6,
        durationSeconds: 180,
        runtimeSeconds: 1080,
        gasFO2: 0.21,
        gasFHe: 0,
      ),
    ],
    segmentOutcomes: [],
    tankUsages: [],
    cnsEnd: 5,
    otuTotal: 5,
    issues: [],
    endTissue: BuhlmannState(compartments: [], gfLowCeilingAnchor: 0),
    tissueTimeline: [],
    ceilingTrace: [],
  );
}

Future<DivePlanNotifier> _pumpSheet(WidgetTester tester) async {
  final notifier = DivePlanNotifier(PlanCalculatorService());
  await tester.pumpWidget(
    testApp(
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        activePlanOutcomeProvider.overrideWithValue(_outcomeWithStop()),
        divePlanNotifierProvider.overrideWith((ref) => notifier),
      ],
      child: PlanResultsSheet(controller: ScrollController()),
    ),
  );
  await tester.pumpAndSettle();
  return notifier;
}

void main() {
  testWidgets(
    'tapping a stop row opens the minimum-duration dialog and applying it '
    'updates the notifier state',
    (tester) async {
      final notifier = await _pumpSheet(tester);

      expect(notifier.state.stopMinimums, isEmpty);

      // Tap anywhere within the stop row (it's wrapped in one InkWell).
      await tester.tap(find.text('6m'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Minimum stop time at 6m'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '5');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(notifier.state.stopMinimums[6], 5 * 60);
      expect(find.byIcon(Icons.push_pin), findsOneWidget);
    },
  );

  testWidgets(
    'applying 0 minutes clears the minimum instead of persisting a no-op 0',
    (tester) async {
      final notifier = await _pumpSheet(tester);
      notifier.setStopMinimum(6, 5 * 60);
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.push_pin), findsOneWidget);

      await tester.tap(find.text('6m'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '0');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(notifier.state.stopMinimums.containsKey(6), isFalse);
      expect(find.byIcon(Icons.push_pin), findsNothing);
    },
  );
}
