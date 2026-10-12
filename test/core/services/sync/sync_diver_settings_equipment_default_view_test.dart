import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// The default equipment view syncs as a nullable JSON column (#2628); a
/// peer still before v286 exports no such key.
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insert(String? statuses) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: 'ds-ev',
            diverId: 'diver-ev',
            createdAt: now,
            updatedAt: now,
          ).copyWith(equipmentDefaultStatuses: Value(statuses)),
        );
  }

  Future<void> reimport(Map<String, dynamic> record) async {
    await (db.delete(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-ev'))).go();
    await serializer.upsertRecord('diverSettings', record);
  }

  Future<String?> storedStatuses() async => (await (db.select(
    db.diverSettings,
  )..where((t) => t.id.equals('ds-ev'))).getSingle()).equipmentDefaultStatuses;

  test('a custom default view is exported and applied', () async {
    await insert('["active"]');
    final exported = await serializer.fetchRecord('diverSettings', 'ds-ev');
    expect(exported!['equipmentDefaultStatuses'], '["active"]');
    await reimport(exported);
    expect(await storedStatuses(), '["active"]');
  });

  test('a pre-v286 payload without the key applies as null', () async {
    await insert(null);
    final exported = await serializer.fetchRecord('diverSettings', 'ds-ev');
    await reimport(
      Map<String, dynamic>.from(exported!)..remove('equipmentDefaultStatuses'),
    );
    expect(await storedStatuses(), isNull);
  });
}
