import 'package:submersion/core/database/database.dart';

/// Every `table.column` in the live schema that references [parent] with
/// neither ON DELETE CASCADE nor ON DELETE SET NULL, sorted.
///
/// Under `PRAGMA foreign_keys = ON` each of these fails the delete of any
/// [parent] row a row of it points at with SqliteException(787), so a delete
/// path has to clear or remove them first. Guard tests compare this against
/// the references their delete handles, so a new column fails the test
/// rather than the user's delete.
Future<List<String>> blockingReferencesTo(AppDatabase db, String parent) async {
  final tables = await db
      .customSelect(
        "SELECT name FROM sqlite_master WHERE type = 'table' "
        "AND name NOT LIKE 'sqlite_%'",
      )
      .get();
  final blocking = <String>[];
  for (final row in tables) {
    final table = row.read<String>('name');
    final keys = await db
        .customSelect("PRAGMA foreign_key_list('$table')")
        .get();
    for (final k in keys) {
      final action = k.read<String>('on_delete').toUpperCase();
      if (k.read<String>('table') == parent &&
          action != 'CASCADE' &&
          action != 'SET NULL') {
        blocking.add('$table.${k.read<String>('from')}');
      }
    }
  }
  return blocking..sort();
}
