import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/data/repositories/dive_scenario_repository.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_lab/presentation/pages/dive_lab_page.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/scenario_outcome_provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';
import '../../domain/support/synthetic_dives.dart';

LabRequestInputs _inputs(Dive dive) {
  final d = squareDive();
  return LabRequestInputs(
    dive: dive,
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

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  testWidgets('Save creates a scenario and a second Save updates it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final dive = await DiveRepository().createDive(
      Dive(id: '', diveNumber: 1, dateTime: DateTime(2026, 1, 1)),
    );
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          labRequestInputsProvider(
            dive.id,
          ).overrideWith((ref) async => _inputs(dive)),
          labDefaultBranchProvider(dive.id).overrideWith((ref) async => 900),
          scenarioEngineRunnerProvider.overrideWithValue(
            (request) async => const ScenarioEngine().run(request),
          ),
        ],
        locale: const Locale('en'),
        child: DiveLabPage(diveId: dive.id),
      ),
    );
    await _settle(tester);

    await tester.tap(find.byIcon(Icons.save_outlined));
    await _settle(tester);
    expect(find.text('Name this scenario'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'First');
    await tester.tap(find.text('Save'));
    await _settle(tester);
    final repo = DiveScenarioRepository();
    var saved = await repo.getScenariosForDive(dive.id);
    expect(saved.single.name, 'First');
    expect(saved.single.branchSeconds, 900);

    await tester.tap(find.byIcon(Icons.save_outlined));
    await _settle(tester);
    await tester.enterText(find.byType(TextField), 'Second');
    await tester.tap(find.text('Save'));
    await _settle(tester);
    saved = await repo.getScenariosForDive(dive.id);
    expect(saved.single.name, 'Second');
  });
}
