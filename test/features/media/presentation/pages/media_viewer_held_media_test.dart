import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart' hide Dive, Sighting;
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_edit_save_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_buddies_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_sightings_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields.dart';
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/media/data/repositories/media_color_adjustment_repository.dart';
import 'package:submersion/features/media/data/repositories/media_people_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/data/repositories/site_attachment_repository.dart';
import 'package:submersion/features/media/data/resolvers/media_store_resolver.dart';
import 'package:submersion/features/media/data/services/photo_edit_save_service.dart';
import 'package:submersion/features/media/data/services/photo_record_reader.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/data/services/species_tagging_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_person_tag.dart';
import 'package:submersion/features/media/domain/entities/photo_record.dart';
import 'package:submersion/features/media/domain/entities/species_tag_chip.dart';
import 'package:submersion/features/media/domain/value_objects/photo_tag_edits.dart';
import 'package:submersion/features/media/presentation/editing/photo_edit_fields.dart';
import 'package:submersion/features/media/presentation/editing/photo_held_writes.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/features/media/presentation/helpers/media_link_replacer.dart';
import 'package:submersion/features/media/presentation/pages/media_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media/presentation/providers/media_repair_providers.dart';
import 'package:submersion/features/media/presentation/widgets/dive_media_section.dart';
import 'package:submersion/features/media/presentation/widgets/media_grid.dart';
import 'package:submersion/features/media/presentation/widgets/media_item_view.dart';
import 'package:submersion/features/media/presentation/widgets/media_viewer_toolbar.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/in_memory_media_object_store.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../data/repositories/species_photo_fixtures.dart';
import 'media_viewer_unlock_harness.dart';

