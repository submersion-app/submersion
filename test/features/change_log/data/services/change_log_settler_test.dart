import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/change_log/change_log_scope.dart';
import 'package:submersion/features/change_log/data/services/change_log_settler.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

Future<List<ChangeLogOperationRow>> _operations(AppDatabase db) async =>
    (db.select(
      db.changeLogOperations,
    )..orderBy([(o) => OrderingTerm.asc(o.startedAt)])).get();

Future<void> _editNotes(AppDatabase db, String notes, {String id = 'dive'}) =>
    db.customStatement("UPDATE dives SET notes = '$notes' WHERE id = '$id'");

/// Rewrites the times of the raw events, oldest first.
Future<void> _stampEvents(AppDatabase db, List<int> times) async {
  final events = await logEvents(db);
  expect(events, hasLength(times.length));
  for (var i = 0; i < times.length; i++) {
    await db.customStatement(
      'UPDATE change_log_events SET changed_at = ? WHERE id = ?',
      [times[i], events[i]['id']],
    );
  }
}

Future<void> _insertSite(AppDatabase db, String id, String name) => db
    .into(db.diveSites)
    .insert(
      DiveSitesCompanion.insert(
        id: id,
        name: name,
        createdAt: 0,
        updatedAt: 0,
        diverId: const Value('diver'),
      ),
    );

