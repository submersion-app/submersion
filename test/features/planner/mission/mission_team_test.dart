import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_team.dart';

MissionMember _member(
  String id,
  int order,
  double speed, {
  double swim = 0.2,
}) => MissionMember(
  id: id,
  order: order,
  displayName: id,
  sacBottom: 15,
  swimSpeedMps: swim,
  scooter: ScooterSpec(
    name: 'S-$id',
    ratedSpeedMps: speed,
    burnTimeSeconds: 3600,
  ),
);

void main() {
  test('the team cruises at the slowest rated speed', () {
    final team = [
      _member('a', 0, 0.9),
      _member('b', 1, 0.7),
      _member('c', 2, 0.8),
    ];
    expect(cruiseSpeedMps(team), 0.7);
    expect(cruiseLimitingMemberId(team), 'b');
  });

  test('a tie goes to the earlier member', () {
    final team = [_member('a', 0, 0.7), _member('b', 1, 0.7)];
    expect(cruiseLimitingMemberId(team), 'a');
  });

  test('an empty team has no cruise speed and no limiting member', () {
    expect(cruiseSpeedMps(const []), 0);
    expect(cruiseLimitingMemberId(const []), isNull);
    expect(slowestSwimSpeedMps(const []), 0);
  });

  test('the slowest swimmer sets the swim exit speed', () {
    final team = [
      _member('a', 0, 0.9, swim: 0.25),
      _member('b', 1, 0.9, swim: 0.15),
    ];
    expect(slowestSwimSpeedMps(team), 0.15);
  });
}
