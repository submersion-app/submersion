import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_lab/data/repositories/dive_scenario_repository.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_saved_scenarios_sheet.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

class _Host extends StatelessWidget {
  const _Host(this.diveId);
  final String diveId;
  @override
  Widget build(BuildContext context) => Center(
    child: ElevatedButton(
      onPressed: () => showLabSavedScenariosSheet(context, diveId: diveId),
      child: const Text('open'),
    ),
  );
}

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  testWidgets('lists, opens, renames and deletes saved scenarios', (
    tester,
  ) async {
    final dive = await DiveRepository().createDive(
      Dive(id: '', diveNumber: 1, dateTime: DateTime(2026, 1, 1)),
    );
    final repo = DiveScenarioRepository();
    await repo.saveScenario(
      DiveScenario(
        id: '',
        diveId: dive.id,
        name: 'Lost deco',
        branchSeconds: 1420,
        mode: ScenarioMode.replan,
        interventions: const [LoseTankIntervention(tankId: 'deco50')],
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          labRequestInputsProvider(dive.id).overrideWith((ref) async => null),
        ],
        locale: const Locale('en'),
        child: _Host(dive.id),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(_Host)),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Lost deco'), findsOneWidget);
    expect(find.textContaining('Re-plan at 23:40'), findsOneWidget);

    // Open loads the draft.
    await tester.tap(find.text('Lost deco'));
    await tester.pumpAndSettle();
    final draft = container.read(labDraftProvider(dive.id));
    expect(draft.branchSeconds, 1420);
    expect(draft.name, 'Lost deco');
    expect(draft.scenarioId, isNotNull);

    // Rename through the menu.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rename'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Renamed');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await repo.getScenariosForDive(dive.id)).single.name, 'Renamed');

    // Delete with confirmation.
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(await repo.getScenariosForDive(dive.id), isEmpty);
  });
}
