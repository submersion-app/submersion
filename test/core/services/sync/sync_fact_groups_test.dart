import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/sync/sync_fact_groups.dart';

import '../../../helpers/test_database.dart';

void main() {
  group('registry', () {
    test('media declares an upload and a verification group', () {
      expect(SyncFactGroups.of('media').map((g) => g.name), [
        'upload',
        'verification',
      ]);
      expect(SyncFactGroups.of('dives'), isEmpty);
    });

    test('every declared column and clock exists on the table', () async {
      final db = await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);
      final media = db.allTables.firstWhere(
        (t) => t.actualTableName == 'media',
      );
      final sqlNames = media.$columns.map((c) => c.name).toSet();
      for (final g in SyncFactGroups.of('media')) {
        expect(sqlNames, contains(g.clockColumn), reason: g.name);
        expect(sqlNames, containsAll(g.columns.values), reason: g.name);
      }
    });

    test('the JSON keys match the synced row', () async {
      final db = await setUpTestDatabase();
      addTearDown(tearDownTestDatabase);
      await db.customStatement(
        "INSERT INTO media (id, file_path, created_at, updated_at) "
        "VALUES ('m1', '/x.jpg', 0, 0)",
      );
      final row = (await db.select(db.media).getSingle()).toJson();
      for (final g in SyncFactGroups.of('media')) {
        expect(row.keys, contains(g.clockKey), reason: g.name);
        expect(row.keys, containsAll(g.columns.keys), reason: g.name);
      }
    });

    test('no column belongs to two groups', () {
      final all = [
        for (final g in SyncFactGroups.of('media')) ...g.columns.keys,
      ];
      expect(all.toSet().length, all.length);
    });
  });
}
