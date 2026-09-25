import 'dart:math' as math;

import 'package:submersion/core/constants/gas_model.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/battery_burn_service.dart';
import 'package:submersion/features/planner/domain/services/mission/member_gas_service.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_segment_builder.dart';

/// Per-member conclusions drawn from a computed mission: what binds each
/// member first, their turn pressure, and which member constrains the team.
class MissionMemberAnalysis {
  final BatteryBurnService battery;
  final MemberGasService gas;

  const MissionMemberAnalysis({
    this.battery = const BatteryBurnService(),
    this.gas = const MemberGasService(),
  });

  /// Seconds of the cruise-speed return from each waypoint k back to the
  /// start: the return hold and travel segments of legs 0 through k.
  List<int> returnSecondsFrom(List<MissionLeg> legs, MissionProfile profile) {
    return [
      for (var k = 0; k < legs.length; k++)
        profile.segments
            .where((s) {
              if (!s.id.startsWith('mission-ret-')) return false;
              for (var i = 0; i <= k; i++) {
                if (s.id == 'mission-ret-${legs[i].id}' ||
                    s.id == 'mission-ret-travel-${legs[i].id}') {
                  return true;
                }
              }
              return false;
            })
            .fold(0, (sum, s) => sum + s.durationSeconds),
    ];
  }

  MemberOutcome memberOutcome({
    required MissionMember member,
    required DpvMission mission,
    required List<WaypointOutcome> waypoints,
    required int? abandonment,
    required int roundTripSeconds,
    required List<int> returnSecondsFrom,
    required bool setsCruise,
    required DiveTank bottomTank,
    required double reserveBar,
    required GasModel gasModel,
  }) {
    MissionBindingFactor? factor;
    int? bindingIndex;
    for (var k = 0; k < waypoints.length; k++) {
      final own = waypoints[k].members.firstWhere(
        (m) => m.memberId == member.id,
      );
      final roundTrip = battery.burnFraction(
        scooter: member.scooter,
        poweredSeconds:
            waypoints[k].arrivalRuntimeSeconds + returnSecondsFrom[k],
      );
      if (!battery.withinReserve(
        burnFraction: roundTrip,
        reserveFraction: mission.batteryReserveFraction,
      )) {
        factor = MissionBindingFactor.battery;
      } else if (!own.survivable) {
        factor = _whyUnsurvivable(member.id, own);
      }
      if (factor != null) {
        bindingIndex = k;
        break;
      }
    }

    double? turnPressure;
    if (abandonment != null) {
      // The worst feasible exit at the abandonment point, over every failure
      // (anyone's scooter) and both modes. Total exit litres are charged to
      // the bottom tank: deco litres really come off a deco cylinder when
      // one is carried, so this errs on the safe side.
      var worstLiters = 0.0;
      for (final other in waypoints[abandonment].members) {
        for (final exit in [other.swim, other.tow, other.surface]) {
          if (exit == null || !exit.feasible) continue;
          worstLiters = math.max(
            worstLiters,
            exit.exitLitersByMember[member.id] ?? 0.0,
          );
        }
      }
      final start = bottomTank.startPressure;
      final after = gas.remainingBar(
        tank: bottomTank,
        litersUsed: worstLiters,
        model: gasModel,
      );
      if (start != null && after != null) {
        turnPressure = (start - after) + reserveBar;
      }
    }

    return MemberOutcome(
      memberId: member.id,
      batteryRoundTripFraction: battery.burnFraction(
        scooter: member.scooter,
        poweredSeconds: roundTripSeconds,
      ),
      setsCruiseSpeed: setsCruise,
      bindingFactor: factor,
      bindingWaypointIndex: bindingIndex,
      turnPressureBar: turnPressure,
    );
  }

  /// Why none of [own]'s exits works. The swim and the surface exit burn no
  /// battery, so their gas is the clean witness for a gas reason; then the
  /// surface limit, a possible tow that failed, and a current that closes
  /// every underwater exit.
  MissionBindingFactor _whyUnsurvivable(
    String memberId,
    MemberWaypointOutcome own,
  ) {
    final witnesses = [own.swim, if (own.surface != null) own.surface!];
    if (witnesses.any((e) => e.gasShortfallMemberIds.contains(memberId))) {
      return MissionBindingFactor.ownGas;
    }
    if (witnesses.any((e) => e.gasShortfallMemberIds.isNotEmpty)) {
      return MissionBindingFactor.teamGas;
    }
    if (own.surface?.surfaceLimitExceeded ?? false) {
      return MissionBindingFactor.surfaceSwimLimit;
    }
    final tow = own.tow;
    if (tow != null && !tow.blockedByCurrent) {
      return MissionBindingFactor.noFeasibleTow;
    }
    return MissionBindingFactor.blockedByCurrent;
  }

  MissionConstraint? constraint(List<MemberOutcome> members) {
    MemberOutcome? binding;
    for (final member in members) {
      final index = member.bindingWaypointIndex;
      if (index == null) continue;
      if (binding == null) {
        binding = member;
        continue;
      }
      final current = binding.bindingWaypointIndex!;
      if (index < current) {
        binding = member;
      } else if (index == current &&
          member.bindingFactor!.index < binding.bindingFactor!.index) {
        binding = member;
      }
    }
    if (binding == null) return null;
    return MissionConstraint(
      memberId: binding.memberId,
      factor: binding.bindingFactor!,
      waypointIndex: binding.bindingWaypointIndex!,
    );
  }
}
