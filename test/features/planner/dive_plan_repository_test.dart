import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;

import '../../helpers/test_database.dart';

domain.DivePlan _fullPlan() {
  const backGas = GasMix(o2: 18, he: 45);
  const decoGas = GasMix(o2: 50);
  const tank1 = DiveTank(
    id: 'tank-1',
    name: 'D12',
    volume: 24.0,
    workingPressure: 232.0,
    startPressure: 232.0,
    gasMix: backGas,
    role: TankRole.backGas,
    material: TankMaterial.steel,
  );
  const tank2 = DiveTank(
    id: 'tank-2',
    name: 'S80',
    volume: 11.1,
    startPressure: 207.0,
    gasMix: decoGas,
    role: TankRole.deco,
  );
  return domain.DivePlan(
    id: 'plan-1',
    name: 'Wreck 60 m',
    notes: 'Stern first',
    mode: domain.PlanMode.oc,
    altitude: 700.0,
    waterType: WaterType.salt,
    gfLow: 45,
    gfHigh: 80,
    descentRate: 20.0,
    ascentRate: 9.0,
    lastStopDepth: 6.0,
    gasSwitchStopSeconds: 120,
    airBreaks: const AirBreakPolicy(o2Seconds: 720, breakSeconds: 360),
    sacBottom: 16.0,
    sacDeco: 13.0,
    reservePressure: 55.0,
    surfaceInterval: const Duration(hours: 2),
    deviationDepthDelta: 6.0,
    deviationTimeMinutes: 5,
    turnPressureRule: domain.TurnPressureRule.thirds,
    tanks: const [tank1, tank2],
    segments: [
      PlanSegment.descent(
        id: 'seg-1',
        targetDepth: 60.0,
        tankId: 'tank-1',
        gasMix: backGas,
        order: 0,
      ),
      PlanSegment.bottom(
        id: 'seg-2',
        depth: 60.0,
        durationMinutes: 25,
        tankId: 'tank-1',
        gasMix: backGas,
        order: 1,
      ),
    ],
    createdAt: DateTime(2026, 7, 5, 10),
    updatedAt: DateTime(2026, 7, 5, 10),
  );
}

