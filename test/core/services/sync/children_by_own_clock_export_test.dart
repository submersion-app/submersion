import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// Nearby sync has no changeset log: a child edit already published to the
/// cloud has lost its pending mark by the time two devices meet. With
/// `childrenByOwnClock` the export also selects parent-gated children whose
/// own clock is above the watermark (issue #3731).
void main() {
  late SyncDataSerializer serializer;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
  });
  tearDown(tearDownTestDatabase);

  String hlc(int ms, String node) =>
      '${ms.toString().padLeft(15, '0')}:000000:$node';

  /// A synced dive with two tanks and a gear link; nothing pending. Returns
  /// the dive's own clock, the watermark a peer already holds.
  Future<String> seed() async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('e1', 'Wing', 'bcd', 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO dive_tanks (id, dive_id, hlc) '
      "VALUES ('t1', 'd1', ?), ('t2', 'd1', ?)",
      [hlc(1, 'old'), hlc(1, 'old')],
    );
    await db.customStatement(
      'INSERT INTO dive_equipment (dive_id, equipment_id, hlc) '
      "VALUES ('d1', 'e1', ?)",
      [hlc(1, 'old')],
    );
    final dive = await serializer.fetchRecord('dives', 'd1');
    await SyncRepository().clearAllSyncRecords();
    return dive!['hlc'] as String;
  }

  Future<SyncData> export(String watermark, {required bool byOwnClock}) async {
    final payload = await serializer.exportChangeset(
      deviceId: 'me',
      hlcWatermark: watermark,
      deletions: const [],
      childrenByOwnClock: byOwnClock,
    );
    return payload.data;
  }

  test('a tank edited after the watermark travels without its dive', () async {
    final watermark = await seed();
    await DatabaseService.instance.database.customStatement(
      "UPDATE dive_tanks SET hlc = ? WHERE id = 't1'",
      ['${watermark}z'],
    );

    final cloud = await export(watermark, byOwnClock: false);
    expect(cloud.diveTanks, isEmpty, reason: 'nothing pending');

    final nearby = await export(watermark, byOwnClock: true);
    expect(nearby.dives, isEmpty);
    expect(nearby.diveTanks.map((t) => t['id']), ['t1']);
  });

  test(
    'a composite-key gear link edited after the watermark travels',
    () async {
      final watermark = await seed();
      await DatabaseService.instance.database.customStatement(
        "UPDATE dive_equipment SET hlc = ? WHERE dive_id = 'd1'",
        ['${watermark}z'],
      );
      final nearby = await export(watermark, byOwnClock: true);
      expect(
        nearby.diveEquipment.map((r) => '${r['diveId']}|${r['equipmentId']}'),
        ['d1|e1'],
      );
    },
  );

  test('a shared library site\'s children never travel by their own clock '
      '(issue #2567)', () async {
    final watermark = await seed();
    final db = DatabaseService.instance.database;
    final later = '${watermark}z';
    await db.customStatement(
      'INSERT INTO tags (id, name, created_at, updated_at, hlc) '
      "VALUES ('tag1', 'Reef', 0, 0, ?)",
      [hlc(1, 'old')],
    );
    await db.customStatement(
      'INSERT INTO dive_sites (id, name, created_at, updated_at, hlc, '
      "shared_library_id) VALUES ('mine', 'Home reef', 0, 0, ?, NULL), "
      "('lib-site', 'Club reef', 0, 0, ?, 'lib-1')",
      [hlc(1, 'old'), hlc(1, 'old')],
    );
    await db.customStatement(
      'INSERT INTO site_tags (id, site_id, tag_id, created_at, hlc) '
      "VALUES ('st-mine', 'mine', 'tag1', 0, ?), "
      "('st-lib', 'lib-site', 'tag1', 0, ?)",
      [later, later],
    );
    await SyncRepository().clearAllSyncRecords();

    final nearby = await export(watermark, byOwnClock: true);
    expect(nearby.siteTags.map((r) => r['id']), ['st-mine']);
  });

  test('children at or below the watermark stay out', () async {
    final watermark = await seed();
    final nearby = await export(watermark, byOwnClock: true);
    expect(nearby.diveTanks, isEmpty);
    expect(nearby.diveEquipment, isEmpty);
  });
}
