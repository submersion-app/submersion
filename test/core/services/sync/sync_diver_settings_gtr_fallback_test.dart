import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// A peer still on v176 exports no GTR columns. They are NOT NULL, so an
/// unseeded import would throw in DiverSetting.fromJson.
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
    'applies a pre-v177 diver_settings payload missing the GTR columns',
    () async {
      await db.customStatement('PRAGMA foreign_keys = OFF');

      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.diverSettings)
          .insert(
            DiverSettingsCompanion.insert(
              id: 'ds-gtr',
              diverId: 'diver-gtr',
              createdAt: now,
              updatedAt: now,
            ),
          );
      final exported = await serializer.fetchRecord('diverSettings', 'ds-gtr');
      expect(exported, isNotNull);

      final legacy = Map<String, dynamic>.from(exported!)
        ..remove('defaultShowGtr')
        ..remove('defaultGtrSource')
        ..remove('gtrReservePressure');

      await (db.delete(
        db.diverSettings,
      )..where((t) => t.id.equals('ds-gtr'))).go();

      await serializer.upsertRecord('diverSettings', legacy);

      final row = await (db.select(
        db.diverSettings,
      )..where((t) => t.id.equals('ds-gtr'))).getSingle();
      expect(row.defaultShowGtr, isFalse);
      expect(
        MetricDataSource.fromInt(row.defaultGtrSource),
        MetricDataSource.calculated,
      );
      expect(row.gtrReservePressure, 50.0);
    },
  );
}
