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
        .into(db.wrecks)
        .insert(
          WrecksCompanion.insert(
            id: 'w-1',
            name: 'Hilma Hooker',
            createdAt: 1,
            updatedAt: 1,
            vesselType: const Value('ship'),
          ),
        );
  });

  tearDown(tearDownTestDatabase);

  test('wrecks fetch, upsert, list, and delete round-trip', () async {
    final record = await serializer.fetchRecord('wrecks', 'w-1');
    expect(record, isNotNull);
    expect(record!['name'], 'Hilma Hooker');

    await serializer.upsertRecord('wrecks', {
      ...record,
      'name': 'Hilma',
      'updatedAt': 2,
    });
    expect((await serializer.fetchRecord('wrecks', 'w-1'))!['name'], 'Hilma');

    expect(await serializer.recordIdsFor('wrecks'), contains('w-1'));

    await serializer.deleteRecord('wrecks', 'w-1');
    expect(await serializer.fetchRecord('wrecks', 'w-1'), isNull);
  });

  test('the delta export filters on the row own hlc', () async {
    await (db.update(db.wrecks)..where((t) => t.id.equals('w-1'))).write(
      const WrecksCompanion(hlc: Value('2026-08-17T00:00:00.000-0000')),
    );

    Future<int> count(String? watermark) async {
      final payload = await serializer.exportChangeset(
        deviceId: 'device-1',
        hlcWatermark: watermark,
        deletions: const [],
      );
      return payload.data.wrecks.length;
    }

    // A base carries the row; a newer watermark excludes it; an older one
    // includes it (own-hlc filter, not a parent join).
    expect(await count(null), 1);
    expect(await count('2026-08-18T00:00:00.000-0000'), 0);
    expect(await count('2026-08-16T00:00:00.000-0000'), 1);
  });
}
