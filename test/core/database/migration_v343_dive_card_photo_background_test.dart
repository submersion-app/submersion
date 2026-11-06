import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v343: diver_settings gains show_photo_background_on_dive_cards, off
/// for every existing diver so dive cards look as they did until the diver
/// turns the switch on.
void main() {
  NativeDatabase dbAt(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL)',
      );
      rawDb.execute(
        "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  test('v343 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(343));
    expect(AppDatabase.migrationVersions, contains(343));
    expect(
      AppDatabase.migrationStepCount(342),
      AppDatabase.migrationStepCount(343) + 1,
    );
  });

  test('the column is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(343));
  });

  test(
    'upgrading from v342 leaves the switch off for an existing diver',
    () async {
      final db = AppDatabase(dbAt(342));
      addTearDown(db.close);
      final row = await db
          .customSelect(
            'SELECT show_photo_background_on_dive_cards FROM diver_settings',
          )
          .getSingle();
      expect(row.read<bool>('show_photo_background_on_dive_cards'), isFalse);
    },
  );

  test('upgrading from v342 gives both overlays the default opacity', () async {
    final db = AppDatabase(dbAt(342));
    addTearDown(db.close);
    final row = await db
        .customSelect(
          'SELECT card_photo_overlay_dark, card_photo_overlay_light '
          'FROM diver_settings',
        )
        .getSingle();
    expect(row.read<double>('card_photo_overlay_dark'), 0.6);
    expect(row.read<double>('card_photo_overlay_light'), 0.6);
  });

  test('beforeOpen heals a database already at v343 that lacks it', () async {
    final db = AppDatabase(dbAt(343));
    addTearDown(db.close);
    final columns =
        (await db.customSelect("PRAGMA table_info('diver_settings')").get())
            .map((c) => c.read<String>('name'))
            .toSet();
    expect(
      columns,
      containsAll([
        'show_photo_background_on_dive_cards',
        'card_photo_overlay_dark',
        'card_photo_overlay_light',
      ]),
    );
  });
}
