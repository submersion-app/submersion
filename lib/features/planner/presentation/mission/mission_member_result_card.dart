import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/presentation/mission/mission_avatars.dart';
import 'package:submersion/features/planner/presentation/mission/mission_issue_text.dart';
import 'package:submersion/features/planner/presentation/mission/mission_result_text.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One diver's result: the round-trip battery against the reserve, whether
/// their scooter sets the team's speed, where and why they bind, and their
/// turn pressure.
class MissionMemberResultCard extends StatelessWidget {
  const MissionMemberResultCard({
    super.key,
    required this.member,
    required this.result,
    required this.mission,
    required this.units,
  });

  final MissionMember member;
  final MemberOutcome result;
  final DpvMission mission;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final used = result.batteryRoundTripFraction.clamp(0.0, 1.0);
    final reserve = mission.batteryReserveFraction;
    final overReserve = result.batteryRoundTripFraction > 1 - reserve;
    final binding = result.bindingFactor;
    final bindingIndex = result.bindingWaypointIndex;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The same avatar as the diver's card in Plan Setup.
            Row(
              children: [
                MissionMemberAvatar(member: member),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    member.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _BatteryBar(used: used, reserve: reserve, overReserve: overReserve),
            Text(
              // Placeholders are alphabetical: minutes, percent, reserve.
              l10n.plannerMission_results_battery(
                ceilMinutes(
                  (result.batteryRoundTripFraction *
                          member.scooter.burnTimeSeconds)
                      .round(),
                ).toString(),
                ceilPercent(result.batteryRoundTripFraction),
                ceilPercent(reserve),
              ),
              style: theme.textTheme.bodySmall,
            ),
            if (result.setsCruiseSpeed)
              Text(
                l10n.plannerMission_results_setsCruise,
                style: theme.textTheme.bodySmall,
              ),
            Text(
              binding == null ||
                      bindingIndex == null ||
                      bindingIndex >= mission.legs.length
                  ? l10n.plannerMission_results_noLimit
                  // Placeholders are alphabetical: factor, waypoint.
                  : l10n.plannerMission_results_bindsAt(
                      missionFactorLabel(l10n, binding),
                      missionLegName(l10n, mission.legs[bindingIndex]),
                    ),
              style: theme.textTheme.bodySmall,
            ),
            if (result.turnPressureBar != null)
              Text(
                l10n.plannerMission_results_turnPressure(
                  ceilPressure(units, result.turnPressureBar!),
                ),
                style: theme.textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }
}

/// A bar for the round-trip battery use, with the reserve marked from the
/// right. The fill turns to the error colour once it reaches the reserve.
class _BatteryBar extends StatelessWidget {
  const _BatteryBar({
    required this.used,
    required this.reserve,
    required this.overReserve,
  });

  final double used;
  final double reserve;
  final bool overReserve;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Stack(
            children: [
              Container(color: scheme.surfaceContainerHighest),
              Container(
                width: width * used,
                color: overReserve ? scheme.error : scheme.primary,
              ),
              Positioned(
                left: width * (1 - reserve) - 1,
                top: 0,
                bottom: 0,
                child: Container(width: 2, color: scheme.onSurface),
              ),
            ],
          );
        },
      ),
    );
  }
}
