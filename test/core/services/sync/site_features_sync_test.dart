import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'site-1',
            name: 'Salt Pier',
            createdAt: 1,
            updatedAt: 1,
          ),
        );
    await db
        .into(db.siteFeatures)
        .insert(
          SiteFeaturesCompanion.insert(
            id: 'f-1',
            siteId: 'site-1',
            type: 'hazard',
            latitude: 12.15,
            longitude: -68.3,
            createdAt: 1,
            updatedAt: 1,
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('siteFeatures export, fetch, upsert, and delete round-trip', () async {
    final record = await serializer.fetchRecord('siteFeatures', 'f-1');
    expect(record, isNotNull);
    expect(record!['type'], 'hazard');

    // Remote edit merges over the local row (LWW payload apply).
    await serializer.upsertRecord('siteFeatures', {
      ...record,
      'name': 'Fire coral patch',
      'updatedAt': 2,
    });
    final merged = await serializer.fetchRecord('siteFeatures', 'f-1');
    expect(merged!['name'], 'Fire coral patch');

    expect(await serializer.recordIdsFor('siteFeatures'), contains('f-1'));

    await serializer.deleteRecord('siteFeatures', 'f-1');
    expect(await serializer.fetchRecord('siteFeatures', 'f-1'), isNull);
  });

  test('the delta export filters on the row own hlc', () async {
    await (db.update(db.siteFeatures)..where((t) => t.id.equals('f-1'))).write(
      const SiteFeaturesCompanion(hlc: Value('2026-08-16T00:00:00.000-0000')),
    );

    Future<int> changesetCount(String? watermark) async {
      final payload = await serializer.exportChangeset(
        deviceId: 'device-1',
        hlcWatermark: watermark,
        deletions: const [],
      );
      return payload.data.siteFeatures.length;
    }

    // A base carries the row; a watermark newer than it excludes it; an
    // older watermark includes it (own-hlc filter, not a parent join).
    expect(await changesetCount(null), 1);
    expect(await changesetCount('2026-08-17T00:00:00.000-0000'), 0);
    expect(await changesetCount('2026-08-15T00:00:00.000-0000'), 1);
  });
}
