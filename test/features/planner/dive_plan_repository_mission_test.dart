import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/mission/current_vector.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_leg.dart';
import 'package:submersion/features/planner/domain/entities/mission/mission_member.dart';
import 'package:submersion/features/planner/domain/entities/mission/scooter_spec.dart';

import '../../helpers/test_database.dart';

const _gas = GasMix(o2: 21);

MissionLeg _leg(String id, int order) => MissionLeg(
  id: id,
  order: order,
  label: id,
  distanceM: 300,
  depthM: 20,
  headingDeg: 90,
  current: const CurrentVector(speedMps: 0.1, setsTowardDeg: 270),
);

MissionMember _member(String id, int order) => MissionMember(
  id: id,
  order: order,
  displayName: id,
  sacBottom: 15,
  scooter: const ScooterSpec(
    name: 'Blacktip',
    ratedSpeedMps: 0.9,
    burnTimeSeconds: 5400,
  ),
);

domain.DivePlan _plan({DpvMission? mission}) => domain.DivePlan(
  id: 'plan-1',
  name: 'Mission plan',
  gfLow: 40,
  gfHigh: 80,
  tanks: const [
    DiveTank(id: 'tank-1', volume: 24, startPressure: 200, gasMix: _gas),
  ],
  segments: [
    PlanSegment.hold(
      id: 'seg-1',
      depth: 20,
      durationMinutes: 20,
      tankId: 'tank-1',
      gasMix: _gas,
    ),
  ],
  mission: mission,
  createdAt: DateTime(2026, 9, 19),
  updatedAt: DateTime(2026, 9, 19),
);

final _mission = DpvMission(
  legs: [_leg('L1', 0), _leg('L2', 1)],
  team: [_member('m1', 0), _member('m2', 1)],
  batteryReserveFraction: 0.4,
  defaultCurrent: const CurrentVector(speedMps: 0.05, setsTowardDeg: 10),
);

void main() {
  late db.AppDatabase database;
  late DivePlanRepository repository;

  setUp(() async {
    database = await setUpTestDatabase();
    repository = DivePlanRepository();
  });

  tearDown(tearDownTestDatabase);

  Future<int> count(String table) async =>
      (await database
              .customSelect('SELECT COUNT(*) AS n FROM $table')
              .getSingle())
          .read<int>('n');

  test('a plan without a mission stores no mission rows', () async {
    await repository.savePlan(_plan());
    expect(await count('dive_plan_missions'), 0);
    expect((await repository.getPlan('plan-1'))!.mission, isNull);
  });

  test('a mission round-trips through save and load', () async {
    await repository.savePlan(_plan(mission: _mission));
    final loaded = await repository.getPlan('plan-1');
    expect(loaded!.mission, _mission);
    expect(await count('dive_plan_mission_legs'), 2);
    expect(await count('dive_plan_mission_members'), 2);
  });

  test(
    'a re-save drops removed legs and members and keeps createdAt',
    () async {
      await repository.savePlan(_plan(mission: _mission));
      final before = await (database.select(
        database.divePlanMissionLegs,
      )..where((t) => t.id.equals('L1'))).getSingle();

      await repository.savePlan(
        _plan(
          mission: _mission.copyWith(
            legs: [_leg('L1', 0)],
            team: [_member('m2', 0)],
          ),
        ),
      );

      final loaded = (await repository.getPlan('plan-1'))!.mission!;
      expect(loaded.legs.map((l) => l.id), ['L1']);
      expect(loaded.team.map((m) => m.id), ['m2']);
      final after = await (database.select(
        database.divePlanMissionLegs,
      )..where((t) => t.id.equals('L1'))).getSingle();
      expect(after.createdAt, before.createdAt);
    },
  );

  test('saving without the mission removes every mission row', () async {
    await repository.savePlan(_plan(mission: _mission));
    await repository.savePlan(_plan());
    expect(await count('dive_plan_missions'), 0);
    expect(await count('dive_plan_mission_legs'), 0);
    expect(await count('dive_plan_mission_members'), 0);
    expect((await repository.getPlan('plan-1'))!.mission, isNull);
  });

  test('removed rows and a removed mission are tombstoned', () async {
    await repository.savePlan(_plan(mission: _mission));
    await repository.savePlan(_plan());
    final tombstones = await database
        .customSelect('SELECT entity_type, record_id FROM deletion_log')
        .get();
    final logged = {
      for (final r in tombstones)
        '${r.read<String>('entity_type')}:${r.read<String>('record_id')}',
    };
    expect(
      logged,
      containsAll(<String>[
        'divePlanMissions:plan-1',
        'divePlanMissionLegs:L1',
        'divePlanMissionLegs:L2',
        'divePlanMissionMembers:m1',
        'divePlanMissionMembers:m2',
      ]),
    );
  });

  test('deleting the plan deletes and tombstones its mission', () async {
    await repository.savePlan(_plan(mission: _mission));
    await repository.deletePlan('plan-1');
    expect(await count('dive_plan_missions'), 0);
    expect(await count('dive_plan_mission_legs'), 0);
    expect(await count('dive_plan_mission_members'), 0);
    final n = await database
        .customSelect(
          "SELECT COUNT(*) AS n FROM deletion_log "
          "WHERE entity_type = 'divePlanMissions' AND record_id = 'plan-1'",
        )
        .getSingle();
    expect(n.read<int>('n'), 1);
  });

  test('a duplicate carries the mission under fresh ids', () async {
    await repository.savePlan(_plan(mission: _mission));
    final copy = await repository.duplicatePlan('plan-1');

    final mission = (await repository.getPlan(copy!.id))!.mission!;
    expect(mission.legs.map((l) => l.label), ['L1', 'L2']);
    expect(mission.team.map((m) => m.displayName), ['m1', 'm2']);
    expect(mission.legs.map((l) => l.id), isNot(contains('L1')));
    expect(mission.team.map((m) => m.id), isNot(contains('m1')));
    expect(mission.batteryReserveFraction, 0.4);
    // The source keeps its own rows.
    expect((await repository.getPlan('plan-1'))!.mission, _mission);
  });
}
