import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';

import '../../../helpers/test_database.dart';

/// Issue #4651: a bulk edit of a dive's child rows no longer brings the dive
/// row with it, so a peer applying only the children must still tell the
/// screens that watch `dives` alone (the dive list among them) to refresh.
void main() {
  late AppDatabase db;
  late SyncDataSerializer serializer;

  setUp(() async {
    db = await setUpTestDatabase();
    serializer = SyncDataSerializer();
    await db.customStatement(
      'INSERT INTO dives (id, dive_date_time, created_at, updated_at) '
      "VALUES ('d1', 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at) '
      "VALUES ('tag1', 'Night', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dive_tags (id, dive_id, tag_id, created_at) '
      "VALUES ('dt1', 'd1', 'tag1', 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  /// Counts `dives` ticks while [apply] runs.
  Future<int> divesTicksDuring(Future<void> Function() apply) async {
    await pumpEventQueue();
    var ticks = 0;
    final sub = db
        .tableUpdates(TableUpdateQuery.onTable(db.dives))
        .listen((_) => ticks++);
    addTearDown(sub.cancel);
    await apply();
    await pumpEventQueue();
    return ticks;
  }

  test('a batch of dive child rows ticks dives', () async {
    final row = (await serializer.fetchRecord('diveTags', 'dt1'))!;
    await db.customStatement("DELETE FROM dive_tags WHERE id = 'dt1'");

    final ticks = await divesTicksDuring(
      () => serializer.upsertRecords('diveTags', [row]),
    );

    expect(ticks, greaterThan(0));
  });

  test('a single dive child row ticks dives', () async {
    final row = (await serializer.fetchRecord('diveTags', 'dt1'))!;
    await db.customStatement("DELETE FROM dive_tags WHERE id = 'dt1'");

    final ticks = await divesTicksDuring(
      () => serializer.upsertRecord('diveTags', row),
    );

    expect(ticks, greaterThan(0));
  });

  test('a dive child tombstone ticks dives', () async {
    final ticks = await divesTicksDuring(
      () => serializer.deleteRecord('diveTags', 'dt1'),
    );

    expect(ticks, greaterThan(0));
  });

  // Every member, by its tombstone, so a dropped or misspelt entry fails.
  for (final entity in const [
    'diveTanks',
    'diveWeights',
    'diveTags',
    'diveDiveTypes',
    'diveCourses',
    'diveEquipment',
  ]) {
    test('a $entity tombstone ticks dives', () async {
      expect(
        SyncDataSerializer.diveChildEntitiesThatTickDives,
        contains(entity),
      );
      final ticks = await divesTicksDuring(
        () => serializer.deleteRecord(entity, 'not-here'),
      );

      expect(ticks, greaterThan(0));
    });
  }

  test('rows that are not dive children leave dives quiet', () async {
    final row = (await serializer.fetchRecord('tags', 'tag1'))!;

    final ticks = await divesTicksDuring(
      () => serializer.upsertRecords('tags', [row]),
    );

    expect(ticks, 0);
  });
}
