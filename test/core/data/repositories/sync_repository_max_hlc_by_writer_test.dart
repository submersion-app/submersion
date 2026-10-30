import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// The per-writer watermark nearby sync exchanges (issue #3731): for every
/// device whose clock appears in this library, the highest clock held from
/// it, across synced tables, media fact clocks and tombstones.
void main() {
  late AppDatabase db;
  late SyncRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory(setup: registerAppSqlFunctions));
    repo = SyncRepository(database: db);
  });
  tearDown(() => db.close());

  String hlc(int ms, String node) =>
      '${ms.toString().padLeft(15, '0')}:000000:$node';

  Future<void> insertTag(String id, String? clock) => db.customStatement(
    'INSERT INTO tags (id, name, created_at, updated_at, hlc) '
    'VALUES (?, ?, 0, 0, ?)',
    [id, 'Tag $id', clock],
  );

  test('groups the highest clock per writer across tables', () async {
    await insertTag('t1', hlc(10, 'aaa'));
    await insertTag('t2', hlc(30, 'aaa'));
    await insertTag('t3', hlc(20, 'bbb'));
    await insertTag('t4', null);
    await db.customStatement(
      'INSERT INTO buddies (id, name, created_at, updated_at, hlc) '
      'VALUES (?, ?, 0, 0, ?)',
      ['b1', 'Sam', hlc(50, 'bbb')],
    );

    expect(await repo.maxRowHlcByWriter(), {
      'aaa': hlc(30, 'aaa'),
      'bbb': hlc(50, 'bbb'),
    });
  });

  test('a tombstone counts under the device that deleted it', () async {
    await insertTag('t1', hlc(10, 'aaa'));
    await db.customStatement(
      'INSERT INTO deletion_log (id, entity_type, record_id, deleted_at, '
      'hlc, origin_hlc) VALUES (?, ?, ?, ?, ?, ?)',
      ['x1', 'tags', 'gone', 1, hlc(90, 'aaa'), hlc(60, 'ccc')],
    );
    await db.customStatement(
      'INSERT INTO deletion_log (id, entity_type, record_id, deleted_at, '
      'hlc) VALUES (?, ?, ?, ?, ?)',
      ['x2', 'tags', 'gone2', 1, hlc(40, 'aaa')],
    );

    expect(await repo.maxRowHlcByWriter(), {
      'aaa': hlc(40, 'aaa'),
      'ccc': hlc(60, 'ccc'),
    });
  });

  test('an empty library has no writers', () async {
    expect(await repo.maxRowHlcByWriter(), isEmpty);
  });

  test('rows of a shared library site never count: they never travel in '
      'personal sync', () async {
    await insertTag('t1', hlc(10, 'aaa'));
    await db.customStatement(
      'INSERT INTO dive_sites (id, name, created_at, updated_at, hlc, '
      'shared_library_id) VALUES (?, ?, 0, 0, ?, ?)',
      ['lib-site', 'Club reef', hlc(70, 'club'), 'lib-1'],
    );
    await db.customStatement(
      'INSERT INTO site_tags (id, site_id, tag_id, created_at, hlc) '
      'VALUES (?, ?, ?, 0, ?)',
      ['st1', 'lib-site', 't1', hlc(80, 'club')],
    );
    expect(await repo.maxRowHlcByWriter(), {'aaa': hlc(10, 'aaa')});
    expect(await repo.minRowHlcForWriter('club'), isNull);
  });
}
