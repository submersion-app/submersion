import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

const _purple = 0xFFE040FB;

void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: 'ds-pc',
            diverId: 'diver-pc',
            createdAt: now,
            updatedAt: now,
            profileColorPpO2: const Value(_purple),
          ),
        );
  });

  tearDown(() async => tearDownTestDatabase());

  Future<DiverSetting> row() => (db.select(
    db.diverSettings,
  )..where((t) => t.id.equals('ds-pc'))).getSingle();

  test('exports and re-imports a chosen colour', () async {
    final exported = await serializer.fetchRecord('diverSettings', 'ds-pc');
    expect(exported!['profileColorPpO2'], _purple);
    await serializer.upsertRecord('diverSettings', exported);
    expect((await row()).profileColorPpO2, _purple);
  });

  test(
    'a peer without the column (older build) keeps the local colour',
    () async {
      final exported = await serializer.fetchRecord('diverSettings', 'ds-pc');
      final legacy = Map<String, dynamic>.from(exported!)
        ..removeWhere((k, _) => k.startsWith('profileColor'));
      await serializer.upsertRecord('diverSettings', legacy);
      expect((await row()).profileColorPpO2, _purple);
    },
  );

  test('an incoming null (a reset elsewhere) clears the colour', () async {
    final exported = await serializer.fetchRecord('diverSettings', 'ds-pc');
    final reset = Map<String, dynamic>.from(exported!)
      ..['profileColorPpO2'] = null;
    await serializer.upsertRecord('diverSettings', reset);
    expect((await row()).profileColorPpO2, isNull);
  });
}
