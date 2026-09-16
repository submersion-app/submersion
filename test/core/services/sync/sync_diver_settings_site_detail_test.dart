import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// The site detail columns (v218) ride the generic diverSettings row, so
/// they reach other devices with no serializer change, and a payload from a
/// peer that predates them still applies.
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  const sectionsJson = '[{"id":"notes","visible":false}]';

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    // A placeholder diver_id need not reference a real diver here.
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertRow(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: id,
            diverId: 'diver-1',
            createdAt: now,
            updatedAt: now,
            siteDetailSections: const Value(sectionsJson),
            siteDetailLayout: const Value('list'),
          ),
        );
  }

  Future<DiverSetting> readRow(String id) =>
      (db.select(db.diverSettings)..where((t) => t.id.equals(id))).getSingle();

  test('both columns export and re-import unchanged', () async {
    await insertRow('ds-218');
    final exported = await serializer.fetchRecord('diverSettings', 'ds-218');
    expect(exported!['siteDetailSections'], sectionsJson);
    expect(exported['siteDetailLayout'], 'list');

    await (db.delete(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-218'))).go();
    await serializer.upsertRecord('diverSettings', exported);

    final row = await readRow('ds-218');
    expect(row.siteDetailSections, sectionsJson);
    expect(row.siteDetailLayout, 'list');
  });

  test('a pre-v218 payload without the columns still applies', () async {
    await insertRow('ds-215');
    final exported = await serializer.fetchRecord('diverSettings', 'ds-215');
    final legacy = Map<String, dynamic>.from(exported!)
      ..remove('siteDetailSections')
      ..remove('siteDetailLayout');
    await (db.delete(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-215'))).go();

    await serializer.upsertRecord('diverSettings', legacy);

    final row = await readRow('ds-215');
    expect(row.siteDetailSections, isNull);
    expect(row.siteDetailLayout, isNull);
  });
}
