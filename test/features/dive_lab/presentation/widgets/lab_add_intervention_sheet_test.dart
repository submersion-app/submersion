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
  testWidgets('adds interventions through the sheet', (tester) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final inputs = _inputs();
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        locale: const Locale('en'),
        child: _Host(inputs),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(_Host)),
    );

    // Gradient factors with the defaults.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Add an intervention'), findsOneWidget);
    await tester.tap(find.text('Gradient factors'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    var draft = container.read(labDraftProvider('d'));
    expect(draft.interventions.single, isA<ChangeGfIntervention>());
    expect(draft.mode, ScenarioMode.replay);

    // Reopen: the kind is no longer offered; lose the deco cylinder.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Gradient factors'), findsNothing);
    await tester.tap(find.text('Lose a cylinder'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    draft = container.read(labDraftProvider('d'));
    expect(
      draft.interventions.whereType<LoseTankIntervention>().single.tankId,
      'deco50',
    );

    // Ascend now forces re-plan.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ascend now'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    draft = container.read(labDraftProvider('d'));
    expect(draft.interventions.any((i) => i is AscendNowIntervention), isTrue);
    expect(draft.effectiveMode, ScenarioMode.replan);
    expect(draft.modeForced, isTrue);
  });

  testWidgets('shift ascent editor builds a negative delta by default', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        locale: const Locale('en'),
        child: _Host(_inputs()),
      ),
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(_Host)),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shift the ascent'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await tester.pumpAndSettle();
    final i = container
        .read(labDraftProvider('d'))
        .interventions
        .whereType<ShiftAscentIntervention>()
        .single;
    expect(i.deltaSeconds, -360);
  });
}
