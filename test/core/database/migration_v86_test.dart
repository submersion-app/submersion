import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  Future<Set<String>> cols(AppDatabase db, String table) async {
    final rows = await db.customSelect("PRAGMA table_info('$table')").get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('v86 schema has hlc on deletion_log', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await cols(db, 'deletion_log'), contains('hlc'));
  });

  test(
    'v85 -> v86 adds hlc to deletion_log and backfills existing tombstones',
    () async {
      final native = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 85');
          rawDb.execute(
            'CREATE TABLE deletion_log ('
            'id TEXT NOT NULL PRIMARY KEY, '
            'entity_type TEXT NOT NULL, '
            'record_id TEXT NOT NULL, '
            'deleted_at INTEGER NOT NULL)',
          );
          rawDb.execute(
            'INSERT INTO deletion_log (id, entity_type, record_id, deleted_at) '
            "VALUES ('t1', 'dives', 'd1', 123)",
          );
        },
      );
      final db = AppDatabase(native);
      addTearDown(db.close);
      await db
          .customSelect('SELECT 1')
          .get(); // force the upgrade ladder to run

      expect(await cols(db, 'deletion_log'), contains('hlc'));

      final hlc =
          (await db
                  .customSelect("SELECT hlc FROM deletion_log WHERE id = 't1'")
                  .getSingle())
              .read<String?>('hlc');
      expect(
        hlc,
        isNotNull,
        reason: 'a legacy tombstone must be backfilled, never left null',
      );
      expect(
        hlc!.compareTo('000000000000001:000000:a'),
        lessThan(0),
        reason:
            'the backfill sentinel must sort below any real (post-epoch) hlc so '
            'legacy tombstones are treated as already-published and excluded '
            'from incremental changesets',
      );
    },
  );
}
