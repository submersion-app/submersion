import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/entities/site_attachment_category.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/media/data/repositories/media_color_adjustment_repository.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/repositories/site_attachment_repository.dart';
import 'package:submersion/features/media/data/services/photo_edit_save_service.dart';
import 'package:submersion/features/media/data/services/photo_record_reader.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';
import 'package:submersion/features/media/domain/value_objects/photo_tag_edits.dart';
import 'package:submersion/features/media/domain/value_objects/sighting_timing.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/editing/photo_held_writes.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';

import '../../../../helpers/test_database.dart';
import '../repositories/species_photo_fixtures.dart';

/// Dives whose media time shift cannot be written.
class _NoShift implements DiveRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<void> setMediaTimeOffsetSeconds(String diveId, int seconds) async =>
      throw StateError('the shift could not be written');
}

/// A photo's editing sitting is saved in one transaction and one change log
/// operation, and writes only what the diver changed onto the photo as it is
/// stored at that moment (issue #4527).
void main() {
  late AppDatabase db;
  late PhotoRecordReader reader;
  late MediaPeopleRepository people;
  late MediaColorAdjustmentRepository colors;
  late MediaRepository media;
  late SpeciesRepository species;
  late BuddyRepository buddies;
  final changeLog = ChangeLogRepository();

  PhotoEditSaveService serviceWith({DiveRepository? dives}) =>
      PhotoEditSaveService(
        reader: reader,
        tagging: SpeciesTaggingService(
          tags: MediaSpeciesRepository(),
          media: media,
          species: species,
        ),
        people: people,
        media: media,
        colors: colors,
        attachments: SiteAttachmentRepository(),
        dives: dives ?? DiveRepository(),
        tags: TagLinkRepository(TagScope.media),
      );

  Future<List<Map<String, Object?>>> operations() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect(
          'SELECT id, source, label, root_table, root_id '
          'FROM change_log_operations',
        )
        .get();
    return [for (final row in rows) row.data];
  }

  Future<PhotoRecord> stored(String id) async =>
      (await reader.read(id, diverId: 'me'))!;

  Future<EditSession<PhotoRecord>> sitting(String id) async =>
      EditSession<PhotoRecord>(await stored(id));

  Future<({PhotoRecord before, PhotoRecord after})?> save(
    EditSession<PhotoRecord> session, {
    PhotoEditSaveService? service,
  }) => (service ?? serviceWith()).save(
    mediaId: session.stored.item.id,
    diverId: 'me',
    apply: session.applyTo,
    changedCardIds: session.changedCardIds,
    alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
    alsoWriteIsAChange: session.hasHeldChanges,
  );

  const turtle = SpeciesTagChip(
    speciesId: 'sp_turtle',
    storedName: 'Turtle',
    category: SpeciesCategory.turtle,
    isBuiltIn: false,
  );

  MediaPersonChip personChip(String id, {String? buddyId, String? diverId}) =>
      MediaPersonChip(
        tag: MediaPersonTag(
          id: id,
          mediaId: 'p1',
          buddyId: buddyId,
          diverId: diverId,
          box: const FaceBox(x: 0.2, y: 0.2, width: 0.2, height: 0.2),
          createdAt: DateTime.utc(2026, 11, 1),
          updatedAt: DateTime.utc(2026, 11, 1),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    media = MediaRepository();
    species = SpeciesRepository();
    people = MediaPeopleRepository();
    colors = MediaColorAdjustmentRepository();
    buddies = BuddyRepository();
    reader = PhotoRecordReader(
      media: media,
      species: MediaSpeciesRepository(),
      people: people,
      tags: TagLinkRepository(TagScope.media),
    );
    await insertTestDiver('me');
    await insertTestSite('s1', 'Blue Hole');
    await insertTestDive(
      id: 'd1',
      at: DateTime(2024, 1, 10),
      siteId: 's1',
      diverId: 'me',
    );
    await insertTestSpecies(
      id: 'sp_turtle',
      name: 'Turtle',
      category: SpeciesCategory.turtle,
    );
    await insertTestSpecies(id: 'sp_ray', name: 'Ray');
    await insertTestBuddy(id: 'b1', name: 'Ann', diverId: 'me');
    await insertTestBuddy(id: 'b2', name: 'Bo', diverId: 'me');
    await insertTestMedia(id: 'p1', diveId: 'd1');
    await insertTestMedia(id: 'p2', diveId: 'd1');
    await insertTestMedia(id: 'site-photo', siteId: 's1');
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test('a sitting that tags a species, a person and a colour is one '
      'operation, labelled', () async {
    final session = await sitting('p1');
    session
      ..set(
        photoSpeciesField,
        SpeciesTagEdits.none.toggled(turtle, tagged: true, stored: const []),
      )
      ..set(
        photoPeopleField,
        PersonTagEdits.none.add(
          personChip('local1', buddyId: 'b1'),
          stored: const [],
          isVideo: false,
        ),
      )
      ..set(photoColorField, const ColorAdjustment(warmth: 0.4));

    final result = await save(session);

    expect(result, isNotNull);
    final ops = await operations();
    expect(ops, hasLength(1));
    expect(ops.single['label'], 'record_edit:media:color,people,species');
    expect(ops.single['source'], 'manual');
    // A dive photo's rows belong to its dive.
    expect(ops.single['root_table'], 'dives');
    expect(ops.single['root_id'], 'd1');
    final after = await stored('p1');
    expect(after.species.map((c) => c.speciesId), ['sp_turtle']);
    expect(after.people.single.tag.buddyId, 'b1');
    expect(after.item.colorAdjustment, const ColorAdjustment(warmth: 0.4));
    // The tag logged the species on the dive.
    final sightings = await species.getSightingsForDive('d1');
    expect(sightings.single.speciesId, 'sp_turtle');
  });

  test('only what changed is written: a colour stored meanwhile survives a '
      'sitting that changed the pin', () async {
    final session = await sitting('p1');
    session.set(photoPinField, 120);
    await colors.setColorAdjustment('p1', const ColorAdjustment(tint: 0.2));

    await save(session);

    final after = await stored('p1');
    expect(after.item.manualElapsedSeconds, 120);
    expect(after.item.colorAdjustment, const ColorAdjustment(tint: 0.2));
  });

  test('a tag added on another device during the sitting survives a Save '
      'that removed another', () async {
    final first = await people.addTag(mediaId: 'p1', buddyId: 'b1');
    final session = await sitting('p1');
    session.set(
      photoPeopleField,
      PersonTagEdits.none.remove(first.id, stored: session.stored.people),
    );
    final synced = await people.addTag(mediaId: 'p1', diverId: 'me');

    await save(session);

    final after = await stored('p1');
    expect(after.people.map((c) => c.tag.id), [synced.id]);
  });

  test('a pin and a dive shift are written; the photo is not re-placed by '
      'the save', () async {
    final session = await sitting('p1');
    session
      ..set(photoDiveShiftField, 45)
      ..set(photoPinField, 300);

    await save(session);

    final after = await stored('p1');
    expect(after.diveShiftSeconds, 45);
    expect(after.item.manualElapsedSeconds, 300);
    // The enrichment pass runs after the save, not in it.
    expect(after.item.enrichment, isNull);
  });

  test('a save whose dive shift throws leaves no tag, sighting, colour or '
      'pin', () async {
    final session = await sitting('p1');
    session
      ..set(
        photoSpeciesField,
        SpeciesTagEdits.none.toggled(turtle, tagged: true, stored: const []),
      )
      ..set(
        photoPeopleField,
        PersonTagEdits.none.add(
          personChip('local1', buddyId: 'b1'),
          stored: const [],
          isVideo: false,
        ),
      )
      ..set(photoColorField, const ColorAdjustment(warmth: 0.4))
      ..set(photoPinField, 60)
      ..set(photoDiveShiftField, 30);

    await expectLater(
      save(session, service: serviceWith(dives: _NoShift())),
      throwsStateError,
    );

    final after = await stored('p1');
    expect(after.species, isEmpty);
    expect(after.people, isEmpty);
    expect(after.item.colorAdjustment, isNull);
    expect(after.item.manualElapsedSeconds, isNull);
    expect(after.diveShiftSeconds, 0);
    expect(await species.getSightingsForDive('d1'), isEmpty);
  });

  test('a photo with no dive: the species tag adds no sighting; the label '
      'names species', () async {
    final session = await sitting('site-photo');
    expect(session.stored.diveShiftSeconds, isNull);
    session.set(
      photoSpeciesField,
      SpeciesTagEdits.none.toggled(turtle, tagged: true, stored: const []),
    );

    await save(session);

    final ops = await operations();
    expect(ops.single['label'], 'record_edit:media:species');
    expect(ops.single['root_table'], 'media');
    expect((await stored('site-photo')).species, hasLength(1));
    expect(await species.getSightingsForDive('d1'), isEmpty);
  });

  test('Apply to this dive held: the other photos get the saved sliders at '
      'Save, in the same operation', () async {
    final session = await sitting('p1');
    session.set(photoColorField, const ColorAdjustment(warmth: 0.6));
    holdColorToDive(session, diveId: 'd1', repository: colors);

    await save(session);

    expect((await stored('p2')).item.colorAdjustment?.warmth, 0.6);
    expect((await stored('p1')).item.colorAdjustment?.warmth, 0.6);
    expect(await operations(), hasLength(1));
  });

  test('add buddy held: added at Save', () async {
    final session = await sitting('p1');
    holdAddBuddyToDive(
      session,
      diveId: 'd1',
      buddyId: 'b2',
      repository: buddies,
    );
    expect(session.isDirty, isTrue);

    await save(session);

    final onDive = await buddies.getBuddiesForDive('d1');
    expect(onDive.map((b) => b.buddy.id), ['b2']);
    expect(await operations(), hasLength(1));
  });

  test(
    'add buddy held, already on the dive by then: nothing written',
    () async {
      final session = await sitting('p1');
      holdAddBuddyToDive(
        session,
        diveId: 'd1',
        buddyId: 'b2',
        repository: buddies,
      );
      await buddies.addBuddyToDiveWithRoles('d1', 'b2', const []);

      await save(session);

      expect(await buddies.getBuddiesForDive('d1'), hasLength(1));
    },
  );

  test('a photo moved to another dive since the sitting started: refused, '
      'nothing written', () async {
    await insertTestDive(id: 'd2', at: DateTime(2024, 1, 11), diverId: 'me');
    final session = await sitting('p1');
    session
      ..set(photoPinField, 90)
      ..set(photoDiveShiftField, 30);
    holdAddBuddyToDive(
      session,
      diveId: 'd1',
      buddyId: 'b2',
      repository: buddies,
    );
    await db.customStatement("UPDATE media SET dive_id = 'd2' WHERE id = 'p1'");

    await expectLater(
      serviceWith().save(
        mediaId: 'p1',
        diverId: 'me',
        apply: session.applyTo,
        changedCardIds: session.changedCardIds,
        alsoWrite: session.runHeldWrites,
        alsoWriteIsAChange: true,
        diveAtStart: (id: 'd1'),
      ),
      throwsA(isA<PhotoMovedError>()),
    );

    final after = await stored('p1');
    expect(after.item.manualElapsedSeconds, isNull);
    expect(after.diveShiftSeconds, 0);
    expect(await buddies.getBuddiesForDive('d1'), isEmpty);
  });

  // A site attachment's sitting (issue #4527, phase 2): one unlinked from
  // its site before Save, and kept for a dive, is no longer the site's, so
  // its held details are not written to it.
  test(
    'a site attachment unlinked before Save: gone, nothing written',
    () async {
      await insertTestMedia(id: 'a1', siteId: 's1', fileType: 'document');
      final session = await sitting('a1');
      session.set(photoSiteCategoryField, SiteAttachmentCategory.siteMap);
      await db.customStatement(
        "UPDATE media SET site_id = NULL WHERE id = 'a1'",
      );

      await expectLater(
        serviceWith().save(
          mediaId: 'a1',
          diverId: 'me',
          apply: session.applyTo,
          changedCardIds: session.changedCardIds,
          siteAtStart: 's1',
        ),
        throwsA(isA<PhotoGoneError>()),
      );

      expect((await stored('a1')).item.siteCategory, isNull);
    },
  );

  test('a site attachment still the site\'s saves its details', () async {
    await insertTestMedia(id: 'a1', siteId: 's1', fileType: 'document');
    final session = await sitting('a1');
    session.set(photoSiteCategoryField, SiteAttachmentCategory.siteMap);

    await serviceWith().save(
      mediaId: 'a1',
      diverId: 'me',
      apply: session.applyTo,
      changedCardIds: session.changedCardIds,
      siteAtStart: 's1',
    );

    expect(
      (await stored('a1')).item.siteCategory,
      SiteAttachmentCategory.siteMap,
    );
  });

  test('nothing changed: null, and no operation left behind', () async {
    final session = await sitting('p1');

    expect(await save(session), isNull);
    expect(await operations(), isEmpty);
  });

  test(
    'a media row deleted before Save: StateError, nothing written',
    () async {
      final session = await sitting('p1');
      session.set(photoPinField, 90);
      await media.deleteMedia('p1');

      await expectLater(save(session), throwsA(isA<PhotoGoneError>()));
      expect(await reader.read('p1', diverId: 'me'), isNull);
    },
  );

  test('photo tags held: written at Save; a tag added elsewhere meanwhile '
      'is kept; the label names tags', () async {
    final tags = TagRepository();
    final wreck = await tags.getOrCreateTag(
      'Wreck',
      diverId: 'me',
      scope: TagScope.media,
    );
    final macro = await tags.getOrCreateTag(
      'Macro',
      diverId: 'me',
      scope: TagScope.media,
    );
    final night = await tags.getOrCreateTag(
      'Night',
      diverId: 'me',
      scope: TagScope.media,
    );
    final links = TagLinkRepository(TagScope.media);
    await links.replaceTags('p1', [wreck.id]);
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
    final session = await sitting('p1');
    session.set(
      photoTagsField,
      MediaTagEdits.between(session.stored.tags, [macro]),
    );
    await links.replaceTags('p1', [wreck.id, night.id]);

    await save(session);

    final after = await stored('p1');
    expect(after.tags.map((t) => t.id).toSet(), {night.id, macro.id});
    final labelled = [
      for (final op in await operations())
        if (op['label'] != null) op['label'],
    ];
    expect(labelled, ['record_edit:media:tags']);
  });
  group('Locate held (Task 13)', () {
    late LocalCacheDatabase cacheDb;
    late MediaTransferQueueRepository queue;
    final relinkedPath = p.join(Directory.systemTemp.path, 'relinked.jpg');

    /// Reads every file as holding [hash], as the found file still does at
    /// Save unless a test says otherwise.
    Future<({String hash, int sizeBytes})> Function(File) hashAs(String hash) =>
        (_) async => (hash: hash, sizeBytes: 9);

    setUp(() {
      cacheDb = LocalCacheDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
      queue = MediaTransferQueueRepository(database: cacheDb);
    });
    tearDown(() => cacheDb.close());

    Future<List<String>> uploads() async => [
      for (final row
          in await cacheDb
              .customSelect(
                "SELECT media_id FROM media_transfer_queue "
                "WHERE direction = 'upload'",
              )
              .get())
        row.read<String>('media_id'),
    ];

    /// Different bytes from the row's (stamped OLD-HASH by [sittingWithHash]),
    /// so the relink re-uploads.
    RepairProposal locate(EditSession<PhotoRecord> session) => RepairProposal(
      item: session.stored.item,
      confidence: RepairConfidence.edited,
      candidate: RepairCandidate.file(
        path: relinkedPath,
        sizeBytes: 9,
        hash: 'NEW-HASH',
      ),
    );

    /// A sitting on p1, whose row has the content hash [hash].
    Future<EditSession<PhotoRecord>> sittingWithHash(String hash) async {
      await media.stampContentIdentity('p1', contentHash: hash, sizeBytes: 9);
      await changeLog.settleAll();
      await db.customStatement('DELETE FROM change_log_operations');
      return sitting('p1');
    }

    test('a relink held with a tag: one operation; the upload is queued '
        'after the commit', () async {
      final repair = MediaRepairService(
        repository: media,
        queue: queue,
        createBookmark: null,
        writeBookmark: null,
      );
      final session = await sittingWithHash('OLD-HASH');
      session.set(
        photoSpeciesField,
        SpeciesTagEdits.none.toggled(turtle, tagged: true, stored: const []),
      );
      holdRelink(
        session,
        locate(session),
        service: repair,
        hashFile: hashAs('NEW-HASH'),
      );
      expect(session.changedCardIds, {photoFileCardId, photoSpeciesCardId});

      await undoRelinkOnFailure(session, () => save(session));

      final after = await stored('p1');
      expect(after.item.localPath, relinkedPath);
      expect(after.species.map((c) => c.speciesId), ['sp_turtle']);
      final labelled = [
        for (final op in await operations())
          if (op['label'] != null) op['label'],
      ];
      expect(labelled, ['record_edit:media:file,species']);
      expect(await operations(), hasLength(1));
      // Queued only once the write has committed.
      expect(await uploads(), isEmpty);
      final steps = relinkAfterCommit(session);
      expect(steps, isNotEmpty);
      for (final step in steps) {
        await step();
      }
      expect(await uploads(), ['p1']);
    });

    test('a save that fails after the relink: the link is as it was, no '
        'upload is owed, and the new bookmark is taken away', () async {
      final written = <String>[];
      final deleted = <String>[];
      final repair = MediaRepairService(
        repository: media,
        queue: queue,
        createBookmark: (path) async => Uint8List(1),
        writeBookmark: (ref, blob) async => written.add(ref),
        deleteBookmark: (ref) async => deleted.add(ref),
      );
      final session = await sitting('p1');
      holdRelink(
        session,
        locate(session),
        service: repair,
        hashFile: hashAs('NEW-HASH'),
      );
      // A held write after the relink fails (the buddy could not be added).
      session.holdChange(
        'photo:addBuddyToDive:b1',
        cardId: photoPeopleCardId,
        write: () async => throw StateError('the buddy could not be added'),
      );

      await expectLater(
        undoRelinkOnFailure(session, () => save(session)),
        throwsStateError,
      );

      expect((await stored('p1')).item.localPath, isNull);
      expect(written, hasLength(1));
      expect(deleted, written);
      expect(relinkAfterCommit(session), isEmpty);
      expect(await uploads(), isEmpty);
    });

    test('a relink the repair cannot make fails the save: nothing is '
        'written, and the photo stays as it was', () async {
      final repair = MediaRepairService(
        repository: media,
        queue: queue,
        createBookmark: null,
        writeBookmark: null,
      );
      final session = await sittingWithHash('ROW-HASH');
      session.set(
        photoSpeciesField,
        SpeciesTagEdits.none.toggled(turtle, tagged: true, stored: const []),
      );
      // Found as the same bytes, but they are not: the repair skips it.
      holdRelink(
        session,
        RepairProposal(
          item: session.stored.item,
          confidence: RepairConfidence.exact,
          candidate: RepairCandidate.file(
            path: relinkedPath,
            sizeBytes: 9,
            hash: 'OTHER-HASH',
          ),
        ),
        service: repair,
        hashFile: hashAs('OTHER-HASH'),
      );

      await expectLater(
        undoRelinkOnFailure(session, () => save(session)),
        throwsStateError,
      );

      final after = await stored('p1');
      expect(after.item.localPath, isNull);
      expect(after.species, isEmpty);
      expect(relinkAfterCommit(session), isEmpty);
    });

    test('the relink is checked against the photo as stored at Save, not '
        'as it was when the file was found', () async {
      final repair = MediaRepairService(
        repository: media,
        queue: queue,
        createBookmark: null,
        writeBookmark: null,
      );
      await media.stampContentIdentity(
        'p1',
        contentHash: 'FOUND-HASH',
        sizeBytes: 9,
      );
      final session = await sitting('p1');
      // Found with the row's own bytes.
      holdRelink(
        session,
        RepairProposal(
          item: session.stored.item,
          confidence: RepairConfidence.exact,
          candidate: RepairCandidate.file(
            path: relinkedPath,
            sizeBytes: 9,
            hash: 'FOUND-HASH',
          ),
        ),
        service: repair,
        hashFile: hashAs('FOUND-HASH'),
      );
      // Another device stamps other bytes on the row meanwhile.
      await media.stampContentIdentity(
        'p1',
        contentHash: 'RESTAMPED',
        sizeBytes: 12,
      );
      session.rebase(await stored('p1'));

      await expectLater(
        undoRelinkOnFailure(session, () => save(session)),
        throwsStateError,
      );
      expect((await stored('p1')).item.localPath, isNull);
    });

    test('the relink is checked against the row read inside the save, even '
        'when the sitting has not caught up with it', () async {
      final repair = MediaRepairService(
        repository: media,
        queue: queue,
        createBookmark: null,
        writeBookmark: null,
      );
      final session = await sittingWithHash('FOUND-HASH');
      holdRelink(
        session,
        RepairProposal(
          item: session.stored.item,
          confidence: RepairConfidence.exact,
          candidate: RepairCandidate.file(
            path: relinkedPath,
            sizeBytes: 9,
            hash: 'FOUND-HASH',
          ),
        ),
        service: repair,
        hashFile: hashAs('FOUND-HASH'),
      );
      // Another device stamps other bytes on the row, and the sitting has not
      // followed it yet (no rebase).
      await media.stampContentIdentity(
        'p1',
        contentHash: 'RESTAMPED',
        sizeBytes: 12,
      );

      await expectLater(
        undoRelinkOnFailure(session, () => save(session)),
        throwsStateError,
      );
      expect((await stored('p1')).item.localPath, isNull);
    });

    test('Cancel after Locate: nothing is written', () async {
      final repair = MediaRepairService(
        repository: media,
        queue: queue,
        createBookmark: null,
        writeBookmark: null,
      );
      final session = await sitting('p1');
      holdRelink(
        session,
        locate(session),
        service: repair,
        hashFile: hashAs('NEW-HASH'),
      );
      session.dispose();

      expect((await stored('p1')).item.localPath, isNull);
      expect(await operations(), isEmpty);
    });

    // Copilot's review of PR #4658: the file Locate found can change or
    // go between Locate and Save. The diver saw that file, so Save relinks
    // only to the bytes found, and otherwise fails with nothing written.
    test('a file gone between Locate and Save fails the save: nothing is '
        'written', () async {
      final repair = MediaRepairService(
        repository: media,
        queue: queue,
        createBookmark: null,
        writeBookmark: null,
      );
      final session = await sittingWithHash('OLD-HASH');
      session.set(
        photoSpeciesField,
        SpeciesTagEdits.none.toggled(turtle, tagged: true, stored: const []),
      );
      holdRelink(
        session,
        locate(session),
        service: repair,
        hashFile: (file) async =>
            throw FileSystemException('No such file', file.path),
      );

      await expectLater(
        undoRelinkOnFailure(session, () => save(session)),
        throwsA(isA<LocatedFileChangedError>()),
      );

      final after = await stored('p1');
      expect(after.item.localPath, isNull);
      expect(after.species, isEmpty);
      expect(relinkAfterCommit(session), isEmpty);
      expect(await uploads(), isEmpty);
    });

    test('a file changed between Locate and Save fails the save: nothing is '
        'written', () async {
      final repair = MediaRepairService(
        repository: media,
        queue: queue,
        createBookmark: null,
        writeBookmark: null,
      );
      final session = await sittingWithHash('OLD-HASH');
      session.set(
        photoSpeciesField,
        SpeciesTagEdits.none.toggled(turtle, tagged: true, stored: const []),
      );
      // Found as NEW-HASH, edited on disk since.
      holdRelink(
        session,
        locate(session),
        service: repair,
        hashFile: hashAs('EDITED-SINCE'),
      );

      await expectLater(
        undoRelinkOnFailure(session, () => save(session)),
        throwsA(isA<LocatedFileChangedError>()),
      );

      final after = await stored('p1');
      expect(after.item.localPath, isNull);
      expect(after.item.contentHash, 'OLD-HASH');
      expect(after.species, isEmpty);
      expect(await uploads(), isEmpty);
    });
  });

  group('tags the app applied (issue #4727)', () {
    Future<void> appTag(String mediaId, String speciesId) =>
        SpeciesTaggingService(
          tags: MediaSpeciesRepository(),
          media: media,
          species: species,
        ).applyAppTag(
          mediaId: mediaId,
          speciesId: speciesId,
          timing: SightingTiming.straightAway,
          createdSpecies: false,
        );

    test('confirming in a sitting confirms on save', () async {
      await appTag('p1', 'sp_turtle');
      final session = await sitting('p1');
      session.set(
        photoSpeciesField,
        SpeciesTagEdits.none.confirming('sp_turtle'),
      );

      await save(session);

      final tag = await MediaSpeciesRepository().findTag('p1', 'sp_turtle');
      expect(tag!.unconfirmed, isFalse);
    });

    test('untagging an unconfirmed tag in a sitting rejects it, '
        'taking the sighting it created', () async {
      await appTag('p1', 'sp_turtle');
      final session = await sitting('p1');
      final chip = (await stored('p1')).species.single;
      session.set(
        photoSpeciesField,
        SpeciesTagEdits.none.toggled(chip, tagged: false, stored: [chip]),
      );

      await save(session);

      expect(await MediaSpeciesRepository().findTag('p1', 'sp_turtle'), isNull);
      expect(await species.getSightingsForDive('d1'), isEmpty);
    });

    test(
      'a tag the app writes under an open sitting survives its save',
      () async {
        final session = await sitting('p1');
        session.set(
          photoSpeciesField,
          SpeciesTagEdits.none.toggled(
            const SpeciesTagChip(
              speciesId: 'sp_ray',
              storedName: 'Ray',
              category: SpeciesCategory.fish,
              isBuiltIn: false,
            ),
            tagged: true,
            stored: const [],
          ),
        );
        await appTag('p1', 'sp_turtle');

        await save(session);

        final tags = MediaSpeciesRepository();
        expect((await tags.findTag('p1', 'sp_turtle'))!.unconfirmed, isTrue);
        expect((await tags.findTag('p1', 'sp_ray'))!.unconfirmed, isFalse);
      },
    );
  });
}
