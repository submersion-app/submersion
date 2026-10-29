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
