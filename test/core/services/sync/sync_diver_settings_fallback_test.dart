import 'package:drift/drift.dart' show Value;
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

  test(
    'applies a pre-v133 diver_settings payload missing deco stop keys',
    () async {
      await db.customStatement('PRAGMA foreign_keys = OFF');

      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.diverSettings)
          .insert(
            DiverSettingsCompanion.insert(
              id: 'ds3',
              diverId: 'diver-3',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final exported = await serializer.fetchRecord('diverSettings', 'ds3');
      expect(exported, isNotNull);

      // A payload exported before v133 has neither key. Both columns are NOT
      // NULL, so an unseeded import would throw in DiverSetting.fromJson.
      final legacy = Map<String, dynamic>.from(exported!)
        ..remove('showDecoStopsOnProfile')
        ..remove('defaultDecoStopSource');

      await (db.delete(
        db.diverSettings,
      )..where((t) => t.id.equals('ds3'))).go();

      // Must not throw on the missing non-nullable columns.
      await serializer.upsertRecord('diverSettings', legacy);

      final row = await (db.select(
        db.diverSettings,
      )..where((t) => t.id.equals('ds3'))).getSingle();
      // The v133 columns hydrate to their defaults rather than throwing.
      expect(row.showDecoStopsOnProfile, isTrue);
      expect(row.defaultDecoStopSource, 1);
    },
  );

  test(
    'applies a pre-v135 diver_settings payload missing color accent keys',
    () async {
      await db.customStatement('PRAGMA foreign_keys = OFF');

      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.diverSettings)
          .insert(
            DiverSettingsCompanion.insert(
              id: 'ds4',
              diverId: 'diver-4',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final exported = await serializer.fetchRecord('diverSettings', 'ds4');
      expect(exported, isNotNull);

      // A payload exported before v135 has none of the accent keys. All three
      // columns are NOT NULL, so an unseeded import would throw.
      final legacy = Map<String, dynamic>.from(exported!)
        ..remove('accentNavIcons')
        ..remove('accentSectionHeaders')
        ..remove('accentListIcons');

      await (db.delete(
        db.diverSettings,
      )..where((t) => t.id.equals('ds4'))).go();

      // Must not throw on the missing non-nullable columns.
      await serializer.upsertRecord('diverSettings', legacy);

      final row = await (db.select(
        db.diverSettings,
      )..where((t) => t.id.equals('ds4'))).getSingle();
      // The v135 columns hydrate to their defaults rather than throwing.
      expect(row.accentNavIcons, isFalse);
      expect(row.accentSectionHeaders, isFalse);
      expect(row.accentListIcons, isFalse);
    },
  );

  test('exports the accent columns so they reach other devices', () async {
    await db.customStatement('PRAGMA foreign_keys = OFF');

    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: 'ds5',
            diverId: 'diver-5',
            createdAt: now,
            updatedAt: now,
            accentNavIcons: const Value(true),
            accentListIcons: const Value(true),
          ),
        );

    final exported = await serializer.fetchRecord('diverSettings', 'ds5');
    expect(exported, isNotNull);
    // Export goes through the generated toJson(), so a new column is only
    // carried if it is really on the table -- assert the values, not just
    // the keys, so a silently-dropped toggle fails here.
    expect(exported!['accentNavIcons'], isTrue);
    expect(exported['accentSectionHeaders'], isFalse);
    expect(exported['accentListIcons'], isTrue);
  });
}
