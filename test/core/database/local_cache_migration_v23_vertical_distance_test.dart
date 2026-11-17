import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';

/// v23: each dive's vertical distance, cached on this device only (issue
/// #4569). Never synced or backed up; every device can work it out again.

/// A local cache stamped [version] whose earlier tables exist (the backstop
/// creates any that are missing) but which has no vertical distance cache.
LocalCacheDatabase _existing(int version) => LocalCacheDatabase(
  NativeDatabase.memory(
    setup: (raw) => raw.execute('PRAGMA user_version = $version'),
  ),
);

Future<List<String>> _columns(LocalCacheDatabase db) async =>
    (await db
            .customSelect("PRAGMA table_info('dive_vertical_distance_cache')")
            .get())
        .map((c) => c.read<String>('name'))
        .toList();

void main() {
  test('the local cache is at least version 23', () {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, greaterThanOrEqualTo(23));
  });

  test('a fresh database has the table', () async {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(await _columns(db), [
      'dive_id',
      'meters',
      'inputs_hash',
      'computed_at',
    ]);
  });

  test('a version 22 database gains the table', () async {
    final db = _existing(22);
    addTearDown(db.close);

    expect(await _columns(db), contains('inputs_hash'));
    await db
        .into(db.diveVerticalDistanceCache)
        .insert(
          DiveVerticalDistanceCacheCompanion.insert(
            diveId: 'd1',
            meters: 20,
            inputsHash: 'h',
            computedAt: 0,
          ),
        );
    expect(await db.select(db.diveVerticalDistanceCache).get(), hasLength(1));
  });

  test('a database stamped 23 without the table is healed', () async {
    // A colliding branch's v23 that never created this table.
    final db = _existing(23);
    addTearDown(db.close);

    expect(await _columns(db), contains('meters'));
  });
}
