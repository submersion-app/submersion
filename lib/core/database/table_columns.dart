import 'package:drift/drift.dart';

/// The names of [table]'s columns as the database holds them right now;
/// empty when the table is absent.
Future<Set<String>> tableColumnNames(
  DatabaseConnectionUser db,
  String table,
) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return {for (final row in rows) row.read<String>('name')};
}

/// Adds [column] to [table] as [ddl], where a column already there is not
/// an error: the race [dropColumnIfStillPresent] describes, the other way.
Future<void> addColumnIfStillMissing(
  DatabaseConnectionUser db,
  String table,
  String column,
  String ddl,
) async {
  try {
    await db.customStatement('ALTER TABLE $table ADD COLUMN $column $ddl');
  } catch (e) {
    if (!e.toString().contains('duplicate column name')) rethrow;
  }
}

/// Drops [column] from [table], where a column already gone is not an
/// error. The UI and Workmanager isolates open the database at once and
/// migrations take no lock across them, so both can read the column as
/// present and race to drop it: the loser must not fail its open.
Future<void> dropColumnIfStillPresent(
  DatabaseConnectionUser db,
  String table,
  String column,
) async {
  try {
    await db.customStatement('ALTER TABLE $table DROP COLUMN $column');
  } catch (e) {
    if (!e.toString().contains('no such column')) rethrow;
  }
}
