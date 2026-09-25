import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_lab/presentation/pages/dive_lab_page.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/scenario_outcome_provider.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_delta_panel.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_profile_chart.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../domain/support/synthetic_dives.dart';

LabRequestInputs _inputs() {
  final d = squareDive(depth: 45, bottomMinutes: 30);
  return LabRequestInputs(
    dive: Dive(id: 'd', diveNumber: 1, dateTime: DateTime(2026)),
    profile: [
      for (var i = 0; i < d.depths.length; i++)
        DiveProfilePoint(timestamp: d.timestamps[i], depth: d.depths[i]),
    ],
    depths: d.depths,
    timestamps: d.timestamps,
    diveMode: DiveMode.oc,
    tanks: d.tanks,
    gasSwitches: d.switches,
    tankPressures: d.tankPressures,
    startCns: 0,
    startOtu: 0,
    settings: const ScenarioSettings(),
  );
}

Widget _page() => testApp(
  overrides: [
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    labRequestInputsProvider('d').overrideWith((ref) async => _inputs()),
    labDefaultBranchProvider('d').overrideWith((ref) async => 900),
    scenarioEngineRunnerProvider.overrideWithValue(
      (request) async => const ScenarioEngine().run(request),
    ),
  ],
  locale: const Locale('en'),
  child: const DiveLabPage(diveId: 'd'),
);

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets(
    'phone layout: chart, controls, panel; steppers move the branch',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(_page());
      await _settle(tester);

      expect(find.byType(DiveProfileChart), findsOneWidget);
      expect(find.text('Replay'), findsOneWidget);
      expect(find.text('Re-plan'), findsOneWidget);
      expect(find.textContaining('15:00'), findsWidgets);
      expect(find.text('Add'), findsOneWidget);
      expect(find.byType(LabDeltaPanel), findsOneWidget);

      await tester.tap(find.text('+1 min'));
      await _settle(tester);
      expect(find.textContaining('16:00'), findsWidgets);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(DiveLabPage)),
      );
      await tester.tap(find.text('Re-plan'));
      await _settle(tester);
      expect(
        container.read(labDraftProvider('d')).effectiveMode,
        ScenarioMode.replan,
      );
    },
  );

  testWidgets('wide layout places the panel beside the chart', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(_page());
    await _settle(tester);
    expect(find.byType(DiveProfileChart), findsOneWidget);
    expect(find.byType(LabDeltaPanel), findsOneWidget);
    expect(find.byType(VerticalDivider), findsOneWidget);
  });

  testWidgets('ineligible dive shows the empty state', (tester) async {
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          labRequestInputsProvider('d').overrideWith((ref) async => null),
          labDefaultBranchProvider('d').overrideWith((ref) async => 0),
        ],
        locale: const Locale('en'),
        child: const DiveLabPage(diveId: 'd'),
      ),
    );
    await _settle(tester);
    expect(
      find.text('This dive has no profile to branch from.'),
      findsOneWidget,
    );
  });
}
