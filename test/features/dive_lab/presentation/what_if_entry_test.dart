import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/presentation/pages/dive_lab_page.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/what_if_entry.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/what_if_sheet.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/services/plan_engine.dart';
import 'package:submersion/features/planner/presentation/providers/plan_overlay_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';

List<DiveProfilePoint> _profile() => [
  for (var t = 0; t <= 600; t += 10) DiveProfilePoint(timestamp: t, depth: 20),
];

Dive _dive(DiveMode mode) => Dive(
  id: 'd',
  dateTime: DateTime(2026, 1, 1),
  diveMode: mode,
  profile: _profile(),
);

LinkedPlanComparison _comparison() {
  final plan = domain.DivePlan(
    id: 'p',
    name: 'Plan',
    gfLow: 30,
    gfHigh: 70,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  final outcome = const PlanEngine().compute(plan);
  return LinkedPlanComparison(
    plan: plan,
    outcome: outcome,
    overlay: buildPlannedOverlay(plan, outcome: outcome),
  );
}

Widget _harness(Dive dive, {LinkedPlanComparison? linked}) => testApp(
  overrides: [
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    linkedPlanComparisonProvider.overrideWith((ref, id) async => linked),
    labRequestInputsProvider('d').overrideWith((ref) async => null),
    labDefaultBranchProvider('d').overrideWith((ref) async => 0),
    diveProvider.overrideWith((ref, id) async => dive),
    divesProvider.overrideWith((ref) async => <Dive>[]),
    diveProfileProvider.overrideWith((ref, id) async => dive.profile),
    gasSwitchesProvider.overrideWith((ref, id) async => <GasSwitchWithTank>[]),
  ],
  locale: const Locale('en'),
  child: Builder(
    builder: (context) => ElevatedButton(
      onPressed: () => openWhatIf(context, dive),
      child: const Text('open'),
    ),
  ),
);

void main() {
  testWidgets('an eligible dive opens the Dive Lab', (tester) async {
    await tester.pumpWidget(_harness(_dive(DiveMode.oc)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(DiveLabPage), findsOneWidget);
    expect(find.byType(WhatIfSheet), findsNothing);
  });

  testWidgets('a gauge dive with a profile opens the rebuild sheet', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(_dive(DiveMode.gauge)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(WhatIfSheet), findsOneWidget);
    expect(find.byType(DiveLabPage), findsNothing);
  });

  testWidgets('a linked gauge dive opens the page', (tester) async {
    await tester.pumpWidget(
      _harness(_dive(DiveMode.gauge), linked: _comparison()),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(DiveLabPage), findsOneWidget);
    expect(find.byType(WhatIfSheet), findsNothing);
  });
}