void main() {
  late AppDatabase db;
  late ChangeLogSettler settler;

  setUp(() async {
    db = createTestDatabase();
    settler = ChangeLogSettler(db);
    await insertDiver(db, 'diver');
    await insertDive(db, 'dive', diverId: 'diver', notes: 'Calm');
    await clearLog(db);
  });
  tearDown(() => db.close());

  test('two saves within five seconds on one dive are one operation', () async {
    await _editNotes(db, 'One');
    await _editNotes(db, 'Two');
    await _stampEvents(db, [1000, 5000]);

    expect(await settler.settle(), 2);

    final operation = (await _operations(db)).single;
    expect(operation.source, 'manual');
    expect(operation.eventCount, 2);
    expect(operation.startedAt, 1000);
    expect(operation.endedAt, 5000);
    expect(operation.rootTable, 'dives');
    expect(operation.rootId, 'dive');
    expect(operation.diverId, 'diver');
    final events = await logEvents(db);
    expect(events.every((e) => e['settled'] == 1), isTrue);
    expect(events.every((e) => e['operation_id'] == operation.id), isTrue);
    expect(operation.lastEventId, events.last['id']);
  });

  test('a save six seconds later is a new operation', () async {
    await _editNotes(db, 'One');
    await _editNotes(db, 'Two');
    await _stampEvents(db, [1000, 7000]);

    await settler.settle();

    expect(await _operations(db), hasLength(2));
  });

  test('a later settle joins an operation still in its window', () async {
    await _editNotes(db, 'One');
    await _stampEvents(db, [1000]);
    await settler.settle();

    await _editNotes(db, 'Two');
    await db.customStatement(
      'UPDATE change_log_events SET changed_at = 3000 WHERE settled = 0',
    );
    await settler.settle();

    final operation = (await _operations(db)).single;
    expect(operation.eventCount, 2);
    expect(operation.endedAt, 3000);
  });

  test('a backwards clock starts a new operation', () async {
    await _editNotes(db, 'One');
    await _editNotes(db, 'Two');
    await _stampEvents(db, [9000, 1000]);

    await settler.settle();

    final operations = await _operations(db);
    expect(operations, hasLength(2));
    expect(
      operations.first.lastEventId,
      greaterThan(operations.last.lastEventId!),
    );
  });

  test('edits to two dives are two operations', () async {
    await insertDive(db, 'other', diverId: 'diver', notes: 'Flat');
    await clearLog(db);
    await _editNotes(db, 'One');
    await _editNotes(db, 'Two', id: 'other');

    await settler.settle();

    expect(await _operations(db), hasLength(2));
  });

  test('tank and dive edits share the dive as root', () async {
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank', diveId: 'dive'));
    await clearLog(db);

    await db.customStatement(
      "UPDATE dive_tanks SET start_pressure = 200 WHERE id = 'tank'",
    );
    await _editNotes(db, 'One');
    await settler.settle();

    final operation = (await _operations(db)).single;
    expect(operation.rootTable, 'dives');
    expect(operation.rootId, 'dive');
    final events = await logEvents(db);
    expect(events.every((e) => e['root_table'] == 'dives'), isTrue);
    expect(events.every((e) => e['root_id'] == 'dive'), isTrue);
  });

  test('a grandchild walks to the root', () async {
    await db.customStatement(
      "INSERT INTO courses (id, diver_id, name, agency, start_date, "
      "created_at, updated_at) VALUES ('course', 'diver', 'AOW', 'padi', 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO course_requirements (id, course_id, name, kind, '
      'created_at, updated_at) '
      "VALUES ('req', 'course', 'Deep', 'dives', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO course_requirement_dives (id, requirement_id, dive_id, '
      "created_at) VALUES ('link', 'req', 'dive', 0)",
    );
    await clearLog(db);

    await db.customStatement(
      "DELETE FROM course_requirement_dives WHERE id = 'link'",
    );
    await settler.settle();

    final operation = (await _operations(db)).single;
    expect(operation.rootTable, 'courses');
    expect(operation.rootId, 'course');
  });

  test('a row with a null parent column is its own root', () async {
    await db.customStatement(
      "INSERT INTO media (id, file_path, file_type, taken_at, created_at, "
      "updated_at) VALUES ('m1', 'x', 'photo', 0, 0, 0)",
    );

    await settler.settle();

    final operation = (await _operations(db)).single;
    expect(operation.rootTable, 'media');
    expect(operation.rootId, 'm1');
    expect(operation.diverId, isNull);
  });

  test('replace folds into an update', () async {
    await db.customStatement(
      'INSERT OR REPLACE INTO divers (id, name, created_at, updated_at) '
      "VALUES ('other', 'First', 0, 0)",
    );
    await settler.settle();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');

    await db.customStatement(
      'INSERT OR REPLACE INTO divers (id, name, created_at, updated_at) '
      "VALUES ('other', 'Second', 0, 1)",
    );
    await settler.settle();

    final operation = (await _operations(db)).single;
    expect(operation.eventCount, 1);
    final event = (await logEvents(db)).single;
    expect(event['action'], 'U');
    expect(await logFields(db, event['id']! as int), {
      'name': ('First', 'Second'),
    });
  });

  test('a replace that changes nothing leaves nothing', () async {
    await db.customStatement(
      'INSERT OR REPLACE INTO divers (id, name, created_at, updated_at) '
      "VALUES ('other', 'Same', 0, 0)",
    );
    await settler.settle();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');

    await db.customStatement(
      'INSERT OR REPLACE INTO divers (id, name, created_at, updated_at) '
      "VALUES ('other', 'Same', 0, 5)",
    );
    await settler.settle();

    expect(await logEvents(db), isEmpty);
    expect(await _operations(db), isEmpty);
  });

  test('a replace split across batches still folds', () async {
    await db.customStatement(
      'INSERT OR REPLACE INTO divers (id, name, created_at, updated_at) '
      "VALUES ('other', 'First', 0, 0)",
    );
    await settler.settle();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
    await db.customStatement(
      'INSERT OR REPLACE INTO divers (id, name, created_at, updated_at) '
      "VALUES ('other', 'Second', 0, 1)",
    );

    await settler.settle(batch: 1);
    await settler.settle(batch: 1);

    expect((await logEvents(db)).single['action'], 'U');
    expect((await _operations(db)).single.eventCount, 1);
  });

  test('an insert then delete in one operation vanishes', () async {
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.import,
      body: () async {
        await insertDive(db, 'brief', diverId: 'diver');
        await db.customStatement("DELETE FROM dives WHERE id = 'brief'");
      },
    );

    await settler.settle();

    expect(await logEvents(db), isEmpty);
    expect(await _operations(db), isEmpty);
  });

  test('an empty scope leaves no operation', () async {
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.rule,
      body: () async {},
    );

    await settler.settle();

    expect(await _operations(db), isEmpty);
  });

  test('a running scope is kept', () async {
    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.rule,
      body: () async {
        await settler.settle();
        expect(await _operations(db), hasLength(1));
      },
    );
  });

  test('a summary operation is kept', () async {
    await ChangeLogScope.suppressed(
      db,
      label: 'Library restored',
      source: ChangeLogSource.system,
      body: () async {},
    );

    await settler.settle();

    expect(await _operations(db), hasLength(1));
  });

  test('a scoped operation with two roots has no single root', () async {
    await insertDive(db, 'other', diverId: 'diver');
    await clearLog(db);

    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.rule,
      label: 'Tag rule',
      body: () async {
        await _editNotes(db, 'One');
        await _editNotes(db, 'Two', id: 'other');
        await _editNotes(db, 'Three');
      },
    );
    await settler.settle();

    final operation = (await _operations(db)).single;
    expect(operation.eventCount, 3);
    expect(operation.rootTable, isNull);
    expect(operation.rootId, isNull);
    expect(operation.diverId, 'diver');
    final events = await logEvents(db);
    expect(events.map((e) => e['root_id']), ['dive', 'other', 'dive']);
  });

  test('a scope that touches two divers splits by owner', () async {
    await insertDiver(db, 'second');
    await insertDive(db, 'theirs', diverId: 'second');
    await clearLog(db);

    await ChangeLogScope.run(
      db,
      source: ChangeLogSource.sync,
      deviceId: 'peer',
      body: () async {
        await _editNotes(db, 'Mine');
        await _editNotes(db, 'Theirs', id: 'theirs');
      },
    );
    await settler.settle();

    final operations = await _operations(db);
    expect(operations.map((o) => o.diverId).toSet(), {'diver', 'second'});
    expect(operations.every((o) => o.source == 'sync'), isTrue);
    expect(operations.every((o) => o.deviceId == 'peer'), isTrue);
    expect(operations.every((o) => o.eventCount == 1), isTrue);
  });

  test('owner survives the root being deleted', () async {
    await db.customStatement("DELETE FROM dives WHERE id = 'dive'");

    await settler.settle();

    final operation = (await _operations(db)).single;
    expect(operation.diverId, 'diver');
    expect(operation.rootId, 'dive');
  });

  test('labels survive the root being deleted', () async {
    await _insertSite(db, 'site', 'Blue Hole');
    await db.customStatement(
      "UPDATE dives SET site_id = 'site', dive_number = 412 WHERE id = 'dive'",
    );
    await clearLog(db);

    await db.customStatement("DELETE FROM dives WHERE id = 'dive'");
    await db.customStatement("DELETE FROM dive_sites WHERE id = 'site'");
    await settler.settle();

    final dive = (await _operations(
      db,
    )).firstWhere((o) => o.rootTable == 'dives');
    expect(dive.rootLabel, 'Blue Hole');
    expect(dive.rootOrdinal, 412);
    final site = (await _operations(
      db,
    )).firstWhere((o) => o.rootTable == 'dive_sites');
    expect(site.rootLabel, 'Blue Hole');
  });

  test('a settings key record settles', () async {
    await db.customStatement(
      'INSERT INTO settings (key, value, updated_at) '
      "VALUES ('share_new_records_by_default', 'true', 0)",
    );

    await settler.settle();

    final operation = (await _operations(db)).single;
    expect(operation.rootTable, 'settings');
    expect(operation.rootId, 'share_new_records_by_default');
    expect(operation.diverId, isNull);
  });

  test('a composite key record finds its root', () async {
    await db.customStatement(
      'INSERT INTO equipment (id, diver_id, name, type, created_at, '
      "updated_at) VALUES ('gear', 'diver', 'Reg', 'regulator', 0, 0)",
    );
    await clearLog(db);

    await db.customStatement(
      "INSERT INTO dive_equipment (dive_id, equipment_id) VALUES ('dive', 'gear')",
    );
    await settler.settle();

    final operation = (await _operations(db)).single;
    expect(operation.rootTable, 'dives');
    expect(operation.rootId, 'dive');
    expect(operation.diverId, 'diver');
  });

  test('a machine row deleted while its dive lives leaves nothing', () async {
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank', diveId: 'dive'));
    await db.customStatement(
      'INSERT INTO tide_records (id, dive_id, height_meters, tide_state, '
      "created_at) VALUES ('tide', 'dive', 1.0, 'rising', 0)",
    );
    await settler.settle();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');

    await db.customStatement("DELETE FROM tide_records WHERE id = 'tide'");
    await settler.settle();

    expect(await logEvents(db), isEmpty);
    expect(await _operations(db), isEmpty);
  });

  test('a deleted dive keeps its machine rows', () async {
    await db.customStatement(
      'INSERT INTO tide_records (id, dive_id, height_meters, tide_state, '
      "created_at) VALUES ('tide', 'dive', 1.0, 'rising', 0)",
    );
    await clearLog(db);

    await db.customStatement("DELETE FROM dives WHERE id = 'dive'");
    await settler.settle();

    final operation = (await _operations(db)).single;
    expect(operation.rootId, 'dive');
    expect(
      (await logEvents(db)).map((e) => e['table_name']),
      containsAll(['dives', 'tide_records']),
    );
  });

  test('settling is resumable after a batch limit', () async {
    await _editNotes(db, 'One');
    await _editNotes(db, 'Two');
    await _editNotes(db, 'Three');
    await _stampEvents(db, [1000, 2000, 3000]);

    expect(await settler.settle(batch: 2), 2);
    expect((await _operations(db)).single.eventCount, 2);
    expect(await settler.settle(batch: 2), 1);
    expect((await _operations(db)).single.eventCount, 3);
    expect(await settler.settle(batch: 2), 0);
  });

  test('a settle tells watchers the operations changed', () async {
    final seen = db
        .select(db.changeLogOperations)
        .watch()
        .where((rows) => rows.isNotEmpty)
        .first;
    await _editNotes(db, 'One');

    await settler.settle();

    expect(await seen.timeout(const Duration(seconds: 5)), hasLength(1));
  });

  test('a null operation pointer to a pruned row files as manual', () async {
    await db.customStatement('''
      INSERT INTO change_log_events
        (operation_id, table_name, record_id, action, changed_at, schema_version)
      VALUES ('gone', 'dives', 'dive', 'U', 1000, 1)
    ''');

    await settler.settle();

    expect((await _operations(db)).single.source, 'manual');
  });
}
