import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';

/// Speed the team travels at: the slowest scooter. Zero for an empty team.
double cruiseSpeedMps(List<MissionMember> team) {
  if (team.isEmpty) return 0;
  var slowest = double.infinity;
  for (final member in team) {
    if (member.scooter.ratedSpeedMps < slowest) {
      slowest = member.scooter.ratedSpeedMps;
    }
  }
  return slowest;
}

/// The member whose scooter sets the cruise speed; the earlier member on a
/// tie. Null for an empty team.
String? cruiseLimitingMemberId(List<MissionMember> team) {
  if (team.isEmpty) return null;
  final cruise = cruiseSpeedMps(team);
  for (final member in team) {
    if (member.scooter.ratedSpeedMps == cruise) return member.id;
  }
  return null;
}

/// Speed the team swims at with a scooter dead: the slowest swimmer. Zero
/// for an empty team.
double slowestSwimSpeedMps(List<MissionMember> team) {
  if (team.isEmpty) return 0;
  var slowest = double.infinity;
  for (final member in team) {
    if (member.swimSpeedMps < slowest) slowest = member.swimSpeedMps;
  }
  return slowest;
}
