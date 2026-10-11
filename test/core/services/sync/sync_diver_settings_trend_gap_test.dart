import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// A peer still on v280 exports no trend_gap_collapse_months. The column
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

  test('applies a pre-v281 payload missing the trend gap threshold', () async {
    await db.customStatement('PRAGMA foreign_keys = OFF');
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diverSettings)
        .insert(
          DiverSettingsCompanion.insert(
            id: 'ds-tg',
            diverId: 'diver-tg',
            createdAt: now,
            updatedAt: now,
          ),
        );
    final exported = await serializer.fetchRecord('diverSettings', 'ds-tg');
    expect(exported, isNotNull);
    expect(exported!['trendGapCollapseMonths'], 12);

    final legacy = Map<String, dynamic>.from(exported)
      ..remove('trendGapCollapseMonths');
    await (db.delete(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-tg'))).go();

    await serializer.upsertRecord('diverSettings', legacy);

    final row = await (db.select(
      db.diverSettings,
    )..where((t) => t.id.equals('ds-tg'))).getSingle();
    expect(row.trendGapCollapseMonths, 12);
  });
}
