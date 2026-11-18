import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_prefill.dart';
import 'package:submersion/features/dive_log/domain/entities/new_dive_request.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_edit_cards.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_environment_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/features/media/presentation/editing/record_media_sitting.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tank_rules.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_tanks_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_weights_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/new_dive_prefill.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/data/services/media_import_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/helpers/media_hold.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder_state.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

/// A new dive's prefills go through the cards' own rules, as changes, and
/// the cards they fill are laid out open (issue #4527, plan 8).
void main() {
  final t0 = DateTime.utc(2026, 3, 9);
  final entry = DateTime.utc(2026, 11, 17, 9, 30);
  const starter = DiveTank(
    id: 'starter',
    volume: 11.1,
    workingPressure: 207,
    startPressure: 200,
    endPressure: 50,
    role: TankRole.backGas,
    presetName: 'al80',
  );
  final seed = Dive(
    id: 'new',
    diverId: 'me',
    diveNumber: 43,
    dateTime: entry,
    entryTime: entry,
    tanks: const [starter],
  );
  final trip = Trip(
    id: 'trip',
    diverId: 'me',
    name: 'Palau',
    startDate: DateTime(2026, 11, 15),
    endDate: DateTime(2026, 11, 22),
    createdAt: t0,
    updatedAt: t0,
  );
  TripCylinderState slot(String id) => TripCylinderState(
    cylinder: TripCylinder(
      id: id,
      tripId: 'trip',
      label: id,
      volume: 12.0,
      workingPressure: 232,
      createdAt: t0,
      updatedAt: t0,
    ),
    pressure: 210,
    mix: const GasMix(o2: 32),
    bottleLabel: id,
    status: TripCylinderStatus.full,
  );
  const reef = DiveSite(id: 'reef', name: 'Blue Corner');

  late EditSession<Dive> session;
  late List<DiveSite?> assigned;

  setUp(() {
    session = EditSession<Dive>(seed, isNew: true);
    // As the sitting's start holds them (startDiveSitting).
    holdSittingMedia(
      session,
      SittingMediaWriters(
        writeRows: (_) async => const [],
        insertNetwork: (_) async => const [],
        unlink: (_) async {},
        replace: (_, _, _) async {},
        drainDeletes: () async {},
        enqueueUpload: (_) async {},
      ),
      cardId: 'media',
    );
    assigned = [];
  });
  tearDown(() {
    if (!session.isDisposed) session.dispose();
  });

  Future<void> apply(
    NewDiveRequest request, {
    Future<Trip?> Function(String)? readTrip,
    List<TripCylinderState> slots = const [],
    Future<PreparedMedia> Function(File, DateTime?)? preparePhoto,
    void Function()? onPhotoFailed,
  }) async {
    applyNewDivePrefill(
      session,
      request,
      assignSite: (s, site) {
        assigned.add(site);
        s.set(diveSiteField, site);
      },
      readTrip: readTrip ?? (id) async => id == 'trip' ? trip : null,
      readSlots: (tripId, at) async => slots,
      onPhotoFailed: onPhotoFailed,
      preparePhoto:
          preparePhoto ??
          (file, takenAt) async => (
            item: MediaItem(
              id: 'photo',
              diveId: 'new',
              mediaType: MediaType.photo,
              sourceType: MediaSourceType.localFile,
              filePath: file.path,
              takenAt: takenAt ?? t0,
              createdAt: t0,
              updatedAt: t0,
            ),
            enrichment: null,
          ),
    );
    if (!session.isDisposed) await session.settled();
  }

  group('the cards laid out', () {
    test('the Dive card and the starter set', () {
      expect(newDiveLaidOutCards(const NewDiveRequest()), [
        diveHeaderCardId,
        'tanks',
        'buddies',
        'notes',
      ]);
    });

    test('and each card a prefill fills', () {
      expect(
        newDiveLaidOutCards(
          const NewDiveRequest(
            prefill: DivePrefill(
              airTempCelsius: 28,
              weightKg: 4,
              photoPath: '/scan.jpg',
            ),
            tripId: 'trip',
          ),
        ),
        containsAll(<String>['environment', 'weights', 'details', 'media']),
      );
    });
  });

  test('no request changes nothing', () async {
    await apply(const NewDiveRequest());
    expect(session.isDirty, isFalse);
  });

  test('a scan is entered: its cards carry the dot', () async {
    await apply(
      NewDiveRequest(
        prefill: DivePrefill(
          diveNumber: 12,
          dateTime: DateTime(2024, 3, 12, 14, 5),
          durationMinutes: 41,
          maxDepthMeters: 18.2,
          waterTempCelsius: 27,
          airTempCelsius: 29,
          rating: 4,
          notes: 'Turtle',
          weightKg: 4,
        ),
      ),
    );

    expect(session.valueOf(diveNumberField), 12.0);
    expect(session.valueOf(diveBottomTimeField), 41 * 60.0);
    expect(session.valueOf(diveMaxDepthField), 18.2);
    expect(session.valueOf(diveWaterTempField), 27.0);
    expect(session.valueOf(diveAirTempField), 29.0);
    expect(session.valueOf(diveRatingField), 4);
    expect(session.valueOf(diveNotesField), 'Turtle');
    final weight = session.valueOf(diveWeightsField).single;
    expect(weight.weightType, WeightType.mixed);
    expect(weight.amountKg, 4.0);
    expect(
      session.changedCardIds,
      containsAll(<String>[
        diveHeaderCardId,
        'notes',
        'environment',
        'weights',
      ]),
    );
  });

  test('a scanned date keeps the time it was opened at', () async {
    await apply(
      NewDiveRequest(prefill: DivePrefill(dateTime: DateTime(2024, 3, 12))),
    );
    expect(session.valueOf(diveEntryField), DateTime.utc(2024, 3, 12, 9, 30));
  });

  test('a scanned time of day is taken with its date', () async {
    await apply(
      NewDiveRequest(
        prefill: DivePrefill(
          dateTime: DateTime(2024, 3, 12, 14, 5),
          hasTimeOfDay: true,
        ),
      ),
    );
    expect(session.valueOf(diveEntryField), DateTime.utc(2024, 3, 12, 14, 5));
  });

  test('a scanned site goes through the site rules', () async {
    await apply(const NewDiveRequest(prefill: DivePrefill(site: reef)));
    expect(assigned, [reef]);
  });

  test('scanned pressures and mix go on the starter cylinder', () async {
    await apply(
      const NewDiveRequest(
        prefill: DivePrefill(
          startPressureBar: 220,
          endPressureBar: 60,
          o2Percent: 32,
        ),
      ),
    );
    final tank = session.valueOf(diveTanksField).single;
    expect(tank.id, 'starter');
    expect(tank.startPressure, 220.0);
    expect(tank.endPressure, 60.0);
    expect(tank.gasMix.o2, 32.0);
    expect(tank.volume, 11.1);
    expect(session.changedCardIds, contains('tanks'));
  });

  test(
    'a passport cylinder with a volume replaces the starter\'s spec',
    () async {
      await apply(
        const NewDiveRequest(
          prefill: DivePrefill(
            tank: DiveTank(
              id: 'tag',
              name: 'Tank 7',
              volume: 15,
              workingPressure: 232,
              gasMix: GasMix(o2: 32),
              passportId: 'pp',
            ),
          ),
        ),
      );
      final tank = session.valueOf(diveTanksField).single;
      expect(tank.id, 'starter');
      expect(tank.volume, 15.0);
      expect(tank.presetName, isNull);
      expect(tank.passportId, 'pp');
      expect(tank.startPressure, 200.0);
    },
  );

  test(
    'the trip board slot puts its cylinder first and sets the trip',
    () async {
      await apply(
        const NewDiveRequest(tripId: 'trip', tripCylinderId: 'slot-1'),
        slots: [slot('slot-1'), slot('slot-2')],
      );
      expect(session.valueOf(diveTripField)?.id, 'trip');
      final tank = session.valueOf(diveTanksField).single;
      expect(tank.id, 'starter');
      expect(tank.tripCylinderId, 'slot-1');
      expect(tank.volume, 12.0);
      expect(tank.gasMix.o2, 32.0);
      expect(suggestedTankIds(session), isNot(contains('starter')));
      expect(session.changedCardIds, containsAll(<String>['details', 'tanks']));
    },
  );

  test('a trip with no slot chosen suggests one for the starter', () async {
    await apply(const NewDiveRequest(tripId: 'trip'), slots: [slot('slot-1')]);
    expect(session.valueOf(diveTanksField).single.tripCylinderId, 'slot-1');
    expect(suggestedTankIds(session), contains('starter'));
  });

  test('a trip that answers after the sitting ended changes nothing', () async {
    final answer = Completer<Trip?>();
    final running = apply(
      const NewDiveRequest(tripId: 'trip'),
      readTrip: (_) => answer.future,
    );
    final before = session.working;
    session.dispose();
    answer.complete(trip);
    await running;
    expect(before.trip, isNull);
  });

  test('the logbook photo is held, not written', () async {
    File? prepared;
    await apply(
      const NewDiveRequest(prefill: DivePrefill(photoPath: '/scans/page.jpg')),
      preparePhoto: (file, takenAt) async {
        prepared = file;
        return (
          item: MediaItem(
            id: 'photo',
            diveId: 'new',
            mediaType: MediaType.photo,
            sourceType: MediaSourceType.localFile,
            filePath: '/copy.jpg',
            takenAt: takenAt ?? t0,
            createdAt: t0,
            updatedAt: t0,
          ),
          enrichment: null,
        );
      },
    );
    expect(prepared!.path, '/scans/page.jpg');
    final held = sittingMedia(session).added.single;
    expect(held, isA<HeldMediaRow>());
    expect(held.preview.takenAt, entry);
    expect(session.changedCardIds, contains('media'));
  });

  test(
    'a photo that cannot be prepared leaves the rest, and says so',
    () async {
      var failed = 0;
      await apply(
        const NewDiveRequest(
          prefill: DivePrefill(photoPath: '/gone.jpg', notes: 'Wall'),
        ),
        preparePhoto: (_, _) async => throw const FileSystemException('gone'),
        onPhotoFailed: () => failed++,
      );
      expect(failed, 1);
      expect(session.valueOf(diveNotesField), 'Wall');
      expect(sittingMedia(session).added, isEmpty);
    },
  );

  // A trip changed while the board's slot was read keeps the diver's trip,
  // and the slot of the other trip is not put on (review of #4672).
  test('a trip changed while its slot is read gets no slot from it', () async {
    final slots = Completer<List<TripCylinderState>>();
    final other = trip.copyWith(id: 'other', name: 'Other');
    applyNewDivePrefill(
      session,
      const NewDiveRequest(tripId: 'trip', tripCylinderId: 'slot-1'),
      assignSite: (_, _) {},
      readTrip: (id) async => trip,
      readSlots: (tripId, at) =>
          tripId == 'trip' ? slots.future : Future.value(const []),
      preparePhoto: (_, _) async => throw StateError('unused'),
    );
    await pumpEventQueue();
    expect(session.valueOf(diveTripField)?.id, 'trip');
    session.set(diveTripField, other);
    slots.complete([slot('slot-1')]);
    await session.settled();

    expect(session.valueOf(diveTripField)?.id, 'other');
    expect(session.valueOf(diveTanksField).single.tripCylinderId, isNull);
  });
}
