import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/entities/mission/shore_exit.dart';

/// The `mission` block of a version 3 `.subplan` file (issue #2086).
///
/// Links to a buddy, a diver profile or an equipment item are not written:
/// they name rows of the exporting install, which on another install would
/// dangle or match an unrelated row. The scooter's numbers travel as the
/// snapshot they already are.
Map<String, dynamic> missionToFileMap(DpvMission mission) {
  return {
    'batteryReserveFraction': mission.batteryReserveFraction,
    'defaultCurrent': _currentToMap(mission.defaultCurrent),
    'environment': mission.environment.name,
    'walkSpeedMps': mission.walkSpeedMps,
    'surfaceSwimLimitM': mission.surfaceSwimLimitM,
    'legs': [
      for (final leg in mission.legs)
        {
          'label': leg.label,
          'distanceM': leg.distanceM,
          'depthM': leg.depthM,
          'headingDeg': leg.headingDeg,
          'current': _currentToMap(leg.current),
          'shoreExit': leg.shoreExit == null
              ? null
              : {
                  'surfaceSwimM': leg.shoreExit!.surfaceSwimM,
                  'walkM': leg.shoreExit!.walkM,
                },
        },
    ],
    'team': [
      for (final member in mission.team)
        {
          'displayName': member.displayName,
          'sacBottom': member.sacBottom,
          'swimSpeedMps': member.swimSpeedMps,
          'scooter': {
            'name': member.scooter.name,
            'ratedSpeedMps': member.scooter.ratedSpeedMps,
            'burnTimeSeconds': member.scooter.burnTimeSeconds,
            'towSpeedFactor': member.scooter.towSpeedFactor,
            'towBurnFactor': member.scooter.towBurnFactor,
          },
        },
    ],
  };
}

/// Reads a `mission` block, minting ids with [newId]. Throws
/// [FormatException] when a required number is missing; a cast failure on a
/// malformed file is converted by the caller.
DpvMission missionFromFileMap(
  Map<String, dynamic> map,
  String Function() newId,
) {
  double required(Map<String, dynamic> m, String key) {
    final value = m[key];
    if (value is! num) {
      throw FormatException('Mission field "$key" is missing');
    }
    return value.toDouble();
  }

  final legs = <MissionLeg>[];
  for (final (i, raw) in (map['legs'] as List? ?? const []).indexed) {
    final leg = raw as Map<String, dynamic>;
    legs.add(
      MissionLeg(
        id: newId(),
        order: i,
        label: leg['label'] as String? ?? '',
        distanceM: required(leg, 'distanceM'),
        depthM: required(leg, 'depthM'),
        headingDeg: required(leg, 'headingDeg'),
        current: _currentFromMap(leg['current']),
        shoreExit: _shoreFromMap(leg['shoreExit']),
      ),
    );
  }

  final team = <MissionMember>[];
  for (final (i, raw) in (map['team'] as List? ?? const []).indexed) {
    final member = raw as Map<String, dynamic>;
    final scooter = member['scooter'] as Map<String, dynamic>;
    team.add(
      MissionMember(
        id: newId(),
        order: i,
        displayName: member['displayName'] as String? ?? '',
        sacBottom: required(member, 'sacBottom'),
        swimSpeedMps:
            (member['swimSpeedMps'] as num?)?.toDouble() ??
            kDefaultSwimSpeedMps,
        scooter: ScooterSpec(
          name: scooter['name'] as String? ?? '',
          ratedSpeedMps: required(scooter, 'ratedSpeedMps'),
          burnTimeSeconds: required(scooter, 'burnTimeSeconds').round(),
          towSpeedFactor:
              (scooter['towSpeedFactor'] as num?)?.toDouble() ??
              kDefaultTowSpeedFactor,
          towBurnFactor:
              (scooter['towBurnFactor'] as num?)?.toDouble() ??
              kDefaultTowBurnFactor,
        ),
      ),
    );
  }

  return DpvMission(
    legs: legs,
    team: team,
    batteryReserveFraction:
        (map['batteryReserveFraction'] as num?)?.toDouble() ??
        kDefaultBatteryReserveFraction,
    defaultCurrent: _currentFromMap(map['defaultCurrent']),
    environment:
        MissionEnvironment.values.asNameMap()[map['environment']] ??
        MissionEnvironment.overhead,
    walkSpeedMps:
        (map['walkSpeedMps'] as num?)?.toDouble() ?? kDefaultWalkSpeedMps,
    surfaceSwimLimitM: (map['surfaceSwimLimitM'] as num?)?.toDouble(),
  );
}

ShoreExit? _shoreFromMap(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  final swim = raw['surfaceSwimM'];
  final walk = raw['walkM'];
  if (swim is! num || walk is! num) return null;
  return ShoreExit(surfaceSwimM: swim.toDouble(), walkM: walk.toDouble());
}

Map<String, dynamic>? _currentToMap(CurrentVector? current) {
  if (current == null) return null;
  return {'speedMps': current.speedMps, 'setsTowardDeg': current.setsTowardDeg};
}

CurrentVector? _currentFromMap(Object? raw) {
  if (raw is! Map<String, dynamic>) return null;
  final speed = raw['speedMps'];
  final toward = raw['setsTowardDeg'];
  if (speed is! num || toward is! num) return null;
  return CurrentVector(
    speedMps: speed.toDouble(),
    setsTowardDeg: toward.toDouble(),
  );
}
