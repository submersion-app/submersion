import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/equipment_item_fold.dart';
import 'package:submersion/features/media/data/repositories/media_gear_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_row_restore.dart';

import '../../../../helpers/test_database.dart';

/// Gear links leave with their photo or their gear item, tombstoned so every
/// peer drops them too, and come back with an undone photo delete
/// (issue #5046).
void main() {
  late AppDatabase db;
  final gear = MediaGearRepository();

  Future<void> photo(String id) => db.customStatement(
    'INSERT INTO media (id, file_path, file_type, created_at, updated_at) '
    "VALUES ('$id', '', 'photo', 1, 1)",
  );

  Future<void> item(String id) => db.customStatement(
    'INSERT INTO equipment (id, name, type, created_at, updated_at, '
    "diver_id) VALUES ('$id', '$id', 'computer', 0, 0, 'd1')",
  );

  Future<Set<String>> tombstones() async => {
    for (final r in await (db.select(
      db.deletionLog,
    )..where((t) => t.entityType.equals('mediaEquipment'))).get())
      r.recordId,
  };

  Future<Set<String>> linkIds() async => {
    for (final r in await db.select(db.mediaEquipment).get()) r.id,
  };

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('d1', 'd1', 0, 0)",
    );
    await photo('m1');
    await photo('m2');
    await item('e1');
    await item('e2');
  });
  tearDown(tearDownTestDatabase);

  test('a photo linked to gear counts as carrying user metadata', () async {
    // Unlinking it from the Library deletes the links with the row, so the
    // unlink confirmation must warn (issue #5046).
    await gear.addGear(['m1'], ['e1']);

    expect(await MediaRepository().idsWithUserMetadata(['m1', 'm2']), {'m1'});
  });

  test('deleting a photo deletes its links and logs each deletion', () async {
    await gear.addGear(['m1', 'm2'], ['e1', 'e2']);
    final m1Links = {
      for (final r in await db.select(db.mediaEquipment).get())
        if (r.mediaId == 'm1') r.id,
    };

    await MediaRepository().deleteMedia('m1');

    expect(await gear.gearIdsFor('m1'), isEmpty);
    expect(await tombstones(), m1Links);

    await MediaRepository().deleteMultipleMedia(['m2']);
    expect(await linkIds(), isEmpty);
    expect(await tombstones(), hasLength(4));
  });

  test(
    'deleting a gear item deletes its links and logs each deletion',
    () async {
      await gear.addGear(['m1', 'm2'], ['e1', 'e2']);

      await EquipmentRepository().deleteEquipment('e1');

      expect(await gear.mediaIdsFor('e1'), isEmpty);
      expect(await gear.mediaIdsFor('e2'), unorderedEquals(['m1', 'm2']));
      expect(await tombstones(), hasLength(2));
    },
  );

  test('undoing a photo delete restores its links', () async {
    await gear.addGear(['m1'], ['e1', 'e2']);
    final snapshot = await readMediaRows(db, ['m1']);
    await MediaRepository().deleteMedia('m1');

    await restoreMediaRows(db, SyncRepository(), snapshot, now: 10);

    expect((await gear.gearIdsFor('m1')).toSet(), {'e1', 'e2'});
  });

  test(
    'undoing a photo delete skips a link to gear deleted meanwhile',
    () async {
      await gear.addGear(['m1'], ['e1', 'e2']);
      final snapshot = await readMediaRows(db, ['m1']);
      await MediaRepository().deleteMedia('m1');
      await EquipmentRepository().deleteEquipment('e2');

      await restoreMediaRows(db, SyncRepository(), snapshot, now: 10);

      expect(await gear.gearIdsFor('m1'), ['e1']);
    },
  );

  test('folding a duplicate gear item moves its links without duplicating a '
      'pair', () async {
    await gear.addGear(['m1'], ['e1', 'e2']);
    await gear.addGear(['m2'], ['e2']);

    expect(await EquipmentItemFold().fold(fromId: 'e2', intoId: 'e1'), isTrue);

    expect(await gear.mediaIdsFor('e1'), unorderedEquals(['m1', 'm2']));
    expect(await gear.mediaIdsFor('e2'), isEmpty);
  });
}
