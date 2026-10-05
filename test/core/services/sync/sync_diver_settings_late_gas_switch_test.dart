import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// A peer still on v263 exports no default_show_late_gas_switches. The column
/// is NOT NULL, so an unseeded import would throw in DiverSetting.fromJson.
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

  test('applies a pre-v264 payload missing the late switch default', () async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: 'ds-lgs',
            diverId: 'diver-lgs',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final exported = await serializer.fetchRecord('diverSettings', 'ds-lgs');
    expect(exported, isNotNull);
    expect(exported!['defaultShowLateGasSwitches'], isTrue);

    final legacy = Map<String, dynamic>.from(exported)
      ..remove('defaultShowLateGasSwitches');
    await (db.delete(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-lgs'))).go();

    await serializer.upsertRecord('diverSettings', legacy);

    final row = await (db.select(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-lgs'))).getSingle();
    expect(row.defaultShowLateGasSwitches, isTrue);
  });
}
