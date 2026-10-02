import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_outcome.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';
import 'package:submersion/features/planner/presentation/providers/mission_issues_provider.dart';

void main() {
  late ProviderContainer container;
  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  final starter = MissionEdits.starter(
    legId: 'L1',
    memberId: 'm1',
    memberName: 'Sam',
    sacBottom: 15,
  );
  // 300 m at 20 m on a 0.9 m/s scooter: nothing blocks it.
  final complete = MissionEdits.updateMember(
    MissionEdits.updateLeg(
      starter,
      starter.legs.single.copyWith(distanceM: 300, depthM: 20),
    ),
    starter.team.single.copyWith(
      scooter: const ScooterSpec(
        name: 'S',
        ratedSpeedMps: 0.9,
        burnTimeSeconds: 5400,
      ),
    ),
  );

  List<MissionIssueType> types() => [
    for (final i in container.read(missionBlockingIssuesProvider)) i.type,
  ];

  test('no mission, no issues', () {
    expect(container.read(missionBlockingIssuesProvider), isEmpty);
  });

  test('the starter names what it is missing', () {
    container.read(divePlanNotifierProvider.notifier).enableMission(starter);
    // Exactly what is missing: a scooter with no speed is not a current
    // that blocks leg 1, which the engine would never report.
    expect(types(), [
      MissionIssueType.scooterUnspecified,
      MissionIssueType.legTooShort,
    ]);
  });

  test('a complete mission has none, and a blocked first leg is one', () {
    final notifier = container.read(divePlanNotifierProvider.notifier);
    notifier.enableMission(complete);
    expect(types(), isEmpty);
    notifier.updateMission(
      MissionEdits.updateLeg(
        complete,
        complete.legs.single.copyWith(
          // 1.2 m/s setting south against a 0.9 m/s scooter heading north.
          current: const CurrentVector(speedMps: 1.2, setsTowardDeg: 180),
        ),
      ),
    );
    expect(types(), [MissionIssueType.untraversableLeg]);
  });
}