/// Task 13 of plan 10 (issue #4527): the photo viewer opened from a dive's
/// sitting, a photo held only in that sitting, and Locate held in the
/// photo's own sitting.
void main() {
  late AppDatabase db;
  final changeLog = ChangeLogRepository();

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await seedViewerData();
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });
  tearDown(tearDownTestDatabase);

  Future<List<Object?>> labels() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect(
          'SELECT label FROM change_log_operations WHERE label IS NOT NULL',
        )
        .get();
    return [for (final row in rows) row.data['label']];
  }

  Future<List<Override>> asDiver() async {
    final diver = MockCurrentDiverIdNotifier();
    await diver.setCurrentDiver('me');
    return [currentDiverIdProvider.overrideWith((ref) => diver)];
  }

  group('opened from the dive\'s sitting', () {
    /// A photo the Media card holds for Save: not stored, so no row.
    final held = MediaItem(
      id: 'n1',
      diveId: 'd1',
      mediaType: MediaType.photo,
      localPath: '/picked/n1.jpg',
      takenAt: DateTime(2024, 1, 10, 9, 5),
      createdAt: DateTime(2026, 11, 16),
      updatedAt: DateTime(2026, 11, 16),
    );

    late LocalCacheDatabase storeDb;
    late Directory storeRoot;

    setUp(() async {
      storeDb = LocalCacheDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
      storeRoot = await Directory.systemTemp.createTemp('held_media_store');
    });
    tearDown(() async {
      await storeDb.close();
      await storeRoot.delete(recursive: true);
    });

    /// A media store connected on this device, so Re-upload is offered.
    List<Override> storeConnected() => [
      mediaStoreResolverProvider.overrideWith(
        (ref) => MediaStoreResolver(
          store: InMemoryMediaObjectStore(),
          cache: MediaCacheStore(database: storeDb, root: storeRoot),
        ),
      ),
      mediaStoreReuploadProvider.overrideWithValue((_, _) async {}),
    ];

    bool offersReupload() =>
        find.byKey(const ValueKey('viewer_reupload')).evaluate().isNotEmpty ||
        find
            .byKey(const ValueKey('viewer_menu_reupload'))
            .evaluate()
            .isNotEmpty;

    Future<RecordEditController<Dive>> pumpCard(WidgetTester tester) async {
      final controller = RecordEditController<Dive>(onSave: (_) async {})
        ..unlock(harnessDive);
      addTearDown(controller.dispose);
      final session = controller.session!;
      holdSittingMedia(
        session,
        SittingMediaWriters(
          writeRows: (_) async => const [],
          insertNetwork: (_) async => const [],
          unlink: (_) async {},
          replace: (_, _, _) async {},
          drainDeletes: () async {},
          enqueueUpload: (_) {},
        ),
        cardId: 'media',
      );
      addMediaToSitting(session, [
        HeldMediaRow((item: held, enrichment: null)),
      ]);
      await pumpViewerApp(
        tester,
        Scaffold(
          body: SingleChildScrollView(
            child: RecordEditScope<Dive>(
              controller: controller,
              child: DiveMediaSection(diveId: 'd1', editing: session),
            ),
          ),
        ),
        // Tall enough for the info sheet's lower sections to be built.
        size: const Size(1280, 2400),
        overrides: storeConnected(),
      );
      return controller;
    }

    Future<void> openTile(WidgetTester tester, String id) async {
      await tester.tap(
        find.byWidgetPredicate(
          (w) => w is MediaThumbnailTile && w.item.id == id,
        ),
      );
      await settleViewer(tester);
    }

    String onScreen(WidgetTester tester) => tester
        .widget<MediaViewerToolbar>(find.byType(MediaViewerToolbar))
        .item
        .id;

    testWidgets('a photo only held in the dive\'s sitting opens on itself, '
        'read only, no unlock', (tester) async {
      await pumpCard(tester);
      final events = await tester.runAsync(() => eventCount(db));

      await openTile(tester, 'n1');

      expect(find.byType(MediaViewerPage), findsOneWidget);
      expect(onScreen(tester), 'n1');
      expect(find.byKey(const ValueKey('viewer_unlock')), findsNothing);
      expect(find.byKey(const ValueKey('viewer_species')), findsNothing);
      expect(find.byKey(const ValueKey('viewer_people')), findsNothing);
      // Nothing is stored yet for the store to take again.
      expect(offersReupload(), isFalse);
      // Its info reads only: no file check or upload for a row that does
      // not exist yet.
      await tester.tap(find.byKey(const ValueKey('viewer_info')));
      await settleViewer(tester);
      expect(find.text('Media info'), findsWidgets);
      expect(find.text('Check now'), findsNothing);
      expect(find.text('Copy now'), findsNothing);
      expect(await tester.runAsync(() => eventCount(db)), events);
    });

    testWidgets('a stored photo opened from the dive\'s sitting has a lock '
        'of its own, and unlocking it leaves the dive\'s sitting open', (
      tester,
    ) async {
      final dive = await pumpCard(tester);

      await openTile(tester, 'p1');

      expect(onScreen(tester), 'p1');
      expect(offersReupload(), isTrue);
      await tapUnlock(tester);
      expect(photoController(tester).isUnlocked, isTrue);
      expect(dive.isUnlocked, isTrue);
      await tester.tap(find.byKey(const ValueKey('viewer_info')));
      await settleViewer(tester);
      expect(find.text('Check now'), findsOneWidget);
    });

    testWidgets('when the dive\'s sitting ends, the viewer pages through the '
        'stored photos again', (tester) async {
      final dive = await pumpCard(tester);
      await openTile(tester, 'p2');
      int total() => tester
          .widget<MediaViewerToolbar>(find.byType(MediaViewerToolbar))
          .totalCount;
      // The three stored photos and the one held.
      expect(total(), 4);

      dive.lock();
      await settleViewer(tester);

      expect(total(), 3);
      expect(onScreen(tester), 'p2');
    });

    testWidgets('the viewer keeps its place and its own sitting when the '
        'dive\'s sitting ends under it', (tester) async {
      final dive = await pumpCard(tester);
      await openTile(tester, 'p2');
      await tapUnlock(tester);
      final viewer = tester.state(find.byType(MediaViewerPage));
      final photo = photoController(tester);

      dive.lock();
      // The dive's photos are read again (a photo synced in, say).
      ProviderScope.containerOf(
        tester.element(find.byType(MediaViewerPage)),
      ).invalidate(mediaForDiveProvider('d1'));
      await settleViewer(tester);

      expect(tester.state(find.byType(MediaViewerPage)), same(viewer));
      expect(onScreen(tester), 'p2');
      expect(photo.isUnlocked, isTrue);
    });
  });

  group('the photo\'s Save, then the dive\'s', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer(
        overrides: [diveRoleMapProvider.overrideWith((ref) async => {})],
      );
      addTearDown(container.dispose);
    });

    PhotoEditSaveService photoSaver() => PhotoEditSaveService(
      reader: PhotoRecordReader(
        media: MediaRepository(),
        species: MediaSpeciesRepository(),
        people: MediaPeopleRepository(),
        tags: TagLinkRepository(TagScope.media),
      ),
      tagging: SpeciesTaggingService(
        tags: MediaSpeciesRepository(),
        media: MediaRepository(),
        species: SpeciesRepository(),
      ),
      people: MediaPeopleRepository(),
      media: MediaRepository(),
      colors: MediaColorAdjustmentRepository(),
      attachments: SiteAttachmentRepository(),
      dives: DiveRepository(),
      tags: TagLinkRepository(TagScope.media),
    );

    Future<EditSession<Dive>> diveSitting() async {
      final dive = (await DiveRepository().getDiveById('d1'))!;
      final session = EditSession<Dive>(dive);
      addTearDown(() {
        if (!session.isDisposed) session.dispose();
      });
      startDiveSitting(session, container.read);
      await session.settled();
      return session;
    }

    Future<void> saveDive(EditSession<Dive> session) =>
        DiveEditSaveService(DiveRepository(), TripRepository()).save(
          diveId: 'd1',
          apply: (stored) => diveSittingApply(session, stored),
          changedCardIds: session.changedCardIds,
          writeFirst: session.hasHeldWritesBeforeRecord
              ? () => session.runHeldWrites(beforeRecord: true)
              : null,
          alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
          alsoWriteIsAChange: session.hasHeldChanges,
        );

    Future<void> savePhoto(EditSession<PhotoRecord> session) =>
        photoSaver().save(
          mediaId: session.stored.item.id,
          diverId: 'me',
          apply: session.applyTo,
          changedCardIds: session.changedCardIds,
          alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
          alsoWriteIsAChange: session.hasHeldChanges,
        );

    Future<EditSession<PhotoRecord>> photoSitting(String id) async {
      final stored = await PhotoRecordReader(
        media: MediaRepository(),
        species: MediaSpeciesRepository(),
        people: MediaPeopleRepository(),
        tags: TagLinkRepository(TagScope.media),
      ).read(id, diverId: 'me');
      final session = EditSession<PhotoRecord>(stored!);
      addTearDown(() {
        if (!session.isDisposed) session.dispose();
      });
      return session;
    }

    test('a photo opened from the dive\'s sitting: its Save adds a sighting; '
        'the dive\'s sitting then Saves and the sighting survives', () async {
      await insertTestSpecies(id: 'sp_ray', name: 'Ray');
      final dive = await diveSitting();
      // The dive's sitting changes its sightings too, from the list it
      // loaded before the photo was saved.
      diveSightingsList.set(dive, [
        const Sighting(
          id: 's-ray',
          diveId: 'd1',
          speciesId: 'sp_ray',
          speciesName: 'Ray',
        ),
      ]);
      final photo = await photoSitting('p1');
      photo.set(
        photoSpeciesField,
        SpeciesTagEdits.none.toggled(
          const SpeciesTagChip(
            speciesId: 'sp_turtle',
            storedName: 'Turtle',
            category: SpeciesCategory.fish,
            isBuiltIn: false,
          ),
          tagged: true,
          stored: const [],
        ),
      );

      await savePhoto(photo);
      await saveDive(dive);

      final sightings = await SpeciesRepository().getSightingsForDive('d1');
      expect(sightings.map((s) => s.speciesId).toSet(), {
        'sp_turtle',
        'sp_ray',
      });
    });

    test('a buddy the photo\'s Save added survives the dive\'s Save that '
        'changed Buddies', () async {
      final dive = await diveSitting();
      final bo = (await BuddyRepository().getBuddyById('b2'))!;
      diveBuddiesList.set(dive, [
        BuddyWithRole(buddy: bo, roles: [DiveRole.synthetic(DiveRole.buddyId)]),
      ]);
      final photo = await photoSitting('p1');
      photo.set(
        photoPeopleField,
        PersonTagEdits.none.add(
          MediaPersonChip(
            tag: MediaPersonTag(
              id: 'local1',
              mediaId: 'p1',
              buddyId: 'b1',
              createdAt: DateTime.utc(2026, 11, 16),
              updatedAt: DateTime.utc(2026, 11, 16),
            ),
          ),
          stored: const [],
          isVideo: false,
        ),
      );
      holdAddBuddyToDive(
        photo,
        diveId: 'd1',
        buddyId: 'b1',
        repository: BuddyRepository(),
      );

      await savePhoto(photo);
      expect(
        (await BuddyRepository().getBuddiesForDive(
          'd1',
        )).map((b) => b.buddy.id),
        ['b1'],
      );
      await saveDive(dive);

      final onDive = await BuddyRepository().getBuddiesForDive('d1');
      expect(onDive.map((b) => b.buddy.id).toSet(), {'b1', 'b2'});
    });
  });

  group('Locate in the photo\'s sitting', () {
    late LocalCacheDatabase cacheDb;

    setUp(() async {
      cacheDb = LocalCacheDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
      addTearDown(cacheDb.close);
      // p1's file is missing, so the info sheet offers Locate.
      await db.customStatement(
        "UPDATE media SET source_type = 'localFile', "
        "local_path = '/gone/p1.jpg', is_orphaned = 1 WHERE id = 'p1'",
      );
      await changeLog.settleAll();
      await db.customStatement('DELETE FROM change_log_operations');
    });

    Future<void> pump(
      WidgetTester tester, {
      MediaRepairService? repair,
      Future<({String hash, int sizeBytes})> Function(File file)? hash,
    }) async {
      final items = await tester.runAsync(() => storedMedia(['p1', 'p2']));
      final diver = (await tester.runAsync(asDiver))!;
      await pumpViewerApp(
        tester,
        MediaViewerPage(mediaList: items!, initialMediaId: 'p1'),
        size: const Size(1280, 2400),
        overrides: [
          ...diver,
          mediaLinkFileSourceProvider.overrideWithValue(
            MediaLinkFileSource(
              pick: () async => '/found/p1.jpg',
              hash: hash ?? (_) async => (hash: 'same', sizeBytes: 9),
            ),
          ),
          mediaRepairServiceProvider.overrideWithValue(
            repair ??
                MediaRepairService(
                  repository: MediaRepository(),
                  queue: MediaTransferQueueRepository(database: cacheDb),
                  createBookmark: null,
                  writeBookmark: null,
                ),
          ),
        ],
      );
    }

    Future<void> saveAndWait(WidgetTester tester) async {
      await tester.tap(find.text('Save'));
      // Until the save's transaction has ended: a read of the database
      // while it runs would wait on a write the test's clock is not moving.
      for (var i = 0; i < 100 && photoController(tester).isSaving; i++) {
        await settleViewer(tester, rounds: 1);
      }
      await settleViewer(tester);
    }

    MediaItem drawn(WidgetTester tester) => tester
        .widgetList<MediaItemView>(find.byType(MediaItemView))
        .map((v) => v.item)
        .firstWhere((item) => item.id == 'p1');

    Future<void> locate(
      WidgetTester tester, {
      bool confirmOtherBytes = false,
    }) async {
      await tapUnlock(tester);
      await tester.tap(find.byKey(const ValueKey('viewer_info')));
      await settleViewer(tester);
      await tester.tap(find.text('Locate file...'));
      await settleViewer(tester);
      if (confirmOtherBytes) {
        await tester.tap(find.text('Re-link'));
        await settleViewer(tester);
      }
      Navigator.of(tester.element(find.text('Media info').last)).pop();
      await settleViewer(tester);
    }

    Future<String?> storedPath(WidgetTester tester) async =>
        (await tester.runAsync(
          () => MediaRepository().getMediaById('p1'),
        ))!.localPath;

    Future<List<String>> uploads(WidgetTester tester) async =>
        (await tester.runAsync(
          () async => [
            for (final row
                in await cacheDb
                    .customSelect(
                      "SELECT media_id FROM media_transfer_queue "
                      "WHERE direction = 'upload'",
                    )
                    .get())
              row.read<String>('media_id'),
          ],
        ))!;

    testWidgets('Locate in a sitting: held, the viewer shows the new file, '
        'Save relinks in the same entry and then queues the upload', (
      tester,
    ) async {
      // The file found has other bytes than the row's, so the relink owes
      // the store a new upload, queued once the save has committed.
      await tester.runAsync(
        () => db.customStatement(
          "UPDATE media SET content_hash = 'OLD-HASH' WHERE id = 'p1'",
        ),
      );
      await pump(tester);

      await locate(tester, confirmOtherBytes: true);

      expect(drawn(tester).localPath, '/found/p1.jpg');
      expect(drawn(tester).isOrphaned, isFalse);
      expect(await storedPath(tester), '/gone/p1.jpg');

      await tester.tap(find.text('Save'));
      // Until the save's transaction has ended: a read of the database
      // while it runs would wait on a write the test's clock is not moving.
      for (var i = 0; i < 100 && photoController(tester).isSaving; i++) {
        await settleViewer(tester, rounds: 1);
      }
      await settleViewer(tester);

      expect(photoController(tester).isUnlocked, isFalse);
      expect(await storedPath(tester), '/found/p1.jpg');
      expect(await tester.runAsync(labels), ['record_edit:media:file']);
      expect(await uploads(tester), ['p1']);
      // The viewer goes on drawing the file the photo now points at, once
      // the row's change has come through (its tick is debounced).
      await tester.pump(const Duration(seconds: 1));
      await settleViewer(tester);
      expect(drawn(tester).localPath, '/found/p1.jpg');
    });

    // Copilot's review of PR #4658: the file Locate found can change or go
    // before Save. Save is refused, and the diver is told to locate it again
    // rather than handed the plain failure to retry.
    testWidgets('a located file edited before Save: the save is refused and '
        'says to locate it again', (tester) async {
      var bytes = 'same';
      await pump(tester, hash: (_) async => (hash: bytes, sizeBytes: 9));
      await locate(tester);
      bytes = 'edited since';

      await saveAndWait(tester);

      expect(photoController(tester).isUnlocked, isTrue);
      expect(await storedPath(tester), '/gone/p1.jpg');
      expect(
        find.text(
          'The file you located has changed or moved since. Locate it again, '
          'or cancel.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a Save that fails after the relink takes its new bookmark '
        'back, and the photo stays unlocked with the change', (tester) async {
      final written = <String>[];
      final deleted = <String>[];
      await pump(
        tester,
        repair: MediaRepairService(
          repository: MediaRepository(),
          queue: MediaTransferQueueRepository(database: cacheDb),
          createBookmark: (path) async => Uint8List(1),
          writeBookmark: (ref, blob) async => written.add(ref),
          deleteBookmark: (ref) async => deleted.add(ref),
        ),
      );
      await locate(tester);
      // A held write after the relink fails (the buddy could not be added).
      photoController(tester).session!.holdChange(
        'photo:addBuddyToDive:b1',
        cardId: photoPeopleCardId,
        write: () async => throw StateError('the buddy could not be added'),
      );

      await saveAndWait(tester);

      expect(photoController(tester).isUnlocked, isTrue);
      expect(written, hasLength(1));
      expect(deleted, written);
      expect(await storedPath(tester), '/gone/p1.jpg');
    });

    testWidgets('Locate in a sitting, then Cancel: the link is as it was', (
      tester,
    ) async {
      await pump(tester);
      final events = await tester.runAsync(() => eventCount(db));

      await locate(tester);
      await tester.tap(find.text('Cancel'));
      await settleViewer(tester);
      await tester.tap(find.text('Discard'));
      await settleViewer(tester);

      expect(photoController(tester).isUnlocked, isFalse);
      expect(drawn(tester).localPath, '/gone/p1.jpg');
      expect(await storedPath(tester), '/gone/p1.jpg');
      expect(await tester.runAsync(() => eventCount(db)), events);
    });
  });
}
