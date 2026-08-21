import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_lab/data/repositories/dive_scenario_repository.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/dive_lab_section.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

void main() {
  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Widget harness(String diveId) => testApp(
    overrides: [
      settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
      labRequestInputsProvider(diveId).overrideWith((ref) async => null),
    ],
    locale: const Locale('en'),
    child: SingleChildScrollView(child: DiveLabSection(diveId: diveId)),
  );

  testWidgets('shows the CTA with no scenarios', (tester) async {
    final dive = await DiveRepository().createDive(
      Dive(id: '', diveNumber: 1, dateTime: DateTime(2026, 1, 1)),
    );
    await tester.pumpWidget(harness(dive.id));
    await tester.pump();
    expect(find.text('What if'), findsOneWidget);
    expect(find.text('New scenario'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('lists saved scenarios with their summary', (tester) async {
    final dive = await DiveRepository().createDive(
      Dive(id: '', diveNumber: 1, dateTime: DateTime(2026, 1, 1)),
    );
    await DiveScenarioRepository().saveScenario(
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
    await tester.pumpWidget(harness(dive.id));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Lost deco'), findsOneWidget);
    expect(find.textContaining('Re-plan at 23:40'), findsOneWidget);
    expect(find.byType(ListTile), findsOneWidget);
  });
}
