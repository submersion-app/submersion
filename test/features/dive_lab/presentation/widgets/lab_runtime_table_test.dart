import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_lab/presentation/widgets/lab_runtime_table.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_app.dart';
import '../../domain/support/synthetic_dives.dart';

/// A no-deco replan of a 30 m dive carrying EAN50, with a one minute gas
/// switch stop (issue #4160).
PlanOutcome _noDecoWithSwitchStop() {
  final d = squareDive(depth: 30, bottomMinutes: 10);
  return const ScenarioEngine()
      .run(
        ScenarioRequest(
          diveId: 'd',
          depths: d.depths,
          timestamps: d.timestamps,
          tanks: d.tanks,
          gasSwitches: d.switches,
          tankPressures: d.tankPressures,
          scenario: DiveScenario(
            id: 's',
            diveId: 'd',
            name: 's',
            branchSeconds: 300,
            mode: ScenarioMode.replan,
            interventions: const [
              AscentPolicyIntervention(gasSwitchStopSeconds: 60),
            ],
            createdAt: DateTime(2026),
            updatedAt: DateTime(2026),
          ),
        ),
      )
      .planOutcome!;
}

void main() {
  testWidgets('a no-deco outcome with switch stops says no deco and still '
      'lists the stops', (tester) async {
    final outcome = _noDecoWithSwitchStop();
    expect(outcome.stops, isNotEmpty, reason: 'precondition');
    expect(outcome.owesDecompression, isFalse, reason: 'precondition');

    await tester.pumpWidget(
      testApp(
        child: LabRuntimeTable(
          outcome: outcome,
          units: const UnitFormatter(AppSettings()),
        ),
      ),
    );

    expect(find.text('No decompression required'), findsOneWidget);
    expect(find.text('Depth'), findsOneWidget);
  });
}
