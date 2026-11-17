import 'package:flutter_test/flutter_test.dart';
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
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/domain/value_objects/photo_tag_edits.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/editing/photo_held_writes.dart';
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
}
