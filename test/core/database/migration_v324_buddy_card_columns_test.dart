import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v324: buddy card swap columns (issue #3728). Buddies gain the
/// card's id, social handle and experience figures with the day the card
/// arrived; certifications record the card that made them; divers gain a
/// social handle and their share choices.
void main() {
  const expected = {
    'buddies': [
      'card_id',
      'social_handle',
      'card_dive_count',
      'card_diving_since',
      'card_last_dive',
      'card_received_at',
    ],
    'certifications': ['card_id'],
    'divers': ['social_handle', 'buddy_card_share'],
  };

  NativeDatabase dbAt(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL)',
      );
      rawDb.execute(
        'CREATE TABLE buddies (id TEXT NOT NULL PRIMARY KEY, '
        'name TEXT NOT NULL)',
      );
      rawDb.execute(
        'CREATE TABLE certifications (id TEXT NOT NULL PRIMARY KEY, '
        'name TEXT NOT NULL, agency TEXT NOT NULL)',
      );
    },
  );

  Future<Set<String>> columnsOf(AppDatabase db, String table) async =>
      (await db.customSelect("PRAGMA table_info('$table')").get())
          .map((c) => c.read<String>('name'))
          .toSet();

  test('v324 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(324));
    expect(AppDatabase.migrationVersions, contains(324));
    expect(
      AppDatabase.migrationStepCount(323),
      AppDatabase.migrationStepCount(324) + 1,
    );
  });

  test('the columns are additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(324));
  });

  test('upgrading from v323 adds every buddy card column', () async {
    final db = AppDatabase(dbAt(323));
    addTearDown(db.close);
    for (final entry in expected.entries) {
      expect(
        await columnsOf(db, entry.key),
        containsAll(entry.value),
        reason: entry.key,
      );
    }
  });

  test('beforeOpen heals a database already at v324 that lacks them', () async {
    final db = AppDatabase(dbAt(324));
    addTearDown(db.close);
    for (final entry in expected.entries) {
      expect(
        await columnsOf(db, entry.key),
        containsAll(entry.value),
        reason: entry.key,
      );
    }
  });
}
