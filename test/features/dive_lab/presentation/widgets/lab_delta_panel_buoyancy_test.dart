import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_buoyancy_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_delta_panel.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../domain/support/synthetic_dives.dart';

TwinOutputs _outputs(double net, double peak, double ditch) => TwinOutputs(
  beginNetKg: 0,
  endNetKg: net,
  peakLiftDemandKg: peak,
  minDitchableKg: ditch,
  droppableLeadKg: 4,
  idealLeadKg: 5,
  verdict: TwinVerdict(
    anchor: const TwinAnchor(
      kind: TwinAnchorKind.convention,
      timestamp: -1,
      depthM: 5,
    ),
    netKg: net,
    terms: const [],
  ),
  drysuitGasLiters: 0,
);

void main() {
  testWidgets('renders the three buoyancy rows in weight units', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    final d = squareDive();
    final inputs = LabRequestInputs(
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
    final outcome = const ScenarioEngine().run(
      inputs.toRequest(
        DiveScenario(
          id: 's',
          diveId: 'd',
          name: 'n',
          branchSeconds: 900,
          mode: ScenarioMode.replay,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ),
    );
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        locale: const Locale('en'),
        child: SingleChildScrollView(
          child: LabDeltaPanel(
            inputs: inputs,
            outcome: outcome,
            buoyancy: BuoyancyComparison(
              actual: _outputs(-0.4, 6.0, 2.0),
              counterfactual: _outputs(0.8, 4.5, 1.5),
              wingLiftCapacityKg: 18,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('BUOYANCY'), findsOneWidget);
    expect(find.text('Net buoyancy at the stop'), findsOneWidget);
    expect(find.text('Peak lift demand'), findsOneWidget);
    expect(find.text('Min ditchable lead'), findsOneWidget);
    expect(find.text('6.0 kg'), findsOneWidget);
    expect(find.text('-1.5 kg'), findsOneWidget);
  });
}
