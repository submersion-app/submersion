import 'dart:typed_data';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/core/services/sync/sync_clock.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/change_log/domain/entities/change_log_revert_plan.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late ChangeLogRevertService service;
  final repository = ChangeLogRepository();

  Future<void> forget() async {
    await repository.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
  }

  Future<int> count(String table, [String where = '1 = 1']) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS c FROM $table WHERE $where')
        .getSingle();
    return row.read<int>('c');
  }

  /// The newest settled operation.
  Future<String> newestOperation() async {
    await repository.settleAll();
    final row = await db
        .customSelect(
          'SELECT id FROM change_log_operations '
          'WHERE event_count > 0 ORDER BY last_event_id DESC LIMIT 1',
        )
        .getSingle();
    return row.read<String>('id');
  }

  setUp(() async {
    db = await setUpTestDatabase();
    SyncClock.instance.configure(nodeId: 'node-test', now: () => 5000);
    service = ChangeLogRevertService(afterDiveWrites: (_) {});
    await insertDiver(db, 'me');
    await insertDive(db, 'dive', diverId: 'me', notes: 'Calm');
    await db.customStatement(
      'INSERT INTO equipment (id, diver_id, name, type, created_at, '
      "updated_at) VALUES ('gear', 'me', 'Reg', 'regulator', 0, 0)",
    );
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank', diveId: 'dive'));
    await db.customStatement(
      "INSERT INTO dive_equipment (dive_id, equipment_id) VALUES ('dive', 'gear')",
    );
    await db.customStatement(
      'INSERT INTO dive_profile_series (id, dive_id, sample_count, '
      'start_timestamp, end_timestamp, max_depth, first_depth, last_depth, '
      'codec_version, samples, created_at, updated_at) VALUES '
      "('series', 'dive', 2, 0, 60, 10.0, 0.0, 0.0, 1, ?, 0, 0)",
      [
        Uint8List.fromList([1, 2, 3]),
      ],
    );
    await forget();
    await SyncRepository().clearPendingRecords();
  });

  tearDown(() async {
    SyncClock.instance.reset();
    await tearDownTestDatabase();
  });

  group('restoring a delete', () {
    setUp(() async {
      await DiveRepository().deleteDive('dive');
    });

    test('a deleted dive returns with tanks, gear and profile', () async {
      final result = await service.execute(
        await service.planOperation(await newestOperation()),
      );

      expect(result.reverted, greaterThan(0));
      expect(await count('dives', "id = 'dive' AND notes = 'Calm'"), 1);
      expect(await count('dive_tanks', "dive_id = 'dive'"), 1);
      expect(await count('dive_equipment', "dive_id = 'dive'"), 1);
      final series = await db
          .customSelect('SELECT samples FROM dive_profile_series')
          .getSingle();
      expect(series.data['samples'], [1, 2, 3]);
    });

    test('a restored root row revives on a peer', () async {
      final before = DateTime.now().millisecondsSinceEpoch;

      await service.execute(
        await service.planOperation(await newestOperation()),
      );

      final dive = await db
          .customSelect("SELECT updated_at, hlc FROM dives WHERE id = 'dive'")
          .getSingle();
      expect(dive.read<int>('updated_at'), greaterThanOrEqualTo(before));
      expect(dive.data['hlc'], isNotNull);
      expect(
        await count(
          'deletion_log',
          "entity_type = 'dives' AND record_id = 'dive'",
        ),
        0,
      );
      final pending = await SyncRepository().getPendingRecords();
      expect(
        pending.map((r) => '${r.entityType}:${r.recordId}'),
        containsAll(['dives:dive', 'diveTanks:tank']),
      );
    });

    test('a record already back is blocked', () async {
      final operation = await newestOperation();
      await service.execute(await service.planOperation(operation));
      await repository.settleAll();

      final plan = await service.planOperation(operation);

      expect(
        plan.items.every((i) => i.block == ChangeLogBlock.alreadyRestored),
        isTrue,
      );
    });

    test('a restored dive can be deleted again by reverting', () async {
      final result = await service.execute(
        await service.planOperation(await newestOperation()),
      );
      await repository.settleAll();

      await service.execute(await service.planOperation(result.operationId!));

      expect(await count('dives', "id = 'dive'"), 0);
    });
  });

  test('a deleted dive returns with its revision lineage', () async {
    final series = ProfileSeriesRepository();
    final root = await series.insertSeries(
      diveId: 'dive',
      samples: const [ProfileSample(timestamp: 0, depth: 1)],
      now: 1000,
    );
    await series.insertSeries(
      diveId: 'dive',
      parentSeriesId: root,
      revisionKind: 'Edit: profile_editor',
      samples: const [ProfileSample(timestamp: 0, depth: 2)],
      now: 2000,
    );
    final before = await series.getRevisionsForDive('dive');
    await forget();
    await SyncRepository().clearPendingRecords();

    await DiveRepository().deleteDive('dive');
    await service.execute(await service.planOperation(await newestOperation()));

    expect(await series.getRevisionsForDive('dive'), before);
    final pending = await SyncRepository().getPendingRecords();
    expect(
      pending.map((r) => r.entityType),
      isNot(contains('diveProfileSeriesHistory')),
      reason: 'revision lineage is local to this device',
    );
  });

  test('a null with a non-null default comes back null', () async {
    await db.customStatement(
      'INSERT INTO diver_settings (id, diver_id, default_tank_preset, '
      "created_at, updated_at) VALUES ('s1', 'me', NULL, 0, 0)",
    );
    await forget();
    await db.customStatement("DELETE FROM diver_settings WHERE id = 's1'");

    await service.execute(await service.planOperation(await newestOperation()));

    final row = await db
        .customSelect('SELECT default_tank_preset FROM diver_settings')
        .getSingle();
    expect(row.data['default_tank_preset'], isNull);
  });

  test('a restored child with a missing parent is blocked', () async {
    await db.customStatement("DELETE FROM dive_tanks WHERE id = 'tank'");
    final operation = await newestOperation();
    // Outside the window that would group both deletes on this dive.
    await db.customStatement(
      'UPDATE change_log_operations SET ended_at = ended_at - 60000',
    );
    await DiveRepository().deleteDive('dive');
    await repository.settleAll();

    final plan = await service.planOperation(operation);

    expect(plan.items.single.block, ChangeLogBlock.parentGone);
    final result = await service.execute(plan);
    expect(result.reverted, 0);
    expect(result.kept, 1);
  });

  test('an edit back to a deleted parent is blocked', () async {
    await db.customStatement(
      'INSERT INTO dive_sites (id, diver_id, name, created_at, updated_at) '
      "VALUES ('a', 'me', 'A', 0, 0), ('b', 'me', 'B', 0, 0)",
    );
    await db.customStatement("UPDATE dives SET site_id = 'a'");
    await forget();
    await db.customStatement("UPDATE dives SET site_id = 'b'");
    final operation = await newestOperation();
    await db.customStatement("DELETE FROM dive_sites WHERE id = 'a'");
    await repository.settleAll();

    final plan = await service.planOperation(operation);

    expect(plan.items.single.block, ChangeLogBlock.parentGone);
    final result = await service.execute(plan);
    expect(result.kept, 1);
  });

  test('an edit back to a parent restored with it is allowed', () async {
    await db.customStatement(
      'INSERT INTO dive_sites (id, diver_id, name, created_at, updated_at) '
      "VALUES ('a', 'me', 'A', 0, 0), ('b', 'me', 'B', 0, 0)",
    );
    await db.customStatement("UPDATE dives SET site_id = 'a'");
    await forget();

    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.manual,
      body: () async {
        await db.customStatement("UPDATE dives SET site_id = 'b'");
        await db.customStatement("DELETE FROM dive_sites WHERE id = 'a'");
      },
    );
    await service.execute(await service.planOperation(await newestOperation()));

    final row = await db.customSelect('SELECT site_id FROM dives').getSingle();
    expect(row.data['site_id'], 'a');
  });

  test('an edit and a delete in one entry restore the original', () async {
    await db.customStatement(
      "UPDATE dives SET notes = 'Edited' WHERE id = 'dive'",
    );
    await DiveRepository().deleteDive('dive');
    final operation = await newestOperation();

    final plan = await service.planOperation(operation);

    expect(plan.items.where((i) => i.isBlocked), isEmpty);
    await service.execute(plan);
    expect(await count('dives', "id = 'dive' AND notes = 'Calm'"), 1);
  });

  test('two deletes of one record in an entry restore it once', () async {
    await db.customStatement("DELETE FROM dive_tanks WHERE id = 'tank'");
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank', diveId: 'dive'));
    await db.customStatement("UPDATE dive_tanks SET tank_name = 'Later'");
    await db.customStatement("DELETE FROM dive_tanks WHERE id = 'tank'");
    final operation = await newestOperation();

    await service.execute(await service.planOperation(operation));

    expect(await count('dive_tanks', "id = 'tank'"), 1);
  });

  group('undoing a bulk action', () {
    Future<String> importDive() async {
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.import,
        label: 'Perdix',
        body: () async {
          await insertDive(db, 'imported', diverId: 'me');
          await db.customStatement(
            "UPDATE equipment SET name = 'Reg XTX' WHERE id = 'gear'",
          );
        },
      );
      return newestOperation();
    }

    test(
      'undoing an import removes its dives and reverses its edits',
      () async {
        final operation = await importDive();
        await SyncRepository().clearPendingRecords();

        await service.execute(await service.planOperation(operation));

        expect(await count('dives', "id = 'imported'"), 0);
        expect(await count('equipment', "name = 'Reg'"), 1);
        expect(
          await count(
            'deletion_log',
            "entity_type = 'dives' AND record_id = 'imported'",
          ),
          1,
        );
      },
    );

    test('a created child of a created dive goes with it', () async {
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.import,
        body: () async {
          await insertDive(db, 'imported', diverId: 'me');
          await db
              .into(db.diveTanks)
              .insert(
                DiveTanksCompanion.insert(id: 'new-tank', diveId: 'imported'),
              );
        },
      );

      final plan = await service.planOperation(await newestOperation());

      expect(plan.items.where((i) => i.isBlocked), isEmpty);
      await service.execute(plan);
      expect(await count('dive_tanks', "id = 'new-tank'"), 0);
    });

    test('an imported site used by a later dive is kept and listed', () async {
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.import,
        body: () => db.customStatement(
          'INSERT INTO dive_sites (id, diver_id, name, created_at, '
          "updated_at) VALUES ('reef', 'me', 'Reef', 0, 0)",
        ),
      );
      final operation = await newestOperation();
      await db.customStatement("UPDATE dives SET site_id = 'reef'");
      await repository.settleAll();

      final plan = await service.planOperation(operation);

      expect(plan.items.single.block, ChangeLogBlock.inUse);
      final result = await service.execute(plan);
      expect(await count('dive_sites', "id = 'reef'"), 1);
      expect(result.kept, 1);
      expect(result.keptItems.single.event.recordId, 'reef');
    });

    test(
      'imported gear on a later dive is kept and that dive is untouched',
      () async {
        await ChangeLogScope.run(
          db,
          source: ChangeLogSource.import,
          body: () => db.customStatement(
            'INSERT INTO equipment (id, diver_id, name, type, created_at, '
            "updated_at) VALUES ('new-gear', 'me', 'BCD', 'bcd', 0, 0)",
          ),
        );
        final operation = await newestOperation();
        await db.customStatement(
          'INSERT INTO dive_equipment (dive_id, equipment_id) '
          "VALUES ('dive', 'new-gear')",
        );
        await repository.settleAll();

        final plan = await service.planOperation(operation);

        expect(plan.items.single.block, ChangeLogBlock.inUse);
        await service.execute(plan);
        expect(await count('equipment', "id = 'new-gear'"), 1);
        expect(await count('dive_equipment', "equipment_id = 'new-gear'"), 1);
      },
    );

    test('an edited created record is reported as changed since', () async {
      final operation = await importDive();
      await db.customStatement(
        "UPDATE dives SET notes = 'Mine now' WHERE id = 'imported'",
      );
      await repository.settleAll();

      final plan = await service.planOperation(operation);

      final item = plan.items.singleWhere(
        (i) => i.event.recordId == 'imported',
      );
      expect(item.changedSince, isTrue);
      expect(item.block, isNull);
      expect(plan.hasChangedSince, isTrue);
    });

    test(
      'a child added to a created dive later counts as an edit, not use',
      () async {
        final operation = await importDive();
        await db
            .into(db.diveTanks)
            .insert(DiveTanksCompanion.insert(id: 'later', diveId: 'imported'));
        await repository.settleAll();

        final plan = await service.planOperation(operation);

        final item = plan.items.singleWhere(
          (i) => i.event.recordId == 'imported',
        );
        expect(item.changedSince, isTrue);
        expect(item.block, isNull);
      },
    );

    test('includeChangedSince false skips those records', () async {
      final operation = await importDive();
      await db.customStatement(
        "UPDATE dives SET notes = 'Mine now' WHERE id = 'imported'",
      );
      await repository.settleAll();

      final result = await service.execute(
        await service.planOperation(operation),
        includeChangedSince: false,
      );

      expect(await count('dives', "id = 'imported'"), 1);
      expect(await count('equipment', "name = 'Reg'"), 1);
      expect(result.keptItems.map((i) => i.event.recordId), ['imported']);
    });

    test('a skipped dive keeps its children', () async {
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.import,
        body: () async {
          await insertDive(db, 'imported', diverId: 'me');
          await db
              .into(db.diveTanks)
              .insert(
                DiveTanksCompanion.insert(id: 'new-tank', diveId: 'imported'),
              );
        },
      );
      final operation = await newestOperation();
      await db.customStatement(
        "UPDATE dives SET notes = 'Mine now' WHERE id = 'imported'",
      );
      await repository.settleAll();

      await service.execute(
        await service.planOperation(operation),
        includeChangedSince: false,
      );

      expect(await count('dives', "id = 'imported'"), 1);
      expect(await count('dive_tanks', "id = 'new-tank'"), 1);
      expect(
        await count('deletion_log', "record_id = 'new-tank'"),
        0,
        reason: 'a tombstone would take the tank off every other device',
      );
    });

    test('a dive kept because it is in use keeps its children', () async {
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.import,
        body: () async {
          await insertDive(db, 'imported', diverId: 'me');
          await db
              .into(db.diveTanks)
              .insert(
                DiveTanksCompanion.insert(id: 'new-tank', diveId: 'imported'),
              );
        },
      );
      final operation = await newestOperation();
      await db.customStatement(
        'INSERT INTO dive_plans (id, name, linked_dive_id, created_at, '
        "updated_at) VALUES ('plan', 'Plan', 'imported', 0, 0)",
      );
      await repository.settleAll();

      final plan = await service.planOperation(operation);

      expect(plan.items.map((i) => i.block).toSet(), {ChangeLogBlock.inUse});
      await service.execute(plan);
      expect(await count('dive_tanks', "id = 'new-tank'"), 1);
    });

    test('an owned child with no delete action keeps the record', () async {
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.import,
        body: () => db.customStatement(
          'INSERT INTO trips (id, diver_id, name, start_date, end_date, '
          "created_at, updated_at) VALUES ('trip', 'me', 'Red Sea', 0, 0, 0, 0)",
        ),
      );
      final operation = await newestOperation();
      await db.customStatement(
        'INSERT INTO trip_itinerary_days (id, trip_id, day_number, date, '
        "created_at, updated_at) VALUES ('day', 'trip', 1, 0, 0, 0)",
      );
      await repository.settleAll();

      final plan = await service.planOperation(operation);

      expect(plan.items.single.block, ChangeLogBlock.inUse);
      final result = await service.execute(plan);
      expect(result.kept, 1);
      expect(await count('trips', "id = 'trip'"), 1);
    });

    test('a soft reference keeps the record too', () async {
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.import,
        body: () => db.customStatement(
          'INSERT INTO dive_types (id, diver_id, name, created_at, updated_at) '
          "VALUES ('my-wreck', 'me', 'Wreck', 0, 0)",
        ),
      );
      final operation = await newestOperation();
      await db.customStatement(
        'INSERT INTO dive_dive_types (id, dive_id, dive_type_id, created_at) '
        "VALUES ('link', 'dive', 'my-wreck', 0)",
      );
      await repository.settleAll();

      final plan = await service.planOperation(operation);

      expect(plan.items.single.block, ChangeLogBlock.inUse);
    });

    test('a partial undo leaves the entry open to retry', () async {
      final operation = await importDive();
      await db.customStatement(
        "UPDATE dives SET notes = 'Mine now' WHERE id = 'imported'",
      );
      await repository.settleAll();

      await service.execute(
        await service.planOperation(operation),
        includeChangedSince: false,
      );

      expect(
        await count(
          'change_log_operations',
          "id = '$operation' AND reverted_by_id IS NOT NULL",
        ),
        0,
      );
    });

    test('reverting a revert clears the badge on the original', () async {
      final operation = await importDive();
      final result = await service.execute(
        await service.planOperation(operation),
      );
      await repository.settleAll();
      expect(
        await count(
          'change_log_operations',
          "id = '$operation' AND reverted_by_id IS NOT NULL",
        ),
        1,
      );

      await service.execute(await service.planOperation(result.operationId!));

      expect(
        await count(
          'change_log_operations',
          "id = '$operation' AND reverted_by_id IS NOT NULL",
        ),
        0,
      );
    });

    test('a record kept by a skipped dive stays in use', () async {
      await ChangeLogScope.run(
        db,
        source: ChangeLogSource.import,
        body: () async {
          await db.customStatement(
            'INSERT INTO dive_sites (id, diver_id, name, created_at, '
            "updated_at) VALUES ('reef', 'me', 'Reef', 0, 0)",
          );
          await insertDive(db, 'imported', diverId: 'me');
          await db.customStatement(
            "UPDATE dives SET site_id = 'reef' WHERE id = 'imported'",
          );
        },
      );
      final operation = await newestOperation();
      await db.customStatement(
        "UPDATE dives SET notes = 'Mine now' WHERE id = 'imported'",
      );
      await repository.settleAll();

      final plan = await service.planOperation(operation);
      final result = await service.execute(plan, includeChangedSince: false);

      expect(await count('dive_sites', "id = 'reef'"), 1);
      expect(await count('dives', "id = 'imported'"), 1);
      expect(result.keptItems.map((i) => i.event.recordId), contains('reef'));
    });
  });
}
