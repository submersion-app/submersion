import 'package:drift/drift.dart' show Value, Variable;

import 'package:submersion/core/database/database.dart';

/// Rows a test reads back from the raw log. `old_value` and `new_value`
/// keep their SQLite type, which the generated row class would not.
Future<List<Map<String, Object?>>> logEvents(AppDatabase db) async {
  final rows = await db
      .customSelect('SELECT * FROM change_log_events ORDER BY id')
      .get();
  return [for (final r in rows) r.data];
}

Future<Map<String, (Object?, Object?)>> logFields(
  AppDatabase db,
  int eventId,
) async {
  final rows = await db
      .customSelect(
        'SELECT column_name, old_value, new_value FROM change_log_fields '
        'WHERE event_id = ?',
        variables: [Variable.withInt(eventId)],
      )
      .get();
  return {
    for (final r in rows)
      r.data['column_name']! as String: (
        r.data['old_value'],
        r.data['new_value'],
      ),
  };
}

Future<void> clearLog(AppDatabase db) async {
  await db.customStatement('DELETE FROM change_log_fields');
  await db.customStatement('DELETE FROM change_log_events');
}

Future<void> insertDiver(AppDatabase db, String id) => db
    .into(db.divers)
    .insert(
      DiversCompanion.insert(id: id, name: id, createdAt: 0, updatedAt: 0),
    );

Future<void> insertDive(
  AppDatabase db,
  String id, {
  required String diverId,
  String? notes,
}) => db
    .into(db.dives)
    .insert(
      DivesCompanion.insert(
        id: id,
        diverId: Value(diverId),
        diveDateTime: 1000,
        createdAt: 0,
        updatedAt: 0,
        notes: Value.absentIfNull(notes),
      ),
    );

/// Trigger names and their `sqlite_master` rowids, which change only when a
/// trigger is dropped and created again.
Future<Map<String, int>> installedTriggers(AppDatabase db) async {
  final rows = await db
      .customSelect(
        'SELECT rowid AS r, name FROM sqlite_master '
        "WHERE type = 'trigger' AND substr(name, 1, 15) = 'change_log_trg_'",
      )
      .get();
  return {for (final r in rows) r.read<String>('name'): r.read<int>('r')};
}
