import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// A receiving device on an older schema sends a diver_settings payload that
/// predates v91, so it lacks `defaultShowAscentRateLine` (a NOT NULL column).
/// The fallback map in [SyncDataSerializer] must seed it, otherwise
/// `DiverSetting.fromJson` throws on the missing non-nullable bool.
void main() {
  late SyncDataSerializer serializer;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test(
    'applies a pre-v91 diver_settings payload missing the new field',
    () async {
      // FK enforcement off so a placeholder diver_id needn't reference a real
      // diver -- this row only exercises the settings serialization path.
      await db.customStatement('PRAGMA foreign_keys = OFF');

      // Seed a real settings row, then read it back in the export wire format.
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.diverSettings)
          .insert(
            DiverSettingsCompanion.insert(
              id: 'ds1',
              diverId: 'diver-1',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final exported = await serializer.fetchRecord('diverSettings', 'ds1');
      expect(exported, isNotNull);

      // Simulate the older sender: strip the v91-era keys from the payload.
      final legacy = Map<String, dynamic>.from(exported!)
        ..remove('defaultShowAscentRateLine')
        ..remove('showAscentRateColors')
        ..remove('defaultShowPhotoMarkers');

      // Remove the local row so the upsert is a fresh insert.
      await (db.delete(
        db.diverSettings,
      )..where((t) => t.id.equals('ds1'))).go();

      // Must not throw on the missing non-nullable column.
      await serializer.upsertRecord('diverSettings', legacy);

      final row = await (db.select(
        db.diverSettings,
      )..where((t) => t.id.equals('ds1'))).getSingle();
      // Both fields hydrate to the v91 defaults rather than throwing.
      expect(row.defaultShowAscentRateLine, isFalse);
      expect(row.showAscentRateColors, isFalse);
      // v96 column hydrates to its default rather than throwing.
      expect(row.defaultShowPhotoMarkers, isTrue);
    },
  );

  test(
    'applies a pre-v113 diver_settings payload missing cnsCalculationMethod',
    () async {
      await db.customStatement('PRAGMA foreign_keys = OFF');

      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.diverSettings)
          .insert(
            DiverSettingsCompanion.insert(
              id: 'ds2',
              diverId: 'diver-2',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final exported = await serializer.fetchRecord('diverSettings', 'ds2');
      expect(exported, isNotNull);

      // Simulate an older sender predating v113: strip the CNS method key.
      final legacy = Map<String, dynamic>.from(exported!)
        ..remove('cnsCalculationMethod');

      await (db.delete(
        db.diverSettings,
      )..where((t) => t.id.equals('ds2'))).go();

      // Must not throw on the missing non-nullable TEXT column.
      await serializer.upsertRecord('diverSettings', legacy);

      final row = await (db.select(
        db.diverSettings,
      )..where((t) => t.id.equals('ds2'))).getSingle();
      // The v113 column hydrates to its default rather than throwing.
      expect(row.cnsCalculationMethod, 'shearwater');
    },
  );
}
