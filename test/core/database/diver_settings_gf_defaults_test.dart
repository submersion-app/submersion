import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../helpers/test_database.dart';

/// A diver_settings row or sync payload that does not name its gradient
/// factors must fall back to the app's own default (AppSettings, GF 50/85,
/// the Medium preset), not to an older 30/70.
void main() {
  late AppDatabase db;
  const defaults = AppSettings();

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<DiverSetting> insertWithoutGf(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: id,
            diverId: 'diver-$id',
            createdAt: now,
            updatedAt: now,
          ),
        );
    return (db.select(
      db.diverSettings,
    )..where((t) => t.id.equals(id))).getSingle();
  }

  test(
    'a row inserted without gradient factors gets the app default',
    () async {
      final row = await insertWithoutGf('ds1');
      expect(row.gfLow, defaults.gfLow);
      expect(row.gfHigh, defaults.gfHigh);
    },
  );

  test(
    'a synced payload without gradient factors gets the app default',
    () async {
      final serializer = SyncDataSerializer();
      await insertWithoutGf('ds2');
      final exported = await serializer.fetchRecord('diverSettings', 'ds2');
      final payload = Map<String, dynamic>.from(exported!)
        ..remove('gfLow')
        ..remove('gfHigh');
      await (db.delete(
        db.diverSettings,
      )..where((t) => t.id.equals('ds2'))).go();

      await serializer.upsertRecord('diverSettings', payload);

      final row = await (db.select(
        db.diverSettings,
      )..where((t) => t.id.equals('ds2'))).getSingle();
      expect(row.gfLow, defaults.gfLow);
      expect(row.gfHigh, defaults.gfHigh);
    },
  );
}
