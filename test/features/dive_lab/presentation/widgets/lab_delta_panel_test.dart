import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_outcome.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_delta_panel.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tissue_heat_map.dart';
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

ScenarioOutcome _outcome(LabRequestInputs inputs) => const ScenarioEngine().run(
  inputs.toRequest(
    DiveScenario(
      id: 's',
      diveId: 'd',
      name: 'n',
      branchSeconds: 900,
      mode: ScenarioMode.replan,
      interventions: const [ShiftAscentIntervention(deltaSeconds: -300)],
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ),
);

Widget _harness(Widget child) => testApp(
  overrides: [settingsProvider.overrideWith((ref) => MockSettingsNotifier())],
  locale: const Locale('en'),
  child: SingleChildScrollView(child: child),
);

void main() {
  testWidgets('renders verdict, table, tissue strips, gas and runtime', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final inputs = _inputs();
    final outcome = _outcome(inputs);
    await tester.pumpWidget(
      _harness(
        LabDeltaPanel(inputs: inputs, outcome: AsyncValue.data(outcome)),
      ),
    );
    await tester.pump();
    expect(find.text('Runtime'), findsWidgets);
    expect(find.text('Actual'), findsWidgets);
    expect(find.text('What if'), findsWidgets);
    expect(find.text('Delta'), findsWidgets);
    expect(find.byType(TissueHeatMapStrip), findsNWidgets(2));
    expect(find.text('Depth'), findsOneWidget);
    expect(
      find.text('No change: the what-if matches the actual dive.'),
      findsNothing,
    );
  });

  testWidgets('shows the progress bar while recomputing with a value', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final inputs = _inputs();
    final outcome = _outcome(inputs);
    await tester.pumpWidget(
      _harness(
        LabDeltaPanel(
          inputs: inputs,
          outcome: const AsyncValue<ScenarioOutcome?>.loading()
              .copyWithPrevious(AsyncValue.data(outcome)),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(TissueHeatMapStrip), findsNWidgets(2));
  });

  testWidgets('no value yet shows the computing line', (tester) async {
    await tester.pumpWidget(
      _harness(
        LabDeltaPanel(
          inputs: _inputs(),
          outcome: const AsyncValue<ScenarioOutcome?>.loading(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('Computing…'), findsOneWidget);
  });
}
