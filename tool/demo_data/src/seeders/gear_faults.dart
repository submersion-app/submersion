import 'dart:math';

import 'package:submersion/features/equipment/data/repositories/equipment_observation_repository.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';

import '../story/story_plan.dart';
import 'dive_kit.dart';
import 'gear_timeline.dart';
import 'seed_context.dart';

/// What goes wrong with the kit, by dive number. The faults live in the
/// dives themselves (pressure gaps, cell readings, the diver's own notes on
/// the gear), so the app's condition program finds them as it would in a
/// real logbook.
class FaultPlan {
  const FaultPlan({
    required this.freeFlowDives,
    required this.lightFloodDives,
    required this.dropoutDives,
    required this.cellDriftDives,
    required this.divergentCellDives,
  });

  /// The cold-water regulator free-flowed in near-freezing water.
  final List<int> freeFlowDives;

  /// The dive light let water in on deep dives.
  final List<int> lightFloodDives;

  /// The doubles' transmitter lost its link for a good part of the dive.
  final List<int> dropoutDives;

  /// Oxygen cell 2 read low before it was swapped.
  final List<int> cellDriftDives;

  /// Oxygen cell 3 reads high against the other two.
  final List<int> divergentCellDives;
}

/// Picks the dives each fault happens on, from the kit each dive used.
FaultPlan planFaults(StoryPlan plan, GearTimeline t) {
  List<PlannedDive> using(String key) => [
    for (final d in plan.dives)
      if (kitFor(d, t, photo: false).gearKeys.contains(key)) d,
  ];

  // The last dives in near-freezing water: the free-flows come with the
  // cold, which the condition program reads from the dives.
  final freeFlow = [
    for (final d in using('reg-cold'))
      if (d.waterTempC < 9) d.number,
  ];

  final light = using('light-primary');
  final deep = [
    for (final d in light)
      if (d.targetMaxDepth >= 33) d.number,
  ];

  final doubles = [
    for (final d in using('reg-right'))
      if (t.inUseOn('transmitter-right', d.start)) d.number,
  ];

  final swap = plan.milestones[StoryMilestone.cellSwap]!;
  final ccr = [
    for (final d in plan.dives)
      if (d.diveMode == 'ccr') d.number,
  ];
  return FaultPlan(
    freeFlowDives: freeFlow.length > 4
        ? freeFlow.sublist(freeFlow.length - 4)
        : freeFlow,
    lightFloodDives: deep.length > 3 ? deep.sublist(deep.length - 3) : deep,
    // The last eight, so the five latest that carry pressure all show it
    // (a dive whose source logged no tank pressure has nothing to drop).
    dropoutDives: doubles.sublist(max(0, doubles.length - 8)),
    cellDriftDives: [
      for (final n in ccr)
        if (n < swap && n >= swap - 4) n,
    ],
    divergentCellDives: ccr.sublist(max(0, ccr.length - 4)),
  );
}

/// The diver's notes on the gear: the faults, and the moderate free-flow
/// incident's regulator. Runs after the dives.
class FaultSeeder implements DemoSeeder {
  @override
  String get name => 'gear faults';

  @override
  Future<void> seed(DemoSeedContext ctx) async {
    final observations = EquipmentObservationRepository();
    Future<void> note(
      String key,
      int dive,
      ObservationTag tag,
      String text,
    ) async {
      final d = ctx.plan.dives[dive - 1];
      await observations.create(
        equipmentId: ctx.equipment[key]!,
        diveId: ctx.diveId(dive),
        diverId: DemoSeedContext.diverId,
        observedAt: d.start.add(d.plannedDuration),
        status: ObservationStatus.issue,
        issueTags: [tag],
        note: text,
        now: d.start.add(d.plannedDuration),
      );
    }

    final faults = ctx.faults;
    for (final n in faults.freeFlowDives) {
      await note(
        'reg-cold',
        n,
        ObservationTag.freeFlow,
        'Primary free-flowed on the descent in the cold water.',
      );
    }
    for (final n in faults.lightFloodDives) {
      await note(
        'light-primary',
        n,
        ObservationTag.flooded,
        'Water in the light head after the deep part of the dive.',
      );
    }
  }
}