void main() {
  late DivePlanRepository repository;
  late db.AppDatabase database;

  setUp(() async {
    database = await setUpTestDatabase();
    repository = DivePlanRepository();
  });

  tearDown(() {
    DatabaseService.instance.resetForTesting();
  });

  group('DivePlanRepository', () {
    test('save then get round-trips every field', () async {
      final plan = _fullPlan();
      await repository.savePlan(plan);
      final loaded = await repository.getPlan('plan-1');

      expect(loaded, isNotNull);
      expect(loaded!.name, 'Wreck 60 m');
      expect(loaded.notes, 'Stern first');
      expect(loaded.mode, domain.PlanMode.oc);
      expect(loaded.altitude, 700.0);
      expect(loaded.waterType, WaterType.salt);
      expect(loaded.gfLow, 45);
      expect(loaded.gfHigh, 80);
      expect(loaded.descentRate, 20.0);
      expect(loaded.lastStopDepth, 6.0);
      expect(loaded.gasSwitchStopSeconds, 120);
      expect(loaded.airBreaks?.o2Seconds, 720);
      expect(loaded.airBreaks?.breakSeconds, 360);
      expect(loaded.sacBottom, 16.0);
      expect(loaded.sacDeco, 13.0);
      expect(loaded.sacStressed, isNull);
      expect(loaded.reservePressure, 55.0);
      expect(loaded.surfaceInterval, const Duration(hours: 2));
      expect(loaded.turnPressureRule, domain.TurnPressureRule.thirds);
      expect(loaded.tanks, hasLength(2));
      expect(loaded.tanks.first.gasMix.he, 45);
      expect(loaded.tanks.first.material, TankMaterial.steel);
      expect(loaded.tanks.last.role, TankRole.deco);
      expect(loaded.segments, hasLength(2));
      expect(loaded.segments.first.type, SegmentType.descent);
      expect(loaded.segments.last.durationSeconds, 25 * 60);
    });

    test('summaries return saved numbers without children', () async {
      await repository.savePlan(
        _fullPlan(),
        summary: const PlanSummaryData(
          maxDepth: 60.0,
          runtimeSeconds: 74 * 60,
          ttsSeconds: 39 * 60,
        ),
      );
      final summaries = await repository.getAllPlanSummaries();
      expect(summaries, hasLength(1));
      expect(summaries.single.maxDepth, 60.0);
      expect(summaries.single.runtimeSeconds, 74 * 60);
      expect(summaries.single.ttsSeconds, 39 * 60);
    });

    test('re-save with a removed segment tombstones it', () async {
      final plan = _fullPlan();
      await repository.savePlan(plan);
      final shorter = plan.copyWith(segments: [plan.segments.first]);
      await repository.savePlan(shorter);

      final loaded = await repository.getPlan('plan-1');
      expect(loaded!.segments, hasLength(1));

      final deletions = await database.select(database.deletionLog).get();
      final segmentTombstones = deletions.where(
        (d) => d.entityType == 'divePlanSegments' && d.recordId == 'seg-2',
      );
      expect(segmentTombstones, hasLength(1));
    });

    test('deletePlan removes all rows and tombstones each', () async {
      await repository.savePlan(_fullPlan());
      await repository.deletePlan('plan-1');

      expect(await repository.getPlan('plan-1'), isNull);
      expect(await database.select(database.divePlanTanks).get(), isEmpty);
      expect(await database.select(database.divePlanSegments).get(), isEmpty);

      final deletions = await database.select(database.deletionLog).get();
      final types = deletions.map((d) => '${d.entityType}:${d.recordId}');
      expect(
        types,
        containsAll([
          'divePlans:plan-1',
          'divePlanTanks:tank-1',
          'divePlanTanks:tank-2',
          'divePlanSegments:seg-1',
          'divePlanSegments:seg-2',
        ]),
      );
    });

    test('duplicatePlan remaps ids and suffixes the name', () async {
      await repository.savePlan(_fullPlan());
      final copy = await repository.duplicatePlan('plan-1');

      expect(copy, isNotNull);
      expect(copy!.id, isNot('plan-1'));
      expect(copy.name, 'Wreck 60 m (copy)');
      expect(copy.tanks.map((t) => t.id), isNot(contains('tank-1')));
      // Every segment points at one of the NEW tank ids.
      final newTankIds = copy.tanks.map((t) => t.id).toSet();
      for (final segment in copy.segments) {
        expect(newTankIds, contains(segment.tankId));
      }
      expect(await repository.getAllPlanSummaries(), hasLength(2));
    });

    test('savePlan marks plan and children pending for sync', () async {
      await repository.savePlan(_fullPlan());
      final pending = await database.select(database.syncRecords).get();
      final keys = pending.map((r) => '${r.entityType}:${r.recordId}');
      expect(
        keys,
        containsAll([
          'divePlans:plan-1',
          'divePlanTanks:tank-1',
          'divePlanSegments:seg-1',
        ]),
      );
      // HLC stamped on the plan row.
      final planRow = await database.select(database.divePlans).getSingle();
      expect(planRow.hlc, isNotNull);
    });

    test(
      're-save preserves child createdAt while advancing updatedAt',
      () async {
        final repo = DivePlanRepository();
        await repo.savePlan(_fullPlan());

        final originalTank = await (database.select(
          database.divePlanTanks,
        )..where((t) => t.id.equals('tank-1'))).getSingle();
        final originalSegment = await (database.select(
          database.divePlanSegments,
        )..where((t) => t.id.equals('seg-1'))).getSingle();

        // Let the clock advance so a regressed "createdAt = now" would differ.
        await Future<void>.delayed(const Duration(milliseconds: 5));
        // Edit and re-save (rename keeps the same child rows).
        await repo.savePlan(_fullPlan().copyWith(name: 'Wreck 60 m (edited)'));

        final tankAfter = await (database.select(
          database.divePlanTanks,
        )..where((t) => t.id.equals('tank-1'))).getSingle();
        final segmentAfter = await (database.select(
          database.divePlanSegments,
        )..where((t) => t.id.equals('seg-1'))).getSingle();

        expect(
          tankAfter.createdAt,
          originalTank.createdAt,
          reason: 'tank createdAt must survive an edit',
        );
        expect(
          segmentAfter.createdAt,
          originalSegment.createdAt,
          reason: 'segment createdAt must survive an edit',
        );
        expect(
          tankAfter.updatedAt,
          greaterThanOrEqualTo(originalTank.updatedAt),
          reason: 'updatedAt still advances on edit',
        );
      },
    );
  });
}
