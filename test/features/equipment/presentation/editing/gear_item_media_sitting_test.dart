import 'package:flutter_test/flutter_test.dart';

import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/gear_photo_repository.dart';
import 'package:submersion/features/equipment/data/services/gear_item_edit_save_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_fields.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_media_sitting.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A gear item's photos, its cover and its older linked files, held in its
/// page's sitting (issue #4527, phase 3, plan 6).
void main() {
  late EquipmentRepository items;
  late ProviderContainer container;

  setUp(() async {
    final db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    container = ProviderContainer();
    addTearDown(container.dispose);
    items = EquipmentRepository();
    await items.createEquipment(
      const EquipmentItem(
        id: 'g1',
        name: 'Apex',
        type: EquipmentType.regulator,
      ),
    );
    await db.customStatement(
      "INSERT INTO media (id, equipment_id, file_path, created_at, "
      "updated_at) VALUES ('p1', 'g1', '/p1.jpg', 0, 0), "
      "('doc1', 'g1', '/manual.zip', 0, 0)",
    );
    await db.customStatement(
      "UPDATE media SET file_type = 'document' WHERE id = 'doc1'",
    );
    await GearPhotoRepository().setCover('g1', 'p1');
  });
  tearDown(tearDownTestDatabase);

  Future<EquipmentItem> stored() async => (await items.getEquipmentById('g1'))!;

  Future<bool> mediaExists(String id) async =>
      (await DatabaseService.instance.database
              .customSelect(
                'SELECT id FROM media WHERE id = ?',
                variables: [Variable.withString(id)],
              )
              .get())
          .isNotEmpty;

  Future<EditSession<EquipmentItem>> sitting() async {
    final session = EditSession(await stored());
    addTearDown(session.dispose);
    final writers = SittingMediaWriters.forEquipment(container.read);
    holdSittingMedia(session, writers, cardId: 'photos');
    holdLegacyFiles(session, writers);
    return session;
  }

  Future<void> save(EditSession<EquipmentItem> session) => undoMediaOnFailure(
    session,
    () => GearItemEditSaveService(items, GearPhotoRepository()).save(
      equipmentId: 'g1',
      apply: (s) => gearItemToSave(s, session.applyTo(s)),
      changedCardIds: session.changedCardIds,
      alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
      alsoWriteIsAChange: session.hasHeldChanges,
    ),
  );

  HeldMediaAdd heldPhoto(String id) => HeldMediaRow((
    item: MediaItem(
      id: id,
      equipmentId: 'g1',
      filePath: '/$id.jpg',
      localPath: '/$id.jpg',
      mediaType: MediaType.photo,
      takenAt: DateTime.utc(2026, 1, 1),
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
    enrichment: null,
  ));

  test('a photo imported and chosen as the cover: the cover is written '
      'after the photo', () async {
    final session = await sitting();
    addMediaToSitting(session, [heldPhoto('p2')]);
    session.set(gearCoverField, 'p2');

    expect(await mediaExists('p2'), isFalse);
    await save(session);

    expect(await mediaExists('p2'), isTrue);
    expect((await stored()).coverMediaId, 'p2');
  });

  test('the cover unlinked, then Cancel: cover and photo kept', () async {
    final session = await sitting();
    unlinkMediaInSitting(session, {'p1'});
    session.set(gearCoverField, null);

    // Cancel: the sitting ends unsaved (disposed at tear-down).
    expect(await mediaExists('p1'), isTrue);
    expect((await stored()).coverMediaId, 'p1');
  });

  test(
    'the cover unlinked, then Save: cover cleared with the unlink',
    () async {
      final session = await sitting();
      unlinkMediaInSitting(session, {'p1'});
      session.set(gearCoverField, null);

      await save(session);

      expect(await mediaExists('p1'), isFalse);
      expect((await stored()).coverMediaId, isNull);
    },
  );

  test('a legacy file unlinked in the sitting stays until Save', () async {
    final session = await sitting();
    unlinkLegacyFileInSitting(session, 'doc1');

    expect(session.changedCardIds, {'legacyFiles'});
    expect(await mediaExists('doc1'), isTrue);
    await save(session);

    expect(await mediaExists('doc1'), isFalse);
    expect(legacyFilesAfterCommit(session), hasLength(1));
  });
}
