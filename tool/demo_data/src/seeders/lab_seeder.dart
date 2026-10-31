import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/features/dive_lab/data/repositories/dive_scenario_repository.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;

import '../shape/dive_shape.dart';
import '../story/story_plan.dart';
import 'seed_context.dart';

/// Saved Compare what-ifs: the questions a diver asks of a dive afterwards,
/// answered by replaying it (other gradient factors, other gas) or by
/// re-planning from partway through (leaving early).
class LabSeeder implements DemoSeeder {
  @override
  String get name => 'saved what-ifs';

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    final scenarios = DiveScenarioRepository();
    final now = ctx.anchor;

    final deco = ctx.plan.dives.lastWhere(
      (d) =>
          d.diveMode == 'oc' &&
          ctx.pickedKinds[d.number]!.contains(ShapeKind.multiGasDeco),
    );
    final decoId = ctx.diveId(deco.number);
    await scenarios.saveScenario(
      DiveScenario(
        id: 'demo-scenario-gf',
        diveId: decoId,
        name: 'Tighter gradient factors',
        notes: 'The same dive on GF 30/60: how much longer would the stops be?',
        branchSeconds: 0,
        mode: ScenarioMode.replay,
        interventions: const [ChangeGfIntervention(gfLow: 30, gfHigh: 60)],
        createdAt: now,
        updatedAt: now,
      ),
    );
    final decoRow = await (ctx.db.select(
      ctx.db.dives,
    )..where((t) => t.id.equals(decoId))).getSingle();
    await scenarios.saveScenario(
      DiveScenario(
        id: 'demo-scenario-early',
        diveId: decoId,
        name: 'Leaving the bottom early',
        notes: 'Calling the dive a third of the way in, and what deco is left.',
        branchSeconds: decoRow.runtime! ~/ 3,
        mode: ScenarioMode.replan,
        interventions: const [AscendNowIntervention()],
        createdAt: now,
        updatedAt: now,
      ),
    );

    final (air, tank) = await _airDive(ctx);
    await scenarios.saveScenario(
      DiveScenario(
        id: 'demo-scenario-nitrox',
        diveId: ctx.diveId(air.number),
        name: 'Nitrox instead of air',
        notes:
            'The same profile on 32%: how much lower would the surface GF be?',
        branchSeconds: 0,
        mode: ScenarioMode.replay,
        interventions: [
          SwitchGasIntervention(
            tank: HypotheticalTankRef(
              gasMix: const GasMix(o2: 32),
              volumeLiters: tank.volume!,
              startPressureBar: tank.startPressure!,
            ),
          ),
        ],
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  /// The newest dive on one cylinder of air, at depths where nitrox buys
  /// time. Read from the written rows: whether a dive of this depth got
  /// nitrox was a coin toss when its tanks were planned.
  Future<(PlannedDive, db.DiveTank)> _airDive(DemoSeedContext ctx) async {
    for (final d in ctx.plan.dives.reversed) {
      if (d.diveMode != 'oc' ||
          d.targetMaxDepth < 18 ||
          d.targetMaxDepth > 30) {
        continue;
      }
      final tanks = await (ctx.db.select(
        ctx.db.diveTanks,
      )..where((t) => t.diveId.equals(ctx.diveId(d.number)))).get();
      if (tanks case [
        final only,
      ] when only.o2Percent == 21 && only.hePercent == 0) {
        return (d, only);
      }
    }
    throw StateError('no air dive between 18 and 30 m in the story');
  }
}
