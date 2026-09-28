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
  final legs = [
    for (final (i, raw) in (map['legs'] as List? ?? const []).indexed)
      _legFromMap(raw as Map<String, dynamic>, i, newId()),
  ];
  final team = [
    for (final (i, raw) in (map['team'] as List? ?? const []).indexed)
      _memberFromMap(raw as Map<String, dynamic>, i, newId()),
  ];

  return DpvMission(
    legs: legs,
    team: team,
    batteryReserveFraction:
        (map['batteryReserveFraction'] as num?)?.toDouble() ??
        kDefaultBatteryReserveFraction,
    defaultCurrent: _currentFromMap(map['defaultCurrent'], 'defaultCurrent'),
    environment:
        MissionEnvironment.values.asNameMap()[map['environment']] ??
        MissionEnvironment.overhead,
    walkSpeedMps:
        (map['walkSpeedMps'] as num?)?.toDouble() ?? kDefaultWalkSpeedMps,
    surfaceSwimLimitM: (map['surfaceSwimLimitM'] as num?)?.toDouble(),
  );
}

MissionLeg _legFromMap(Map<String, dynamic> leg, int order, String id) {
  return MissionLeg(
    id: id,
    order: order,
    label: leg['label'] as String? ?? '',
    distanceM: _numberOrThrow(leg, 'distanceM'),
    depthM: _numberOrThrow(leg, 'depthM'),
    headingDeg: _numberOrThrow(leg, 'headingDeg'),
    current: _currentFromMap(leg['current'], 'current'),
    shoreExit: _shoreFromMap(leg['shoreExit']),
  );
}

MissionMember _memberFromMap(
  Map<String, dynamic> member,
  int order,
  String id,
) {
  final scooter = member['scooter'] as Map<String, dynamic>;
  return MissionMember(
    id: id,
    order: order,
    displayName: member['displayName'] as String? ?? '',
    sacBottom: _numberOrThrow(member, 'sacBottom'),
    swimSpeedMps:
        (member['swimSpeedMps'] as num?)?.toDouble() ?? kDefaultSwimSpeedMps,
    scooter: ScooterSpec(
      name: scooter['name'] as String? ?? '',
      ratedSpeedMps: _numberOrThrow(scooter, 'ratedSpeedMps'),
      burnTimeSeconds: _numberOrThrow(scooter, 'burnTimeSeconds').round(),
      towSpeedFactor:
          (scooter['towSpeedFactor'] as num?)?.toDouble() ??
          kDefaultTowSpeedFactor,
      towBurnFactor:
          (scooter['towBurnFactor'] as num?)?.toDouble() ??
          kDefaultTowBurnFactor,
    ),
  );
}

/// A null [raw] is no shore exit; anything else must carry both distances.
ShoreExit? _shoreFromMap(Object? raw) {
  if (raw == null) return null;
  final map = _objectOrThrow(raw, 'shoreExit');
  return ShoreExit(
    surfaceSwimM: _numberOrThrow(map, 'surfaceSwimM'),
    walkM: _numberOrThrow(map, 'walkM'),
  );
}

Map<String, dynamic>? _currentToMap(CurrentVector? current) {
  if (current == null) return null;
  return {'speedMps': current.speedMps, 'setsTowardDeg': current.setsTowardDeg};
}

/// A null [raw] is no current; anything else must carry both halves.
CurrentVector? _currentFromMap(Object? raw, String field) {
  if (raw == null) return null;
  final map = _objectOrThrow(raw, field);
  return CurrentVector(
    speedMps: _numberOrThrow(map, 'speedMps'),
    setsTowardDeg: _numberOrThrow(map, 'setsTowardDeg'),
  );
}

Map<String, dynamic> _objectOrThrow(Object raw, String field) {
  if (raw is! Map<String, dynamic>) {
    throw FormatException('Mission field "$field" is not an object');
  }
  return raw;
}

double _numberOrThrow(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! num) {
    throw FormatException('Mission field "$key" is missing');
  }
  return value.toDouble();
}
