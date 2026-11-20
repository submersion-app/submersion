import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart' hide Dive, Trip;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/features/trips/data/repositories/itinerary_day_repository.dart';
import 'package:submersion/features/trips/data/repositories/liveaboard_details_repository.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/data/services/trip_edit_save_service.dart';
import 'package:submersion/features/trips/domain/entities/dive_candidate.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/editing/trip_dives_sitting.dart';
import 'package:submersion/features/trips/presentation/editing/trip_photos_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// The photos a trip's scans find, held in its sitting and written at Save
/// to their own dives, in the trip's History entry (issue #4527).
void main() {
  late AppDatabase db;
  late TripRepository trips;
  late TripEditSaveService service;
  final changeLog = ChangeLogRepository();
  final uploads = <String>[];
  final at = DateTime.utc(2030, 6, 2, 9);

  MediaItem photo(String id, String diveId) => MediaItem(
    id: id,
    diveId: diveId,
    mediaType: MediaType.photo,
    sourceType: MediaSourceType.platformGallery,
    platformAssetId: 'asset-$id',
    takenAt: at,
    createdAt: at,
    updatedAt: at,
  );

  Future<EditSession<Trip>> open() async {
    final session = EditSession<Trip>((await trips.getTripById('t1'))!);
    // The app's writers but for the row write, which needs no enrichment
    // service here, and the upload queue, recorded.
    holdSittingMedia(
      session,
      SittingMediaWriters(
        writeRows: (prepared) async => [
          for (final p in prepared)
            (await MediaRepository().createMedia(p.item)).id,
        ],
        insertNetwork: (_) async => const [],
        unlink: (_) async {},
        replace: (_, _, _) async {},
        drainDeletes: () async {},
        enqueueUpload: uploads.add,
      ),
      cardId: 'photos',
    );
    return session;
  }

  Future<void> save(EditSession<Trip> session) async {
    await undoMediaOnFailure(
      session,
      () => service.save(
        tripId: 't1',
        apply: session.applyTo,
        changedCardIds: session.changedCardIds,
        actingDiverId: 'me',
        alsoWrite: session.runHeldWrites,
        alsoWriteIsAChange: session.hasHeldChanges,
      ),
    );
    for (final step in mediaAfterCommit(session)) {
      await step();
    }
  }

  Future<List<String>> storedPhotoIds() async => [
    for (final r in await db.customSelect('SELECT id FROM media').get())
      r.read<String>('id'),
  ];

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = OFF');
    addTearDown(SyncCoordinator.reset);
    uploads.clear();
    final days = ItineraryDayRepository();
    trips = TripRepository(itineraryDays: days);
    service = TripEditSaveService(trips, days, LiveaboardDetailsRepository());
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('me'),
            name: Value('Me'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    await trips.createTrip(
      Trip(
        id: 't1',
        diverId: 'me',
        name: 'Red Sea',
        startDate: DateTime(2030, 6, 1),
        endDate: DateTime(2030, 6, 8),
        createdAt: at,
        updatedAt: at,
      ),
    );
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test('scanned photos are written at Save to their dives in the trip '
      'entry, uploads queued after, and a revert takes them back', () async {
    final session = await open();
    addMediaToSitting(session, [
      HeldMediaRow((item: photo('m1', 'd1'), enrichment: null)),
      HeldMediaRow((item: photo('m2', 'd2'), enrichment: null)),
    ]);

    expect(session.changedCardIds, {'photos'});
    expect(await storedPhotoIds(), isEmpty);
    await save(session);

    expect(await storedPhotoIds(), unorderedEquals(['m1', 'm2']));
    expect(uploads, unorderedEquals(['m1', 'm2']));
    await changeLog.settleAll();
    final op = await db
        .customSelect('SELECT id, label FROM change_log_operations')
        .getSingle();
    expect(op.read<String>('label'), 'record_edit:trips:t1:photos');

    final revert = ChangeLogRevertService(afterDiveWrites: (_) {});
    await revert.execute(await revert.planOperation(op.read<String>('id')));
    expect(await storedPhotoIds(), isEmpty);
  });

  test('a held photo taken out is not written; with none left nothing is '
      'held', () async {
    final session = await open();
    addMediaToSitting(session, [
      HeldMediaRow((item: photo('m1', 'd1'), enrichment: null)),
    ]);

    takeOutHeldPhoto(session, 'm1');

    expect(heldTripPhotos(session), isEmpty);
    expect(session.changedCardIds, isEmpty);
  });

  test('a dive taken out takes its held photos with it, and leaves the '
      "other dives' photos", () async {
    final session = await open();
    holdScannedDives(
      session,
      trips,
      [
        DiveCandidate(
          dive: Dive(id: 'd1', dateTime: at),
        ),
        DiveCandidate(
          dive: Dive(id: 'd2', dateTime: at),
        ),
      ],
      ['d1', 'd2'],
    );
    addMediaToSitting(session, [
      HeldMediaRow((item: photo('m1', 'd1'), enrichment: null)),
      HeldMediaRow((item: photo('m2', 'd2'), enrichment: null)),
    ]);

    takeOutScannedDive(session, trips, 'd1');

    expect([for (final p in heldTripPhotos(session)) p.id], ['m2']);
    expect([for (final d in scannedDivesOf(session).dives) d.id], ['d2']);
  });

  test('Cancel writes no photo and queues no upload', () async {
    final session = await open();
    addMediaToSitting(session, [
      HeldMediaRow((item: photo('m1', 'd1'), enrichment: null)),
    ]);

    session.dispose();

    expect(await storedPhotoIds(), isEmpty);
    expect(uploads, isEmpty);
  });
}
