import 'dart:math' as math;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/mission/battery_burn_service.dart';
import 'package:submersion/features/planner/domain/services/mission/leg_speed_resolver.dart';
import 'package:submersion/features/planner/domain/services/mission/member_gas_service.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_segment_builder.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_team.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// Evaluates one scooter failure: a member's scooter dies on arrival at a
/// waypoint and the team exits by swimming or by towing.
///
/// Each scenario is a plan copy whose segments run out to the waypoint at
/// cruise and back at the exit speed. The plan engine runs once per scenario
/// for the schedule and time to surface; per-member gas is re-derived from
/// the schedule rows with each member's own SAC.
class MissionScenarioService {
  final PlanEngine engine;
  final MissionSegmentBuilder builder;
  final BatteryBurnService battery;
  final MemberGasService gas;
  final LegSpeedResolver speeds;

  const MissionScenarioService({
    this.engine = const PlanEngine(),
    this.builder = const MissionSegmentBuilder(),
    this.battery = const BatteryBurnService(),
    this.gas = const MemberGasService(),
    this.speeds = const LegSpeedResolver(),
  });

  /// Speed of a tow exit: the tower's tow speed, capped by every other
  /// running scooter's rated speed so the team stays together.
  double towSpeedMps({
    required DpvMission mission,
    required String failedMemberId,
    required String towerId,
  }) {
    var speed = double.infinity;
    for (final member in mission.team) {
      if (member.id == failedMemberId) continue;
      final own = member.id == towerId
          ? member.scooter.towSpeedMps
          : member.scooter.ratedSpeedMps;
      speed = math.min(speed, own);
    }
    return speed.isFinite ? speed : 0.0;
  }

  ExitOutcome evaluate({
    required domain.DivePlan plan,
    required DpvMission mission,
    required int waypointIndex,
    required String failedMemberId,
    required MissionExitMode mode,
    String? towerId,
  }) {
    final exitSpeed = switch (mode) {
      MissionExitMode.swim => slowestSwimSpeedMps(mission.team),
      MissionExitMode.tow => towSpeedMps(
        mission: mission,
        failedMemberId: failedMemberId,
        towerId: towerId!,
      ),
    };
    if (!_exitTraversable(mission, waypointIndex, exitSpeed)) {
      return ExitOutcome(
        mode: mode,
        towerId: mode == MissionExitMode.tow ? towerId : null,
        feasible: false,
        exitBottomSeconds: 0,
        ttsSeconds: 0,
        exitLitersByMember: const {},
        blockedByCurrent: true,
      );
    }
    final profile = builder.build(
      plan: plan,
      mission: mission,
      throughLegIndex: waypointIndex,
      outboundSpeedMps: cruiseSpeedMps(mission.team),
      exitSpeedMps: exitSpeed,
    );
    final outcome = engine.compute(plan.copyWith(segments: profile.segments));
    final failureRuntime = profile.waypointArrivalSeconds[waypointIndex];
    final authoredRuntime = outcome.runtimeSeconds - outcome.ttsAtBottom;
    final exitBottomSeconds = math.max(0, authoredRuntime - failureRuntime);
    final environment = environmentFor(plan);

    final outboundRows = outcome.schedule
        .where((r) => r.runtimeSeconds <= failureRuntime)
        .toList();
    final exitRows = outcome.schedule
        .where((r) => r.runtimeSeconds > failureRuntime)
        .toList();

    final exitLiters = <String, double>{};
    final gasShortfall = <String>{};
    final batteryShortfall = <String>{};

    for (final member in mission.team) {
      final failed = member.id == failedMemberId;
      final outbound = gas.litersByTank(
        rows: outboundRows,
        environment: environment,
        sacFor: (_) => member.sacBottom,
      );
      final exit = gas.litersByTank(
        rows: exitRows,
        environment: environment,
        sacFor: (row) => _exitSac(
          plan: plan,
          member: member,
          failed: failed,
          row: row,
          authoredRuntime: authoredRuntime,
        ),
      );
      exitLiters[member.id] = exit.values.fold(0.0, (a, b) => a + b);
      if (_gasShort(plan, outbound, exit)) gasShortfall.add(member.id);
      if (!failed) {
        final tows = mode == MissionExitMode.tow && member.id == towerId;
        final powered =
            failureRuntime +
            (mode == MissionExitMode.tow && !tows ? exitBottomSeconds : 0);
        final fraction = battery.burnFraction(
          scooter: member.scooter,
          poweredSeconds: powered,
          towingSeconds: tows ? exitBottomSeconds : 0,
        );
        if (!battery.withinReserve(
          burnFraction: fraction,
          reserveFraction: mission.batteryReserveFraction,
        )) {
          batteryShortfall.add(member.id);
        }
      }
    }

    return ExitOutcome(
      mode: mode,
      towerId: mode == MissionExitMode.tow ? towerId : null,
      feasible: gasShortfall.isEmpty && batteryShortfall.isEmpty,
      exitBottomSeconds: exitBottomSeconds,
      ttsSeconds: outcome.ttsAtBottom,
      exitLitersByMember: exitLiters,
      gasShortfallMemberIds: gasShortfall,
      batteryShortfallMemberIds: batteryShortfall,
    );
  }

  /// True when the team can make headway at [exitSpeed] on every leg from
  /// waypoint [waypointIndex] back to the start.
  bool _exitTraversable(
    DpvMission mission,
    int waypointIndex,
    double exitSpeed,
  ) {
    for (var i = 0; i <= waypointIndex; i++) {
      final leg = mission.legs[i];
      final resolved = speeds.resolve(
        leg: leg,
        current: mission.currentFor(leg),
        baseSpeedMps: exitSpeed,
      );
      if (!resolved.returnTraversable) return false;
    }
    return true;
  }

  double _exitSac({
    required domain.DivePlan plan,
    required MissionMember member,
    required bool failed,
    required PlanScheduleRow row,
    required int authoredRuntime,
  }) {
    if (row.runtimeSeconds > authoredRuntime) return plan.sacDecoEffective;
    return failed ? plan.sacStressedEffective : member.sacBottom;
  }

  /// True when any tank with a known size and fill would end below the plan
  /// reserve after [outbound] plus [exit] litres.
  bool _gasShort(
    domain.DivePlan plan,
    Map<String, double> outbound,
    Map<String, double> exit,
  ) {
    for (final tank in plan.tanks) {
      final used = (outbound[tank.id] ?? 0.0) + (exit[tank.id] ?? 0.0);
      final remaining = gas.remainingBar(
        tank: tank,
        litersUsed: used,
        model: engine.config.gasModel,
      );
      if (remaining == null) continue;
      if (remaining < plan.reservePressure) return true;
    }
    return false;
  }

  /// The same environment the engine derives for [plan] (see
  /// `PlanEngine._computeInternal`), so ambient pressure agrees with deco.
  static DiveEnvironment environmentFor(domain.DivePlan plan) {
    return DiveEnvironment.forConditions(
      altitudeMeters: (plan.altitude ?? 0) > 0 ? plan.altitude : null,
      waterType: plan.waterType ?? WaterType.salt,
      salinityPpt: plan.salinityPpt,
    );
  }
}
