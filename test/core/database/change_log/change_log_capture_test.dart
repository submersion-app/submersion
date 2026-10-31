import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

import '../../../helpers/test_database.dart';
import 'change_log_support.dart';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = createTestDatabase();
    await insertDiver(db, 'diver');
    await insertDive(db, 'dive', diverId: 'diver', notes: 'Calm');
    await clearLog(db);
  });
  tearDown(() => db.close());

  test('a field edit logs one event and only that field', () async {
    await db.customStatement(
      "UPDATE dives SET notes = 'Current', updated_at = 9 WHERE id = 'dive'",
    );

    final events = await logEvents(db);
    expect(events, hasLength(1));
    expect(events.single['table_name'], 'dives');
    expect(events.single['record_id'], 'dive');
    expect(events.single['action'], 'U');
    expect(events.single['operation_id'], isNull);
    expect(events.single['schema_version'], AppDatabase.currentSchemaVersion);
    expect(events.single['changed_at'], greaterThan(1600000000000));
    expect(await logFields(db, events.single['id']! as int), {
      'notes': ('Calm', 'Current'),
    });
  });

  test('two changed fields are two rows on one event', () async {
    await db.customStatement(
      "UPDATE dives SET notes = 'Current', max_depth = 31.5 "
      "WHERE id = 'dive'",
    );

    final events = await logEvents(db);
    expect(events, hasLength(1));
    expect(await logFields(db, events.single['id']! as int), {
      'notes': ('Calm', 'Current'),
      'max_depth': (null, 31.5),
    });
  });

  test('a write that changes only hlc or updated_at logs nothing', () async {
    await db.customStatement(
      "UPDATE dives SET hlc = 'clock', updated_at = 9 WHERE id = 'dive'",
    );

    expect(await logEvents(db), isEmpty);
  });

  test('a save of identical values logs nothing', () async {
    await db.customStatement(
      "UPDATE dives SET notes = 'Calm' WHERE id = 'dive'",
    );

    expect(await logEvents(db), isEmpty);
  });

  test('a delete keeps every non-null column', () async {
    await db.customStatement(
      "UPDATE dives SET hlc = 'clock' WHERE id = 'dive'",
    );
    final row = await db
        .customSelect("SELECT * FROM dives WHERE id = 'dive'")
        .getSingle();
    final expected = {
      for (final entry in row.data.entries)
        if (entry.value != null && entry.key != 'hlc') entry.key,
    };

    await db.customStatement("DELETE FROM dives WHERE id = 'dive'");

    final event = (await logEvents(db)).last;
    expect(event['action'], 'D');
    final fields = await logFields(db, event['id']! as int);
    expect(fields.keys.toSet(), expected);
    expect(fields['notes'], ('Calm', null));
    expect(fields['created_at'], (0, null));
  });

  test('deleting a dive logs its cascaded children', () async {
    await db.customStatement(
      'INSERT INTO dive_weights (id, dive_id, weight_type, amount_kg, '
      "created_at) VALUES ('w1', 'dive', 'belt', 4.0, 0)",
    );
    await clearLog(db);

    await db.customStatement("DELETE FROM dives WHERE id = 'dive'");

    final events = await logEvents(db);
    expect(
      events.map((e) => '${e['table_name']}:${e['action']}'),
      containsAll(['dives:D', 'dive_weights:D']),
    );
  });

  test('INSERT OR REPLACE logs a delete and an insert', () async {
    await db.customStatement(
      'INSERT OR REPLACE INTO divers (id, name, created_at, updated_at) '
      "VALUES ('other', 'First', 0, 0)",
    );
    await clearLog(db);

    await db.customStatement(
      'INSERT OR REPLACE INTO divers (id, name, created_at, updated_at) '
      "VALUES ('other', 'Second', 0, 1)",
    );

    final events = await logEvents(db);
    expect(events.map((e) => e['action']), ['D', 'I']);
    expect(events.first['record_id'], 'other');
    final fields = await logFields(db, events.first['id']! as int);
    expect(fields['name'], ('First', null));
  });

  test('an insert logs an event with no fields', () async {
    await insertDive(db, 'second', diverId: 'diver');

    final events = await logEvents(db);
    expect(events.single['action'], 'I');
    expect(await logFields(db, events.single['id']! as int), isEmpty);
  });

  test('a composite key record logs under the joined id', () async {
    await db.customStatement(
      'INSERT INTO equipment (id, diver_id, name, type, created_at, '
      "updated_at) VALUES ('gear', 'diver', 'Reg', 'regulator', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO dive_equipment (dive_id, equipment_id) VALUES ('dive', 'gear')",
    );

    expect((await logEvents(db)).last['record_id'], 'dive|gear');
  });

  test('a settings key record logs under its key', () async {
    await db.customStatement(
      'INSERT INTO settings (key, value, updated_at) '
      "VALUES ('share_new_records_by_default', 'true', 0)",
    );

    expect(
      (await logEvents(db)).single['record_id'],
      'share_new_records_by_default',
    );
  });

  test('a device-local settings key logs nothing', () async {
    await db.customStatement(
      'INSERT INTO settings (key, value, updated_at) '
      "VALUES ('active_diver_id', 'diver', 0)",
    );
    await db.customStatement(
      "UPDATE settings SET value = 'other' WHERE key = 'active_diver_id'",
    );
    await db.customStatement(
      "DELETE FROM settings WHERE key = 'active_diver_id'",
    );

    expect(await logEvents(db), isEmpty);
  });

  test('a suppressed window logs nothing', () async {
    final until = DateTime.now().millisecondsSinceEpoch + 60000;
    await db.customStatement(
      'UPDATE change_log_context SET suppressed_until = $until',
    );

    await db.customStatement(
      "UPDATE dives SET notes = 'Hidden' WHERE id = 'dive'",
    );
    await db.customStatement("DELETE FROM dives WHERE id = 'dive'");

    expect(await logEvents(db), isEmpty);
  });

  test('an expired suppression logs again', () async {
    await db.customStatement(
      'UPDATE change_log_context SET suppressed_until = 1',
    );

    await db.customStatement(
      "UPDATE dives SET notes = 'Seen' WHERE id = 'dive'",
    );

    expect(await logEvents(db), hasLength(1));
  });

  test('a trigger leaves the caller\'s row count and rowid alone', () async {
    final updated = await db.customUpdate(
      "UPDATE dives SET notes = 'Counted' WHERE id = 'dive'",
    );

    expect(updated, 1);
  });
}
