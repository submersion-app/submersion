import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_parent_cascade.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

/// Media the diver kept in the library (`retain_in_library`, issue #5122)
/// outlives the dive, site or gear it was placed on: it stays, with no place,
/// where any other media whose last link dies is deleted.
void main() {
  late AppDatabase db;
  late MediaRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = MediaRepository();
  });
  tearDown(tearDownTestDatabase);

  final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;

  Future<void> insertDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(epoch),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  Future<void> insertSite(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: const Value('Reef'),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  Future<void> insertEquipment(String id) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion(
          id: Value(id),
          name: const Value('Housing'),
          type: const Value('camera'),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  Future<MediaItem> create(
    String name, {
    String? diveId,
    String? siteId,
    String? equipmentId,
    bool retain = false,
  }) => repo.createMedia(
    MediaItem(
      id: '',
      mediaType: MediaType.video,
      sourceType: MediaSourceType.platformGallery,
      filePath: p.join(Directory.systemTemp.path, name),
      localPath: p.join(Directory.systemTemp.path, name),
      originalFilename: name,
      diveId: diveId,
      siteId: siteId,
      equipmentId: equipmentId,
      retainInLibrary: retain,
      takenAt: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  );

  Future<void> expectUnplaced(String id) async {
    final row = await repo.getMediaById(id);
    expect(row, isNotNull);
    expect(row!.diveId, isNull);
    expect(row.siteId, isNull);
    expect(row.equipmentId, isNull);
    expect(row.retainInLibrary, isTrue);
  }

  test('a kept row survives its dive\'s deletion with no place', () async {
    await insertDive('d1');
    final kept = await create('kept.MP4', diveId: 'd1', retain: true);
    final plain = await create('plain.MP4', diveId: 'd1');

    final split = await repo.partitionMediaForDiveDeletion(['d1']);
    expect(split.unlinkIds, [kept.id]);
    expect(split.doomed.map((m) => m.id), [plain.id]);

    await repo.unlinkMediaFromDeletedDives(split.unlinkIds, ['d1']);
    await expectUnplaced(kept.id);
  });

  test('a kept row survives its site\'s deletion with no place', () async {
    await insertSite('s1');
    final kept = await create('kept.MP4', siteId: 's1', retain: true);
    final plain = await create('plain.MP4', siteId: 's1');

    final split = await repo.partitionMediaForSiteDeletion(['s1']);
    expect(split.unlinkIds, [kept.id]);
    expect(split.doomed.map((m) => m.id), [plain.id]);

    await repo.unlinkMediaFromDeletedSites(split.unlinkIds);
    await expectUnplaced(kept.id);
  });

  test('a kept row survives its gear\'s deletion with no place', () async {
    await insertEquipment('e1');
    final kept = await create('kept.MP4', equipmentId: 'e1', retain: true);
    final plain = await create('plain.MP4', equipmentId: 'e1');

    final split = await repo.partitionMediaForEquipmentDeletion(['e1']);
    expect(split.unlinkIds, [kept.id]);
    expect(split.doomed.map((m) => m.id), [plain.id]);

    await repo.unlinkMediaFromDeletedEquipment(split.unlinkIds);
    await expectUnplaced(kept.id);
  });

  test('a diver deletion plans a kept row as a survivor', () async {
    await insertDive('d1');
    await insertSite('s1');
    final kept = await create(
      'kept.MP4',
      diveId: 'd1',
      siteId: 's1',
      retain: true,
    );
    final plain = await create('plain.MP4', diveId: 'd1', siteId: 's1');

    final plan = await planMediaCascade(
      db,
      const DyingMediaParents(diveIds: {'d1'}, siteIds: {'s1'}),
    );

    expect(plan.doomed.map((m) => m.id), [plain.id]);
    final survivor = plan.survivors.singleWhere((s) => s.id == kept.id);
    expect(survivor.diveId, 'd1');
    expect(survivor.siteId, 's1');
  });

  test('mediaRowLivesOn keeps a kept row whose every parent dies', () async {
    await insertDive('d1');
    final kept = await create('kept.MP4', diveId: 'd1', retain: true);
    final row = await (db.select(
      db.media,
    )..where((m) => m.id.equals(kept.id))).getSingle();

    expect(
      mediaRowLivesOn(row, const DyingMediaParents(diveIds: {'d1'})),
      isTrue,
    );
  });
}
