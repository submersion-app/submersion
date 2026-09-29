import 'package:flutter/material.dart';

import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/presentation/mission/mission_issue_text.dart';
import 'package:submersion/features/planner/presentation/mission/mission_result_text.dart';
import 'package:submersion/features/planner/presentation/mission/mission_units.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Out and back speed over the ground and duration for each leg.
class MissionLegTable extends StatelessWidget {
  const MissionLegTable({
    super.key,
    required this.outcome,
    required this.mission,
    required this.units,
  });

  final MissionOutcome outcome;
  final DpvMission mission;
  final MissionUnits units;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final leg in outcome.legs)
          if (mission.legs.where((l) => l.id == leg.legId).firstOrNull
              case final missionLeg?)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '${missionLegName(l10n, missionLeg)}: '
                // Placeholders are alphabetical: backMinutes, backSpeed,
                // outMinutes, outSpeed.
                '${l10n.plannerMission_results_legLine(ceilMinutes(leg.returnSeconds).toString(), units.speed(leg.returnSpeedMps), ceilMinutes(leg.outboundSeconds).toString(), units.speed(leg.outboundSpeedMps))}',
                style: theme.textTheme.bodySmall,
              ),
            ),
      ],
    );
  }
}
