import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/dive_sensor_summary_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_findings_repository.dart';
import 'package:submersion/features/equipment/data/services/equipment_findings_pass.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_worker.dart';
import 'package:submersion/features/equipment/domain/entities/exposure_thresholds.dart';

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  final visited = <String>[];

  setUp(() async {
    db = await setUpTestDatabase();
    visited.clear();
    SensorSummaryScheduler.enabled = true;
    SensorSummaryScheduler.instance.repositoryFactory = () =>
        DiveSensorSummaryRepository(
          db: db,
          runner: (input) async {
            visited.add(input.diveId);
            return computeSensorSummaryFromBlobs(input);
          },
        );
    addTearDown(() {
      SensorSummaryScheduler.enabled = false;
      SensorSummaryScheduler.instance.repositoryFactory =
          SensorSummaryScheduler.defaultRepositoryFactory;
      SensorSummaryScheduler.instance.conditionInputsLoader =
          EquipmentFindingsPass.loadActiveDiverInputs;
    });
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'reg',
            name: 'reg',
            type: 'regulator',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    for (final (id, date) in [('d1', 1000), ('d2', 2000)]) {
      await db
          .into(db.dives)
          .insert(
            DivesCompanion.insert(
              id: id,
              diveDateTime: date,
              createdAt: date,
              updatedAt: date,
            ).copyWith(runtime: const Value(600)),
          );
    }
  });

  tearDown(tearDownTestDatabase);

  test('schedule refreshes the given dives once, merging bursts', () async {
    scheduleSensorSummaryRefresh(['d1']);
    scheduleSensorSummaryRefresh(['d1', 'd2']);
    await SensorSummaryScheduler.instance.idle;
    expect(visited.toSet(), {'d1', 'd2'});
    expect(visited.length, lessThanOrEqualTo(3));
  });

  test('a scheduled dive that is already current is not recomputed', () async {
    scheduleSensorSummaryRefresh(['d1']);
    await SensorSummaryScheduler.instance.idle;
    scheduleSensorSummaryRefresh(['d1']);
    await SensorSummaryScheduler.instance.idle;
    expect(visited, ['d1']);
  });

  test('scheduleStaleSweep visits every stale dive', () async {
    SensorSummaryScheduler.instance.scheduleStaleSweep();
    await SensorSummaryScheduler.instance.idle;
    expect(visited, ['d1', 'd2']);
  });

  test('disabled means no work', () async {
    SensorSummaryScheduler.enabled = false;
    scheduleSensorSummaryRefresh(['d1']);
    SensorSummaryScheduler.instance.scheduleStaleSweep();
    await SensorSummaryScheduler.instance.idle;
    expect(visited, isEmpty);
  });

  test('a failing repository factory does not poison the queue', () async {
    // The queue is one chained future. An error escaping the callback
    // leaves _tail completed with it, and every later schedule chains onto
    // a failed future and never runs: the scheduler is dead until restart.
    var broken = true;
    SensorSummaryScheduler.instance.repositoryFactory = () {
      if (broken) throw StateError('database not initialized');
      return DiveSensorSummaryRepository(
        db: db,
        runner: (input) async {
          visited.add(input.diveId);
          return computeSensorSummaryFromBlobs(input);
        },
      );
    };

    scheduleSensorSummaryRefresh(['d1']);
    await SensorSummaryScheduler.instance.idle;
    expect(visited, isEmpty);

    broken = false;
    scheduleSensorSummaryRefresh(['d2']);
    await SensorSummaryScheduler.instance.idle;
    expect(visited, ['d2']);
  });

  test('a failing dive does not poison the queue', () async {
    SensorSummaryScheduler.instance.repositoryFactory = () =>
        DiveSensorSummaryRepository(
          db: db,
          runner: (input) async {
            visited.add(input.diveId);
            if (input.diveId == 'd1') throw StateError('boom');
            return computeSensorSummaryFromBlobs(input);
          },
        );
    scheduleSensorSummaryRefresh(['d1']);
    scheduleSensorSummaryRefresh(['d2']);
    await SensorSummaryScheduler.instance.idle;
    expect(visited, containsAll(['d1', 'd2']));
  });

  test('a batch ends with a findings pass over active gear', () async {
    // No active diver in this database: the default loader falls back to
    // the default settings, which have the engine on.
    SensorSummaryScheduler.instance.scheduleStaleSweep();
    await SensorSummaryScheduler.instance.idle;
    expect(
      await EquipmentFindingsRepository(db: db).getReview('reg'),
      isNotNull,
    );
  });

  test('the findings pass is skipped when the engine is off', () async {
    SensorSummaryScheduler.instance.conditionInputsLoader = () async =>
        const ConditionPassInputs(
          diverId: null,
          thresholds: ExposureThresholds.defaults,
          engineEnabled: false,
        );
    SensorSummaryScheduler.instance.scheduleStaleSweep();
    await SensorSummaryScheduler.instance.idle;
    expect(await EquipmentFindingsRepository(db: db).getReview('reg'), isNull);
  });

  test('a findings request reviews just the named items', () async {
    // The hook for check-in and incident writes: the item's findings must
    // move without an item page open, and without a summary batch or a
    // pass over every other piece of gear.
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'bcd',
            name: 'bcd',
            type: 'bcd',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    scheduleConditionFindingsRefresh(['reg', 'missing']);
    await SensorSummaryScheduler.instance.idle;
    final findings = EquipmentFindingsRepository(db: db);
    expect(await findings.getReview('reg'), isNotNull);
    expect(await findings.getReview('bcd'), isNull);
    expect(visited, isEmpty);
  });

  test('a findings request reviews only the loaded diver\'s items', () async {
    // The pass runs with the active diver's thresholds. A queued write on
    // another diver's gear (or a diver switch before the queue runs) must
    // not recompute that gear with the wrong diver's settings.
    for (final id in ['me', 'other']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: 1,
              updatedAt: 1,
            ),
          );
    }
    for (final (id, diver) in [('mine', 'me'), ('theirs', 'other')]) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion.insert(
              id: id,
              name: id,
              type: 'bcd',
              createdAt: 1,
              updatedAt: 1,
            ).copyWith(diverId: Value(diver)),
          );
    }
    SensorSummaryScheduler.instance.conditionInputsLoader = () async =>
        const ConditionPassInputs(
          diverId: 'me',
          thresholds: ExposureThresholds.defaults,
          engineEnabled: true,
        );
    scheduleConditionFindingsRefresh(['mine', 'theirs']);
    await SensorSummaryScheduler.instance.idle;
    final findings = EquipmentFindingsRepository(db: db);
    expect(await findings.getReview('mine'), isNotNull);
    expect(await findings.getReview('theirs'), isNull);
  });

  test('an all-gear findings request reviews every active item', () async {
    // The import hook: check-ins arrive inside equipment items, with or
    // without new dives, and none of them names a single item to refresh.
    await db
        .into(db.equipment)
        .insert(
          EquipmentCompanion.insert(
            id: 'bcd',
            name: 'bcd',
            type: 'bcd',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    scheduleAllConditionFindingsRefresh();
    await SensorSummaryScheduler.instance.idle;
    final findings = EquipmentFindingsRepository(db: db);
    expect(await findings.getReview('reg'), isNotNull);
    expect(await findings.getReview('bcd'), isNotNull);
    expect(visited, isEmpty);
  });

  test('a findings request does nothing while disabled', () async {
    SensorSummaryScheduler.enabled = false;
    scheduleConditionFindingsRefresh(['reg']);
    await SensorSummaryScheduler.instance.idle;
    expect(await EquipmentFindingsRepository(db: db).getReview('reg'), isNull);
  });

  test('an empty batch still refreshes findings', () async {
    scheduleSensorSummaryRefresh(['d1', 'd2']);
    await SensorSummaryScheduler.instance.idle;
    await db.delete(db.equipmentConditionReviews).go();
    scheduleSensorSummaryRefresh(['d1']);
    await SensorSummaryScheduler.instance.idle;
    expect(
      await EquipmentFindingsRepository(db: db).getReview('reg'),
      isNotNull,
    );
  });
}
