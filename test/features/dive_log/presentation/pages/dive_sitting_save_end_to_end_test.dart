import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/annotation_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_edit_save_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_annotations_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_sitting.dart';
import 'package:submersion/features/documents/presentation/editing/record_document_links_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_sightings_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A sitting that changes several of plan 6's cards at once, saved by the
/// real save service: one transaction and one History entry, or nothing
/// at all (issue #4527, plan 6).
void main() {
  late AppDatabase db;
  late ProviderContainer container;
  late DiveRepository dives;
  late DiveEditSaveService service;
  final changeLog = ChangeLogRepository();
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);
  final ana = Buddy(id: 'b1', name: 'Ana', createdAt: epoch, updatedAt: epoch);
  late Document card;
  late String turtle;

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    dives = DiveRepository();
    service = DiveEditSaveService(dives, TripRepository());
    container = ProviderContainer(
      overrides: [diveRoleMapProvider.overrideWith((ref) async => {})],
    );
    await db.customStatement(
      'INSERT INTO divers (id, name, created_at, updated_at) '
      "VALUES ('me', 'Me', 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO dives (id, diver_id, dive_date_time, created_at, '
      "updated_at) VALUES ('d1', 'me', 0, 0, 0)",
    );
    await db.customStatement(
      'INSERT INTO buddies (id, diver_id, name, created_at, updated_at) '
      "VALUES ('b1', 'me', 'Ana', 0, 0)",
    );
    turtle = (await SpeciesRepository().createSpecies(
      commonName: 'Turtle',
      category: SpeciesCategory.turtle,
    )).id;
    // Made at once as Personal, as the Documents card's Add does.
    card = await DocumentRepository().save(
      Document(
        id: '',
        diverId: 'me',
        owner: const DocumentOwner.personal(),
        type: DocumentType.permit,
        title: 'Permit',
        createdAt: epoch,
        updatedAt: epoch,
      ),
      const [],
    );
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  Future<EditSession<Dive>> started() async {
    final dive = (await dives.getDiveById('d1'))!;
    final session = EditSession<Dive>(dive);
    addTearDown(() {
      if (!session.isDisposed) session.dispose();
    });
    startDiveSitting(session, container.read);
    await session.settled();
    return session;
  }

  /// A buddy, a sighting, an annotation and a document, all in one sitting.
  void changeEveryCard(EditSession<Dive> session) {
    diveBuddiesList.set(session, [
      BuddyWithRole(buddy: ana, roles: [DiveRole.synthetic(DiveRole.buddyId)]),
    ]);
    diveSightingsList.set(session, [
      Sighting(
        id: 's1',
        diveId: 'd1',
        speciesId: turtle,
        speciesName: 'Turtle',
      ),
    ]);
    expect(
      placeAnnotation(session, seconds: 60, words: 'Turtle here'),
      isNotNull,
    );
    attachDocument(session, card);
  }

  Future<void> save(EditSession<Dive> session) => service.save(
    diveId: 'd1',
    apply: (stored) => diveSittingApply(session, stored),
    changedCardIds: session.changedCardIds,
    writeFirst: session.hasHeldWritesBeforeRecord
        ? () => session.runHeldWrites(beforeRecord: true)
        : null,
    alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
    alsoWriteIsAChange: session.hasHeldChanges,
  );

  Future<({int buddies, int sightings, int annotations, String? documentDive})>
  stored() async => (
    buddies: (await BuddyRepository().getBuddiesForDive('d1')).length,
    sightings: (await SpeciesRepository().getSightingsForDive('d1')).length,
    annotations: (await AnnotationRepository().annotationsForDive('d1')).length,
    documentDive: (await DocumentRepository().getForOwner(
      const DocumentOwner(DocumentOwnerKind.dive, 'd1'),
      diverId: 'me',
    )).map((d) => d.id).firstOrNull,
  );

  test(
    'a change on several cards: one History entry naming them all',
    () async {
      final session = await started();
      changeEveryCard(session);
      expect(
        session.changedCardIds,
        containsAll(['buddies', 'sightings', 'notes', 'documents']),
      );

      await save(session);

      final now = await stored();
      expect(now.buddies, 1);
      expect(now.sightings, 1);
      expect(now.annotations, 1);
      expect(now.documentDive, card.id);
      await changeLog.settleAll();
      final operations = await db
          .customSelect('SELECT label FROM change_log_operations')
          .get();
      expect(operations, hasLength(1));
      final label = operations.single.read<String>('label');
      for (final cardId in ['buddies', 'sightings', 'notes', 'documents']) {
        expect(label, contains(cardId));
      }
    },
  );

  test('Cancel after a change on several cards: nothing written; the buddy, '
      'species and document made on the way remain', () async {
    final session = await started();
    changeEveryCard(session);
    unlinkMediaInSitting(session, {'m1'});
    expect(session.isDirty, isTrue);

    session.dispose();

    final now = await stored();
    expect(now.buddies, 0);
    expect(now.sightings, 0);
    expect(now.annotations, 0);
    expect(now.documentDive, isNull);
    expect((await dives.getDiveById('d1'))!.notes, isEmpty);
    expect(await BuddyRepository().getBuddyById('b1'), isNotNull);
    expect(await SpeciesRepository().getSpeciesById(turtle), isNotNull);
    expect(
      (await DocumentRepository().getForOwner(
        const DocumentOwner.personal(),
        diverId: 'me',
      )).map((d) => d.id),
      [card.id],
    );
  });

  test('a Save whose media write throws: no buddy, sighting, annotation or '
      'document written', () async {
    final session = await started();
    changeEveryCard(session);
    holdSittingMedia(
      session,
      SittingMediaWriters(
        writeRows: (_) async => const [],
        insertNetwork: (_) async => const [],
        unlink: (_) async => throw StateError('media store is gone'),
        replace: (_, _, _) async {},
        drainDeletes: () async {},
        enqueueUpload: (_) {},
      ),
      cardId: 'media',
    );
    unlinkMediaInSitting(session, {'m1'});

    await expectLater(save(session), throwsStateError);

    final now = await stored();
    expect(now.buddies, 0);
    expect(now.sightings, 0);
    expect(now.annotations, 0);
    expect(now.documentDive, isNull);
    expect(mediaAfterCommit(session), isEmpty);
  });

  test('a sighting synced in during the sitting survives a Save that changed '
      'Buddies', () async {
    final session = await started();
    diveBuddiesList.set(session, [
      BuddyWithRole(buddy: ana, roles: [DiveRole.synthetic(DiveRole.buddyId)]),
    ]);
    // Arrives from another device while the sitting is open.
    await SpeciesRepository().addSighting(diveId: 'd1', speciesId: turtle);

    await save(session);

    final now = await stored();
    expect(now.buddies, 1);
    expect(now.sightings, 1);
  });
}
