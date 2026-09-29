import 'dart:async';

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

  test('a rate edit regenerates the mission segments', () {
    notifier.enableMission(starter);
    notifier.updateMission(
      MissionEdits.updateMember(
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
      ),
    );
    final before = notifier.state.segments;
    expect(before, isNotEmpty);
    notifier.updateRates(descent: notifier.state.descentRate / 2);
    expect(notifier.state.segments, isNot(equals(before)));
    // Regenerating is idempotent: the same inputs give the same segments.
    notifier.updateRates(descent: notifier.state.descentRate * 2);
    expect(notifier.state.segments, before);
  });

  test('a quick plan from the calculator replaces the mission', () {
    notifier.enableMission(starter);
    notifier.addSimplePlan(maxDepth: 30, bottomTimeMinutes: 20);
    expect(notifier.state.mission, isNull);
    expect(notifier.state.segments, hasLength(2));
  });

  test('editMission applies the edit to the current mission', () {
    notifier.enableMission(starter);
    notifier.updateMission(starter.copyWith(batteryReserveFraction: 0.5));
    // An edit written against the starter must not undo the reserve change.
    notifier.editMission((m) => m.copyWith(walkSpeedMps: 1.0));
    expect(notifier.state.mission!.batteryReserveFraction, 0.5);
    expect(notifier.state.mission!.walkSpeedMps, 1.0);
  });

  test('editMission does nothing without a mission', () {
    final before = notifier.state;
    notifier.editMission((m) => m.copyWith(walkSpeedMps: 1.0));
    expect(notifier.state, same(before));
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

    Future<void> saveMissionPlan() async {
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
    }

    test(
      'a picked scooter is refreshed from its live item, not dirtied',
      () async {
        await saveMissionPlan();
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

    test('a failed equipment load keeps the stored scooter', () async {
      await saveMissionPlan();
      final opener = DivePlanNotifier(
        PlanCalculatorService(),
        repository: DivePlanRepository(),
        loadEquipment: () async => throw StateError('equipment unavailable'),
      );
      addTearDown(opener.dispose);
      expect(await opener.loadPlanById('plan-1'), isTrue);
      final scooter = opener.state.mission!.team.single.scooter;
      expect(scooter.name, 'Old name');
      expect(scooter.ratedSpeedMps, 0.5);
    });

    test('an edit made while equipment loads is not reverted', () async {
      await saveMissionPlan();
      final called = Completer<void>();
      final items = Completer<List<EquipmentItem>>();
      final opener = DivePlanNotifier(
        PlanCalculatorService(),
        repository: DivePlanRepository(),
        loadEquipment: () {
          called.complete();
          return items.future;
        },
      );
      addTearDown(opener.dispose);
      final loading = opener.loadPlanById('plan-1');
      await called.future;
      final loaded = opener.state.mission!;
      final edited = MissionEdits.updateLeg(
        loaded,
        loaded.legs.single.copyWith(distanceM: 500),
      );
      opener.updateMission(edited);
      items.complete([dpvItem('eq-1')]);
      expect(await loading, isTrue);
      expect(opener.state.mission!.legs.single.distanceM, 500);
    });
  });

  group('opening a saved mission, regeneration', () {
    setUp(() async => setUpTestDatabase());
    tearDown(tearDownTestDatabase);

    test('the profile is regenerated once on load, not dirtied', () async {
      // Saved with a complete manual mission but no segments, as a plan file
      // written by another version might be.
      final mission = MissionEdits.updateMember(
        MissionEdits.updateLeg(
          starter,
          starter.legs.single.copyWith(distanceM: 300, depthM: 20),
        ),
        starter.team.single.copyWith(
          scooter: const ScooterSpec(
            name: 'Manual',
            ratedSpeedMps: 0.9,
            burnTimeSeconds: 5400,
          ),
        ),
      );
      await DivePlanRepository().savePlan(
        domain.DivePlan(
          id: 'plan-2',
          name: 'Stale profile',
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
      );
      addTearDown(opener.dispose);
      expect(await opener.loadPlanById('plan-2'), isTrue);
      expect(
        opener.state.segments.map((s) => s.id),
        contains('mission-out-L1'),
      );
      expect(opener.state.isDirty, isFalse);
    });
  });
}
