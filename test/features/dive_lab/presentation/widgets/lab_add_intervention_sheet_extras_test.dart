import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_add_intervention_sheet.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../domain/support/synthetic_dives.dart';

LabRequestInputs _ccrInputs() {
  final d = squareDive(withDeco50: false, withPressures: false);
  return LabRequestInputs(
    dive: Dive(id: 'd', diveNumber: 1, dateTime: DateTime(2026)),
    profile: [
      for (var i = 0; i < d.depths.length; i++)
        DiveProfilePoint(timestamp: d.timestamps[i], depth: d.depths[i]),
    ],
    depths: d.depths,
    timestamps: d.timestamps,
    diveMode: DiveMode.ccr,
    tanks: const [
      DiveTank(
        id: 'dil',
        volume: 3,
        startPressure: 200,
        gasMix: GasMix(o2: 21),
        role: TankRole.diluent,
      ),
      DiveTank(
        id: 'bo',
        volume: 11.1,
        startPressure: 200,
        gasMix: GasMix(o2: 32),
        role: TankRole.bailout,
      ),
    ],
    gasSwitches: const [],
    tankPressures: const {},
    setpointHigh: 1.3,
    setpointLow: 0.7,
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
  testWidgets('CCR dive offers bail out (not switch gas) and ascent policy', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        locale: const Locale('en'),
        child: _Host(_ccrInputs()),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(_Host)),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Switch gas'), findsNothing);
    expect(find.text('Bail out to open circuit'), findsOneWidget);
    await tester.tap(find.text('Bail out to open circuit'));
    await tester.pumpAndSettle();
    expect(find.text('All bailout cylinders'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    var draft = container.read(labDraftProvider('d'));
    expect(draft.interventions.single, const BailOutIntervention());

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ascent policy'));
    await tester.pumpAndSettle();
    // Extend the last stop by one minute: the third stepper's "+" button.
    final plusButtons = find.byIcon(Icons.add);
    await tester.tap(plusButtons.at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    draft = container.read(labDraftProvider('d'));
    final policy = draft.interventions
        .whereType<AscentPolicyIntervention>()
        .single;
    expect(policy.extraLastStopSeconds, 60);
    expect(policy.ascentRate, isNull);
    expect(draft.effectiveMode, ScenarioMode.replan);
  });
}
