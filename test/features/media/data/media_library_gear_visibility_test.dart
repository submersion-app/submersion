import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/media/data/repositories/media_library_repository.dart';
import 'package:submersion/features/media/domain/entities/media_library_filter.dart';

import '../../../helpers/test_database.dart';

/// Gear photos the Library shows when Attached to picks Equipment (issues
/// #3355, #4224) follow the gear's own visibility (issue #2046): a diver
/// sees photos of gear they own or that is shared with them, never another
/// profile's.
void main() {
  late AppDatabase db;
  final repo = MediaLibraryRepository();
  const now = 1;
  const equipmentOnly = MediaLibraryFilter(
    attachedTo: {MediaAttachmentKind.equipment},
  );

  setUp(() async {
    db = await setUpTestDatabase();
    for (final id in ['me', 'other']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion(
              id: Value(id),
              name: Value(id),
              createdAt: const Value(now),
              updatedAt: const Value(now),
            ),
          );
    }
    for (final (id, owner) in [
      ('mine', 'me'),
      ('theirs', 'other'),
      ('lent', 'other'),
    ]) {
      await db
          .into(db.equipment)
          .insert(
            EquipmentCompanion(
              id: Value(id),
              diverId: Value(owner),
              name: Value(id),
              type: const Value('light'),
              createdAt: const Value(now),
              updatedAt: const Value(now),
            ),
          );
    }
    await db
        .into(db.equipmentShares)
        .insert(
          EquipmentSharesCompanion.insert(
            id: 'share-lent',
            equipmentId: 'lent',
            diverId: 'me',
            createdAt: now,
          ),
        );
    // taken_at descending is the default sort.
    await db.customStatement(
      'INSERT INTO media (id, file_path, file_type, taken_at, created_at, '
      'updated_at, latitude, longitude, equipment_id) VALUES '
      "('mine-photo', 'a', 'photo', 3, 1, 1, 20.5, -87.0, 'mine'), "
      "('theirs-photo', 'b', 'photo', 2, 1, 1, 20.5, -87.0, 'theirs'), "
      "('lent-photo', 'c', 'photo', 1, 1, 1, 20.5, -87.0, 'lent')",
    );
  });
  tearDown(tearDownTestDatabase);

  Future<List<String>> ids(String? diverId) async => [
    for (final e in (await repo.getPage(
      diverId: diverId,
      filter: equipmentOnly,
    )).entries)
      e.item.id,
  ];

  test('a diver sees photos of gear they own or that is shared', () async {
    expect(await ids('me'), ['mine-photo', 'lent-photo']);
    expect(await ids('other'), ['theirs-photo', 'lent-photo']);
  });

  test('the map follows the same rule', () async {
    final points = await repo.getMapPoints(
      diverId: 'me',
      filter: equipmentOnly,
    );

    expect(points.map((p) => p.entry.item.id), ['lent-photo', 'mine-photo']);
  });

  test('a photo of gear that no longer exists stays out', () async {
    // Only sync, applying a photo ahead of its item, leaves such a link, so
    // the foreign key is set aside to stage one.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    addTearDown(() => db.customStatement('PRAGMA foreign_keys = ON'));
    await db.customStatement(
      'INSERT INTO media (id, file_path, file_type, taken_at, created_at, '
      'updated_at, equipment_id) VALUES '
      "('gone-photo', 'd', 'photo', 4, 1, 1, 'gone')",
    );

    expect(await ids(null), ['mine-photo', 'theirs-photo', 'lent-photo']);
  });

  test('ending a share takes the photo away', () async {
    await (db.delete(
      db.equipmentShares,
    )..where((t) => t.id.equals('share-lent'))).go();

    expect(await ids('me'), ['mine-photo']);
  });

  // A share given or taken back changes which photos show without a media
  // row being written, so every reader of them must tick on it.
  for (final (name, watch) in [
    ('watchLibraryChanges', () => repo.watchLibraryChanges()),
    ('watchMapChanges', () => repo.watchMapChanges()),
    (
      'watchGearItemPhotoChanges',
      () => GearPhotoRepository().watchGearItemPhotoChanges(),
    ),
  ]) {
    test('$name ticks when a share changes', () async {
      var ticks = 0;
      final sub = watch().listen((_) => ticks++);
      addTearDown(sub.cancel);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      final before = ticks;

      await (db.delete(
        db.equipmentShares,
      )..where((t) => t.id.equals('share-lent'))).go();
      await Future<void>.delayed(const Duration(milliseconds: 400));

      expect(ticks, greaterThan(before));
    });
  }
}
