import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../domain/support/synthetic_dives.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_add_intervention_sheet.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

LabRequestInputs _inputs() {
  final d = squareDive();
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

class _Host extends StatelessWidget {
  const _Host(this.inputs);
  final LabRequestInputs inputs;
  @override
  Widget build(BuildContext context) => Center(
    child: ElevatedButton(
      onPressed: () =>
          showLabAddInterventionSheet(context, diveId: 'd', inputs: inputs),
      child: const Text('open'),
    ),
  );
}

void main() {
  test('editing a saved scenario preserves its notes', () {
    final n = LabDraftNotifier();
    addTearDown(n.dispose);
    n.loadScenario(
      DiveScenario(
        id: 'saved',
        diveId: 'd',
        name: 'scenario',
        notes: 'Keep this explanation',
        branchSeconds: 100,
        mode: ScenarioMode.replay,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    n.addIntervention(const AscendNowIntervention());
    expect(n.state.toScenario('d').notes, 'Keep this explanation');
    expect(n.state.copyWith(clearNotes: true).toScenario('d').notes, isNull);
  });
  testWidgets('reject a hypothetical gas whose fractions exceed 100 percent', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        locale: const Locale('en'),
        child: _Host(_inputs()),
      ),
    );
    final c = ProviderScope.containerOf(tester.element(find.byType(_Host)));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Switch gas'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hypothetical cylinder').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'O2 %'), '80');
    await tester.enterText(find.widgetWithText(TextField, 'He %'), '50');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Add'));
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(c.read(labDraftProvider('d')).interventions, isEmpty);
    expect(find.textContaining('total 100 or less'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'O2 %'), '50');
    await tester.enterText(find.widgetWithText(TextField, 'Volume (L)'), '0');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(c.read(labDraftProvider('d')).interventions, isEmpty);
    expect(find.text('Enter a value greater than zero'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Volume (L)'),
      '11.1',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Start pressure (bar)'),
      '0',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    expect(c.read(labDraftProvider('d')).interventions, isEmpty);
    await tester.enterText(
      find.widgetWithText(TextField, 'Start pressure (bar)'),
      '200',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    final added =
        c.read(labDraftProvider('d')).interventions.single
            as SwitchGasIntervention;
    expect(
      (added.tank as HypotheticalTankRef).gasMix,
      const GasMix(o2: 50, he: 50),
    );
  });
}
