import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/held_media_export.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v390: the device-local `held_media` table, the media this device
/// keeps back from older devices (issue #5122). Never synced, so the floor
/// holds.
void main() {
  NativeDatabase dbAt(int version) => NativeDatabase.memory(
    setup: (rawDb) => rawDb.execute('PRAGMA user_version = $version'),
  );

  Future<bool> hasHeldMedia(AppDatabase db) async {
    final rows = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'held_media'",
        )
        .get();
    return rows.isNotEmpty;
  }

  test('v390 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(390));
    expect(AppDatabase.migrationVersions, contains(390));
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(390));
    expect(heldMediaSchemaVersion, 390);
  });

  test('upgrading from v389 adds an empty held_media table', () async {
    final db = AppDatabase(dbAt(389));
    addTearDown(db.close);

    expect(await hasHeldMedia(db), isTrue);
    expect(await db.select(db.heldMedia).get(), isEmpty);
  });

  test(
    'a database already at v390 gets the table back from beforeOpen',
    () async {
      final db = AppDatabase(dbAt(390));
      addTearDown(db.close);

      expect(await hasHeldMedia(db), isTrue);
    },
  );
}
