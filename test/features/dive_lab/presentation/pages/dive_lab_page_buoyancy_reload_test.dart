import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_lab/presentation/pages/dive_lab_page.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_buoyancy_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_draft_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/scenario_outcome_provider.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_delta_panel.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../domain/support/synthetic_dives.dart';

TwinOutputs _outputs(double net) => TwinOutputs(
  beginNetKg: 0,
  endNetKg: net,
  peakLiftDemandKg: 5,
  minDitchableKg: 2,
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

void main() {
  testWidgets('the buoyancy comparison stays visible while recomputing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(420, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      testApp(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          labRequestInputsProvider('d').overrideWith((ref) async => _inputs()),
          labDefaultBranchProvider('d').overrideWith((ref) async => 900),
          scenarioEngineRunnerProvider.overrideWithValue(
            (request) async => const ScenarioEngine().run(request),
          ),
          // Like the real provider, it depends on the draft, so a draft edit
          // reloads it.
          labBuoyancyProvider('d').overrideWith((ref) async {
            ref.watch(labDraftProvider('d'));
            await Future<void>.delayed(const Duration(milliseconds: 300));
            return BuoyancyComparison(
              actual: _outputs(-0.4),
              counterfactual: _outputs(0.8),
              wingLiftCapacityKg: 18,
            );
          }),
        ],
        locale: const Locale('en'),
        child: const DiveLabPage(diveId: 'd'),
      ),
    );
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    LabDeltaPanel panel() =>
        tester.widget<LabDeltaPanel>(find.byType(LabDeltaPanel));
    expect(panel().buoyancy, isNotNull);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(DiveLabPage)),
    );
    container
        .read(labDraftProvider('d').notifier)
        .addIntervention(const AscendNowIntervention());
    await tester.pump(const Duration(milliseconds: 100));
    expect(panel().buoyancy, isNotNull);
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  });
}
