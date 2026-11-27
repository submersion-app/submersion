import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_gear_repository.dart';

import '../../../../helpers/test_database.dart';

/// Gear linked to photos (issue #5046).
void main() {
  late AppDatabase db;
  late MediaGearRepository repo;

  Future<void> media(
    String id, {
    String? diveId,
    String fileType = 'photo',
    String sourceType = 'platformGallery',
    String? equipmentId,
    int takenAt = 0,
  }) => db.customStatement(
    'INSERT INTO media (id, file_path, file_type, source_type, dive_id, '
    'equipment_id, taken_at, created_at, updated_at) '
    "VALUES ('$id', '', '$fileType', '$sourceType', "
    "${diveId == null ? 'NULL' : "'$diveId'"}, "
    "${equipmentId == null ? 'NULL' : "'$equipmentId'"}, $takenAt, 1, 1)",
  );

  Future<int> count(String sql) async =>
      (await db.customSelect(sql).getSingle()).read<int>('n');

  setUp(() async {
    db = await setUpTestDatabase();
    repo = MediaGearRepository();
    for (final id in ['owner', 'wife']) {
      await db.customStatement(
        'INSERT INTO divers (id, name, created_at, updated_at) '
        "VALUES ('$id', '$id', 0, 0)",
      );
    }
    for (final id in ['e1', 'e2', 'cyl']) {
      await db.customStatement(
        'INSERT INTO equipment (id, name, type, created_at, updated_at) '
        "VALUES ('$id', '$id', 'other', 0, 0)",
      );
    }
    for (final (id, diver) in [('d1', 'owner'), ('d2', 'wife')]) {
      await db.customStatement(
        'INSERT INTO dives (id, diver_id, dive_date_time, created_at, '
        "updated_at) VALUES ('$id', '$diver', 0, 0, 0)",
      );
    }
    await media('m1', diveId: 'd1', takenAt: 10);
    await media('m2', diveId: 'd2', takenAt: 20);
    await media('m3', takenAt: 30);
  });

  tearDown(tearDownTestDatabase);

  test(
    'replaceGear adds and removes links and stamps hlc on new rows',
    () async {
      await repo.replaceGear('m1', ['e1', 'e2']);
      expect((await repo.gearIdsFor('m1')).toSet(), {'e1', 'e2'});
      expect(
        await count(
          'SELECT COUNT(*) AS n FROM media_equipment WHERE hlc IS NOT NULL',
        ),
        2,
      );

      await repo.replaceGear('m1', ['e2']);
      expect(await repo.gearIdsFor('m1'), ['e2']);
    },
  );

  test('replaceGear twice with the same ids writes nothing', () async {
    await repo.replaceGear('m1', ['e1']);
    final before = await db
        .customSelect('SELECT id, hlc FROM media_equipment')
        .getSingle();
    await repo.replaceGear('m1', ['e1']);
    final after = await db
        .customSelect('SELECT id, hlc FROM media_equipment')
        .getSingle();
    expect(after.data, before.data);
  });

  test('removing a link logs a deletion', () async {
    await repo.replaceGear('m1', ['e1']);
    await repo.removeGear(['m1'], ['e1']);
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM deletion_log WHERE entity_type = 'mediaEquipment'",
      ),
      1,
    );
  });

  test('addGear skips pairs already linked', () async {
    await repo.addGear(['m1'], ['e1']);
    await repo.addGear(['m1', 'm3'], ['e1', 'e2']);
    expect(await count('SELECT COUNT(*) AS n FROM media_equipment'), 4);
    expect(await repo.gearCountsFor(['m1', 'm3']), {'e1': 2, 'e2': 2});
    expect(await repo.gearIdsByMedia(['m1', 'm2']), {
      'm1': {'e1', 'e2'},
    });
  });

  test("linkedMediaFor hides another diver's dive photos and shows dive-less "
      'photos', () async {
    await repo.addGear(['m1', 'm2', 'm3'], ['e1']);
    final ids = [
      for (final m in await repo.linkedMediaFor('e1', diverId: 'owner')) m.id,
    ];
    expect(ids, ['m3', 'm1'], reason: 'newest first');
    expect(await repo.mediaIdsFor('e1'), unorderedEquals(['m1', 'm2', 'm3']));
  });

  test('linkedMediaFor leaves out documents and gear photos', () async {
    await media('doc', fileType: 'document');
    await media('gear', equipmentId: 'e1');
    await repo.addGear(['m3', 'doc', 'gear'], ['e1']);
    final ids = [
      for (final m in await repo.linkedMediaFor('e1', diverId: null)) m.id,
    ];
    expect(ids, ['m3']);
  });

  test('replaceMedia keeps the links of photos outside the list', () async {
    await repo.addGear(['m1', 'm2'], ['e1']);
    await repo.replaceMedia('e1', ['m1', 'm3']);
    expect(await repo.mediaIdsFor('e1'), unorderedEquals(['m1', 'm3']));
  });

  test('linkableMediaOnDives lists the photos of those dives', () async {
    await media('doc', diveId: 'd1', fileType: 'document');
    await media('m4', diveId: 'd1', takenAt: 40);
    final ids = [
      for (final m in await repo.linkableMediaOnDives(['d1'])) m.id,
    ];
    expect(ids, ['m4', 'm1']);
  });

  test('gearOnDive includes a cylinder linked through dive_tanks', () async {
    await db.customStatement(
      "INSERT INTO dive_equipment (dive_id, equipment_id) VALUES ('d1', 'e1')",
    );
    await db.customStatement(
      'INSERT INTO dive_tanks (id, dive_id, equipment_id) '
      "VALUES ('t1', 'd1', 'cyl')",
    );
    expect(await repo.gearOnDive('d1'), {'e1', 'cyl'});
  });

  test('deleteForMedia and deleteForEquipment log each deletion', () async {
    await repo.addGear(['m1', 'm3'], ['e1', 'e2']);
    await repo.deleteForMedia(['m1']);
    expect(await repo.gearIdsFor('m1'), isEmpty);
    await repo.deleteForEquipment('e1');
    expect(await repo.gearIdsFor('m3'), ['e2']);
    expect(
      await count(
        "SELECT COUNT(*) AS n FROM deletion_log WHERE entity_type = 'mediaEquipment'",
      ),
      3,
    );
  });
}
