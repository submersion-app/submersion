import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_dive_photos_list.dart';
import 'package:submersion/features/media/data/repositories/media_gear_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// The photos linked to a gear item, held in its page's sitting (issue
/// #5046): changed on the In dive photos card, written at Save.
void main() {
  late AppDatabase db;
  final gear = MediaGearRepository();
  const item = EquipmentItem(
    id: 'e1',
    name: 'Drysuit',
    type: EquipmentType.drysuit,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    for (final (id, diver) in [('owner', 'owner'), ('wife', 'wife')]) {
      await db.customStatement(
        'INSERT INTO divers (id, name, created_at, updated_at) '
        "VALUES ('$id', '$diver', 0, 0)",
      );
    }
    await db.customStatement(
      'INSERT INTO dives (id, diver_id, dive_date_time, created_at, '
      "updated_at) VALUES ('d-wife', 'wife', 0, 0, 0)",
    );
    for (final (id, dive) in [
      ('m1', null),
      ('m2', null),
      ('m3', null),
      ('wife-photo', 'd-wife'),
    ]) {
      await db.customStatement(
        'INSERT INTO media (id, file_path, file_type, dive_id, created_at, '
        "updated_at) VALUES ('$id', '', 'photo', "
        "${dive == null ? 'NULL' : "'$dive'"}, 1, 1)",
      );
    }
    await db.customStatement(
      'INSERT INTO equipment (id, name, type, created_at, updated_at) '
      "VALUES ('e1', 'Drysuit', 'drysuit', 0, 0)",
    );
  });
  tearDown(tearDownTestDatabase);

  test('linking in the sitting writes it on Save', () async {
    await gear.addGear(['m1'], ['e1']);
    final session = EditSession<EquipmentItem>(item);
    addTearDown(session.dispose);
    final loaded = (await gearItemDivePhotosList.currentOrRead(session))!;

    final m3 = (await MediaRepository().getMediaById('m3'))!;
    gearItemDivePhotosList.set(session, [...loaded, m3]);
    expect(await gear.mediaIdsFor('e1'), ['m1'], reason: 'held until Save');

    await db.transaction(session.runHeldWrites);

    expect(await gear.mediaIdsFor('e1'), unorderedEquals(['m1', 'm3']));
  });

  test("saving keeps another diver's link the card never showed", () async {
    await gear.addGear(['m1', 'wife-photo'], ['e1']);
    final session = EditSession<EquipmentItem>(item);
    addTearDown(session.dispose);
    await gearItemDivePhotosList.currentOrRead(session);
    final shown = gearItemDivePhotosShown(session, visibleIds: {'m1'})!;
    expect([for (final m in shown) m.id], ['m1']);

    // The diver unlinks the one photo they can see.
    gearItemDivePhotosList.set(session, [
      for (final m in gearItemDivePhotosList.current(session)!)
        if (m.id != 'm1') m,
    ]);
    await db.transaction(session.runHeldWrites);

    expect(await gear.mediaIdsFor('e1'), ['wife-photo']);
  });

  test(
    'a link made elsewhere while the sitting is open survives Save',
    () async {
      await gear.addGear(['m1'], ['e1']);
      final session = EditSession<EquipmentItem>(item);
      addTearDown(session.dispose);
      final loaded = (await gearItemDivePhotosList.currentOrRead(session))!;
      final m3 = (await MediaRepository().getMediaById('m3'))!;
      gearItemDivePhotosList.set(session, [...loaded, m3]);
      // Another device links m2 meanwhile.
      await gear.addGear(['m2'], ['e1']);

      await db.transaction(session.runHeldWrites);

      expect(await gear.mediaIdsFor('e1'), unorderedEquals(['m1', 'm2', 'm3']));
    },
  );

  test('replaceShownLinks never lists a photo twice', () {
    final current = [
      for (final id in ['hidden', 'a']) _item(id),
    ];
    final next = replaceShownLinks(
      current: current,
      shownNow: const [],
      keep: [_item('a'), _item('b')],
    );
    expect([for (final m in next) m.id], ['hidden', 'a', 'b']);
  });
}

MediaItem _item(String id) => MediaItem(
  id: id,
  mediaType: MediaType.photo,
  sourceType: MediaSourceType.localFile,
  takenAt: DateTime(2026),
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
