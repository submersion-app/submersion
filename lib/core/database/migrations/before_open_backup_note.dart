part of 'app_database_migrations.dart';

/// Drops the note table a restored backup brings into the live database.
///
/// Every backup copy is stamped with a `backup_info` table
/// (lib/features/backup/data/services/backup_note_stamp.dart), and a restore
/// swaps that copy in as the live database. Dropping it on every open, which
/// includes the reopen inside each restore path, means the live database never
/// keeps it, so a raw byte copy taken later (the pre-migration and
/// pre-downgrade safety copies, which bypass the stamp) cannot carry an old
/// note forward. The name is spelled out here because core must not import a
/// feature; test/core/database/backup_note_table_open_test.dart pins it to the
/// stamp's constant.
extension BeforeOpenBackupNote on AppDatabase {
  Future<void> _dropRestoredBackupNoteTable() async {
    try {
      await customStatement('DROP TABLE IF EXISTS backup_info');
    } catch (e, st) {
      // Never block opening the library over a note: the next backup copy
      // drops the table from itself anyway.
      developer.log(
        'beforeOpen: could not drop backup_info',
        error: e,
        stackTrace: st,
      );
    }
  }
}
