import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v388: equipment.catalogue_id and equipment.catalogue_answers, an
/// item's link to its equipment catalogue record and what the diver settled
/// about catalogue records for it (issue #5118). Nullable, never backfilled.
void main() {
  const answers = '{"not":["mares-quad"]}';

  NativeDatabase dbAt(
    int version, {
    required bool withColumns,
    bool withTable = true,
  }) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      if (!withTable) return;
      rawDb.execute(
        'CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY, '
        'name TEXT NOT NULL, type TEXT NOT NULL, '
        'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL'
        "${withColumns ? ', catalogue_id TEXT, catalogue_answers TEXT' : ''})",
      );
      rawDb.execute(
        'INSERT INTO equipment (id, name, type, created_at, updated_at) '
        "VALUES ('e1', 'Perdix', 'computer', 1, 1)",
      );
      if (withColumns) {
        rawDb.execute(
          "UPDATE equipment SET catalogue_id = 'shearwater-perdix-2', "
          "catalogue_answers = '$answers'",
        );
      }
    },
  );

  Future<List<String>> columns(AppDatabase db) async =>
      (await db.customSelect("PRAGMA table_info('equipment')").get())
          .map((row) => row.read<String>('name'))
          .toList();

  test('v388 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(388));
    expect(AppDatabase.migrationVersions, contains(388));
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(388));
  });

  test('upgrading adds the columns and leaves existing rows empty', () async {
    final db = AppDatabase(dbAt(387, withColumns: false));
    addTearDown(db.close);

    expect(
      await columns(db),
      containsAll(['catalogue_id', 'catalogue_answers']),
    );
    final row = await db
        .customSelect('SELECT catalogue_id, catalogue_answers FROM equipment')
        .getSingle();
    expect(row.read<String?>('catalogue_id'), isNull);
    expect(row.read<String?>('catalogue_answers'), isNull);
  });

  test('values already stored are kept', () async {
    final db = AppDatabase(dbAt(387, withColumns: true));
    addTearDown(db.close);

    final row = await db
        .customSelect('SELECT catalogue_id, catalogue_answers FROM equipment')
        .getSingle();
    expect(row.read<String?>('catalogue_id'), 'shearwater-perdix-2');
    expect(row.read<String?>('catalogue_answers'), answers);
  });

  test('a database stamped current without the columns is healed', () async {
    final db = AppDatabase(
      dbAt(AppDatabase.currentSchemaVersion, withColumns: false),
    );
    addTearDown(db.close);

    expect(
      await columns(db),
      containsAll(['catalogue_id', 'catalogue_answers']),
    );
  });
}
