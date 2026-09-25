import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_lab/presentation/pages/dive_lab_page.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/scenario_outcome_provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/what_if_sheet.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../domain/support/synthetic_dives.dart';

LabRequestInputs _inputs({DiveMode mode = DiveMode.oc}) {
  final d = squareDive(depth: 40, bottomMinutes: 25);
  final dive = Dive(
    id: 'd',
    diveNumber: 1,
    name: 'Wreck',
    dateTime: DateTime(2026, 9, 25, 9),
    diveMode: mode,
    tanks: d.tanks,
    profile: [
      for (var i = 0; i < d.depths.length; i++)
        DiveProfilePoint(timestamp: d.timestamps[i], depth: d.depths[i]),
    ],
  );
  return LabRequestInputs(
    dive: dive,
    profile: dive.profile,
    depths: d.depths,
    timestamps: d.timestamps,
    diveMode: mode,
    tanks: d.tanks,
    gasSwitches: d.switches,
    tankPressures: d.tankPressures,
    startCns: 0,
    startOtu: 0,
    settings: const ScenarioSettings(),
  );
}

GoRouter _router() => GoRouter(
  initialLocation: '/dives/d',
  routes: [
    GoRoute(
      path: '/dives/:id',
      builder: (_, _) => Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDiveLab(context, 'd'),
            child: const Text('open lab'),
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/planning/dive-planner',
      builder: (_, _) => const Scaffold(body: Text('planner page')),
    ),
  ],
);

Widget _app(GoRouter router, LabRequestInputs inputs) => testAppRouter(
  router: router,
  locale: const Locale('en'),
  overrides: [
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    labRequestInputsProvider('d').overrideWith((ref) async => inputs),
    labDefaultBranchProvider('d').overrideWith((ref) async => 900),
    scenarioEngineRunnerProvider.overrideWithValue(
      (request) async => const ScenarioEngine().run(request),
    ),
    gasSwitchesProvider.overrideWith((ref, id) async => <GasSwitchWithTank>[]),
    diveProvider.overrideWith((ref, id) async => inputs.dive),
    divesProvider.overrideWith((ref) async => <Dive>[]),
    diveProfileProvider.overrideWith((ref, id) async => inputs.profile),
  ],
);

Future<void> _openLabAndMenu(WidgetTester tester) async {
  await tester.tap(find.text('open lab'));
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.tap(find.byTooltip('More'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the overflow lists share and planner actions', (tester) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router, _inputs()));
    await tester.pumpAndSettle();
    await _openLabAndMenu(tester);
    expect(find.text('Share PDF slate'), findsOneWidget);
    expect(find.text('Open in planner'), findsOneWidget);
    expect(find.text('Rebuild in planner...'), findsOneWidget);
    expect(find.byType(PopupMenuDivider), findsOneWidget);
  });

  testWidgets('Open in planner loads the hand-off and pushes the planner', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router, _inputs()));
    await tester.pumpAndSettle();
    final container = ProviderScope.containerOf(
      tester.element(find.text('open lab')),
    );
    await _openLabAndMenu(tester);
    await tester.tap(find.text('Open in planner'));
    await tester.pumpAndSettle();
    final state = container.read(divePlanNotifierProvider);
    expect(state.sourceDiveId, 'd');
    expect(state.name, startsWith('What if: Wreck'));
    expect(state.segments, isNotEmpty);
    // The lab is an imperative route above the router's pages, so it must
    // leave before the planner is pushed or the planner lands beneath it.
    expect(find.byType(DiveLabPage), findsNothing);
    expect(find.text('planner page'), findsOneWidget);
    expect(
      router.routerDelegate.currentConfiguration.last.matchedLocation,
      '/planning/dive-planner',
    );
  });

  testWidgets('Open in planner is disabled on a rebreather dive', (
    tester,
  ) async {
    final router = _router();
    addTearDown(router.dispose);
    await tester.pumpWidget(_app(router, _inputs(mode: DiveMode.ccr)));
    await tester.pumpAndSettle();
    await _openLabAndMenu(tester);
    final item = tester.widget<PopupMenuItem<String>>(
      find.ancestor(
        of: find.text('Open in planner'),
        matching: find.byType(PopupMenuItem<String>),
      ),
    );
    expect(item.enabled, isFalse);
    expect(
      find.text('Open in planner is available for open-circuit dives only'),
      findsOneWidget,
    );
  });

  testWidgets(
    'Rebuild in planner opens the sheet, then the lab leaves for the planner',
    (tester) async {
      final router = _router();
      addTearDown(router.dispose);
      await tester.pumpWidget(_app(router, _inputs()));
      await tester.pumpAndSettle();
      await _openLabAndMenu(tester);
      await tester.tap(find.text('Rebuild in planner...'));
      await tester.pumpAndSettle();
      expect(find.byType(WhatIfSheet), findsOneWidget);
      expect(find.byType(DiveLabPage), findsOneWidget);
      // The sheet pushes the planner itself; once it has, the lab leaves so the
      // planner is not left beneath it.
      await tester.tap(find.text('Open in planner'));
      await tester.pumpAndSettle();
      expect(find.byType(DiveLabPage), findsNothing);
      expect(find.text('planner page'), findsOneWidget);
    },
  );
}
