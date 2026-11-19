import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';

/// v26: the displayed shape of each library thumbnail, learned from its
/// decoded image (issue #4738). Never synced or backed up; losing a row costs
/// one re-layout of that tile.

/// A local cache stamped [version] whose earlier tables exist (the backstop
/// creates any that are missing) but which has no shape table.
LocalCacheDatabase _existing(int version) => LocalCacheDatabase(
  NativeDatabase.memory(
    setup: (raw) => raw.execute('PRAGMA user_version = $version'),
  ),
);

Future<List<String>> _columns(LocalCacheDatabase db) async =>
    (await db.customSelect("PRAGMA table_info('media_aspect_cache')").get())
        .map((c) => c.read<String>('name'))
        .toList();

void main() {
  test('the local cache is at least version 26', () {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, greaterThanOrEqualTo(26));
  });

  test('a fresh database has the table', () async {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await _columns(db), [
      'media_id',
      'ratio',
      'width',
      'height',
      'learned_at',
    ]);
  });

  test('a version 25 database gains the table', () async {
    final db = _existing(25);
    addTearDown(db.close);

    await db
        .into(db.mediaAspectCache)
        .insert(
          MediaAspectCacheCompanion.insert(
            mediaId: 'm1',
            ratio: 0.75,
            width: const Value(4000),
            height: const Value(3000),
            learnedAt: 0,
          ),
        );
    expect(await db.select(db.mediaAspectCache).get(), hasLength(1));
  });

  test('a database stamped 26 without the table is healed', () async {
    // A colliding branch's v26 that never created this table.
    final db = _existing(26);
    addTearDown(db.close);

    expect(await _columns(db), contains('ratio'));
  });
}
