import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/test_database.dart';

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
          name: const Value('MK25 EVO'),
          type: const Value('regulator'),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  MediaItem doc(
    String name, {
    String? diveId,
    String? siteId,
    String? equipmentId,
    DateTime? createdAt,
  }) => MediaItem(
    id: '',
    mediaType: MediaType.document,
    sourceType: MediaSourceType.localFile,
    filePath: '/tmp/$name',
    localPath: '/tmp/$name',
    originalFilename: name,
    diveId: diveId,
    siteId: siteId,
    equipmentId: equipmentId,
    takenAt: DateTime(2026, 1, 1),
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  test('an attached document round-trips through the equipment link', () async {
    await insertEquipment('e1');
    final saved = await repo.createMedia(doc('invoice.pdf', equipmentId: 'e1'));

    expect(saved.equipmentId, 'e1');
    final reloaded = await repo.getMediaById(saved.id);
    expect(reloaded!.equipmentId, 'e1');

    final forEquipment = await repo.getMediaForEquipment('e1');
    expect(forEquipment.map((m) => m.id), [saved.id]);
    expect(await repo.getMediaCountForEquipment('e1'), 1);
  });

  test('equipment attachments read back in attach order', () async {
    await insertEquipment('e1');
    // takenAt is identical for both (it is only the attach moment for a
    // document), so createdAt is what has to carry the ordering.
    final first = await repo.createMedia(
      doc('older.pdf', equipmentId: 'e1', createdAt: DateTime(2026, 1, 1)),
    );
    final second = await repo.createMedia(
      doc('newer.pdf', equipmentId: 'e1', createdAt: DateTime(2026, 6, 1)),
    );

    final ordered = await repo.getMediaForEquipment('e1');
    expect(ordered.map((m) => m.id), [first.id, second.id]);
  });

  test('an equipment attachment is not a sweepable orphan', () async {
    // The whole point of widening isLinkedToLogbook: an invoice references
    // no dive and no site, so before issue #1517 the sweep would have
    // collected it as unreferenced.
    await insertEquipment('e1');
    final attached = await repo.createMedia(
      doc('invoice.pdf', equipmentId: 'e1'),
    );
    final loose = await repo.createMedia(doc('stray.pdf'));

    final sweepable = await repo.getSweepableOrphanIds(
      olderThan: DateTime(2030),
    );
    expect(sweepable, contains(loose.id));
    expect(sweepable, isNot(contains(attached.id)));
  });

  group('partitionMediaForEquipmentDeletion', () {
    test('dooms equipment-only rows and unlinks the rest', () async {
      await insertDive('d1');
      await insertSite('s1');
      await insertEquipment('e1');
      final doomed = await repo.createMedia(
        doc('invoice.pdf', equipmentId: 'e1'),
      );
      final diveLinked = await repo.createMedia(
        doc('manual.pdf', equipmentId: 'e1', diveId: 'd1'),
      );
      final siteLinked = await repo.createMedia(
        doc('permit.pdf', equipmentId: 'e1', siteId: 's1'),
      );
      await repo.createMedia(doc('unrelated.pdf', diveId: 'd1'));

      final split = await repo.partitionMediaForEquipmentDeletion(['e1']);

      expect(split.doomed.map((m) => m.id), [doomed.id]);
      expect(split.unlinkIds, unorderedEquals([diveLinked.id, siteLinked.id]));
    });

    test('is a no-op for an empty id list', () async {
      final split = await repo.partitionMediaForEquipmentDeletion([]);
      expect(split.doomed, isEmpty);
      expect(split.unlinkIds, isEmpty);
    });
  });

  test(
    'unlinkMediaFromDeletedEquipment clears the link and stamps it',
    () async {
      await insertDive('d1');
      await insertEquipment('e1');
      final survivor = await repo.createMedia(
        doc('manual.pdf', equipmentId: 'e1', diveId: 'd1'),
      );

      await repo.unlinkMediaFromDeletedEquipment([survivor.id]);

      final reloaded = await repo.getMediaById(survivor.id);
      expect(reloaded!.equipmentId, isNull);
      expect(reloaded.diveId, 'd1');
      // The stamp a silent FK SET NULL never produces: without a pending
      // sync record and a fresh HLC the unlink would not reach the diver's
      // other devices.
      final pending = await db
          .customSelect(
            "SELECT sync_status FROM sync_records "
            "WHERE entity_type = 'media' AND record_id = ?",
            variables: [Variable.withString(survivor.id)],
          )
          .getSingle();
      expect(pending.read<String>('sync_status'), 'pending');

      final stamped = await db
          .customSelect(
            'SELECT hlc FROM media WHERE id = ?',
            variables: [Variable.withString(survivor.id)],
          )
          .getSingle();
      expect(stamped.data['hlc'], isNotNull);
    },
  );

  group('cross-link partitions keep equipment attachments alive', () {
    test('a dive deletion unlinks rather than dooms a gear document', () async {
      await insertDive('d1');
      await insertEquipment('e1');
      final both = await repo.createMedia(
        doc('receipt.pdf', diveId: 'd1', equipmentId: 'e1'),
      );

      final split = await repo.partitionMediaForDiveDeletion(['d1']);
      expect(split.doomed, isEmpty);
      expect(split.unlinkIds, [both.id]);
    });

    test('a site deletion unlinks rather than dooms a gear document', () async {
      await insertSite('s1');
      await insertEquipment('e1');
      final both = await repo.createMedia(
        doc('receipt.pdf', siteId: 's1', equipmentId: 'e1'),
      );

      final split = await repo.partitionMediaForSiteDeletion(['s1']);
      expect(split.doomed, isEmpty);
      expect(split.unlinkIds, [both.id]);
    });

    test('a dive unlink keeps a row the gear still needs', () async {
      await insertDive('d1');
      await insertEquipment('e1');
      final both = await repo.createMedia(
        doc('receipt.pdf', diveId: 'd1', equipmentId: 'e1'),
      );
      final diveOnly = await repo.createMedia(doc('shot.pdf', diveId: 'd1'));

      final split = await repo.partitionForDiveUnlink([both.id, diveOnly.id]);
      expect(split.keptIds, [both.id]);
      expect(split.deletable, [diveOnly.id]);
    });

    test('an equipment unlink keeps a row a dive still needs', () async {
      await insertDive('d1');
      await insertEquipment('e1');
      final both = await repo.createMedia(
        doc('receipt.pdf', diveId: 'd1', equipmentId: 'e1'),
      );
      final gearOnly = await repo.createMedia(
        doc('invoice.pdf', equipmentId: 'e1'),
      );

      final split = await repo.partitionForEquipmentUnlink([
        both.id,
        gearOnly.id,
      ]);
      expect(split.keptIds, [both.id]);
      expect(split.deletable, [gearOnly.id]);
    });
  });

  test('linkMediaToEquipment attaches an existing row', () async {
    await insertEquipment('e1');
    final loose = await repo.createMedia(doc('invoice.pdf'));

    await repo.linkMediaToEquipment([loose.id], 'e1');

    final reloaded = await repo.getMediaById(loose.id);
    expect(reloaded!.equipmentId, 'e1');
  });
}
