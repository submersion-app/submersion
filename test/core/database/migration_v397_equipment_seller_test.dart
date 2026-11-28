import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v397: `equipment.seller_buddy_id` and
/// `equipment.seller_dive_center_id`, who sold a gear item (issue #5140).
/// Nullable, no backfill, so the floor holds and an existing item keeps its
/// typed retailer with no link.
void main() {
  NativeDatabase dbAt(int version, {bool withColumns = false}) {
    final extra = withColumns
        ? ', seller_buddy_id TEXT, seller_dive_center_id TEXT'
        : '';
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $version');
        rawDb.execute(
          'CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY, '
          'name TEXT NOT NULL$extra)',
        );
        if (withColumns) {
          rawDb.execute(
            'INSERT INTO equipment (id, name, seller_buddy_id) '
            "VALUES ('e1', 'Reg', 'b1')",
          );
        } else {
          rawDb.execute(
            "INSERT INTO equipment (id, name) VALUES ('e1', 'Reg')",
          );
        }
      },
    );
  }

  Future<Map<String, Object?>> stored(AppDatabase db) async =>
      (await db
              .customSelect(
                'SELECT seller_buddy_id, seller_dive_center_id FROM equipment',
              )
              .getSingle())
          .data;

  test('v397 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(397));
    expect(AppDatabase.migrationVersions, contains(397));
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(397));
  });

  test(
    'upgrading from v396 leaves an existing item with no seller link',
    () async {
      final db = AppDatabase(dbAt(396));
      addTearDown(db.close);
      expect(await stored(db), {
        'seller_buddy_id': null,
        'seller_dive_center_id': null,
      });
    },
  );

  test('a database already carrying the columns keeps its links', () async {
    final db = AppDatabase(dbAt(396, withColumns: true));
    addTearDown(db.close);
    expect(await stored(db), {
      'seller_buddy_id': 'b1',
      'seller_dive_center_id': null,
    });
  });
}
