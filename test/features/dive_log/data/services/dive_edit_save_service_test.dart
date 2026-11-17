import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/app_enums.dart';
import 'package:submersion/core/database/database.dart'
    hide Dive, DiveCenter, DiveCustomField, DiveWeight, Tag, Trip;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_edit_save_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_altitude_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_details_fields.dart';
import 'package:submersion/features/dive_log/presentation/widgets/visibility_input/visibility_entry.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/features/trips/data/repositories/trip_repository.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/domain/services/trip_date_stretch.dart';

import '../../../../core/database/change_log/change_log_support.dart';
import '../../../../helpers/test_database.dart';

/// Trips whose dates cannot be moved.
class _NoStretch extends TripRepository {
  @override
  Future<List<TripDateStretch>> stretchToCoverDives(
    List<String> diveIds,
  ) async => throw StateError('the trip could not be stretched');
}

/// An editing sitting is saved in one transaction and one change log
/// operation, and writes only what the diver changed onto the dive as it is
/// stored at that moment (issue #4527).
void main() {
  late AppDatabase db;
  late DiveEditSaveService service;
  late Tag wreck;
  late Tag night;
  final changeLog = ChangeLogRepository();
  final tags = TagRepository();
  // Built per test: a repository made for an earlier test's database must
  // not be reused on this one.
  late DiveRepository dives;
  late TripRepository trips;
  final epoch = DateTime.fromMillisecondsSinceEpoch(0);

  Future<Dive> stored() async => (await dives.getDiveById('dive'))!;

  Future<List<Map<String, Object?>>> operations() async {
    await changeLog.settleAll();
    final rows = await db
        .customSelect('SELECT id, source, label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.data];
  }

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    dives = DiveRepository();
    trips = TripRepository();
    service = DiveEditSaveService(dives, trips);
    await insertDiver(db, 'me');
    await insertDive(db, 'dive', diverId: 'me', notes: 'Calm');
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'site',
            name: 'Lake',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await db
        .into(db.diveTanks)
        .insert(DiveTanksCompanion.insert(id: 'tank', diveId: 'dive'));
    wreck = await tags.createTag(
      Tag(
        id: 'wreck',
        diverId: 'me',
        name: 'Wreck',
        createdAt: epoch,
        updatedAt: epoch,
      ),
    );
    night = await tags.createTag(
      Tag(
        id: 'night',
        diverId: 'me',
        name: 'Night',
        createdAt: epoch,
        updatedAt: epoch,
      ),
    );
    // One save through the repository, so the dive is stored the way the
    // app stores it, with children of several kinds. What follows then
    // shows only what a sitting itself writes.
    await dives.updateDive(
      (await stored()).copyWith(
        diveTypeIds: const ['shore'],
        tags: [wreck, night],
        weights: const [
          DiveWeight(
            id: 'weight',
            diveId: 'dive',
            weightType: WeightType.belt,
            amountKg: 4,
          ),
        ],
        customFields: const [
          DiveCustomField(id: 'field', key: 'Boat', value: 'Aggressor'),
        ],
      ),
    );
    // The children really are there, so the tests below prove the writers
    // for each of them leave an untouched row alone.
    final seeded = await stored();
    expect(seeded.tanks, hasLength(1));
    expect(seeded.weights, hasLength(1));
    expect(seeded.customFields, hasLength(1));
    expect(seeded.tags, hasLength(2));
    expect(seeded.diveTypeIds, ['shore']);
    await changeLog.settleAll();
    await clearLog(db);
    await db.customStatement('DELETE FROM change_log_operations');
  });
  tearDown(tearDownTestDatabase);

  test('a notes-only save records exactly one changed field', () async {
    final result = await service.save(
      diveId: 'dive',
      apply: (dive) => dive.copyWith(notes: 'Current'),
      changedCardIds: ['notes'],
    );

    expect(result!.before.notes, 'Calm');
    expect(result.after.notes, 'Current');
    final events = await logEvents(db);
    expect(
      [for (final e in events) e['table_name']],
      ['dives'],
      reason:
          'an extra table here names a writer in updateDive that rewrites '
          'rows it should have left alone',
    );
    expect(await logFields(db, events.single['id']! as int), {
      'notes': ('Calm', 'Current'),
    });
  });

  test('one sitting is one operation, labelled with its cards', () async {
    await service.save(
      diveId: 'dive',
      apply: (dive) => dive.copyWith(notes: 'Current', tags: [wreck]),
      changedCardIds: ['tags', 'notes'],
    );

    final operation = (await operations()).single;
    expect(operation['source'], 'manual');
    expect(operation['label'], 'record_edit:dives:dive:notes,tags');
  });

  test('changes are applied to the dive as stored at save time', () async {
    // Something else changes the stored dive after the sitting began.
    await dives.updateDive((await stored()).copyWith(rating: 5));

    await service.save(
      diveId: 'dive',
      apply: (dive) => dive.copyWith(notes: 'Current'),
      changedCardIds: ['notes'],
    );

    final saved = await stored();
    expect(saved.notes, 'Current');
    expect(saved.rating, 5);
  });

  test('a sitting that changes nothing writes nothing', () async {
    final result = await service.save(
      diveId: 'dive',
      apply: (dive) => dive,
      changedCardIds: const [],
    );

    expect(result, isNull);
    expect(await logEvents(db), isEmpty);
    expect(await operations(), isEmpty);
  });

  test('a dive that no longer exists throws and writes nothing', () async {
    await dives.deleteDive('dive');
    await changeLog.settleAll();
    await clearLog(db);

    await expectLater(
      service.save(
        diveId: 'dive',
        apply: (dive) => dive.copyWith(notes: 'x'),
        changedCardIds: ['notes'],
      ),
      throwsStateError,
    );

    expect(await logEvents(db), isEmpty);
  });

  test('a write the repository rejects leaves the dive unchanged', () async {
    // updateDive refuses a tank with an empty id.
    await expectLater(
      service.save(
        diveId: 'dive',
        apply: (dive) => dive.copyWith(
          notes: 'Current',
          tanks: [dive.tanks.first.copyWith(id: '')],
        ),
        changedCardIds: ['notes'],
      ),
      throwsArgumentError,
    );

    expect((await stored()).notes, 'Calm');
    expect(await logEvents(db), isEmpty);
  });

  test('reverting the sitting restores what it changed', () async {
    await service.save(
      diveId: 'dive',
      apply: (dive) => dive.copyWith(notes: 'Current', tags: const []),
      changedCardIds: ['notes', 'tags'],
    );
    expect((await stored()).tags, isEmpty);
    final operationId = (await operations()).single['id']! as String;

    final revert = ChangeLogRevertService(afterDiveWrites: (_) {});
    await revert.execute(await revert.planOperation(operationId));

    final reverted = await stored();
    expect(reverted.notes, 'Calm');
    expect(reverted.tags.map((tag) => tag.id).toSet(), {'wreck', 'night'});
  });

  // The dive's writer stores every column it is handed, so a value the diver
  // emptied reaches storage only if the field hands it a null.
  test('a cleared altitude is stored as null', () async {
    await dives.updateDive(
      (await stored()).copyWith(altitude: 900, surfacePressure: 0.9),
    );
    await changeLog.settleAll();
    await clearLog(db);
    expect((await stored()).altitude, 900);

    await service.save(
      diveId: 'dive',
      apply: (dive) => diveAltitudeField.write(dive, null),
      changedCardIds: ['altitude'],
    );

    final saved = await stored();
    expect(saved.altitude, isNull);
    expect(saved.surfacePressure, 0.9);
    final events = await logEvents(db);
    expect(await logFields(db, events.single['id']! as int), {
      'altitude': (900.0, null),
    });
  });

  // A sitting can owe a write to another record: the altitude a lookup
  // found, copied back to the dive's site. It is written with the sitting.
  group('a write to another record', () {
    Future<double?> siteAltitude() async {
      final row = await db
          .customSelect("SELECT altitude FROM dive_sites WHERE id = 'site'")
          .getSingle();
      return row.data['altitude'] as double?;
    }

    test('is written in the same History entry as the dive', () async {
      final sites = SiteRepository();

      await service.save(
        diveId: 'dive',
        apply: (dive) => dive.copyWith(notes: 'Current'),
        changedCardIds: ['notes'],
        alsoWrite: () => sites.updateSiteAltitude('site', 512),
      );

      expect((await stored()).notes, 'Current');
      expect(await siteAltitude(), 512);
      final operation = (await operations()).single;
      final events = await logEvents(db);
      expect(
        {for (final e in events) e['table_name']},
        {'dives', 'dive_sites'},
      );
      expect({for (final e in events) e['operation_id']}, {operation['id']});
    });

    test('that fails rolls the dive write back', () async {
      await expectLater(
        service.save(
          diveId: 'dive',
          apply: (dive) => dive.copyWith(notes: 'Current'),
          changedCardIds: ['notes'],
          alsoWrite: () async => throw StateError('no'),
        ),
        throwsStateError,
      );

      expect((await stored()).notes, 'Calm');
      expect(await logEvents(db), isEmpty);
    });

    test('that fails part way leaves the other record as it was', () async {
      final sites = SiteRepository();

      await expectLater(
        service.save(
          diveId: 'dive',
          apply: (dive) => dive.copyWith(notes: 'Current'),
          changedCardIds: ['notes'],
          alsoWrite: () async {
            await sites.updateSiteAltitude('site', 512);
            throw StateError('no');
          },
        ),
        throwsStateError,
      );

      expect((await stored()).notes, 'Calm');
      expect(await siteAltitude(), isNull);
      expect(await logEvents(db), isEmpty);
    });

    // A dismissed suggestion or a location added to the site changes no
    // dive value: the held write is the change (issue #4527, plan 4).
    test(
      'a held change with no dive change is written, in one entry',
      () async {
        final result = await service.save(
          diveId: 'dive',
          apply: (dive) => dive,
          changedCardIds: ['header'],
          alsoWrite: () => dives.setSiteSuggestionDismissed('dive', true),
          alsoWriteIsAChange: true,
        );

        expect(result, isNotNull);
        expect(result!.before, result.after);
        expect(result.tripDateStretches, isEmpty);
        final row = await db
            .customSelect(
              "SELECT site_suggestion_dismissed_at AS at FROM dives "
              "WHERE id = 'dive'",
            )
            .getSingle();
        expect(row.data['at'], isNotNull);
        final operation = (await operations()).single;
        expect(operation['label'], 'record_edit:dives:dive:header');
        final events = await logEvents(db);
        expect(events, isNotEmpty);
        expect({for (final e in events) e['operation_id']}, {operation['id']});
      },
    );

    // A reassign moves readings between cylinder rows that must both still
    // exist: it runs before the dive's rows are written (issue #4527).
    test(
      'writeFirst runs before the dive is written, in the same entry',
      () async {
        String? notesSeen;

        await service.save(
          diveId: 'dive',
          apply: (dive) => dive.copyWith(notes: 'Changed'),
          changedCardIds: ['tanks'],
          writeFirst: () async =>
              notesSeen = (await dives.getDiveById('dive'))!.notes,
        );

        expect(notesSeen, 'Calm');
        expect((await stored()).notes, 'Changed');
      },
    );

    test('writeFirst alone, with no dive change, is written', () async {
      var ran = 0;

      final result = await service.save(
        diveId: 'dive',
        apply: (dive) => dive,
        changedCardIds: ['tanks'],
        writeFirst: () async => ran++,
        alsoWriteIsAChange: true,
      );

      expect(result, isNotNull);
      expect(ran, 1);
    });

    test('a held change that throws leaves everything as it was', () async {
      final sites = SiteRepository();

      await expectLater(
        service.save(
          diveId: 'dive',
          apply: (dive) => dive,
          changedCardIds: ['header'],
          alsoWrite: () async {
            await sites.updateSiteAltitude('site', 512);
            throw StateError('no');
          },
          alsoWriteIsAChange: true,
        ),
        throwsStateError,
      );

      expect(await siteAltitude(), isNull);
      expect(await logEvents(db), isEmpty);
    });

    test('is not made when the sitting changed nothing', () async {
      var ran = 0;

      final result = await service.save(
        diveId: 'dive',
        apply: (dive) => dive,
        changedCardIds: const [],
        alsoWrite: () async => ran++,
      );

      expect(result, isNull);
      expect(ran, 0);
    });

    test('is undone when the sitting is reverted', () async {
      final sites = SiteRepository();
      await service.save(
        diveId: 'dive',
        apply: (dive) => dive.copyWith(notes: 'Current'),
        changedCardIds: ['notes'],
        alsoWrite: () => sites.updateSiteAltitude('site', 512),
      );
      final operationId = (await operations()).single['id']! as String;

      final revert = ChangeLogRevertService(afterDiveWrites: (_) {});
      await revert.execute(await revert.planOperation(operationId));

      expect((await stored()).notes, 'Calm');
      expect(await siteAltitude(), isNull);
    });
  });

  // What the Details card edits, and the one rule that runs at save time:
  // a dive put on a trip stretches that trip's dates to cover it.
  group('the Details card', () {
    // The seeded dive is on 1 January 1970, before either trip begins.
    Future<Trip> addTrip(String id) => trips.createTrip(
      Trip(
        id: id,
        diverId: 'me',
        name: 'Trip $id',
        startDate: DateTime(1970, 1, 5),
        endDate: DateTime(1970, 1, 7),
        createdAt: epoch,
        updatedAt: epoch,
      ),
    );

    /// Forgets what seeding wrote, so a test sees only its own save.
    Future<void> forgetLog() async {
      await changeLog.settleAll();
      await clearLog(db);
      await db.customStatement('DELETE FROM change_log_operations');
    }

    Future<DateTime> startOf(String tripId) async =>
        (await trips.getTripById(tripId))!.startDate;

    bool isFirstOfJanuary(DateTime day) =>
        (day.year, day.month, day.day) == (1970, 1, 1);

    test('a cleared trip is stored with no trip', () async {
      final tripA = await addTrip('a');
      await dives.updateDive(
        (await stored()).copyWith(trip: tripA, tripId: 'a'),
      );
      expect((await stored()).tripId, 'a');

      await service.save(
        diveId: 'dive',
        apply: (dive) => diveTripField.write(dive, null),
        changedCardIds: ['details'],
      );

      final after = await stored();
      expect((after.trip, after.tripId), (null, null));
    });

    test(
      'a dive put on a trip stretches it, in the one History entry',
      () async {
        final tripA = await addTrip('a');
        await forgetLog();

        final result = await service.save(
          diveId: 'dive',
          apply: (dive) => diveTripField.write(dive, tripA),
          changedCardIds: ['details'],
        );

        expect(result!.tripDateStretches.single.tripId, 'a');
        expect(isFirstOfJanuary(await startOf('a')), isTrue);
        expect((await stored()).tripId, 'a');
        expect(await operations(), hasLength(1));
        expect({
          for (final event in await logEvents(db)) event['table_name'],
        }, containsAll(['dives', 'trips']));
      },
    );

    test('a dive whose trip was not touched does not stretch it', () async {
      final tripA = await addTrip('a');
      // On the trip already, and outside its dates.
      await dives.updateDive(
        (await stored()).copyWith(trip: tripA, tripId: 'a'),
      );

      final result = await service.save(
        diveId: 'dive',
        apply: (dive) => dive.copyWith(notes: 'Current'),
        changedCardIds: ['notes'],
      );

      expect(result!.tripDateStretches, isEmpty);
      expect(await startOf('a'), DateTime(1970, 1, 5));
    });

    test('a failing alsoWrite rolls the stretch back with the dive', () async {
      final tripA = await addTrip('a');

      await expectLater(
        service.save(
          diveId: 'dive',
          apply: (dive) => diveTripField.write(dive, tripA),
          changedCardIds: ['details'],
          alsoWrite: () async => throw StateError('no'),
        ),
        throwsStateError,
      );

      expect(await startOf('a'), DateTime(1970, 1, 5));
      expect((await stored()).tripId, isNull);
    });

    test('a stretch that fails fails the save, and the dive is left as it '
        'was', () async {
      final tripA = await addTrip('a');
      await forgetLog();
      final failing = DiveEditSaveService(dives, _NoStretch());

      await expectLater(
        failing.save(
          diveId: 'dive',
          apply: (dive) => diveTripField.write(dive, tripA),
          changedCardIds: ['details'],
        ),
        throwsStateError,
      );

      expect((await stored()).tripId, isNull);
      expect(await startOf('a'), DateTime(1970, 1, 5));
      expect(await logEvents(db), isEmpty);
    });

    test(
      'reverting the sitting puts the trip\'s dates back with the dive',
      () async {
        final tripA = await addTrip('a');
        await forgetLog();
        await service.save(
          diveId: 'dive',
          apply: (dive) => diveTripField.write(dive, tripA),
          changedCardIds: ['details'],
        );
        expect(isFirstOfJanuary(await startOf('a')), isTrue);
        final operationId = (await operations()).single['id']! as String;

        final revert = ChangeLogRevertService(afterDiveWrites: (_) {});
        await revert.execute(await revert.planOperation(operationId));

        expect((await stored()).tripId, isNull);
        expect(await startOf('a'), DateTime(1970, 1, 5));
      },
    );

    test(
      'a tank linked to the old trip\'s cylinder loses the link when the trip '
      'changes',
      () async {
        final tripA = await addTrip('a');
        final tripB = await addTrip('b');
        await db
            .into(db.tripCylinders)
            .insert(
              TripCylindersCompanion.insert(
                id: 'slot',
                tripId: 'a',
                createdAt: 0,
                updatedAt: 0,
              ),
            );
        final seeded = await stored();
        await dives.updateDive(
          seeded.copyWith(
            trip: tripA,
            tripId: 'a',
            tanks: [seeded.tanks.single.copyWith(tripCylinderId: 'slot')],
          ),
        );
        expect((await stored()).tanks.single.tripCylinderId, 'slot');

        await service.save(
          diveId: 'dive',
          apply: (dive) => diveTripField.write(dive, tripB),
          changedCardIds: ['details'],
        );

        final after = await stored();
        expect(after.tripId, 'b');
        expect(after.tanks.single.tripCylinderId, isNull);
      },
    );

    test('dive types are written with the dive, in order', () async {
      await service.save(
        diveId: 'dive',
        apply: (dive) => diveTypeIdsField.write(dive, ['wreck', 'night']),
        changedCardIds: ['details'],
      );

      expect((await stored()).diveTypeIds, ['wreck', 'night']);
    });

    test('courses are written with the dive, as a set', () async {
      for (final id in ['c1', 'c2']) {
        await db
            .into(db.courses)
            .insert(
              CoursesCompanion.insert(
                id: id,
                diverId: 'me',
                name: 'Course $id',
                agency: 'padi',
                startDate: 0,
                createdAt: 0,
                updatedAt: 0,
              ),
            );
      }

      await service.save(
        diveId: 'dive',
        apply: (dive) => diveCourseIdsField.write(dive, ['c2', 'c1']),
        changedCardIds: ['details'],
      );

      // Read back in the writer's own order: by start date, then name.
      expect((await stored()).courseIds, ['c1', 'c2']);
    });

    test('a cleared visibility, water type, operator and dive center are '
        'stored as null', () async {
      await db
          .into(db.diveCenters)
          .insert(
            DiveCentersCompanion.insert(
              id: 'center',
              name: 'Blue Hole Divers',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await dives.updateDive(
        (await stored()).copyWith(
          visibilityMeters: 12,
          waterType: WaterType.salt,
          diveOperator: 'Emperor',
          diveCenter: DiveCenter(
            id: 'center',
            name: 'Blue Hole Divers',
            createdAt: epoch,
            updatedAt: epoch,
          ),
        ),
      );
      final seeded = await stored();
      expect(seeded.visibilityMeters, 12);
      expect(seeded.waterType, WaterType.salt);
      expect(seeded.diveOperator, 'Emperor');
      expect(seeded.diveCenter?.id, 'center');

      await service.save(
        diveId: 'dive',
        apply: (dive) {
          var next = diveVisibilityField.write(dive, StoredVisibility.none);
          next = diveWaterTypeField.write(next, null);
          next = diveCenterField.write(next, null);
          return diveOperatorField.write(next, null);
        },
        changedCardIds: ['details'],
      );

      final after = await stored();
      expect(after.visibilityMeters, isNull);
      expect(after.waterType, isNull);
      expect(after.diveOperator, isNull);
      expect(after.diveCenter, isNull);
    });
  });
}
