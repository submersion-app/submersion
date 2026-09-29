import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/data/services/plan_calculator_service.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';
import 'package:submersion/features/planner/domain/services/mission/mission_edits.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late DivePlanNotifier notifier;

  setUp(() {
    notifier = DivePlanNotifier(PlanCalculatorService());
    // The starter plan must carry a back-gas cylinder for segments to exist.
    notifier.addTank(
      const DiveTank(
        id: 'back',
        volume: 24,
        startPressure: 230,
        gasMix: GasMix(o2: 21),
        role: TankRole.backGas,
      ),
    );
  });

  tearDown(() => notifier.dispose());

  final starter = MissionEdits.starter(
    legId: 'L1',
    memberId: 'm1',
    memberName: 'Sam',
    sacBottom: 15,
  );

  test('enabling a half-built mission sets it and generates nothing', () {
    notifier.enableMission(starter);
    expect(notifier.state.mission, starter);
    expect(notifier.state.segments, isEmpty);
    expect(notifier.state.isDirty, isTrue);
  });

  test('completing the mission regenerates the segments', () {
    notifier.enableMission(starter);
    var mission = MissionEdits.updateLeg(
      starter,
      starter.legs.single.copyWith(distanceM: 300, depthM: 20),
    );
    mission = MissionEdits.updateMember(
      mission,
      mission.team.single.copyWith(
        scooter: const ScooterSpec(
          name: 'Blacktip',
          ratedSpeedMps: 0.9,
          burnTimeSeconds: 5400,
        ),
      ),
    );
    notifier.updateMission(mission);
    expect(
      notifier.state.segments.map((s) => s.id),
      contains('mission-out-L1'),
    );

    // A second edit replaces the segments rather than appending to them.
    final count = notifier.state.segments.length;
    notifier.updateMission(
      MissionEdits.updateLeg(
        mission,
        mission.legs.single.copyWith(distanceM: 400),
      ),
    );
    expect(notifier.state.segments.length, count);
  });

  test('disabling keeps the generated segments as ordinary segments', () {
    notifier.enableMission(starter);
    final mission = MissionEdits.updateMember(
      MissionEdits.updateLeg(
        starter,
        starter.legs.single.copyWith(distanceM: 300, depthM: 20),
      ),
      starter.team.single.copyWith(
        scooter: const ScooterSpec(
          name: 'Blacktip',
          ratedSpeedMps: 0.9,
          burnTimeSeconds: 5400,
        ),
      ),
    );
    notifier.updateMission(mission);
    final generated = notifier.state.segments;
    notifier.disableMission();
    expect(notifier.state.mission, isNull);
    expect(notifier.state.segments, generated);
  });

  test('the default swim speed survives into the state', () {
    notifier.enableMission(starter);
    expect(
      notifier.state.mission!.team.single.swimSpeedMps,
      kDefaultSwimSpeedMps,
    );
  });

  group('opening a saved mission', () {
    setUp(() async => setUpTestDatabase());
    tearDown(tearDownTestDatabase);

    EquipmentItem dpvItem(String id) => EquipmentItem(
      id: id,
      name: 'Blacktip',
      type: EquipmentType.dpv,
      attributes: [
        EquipmentAttribute.curated(
          equipmentId: id,
          key: 'speed_mps',
          valueNum: 0.9,
        ),
        EquipmentAttribute.curated(
          equipmentId: id,
          key: 'burn_time_h',
          valueNum: 1.5,
        ),
      ],
    );

    test(
      'a picked scooter is refreshed from its live item, not dirtied',
      () async {
        var mission = MissionEdits.updateLeg(
          starter,
          starter.legs.single.copyWith(distanceM: 300, depthM: 20),
        );
        mission = MissionEdits.updateMember(
          mission,
          mission.team.single.copyWith(
            scooter: const ScooterSpec(
              equipmentId: 'eq-1',
              name: 'Old name',
              ratedSpeedMps: 0.5,
              burnTimeSeconds: 3600,
            ),
          ),
        );
        await DivePlanRepository().savePlan(
          domain.DivePlan(
            id: 'plan-1',
            name: 'Saved mission',
            gfLow: 40,
            gfHigh: 80,
            tanks: const [
              DiveTank(
                id: 'back',
                volume: 24,
                startPressure: 230,
                gasMix: GasMix(o2: 21),
                role: TankRole.backGas,
              ),
            ],
            mission: mission,
            createdAt: DateTime(2026, 9, 28),
            updatedAt: DateTime(2026, 9, 28),
          ),
        );

        final opener = DivePlanNotifier(
          PlanCalculatorService(),
          repository: DivePlanRepository(),
          loadEquipment: () async => [dpvItem('eq-1')],
        );
        addTearDown(opener.dispose);
        expect(await opener.loadPlanById('plan-1'), isTrue);

        final scooter = opener.state.mission!.team.single.scooter;
        expect(scooter.name, 'Blacktip');
        expect(scooter.ratedSpeedMps, 0.9);
        expect(scooter.burnTimeSeconds, 5400);
        expect(opener.state.isDirty, isFalse);
        expect(opener.state.segments, isNotEmpty);
      },
    );
  });
}
