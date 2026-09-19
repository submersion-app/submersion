import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';

import '../../../../helpers/test_database.dart';

/// Deleting a diver has to tombstone every row it deletes.
///
/// A peer applies the diver's own tombstone as a single-row delete. The
/// `diver_id` of these tables references `divers` with no ON DELETE action,
/// so nothing cascades there: the peer's FK repair sets the dangling
/// `diver_id` to NULL instead, and several readers treat an ownerless row as
/// shared with every diver. Without a tombstone per row the deleted diver's
/// dives, gear, buddies and tags would surface for everyone on the other
/// devices, and a base snapshot from that peer would spread them further.
///
/// Each table's rows get the tombstones its own repository delete writes,
/// children included (a trip's itinerary, gear's service schedules). Children
/// that repository leaves to an ON DELETE CASCADE (a dive's tanks) go the
/// same way on the peer once the parent's tombstone lands, so they get none.
void main() {
  late DiverRepository repository;
  late AppDatabase db;
  const stale = 1000;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiverRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDiver(String id, {bool isDefault = false}) async {
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(id),
            name: Value(id),
            isDefault: Value(isDefault),
            createdAt: const Value(stale),
            updatedAt: const Value(stale),
          ),
        );
  }

  Future<int> countOf(String table, String id) async =>
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM $table WHERE id = ?',
                variables: [Variable<String>(id)],
              )
              .getSingle())
          .read<int>('n');

  Future<int> tombstonesFor(String entityType, String recordId) async =>
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM deletion_log '
                'WHERE entity_type = ? AND record_id = ?',
                variables: [
                  Variable<String>(entityType),
                  Variable<String>(recordId),
                ],
              )
              .getSingle())
          .read<int>('n');

  Future<int> pendingCountFor(String entityType, String recordId) async =>
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM sync_records WHERE entity_type = ? '
                "AND record_id = ? AND sync_status = 'pending'",
                variables: [
                  Variable<String>(entityType),
                  Variable<String>(recordId),
                ],
              )
              .getSingle())
          .read<int>('n');

  Future<void> insertDive(String id, String? diverId) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: Value(diverId),
          diveDateTime: stale,
          createdAt: stale,
          updatedAt: stale,
        ),
      );

  Future<void> insertTrip(String id, {bool isShared = false}) => db
      .into(db.trips)
      .insert(
        TripsCompanion.insert(
          id: id,
          name: id,
          startDate: stale,
          endDate: stale,
          diverId: const Value('diver-a'),
          isShared: Value(isShared),
          createdAt: stale,
          updatedAt: stale,
        ),
      );

  Future<void> insertSite(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion.insert(
          id: id,
          name: id,
          diverId: const Value('diver-a'),
          createdAt: stale,
          updatedAt: stale,
        ),
      );

  Future<void> insertEquipment(String id) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: 'regulator',
          diverId: const Value('diver-a'),
          createdAt: stale,
          updatedAt: stale,
        ),
      );

  Future<void> insertBuddy(String id) => db
      .into(db.buddies)
      .insert(
        BuddiesCompanion.insert(
          id: id,
          name: id,
          diverId: const Value('diver-a'),
          createdAt: stale,
          updatedAt: stale,
        ),
      );

  Future<void> insertCenter(String id) => db
      .into(db.diveCenters)
      .insert(
        DiveCentersCompanion.insert(
          id: id,
          name: id,
          diverId: const Value('diver-a'),
          createdAt: stale,
          updatedAt: stale,
        ),
      );

  /// One seeder per diver-owned table: each inserts a row owned by
  /// `diver-a`, plus the children its repository delete tombstones, and
  /// names the rows the delete must remove as (table, entity type, id).
  final seeders = <String, Future<List<(String, String, String)>> Function()>{
    'a dive': () async {
      await insertDive('dive-a', 'diver-a');
      // Cascades with the dive here and, from the dive's tombstone, on a
      // peer; DiveRepository.bulkDeleteDives writes it no tombstone either.
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: 'tank-a', diveId: 'dive-a'));
      return [('dives', 'dives', 'dive-a')];
    },
    'a private trip and its children': () async {
      await insertTrip('trip-a');
      await db
          .into(db.liveaboardDetailRecords)
          .insert(
            LiveaboardDetailRecordsCompanion.insert(
              id: 'lb-a',
              tripId: 'trip-a',
              vesselName: 'Nautilus',
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.tripItineraryDays)
          .insert(
            TripItineraryDaysCompanion.insert(
              id: 'day-a',
              tripId: 'trip-a',
              dayNumber: 1,
              date: stale,
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.tripChecklistItems)
          .insert(
            TripChecklistItemsCompanion.insert(
              id: 'check-a',
              tripId: 'trip-a',
              title: 'Passport',
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.tripDayWeather)
          .insert(
            TripDayWeatherCompanion.insert(
              id: 'wx-a',
              tripId: 'trip-a',
              date: stale,
              latitude: 1,
              longitude: 2,
              fetchedAt: stale,
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      return [
        ('trips', 'trips', 'trip-a'),
        ('liveaboard_detail_records', 'liveaboardDetails', 'lb-a'),
        ('trip_itinerary_days', 'itineraryDays', 'day-a'),
        ('trip_checklist_items', 'tripChecklistItems', 'check-a'),
        ('trip_day_weather', 'tripDayWeather', 'wx-a'),
      ];
    },
    'a private dive site': () async {
      await insertSite('site-a');
      return [('dive_sites', 'diveSites', 'site-a')];
    },
    'gear with its service, component, check-in and finding rows': () async {
      await insertEquipment('reg-a');
      await insertEquipment('hose-a');
      // Shared, so the diver's own service kinds step leaves it alone.
      await db
          .into(db.serviceKinds)
          .insert(
            ServiceKindsCompanion.insert(
              id: 'kind-x',
              name: 'Annual',
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.serviceSchedules)
          .insert(
            ServiceSchedulesCompanion.insert(
              id: 'sched-a',
              equipmentId: 'reg-a',
              serviceKindId: 'kind-x',
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.serviceRecords)
          .insert(
            ServiceRecordsCompanion.insert(
              id: 'rec-a',
              equipmentId: 'reg-a',
              serviceCategory: 'annual',
              serviceDate: stale,
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.equipmentComponents)
          .insert(
            EquipmentComponentsCompanion.insert(
              id: 'comp-a',
              parentEquipmentId: 'reg-a',
              componentEquipmentId: 'hose-a',
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.equipmentObservations)
          .insert(
            EquipmentObservationsCompanion.insert(
              id: 'obs-a',
              equipmentId: 'reg-a',
              observedAt: stale,
              status: 'ok',
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.equipmentFindings)
          .insert(
            EquipmentFindingsCompanion.insert(
              id: 'find-a',
              equipmentId: 'reg-a',
              ruleId: 'service-overdue',
              severity: 'warning',
              evidenceFingerprint: 'fp',
              engineVersion: 1,
              createdAt: stale,
            ),
          );
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: 'tag-gear',
              name: 'Travel',
              diverId: const Value('diver-a'),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.equipmentTags)
          .insert(
            EquipmentTagsCompanion.insert(
              id: 'eqtag-a',
              equipmentId: 'reg-a',
              tagId: 'tag-gear',
              createdAt: stale,
            ),
          );
      return [
        ('equipment', 'equipment', 'reg-a'),
        ('equipment', 'equipment', 'hose-a'),
        ('service_schedules', 'serviceSchedules', 'sched-a'),
        ('service_records', 'serviceRecords', 'rec-a'),
        ('equipment_components', 'equipmentComponents', 'comp-a'),
        ('equipment_observations', 'equipmentObservations', 'obs-a'),
        ('equipment_findings', 'equipmentFindings', 'find-a'),
        ('equipment_tags', 'equipmentTags', 'eqtag-a'),
        ('tags', 'tags', 'tag-gear'),
      ];
    },
    'an equipment set and its geofence': () async {
      await db
          .into(db.equipmentSets)
          .insert(
            EquipmentSetsCompanion.insert(
              id: 'set-a',
              name: 'Cold water',
              diverId: const Value('diver-a'),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      await db
          .into(db.equipmentSetGeofences)
          .insert(
            EquipmentSetGeofencesCompanion.insert(
              id: 'fence-a',
              setId: 'set-a',
              latitude: 1,
              longitude: 2,
              radiusMeters: 500,
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      return [
        ('equipment_sets', 'equipmentSets', 'set-a'),
        ('equipment_set_geofences', 'equipmentSetGeofences', 'fence-a'),
      ];
    },
    'a buddy and the certifications recorded for them': () async {
      await insertBuddy('buddy-a');
      await db
          .into(db.certifications)
          .insert(
            CertificationsCompanion.insert(
              id: 'buddy-cert-a',
              name: 'Rescue Diver',
              agency: 'padi',
              buddyId: const Value('buddy-a'),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      return [
        ('buddies', 'buddies', 'buddy-a'),
        ('certifications', 'certifications', 'buddy-cert-a'),
      ];
    },
    'a certification': () async {
      await db
          .into(db.certifications)
          .insert(
            CertificationsCompanion.insert(
              id: 'cert-a',
              name: 'Open Water Diver',
              agency: 'padi',
              diverId: const Value('diver-a'),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      return [('certifications', 'certifications', 'cert-a')];
    },
    'a dive center and its rental gear notes': () async {
      await insertCenter('center-a');
      await db
          .into(db.diveCenterGearNotes)
          .insert(
            DiveCenterGearNotesCompanion.insert(
              id: 'note-a',
              diveCenterId: 'center-a',
              gearType: 'bcd',
              verdict: 'worked',
              notedAt: stale,
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      return [
        ('dive_centers', 'diveCenters', 'center-a'),
        ('dive_center_gear_notes', 'diveCenterGearNotes', 'note-a'),
      ];
    },
    'a tag': () async {
      await db
          .into(db.tags)
          .insert(
            TagsCompanion.insert(
              id: 'tag-a',
              name: 'Wreck',
              diverId: const Value('diver-a'),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      return [('tags', 'tags', 'tag-a')];
    },
    'a custom dive type': () async {
      await db
          .into(db.diveTypes)
          .insert(
            DiveTypesCompanion.insert(
              id: 'type-a',
              name: 'Ice',
              diverId: const Value('diver-a'),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      return [('dive_types', 'diveTypes', 'type-a')];
    },
    'a tank preset': () async {
      await db
          .into(db.tankPresets)
          .insert(
            TankPresetsCompanion.insert(
              id: 'preset-a',
              name: 'al80',
              displayName: 'AL80',
              volumeLiters: 11.1,
              workingPressureBar: 207,
              material: 'aluminum',
              diverId: const Value('diver-a'),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      return [('tank_presets', 'tankPresets', 'preset-a')];
    },
    'a dive computer': () async {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: 'dc-a',
              name: 'Perdix',
              diverId: const Value('diver-a'),
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      return [('dive_computers', 'diveComputers', 'dc-a')];
    },
    'a weight entry': () async {
      await db
          .into(db.diverWeightEntries)
          .insert(
            DiverWeightEntriesCompanion.insert(
              id: 'weight-a',
              diverId: 'diver-a',
              measuredAt: stale,
              weightKg: 80,
              createdAt: stale,
              updatedAt: stale,
            ),
          );
      return [('diver_weight_entries', 'diverWeightEntries', 'weight-a')];
    },
  };

  for (final MapEntry(key: label, value: seed) in seeders.entries) {
    test('deleting a diver who owns $label tombstones every row', () async {
      await insertDiver('diver-a');
      await insertDiver('diver-b', isDefault: true);
      final owned = await seed();

      await repository.deleteDiverWithReassignment('diver-a');

      for (final (table, entityType, id) in owned) {
        expect(
          await countOf(table, id),
          0,
          reason: '$table row $id belonged to the deleted diver',
        );
        expect(
          await tombstonesFor(entityType, id),
          1,
          reason: 'a peer keeps $entityType $id, ownerless, without one',
        );
      }
    });
  }

  test('every one of a large logbook is tombstoned', () async {
    await insertDiver('diver-a');
    const count = 2000;
    await db.batch((b) {
      b.insertAll(db.dives, [
        for (var i = 0; i < count; i++)
          DivesCompanion.insert(
            id: 'dive-$i',
            diverId: const Value('diver-a'),
            diveDateTime: stale + i,
            createdAt: stale,
            updatedAt: stale,
          ),
      ]);
    });

    await repository.deleteDiverWithReassignment('diver-a');

    final n = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM deletion_log WHERE entity_type = 'dives'",
        )
        .getSingle();
    expect(n.read<int>('n'), count);
  });

  test(
    'a shared trip handed to the surviving diver is not tombstoned',
    () async {
      await insertDiver('diver-a');
      await insertDiver('diver-b', isDefault: true);
      await insertTrip('trip-shared', isShared: true);

      await repository.deleteDiverWithReassignment('diver-a');

      expect(await countOf('trips', 'trip-shared'), 1);
      expect(await tombstonesFor('trips', 'trip-shared'), 0);
    },
  );

  test("another diver's dive at the deleted diver's dive center is cleared, "
      'stamped and marked', () async {
    // dives.dive_center_id references dive_centers with no ON DELETE action,
    // so Bob's dive at Alice's center failed the dive_centers step with
    // SqliteException(787) and rolled the whole delete back.
    await insertDiver('diver-a');
    await insertDiver('diver-b', isDefault: true);
    await insertCenter('center-a');
    await insertDive('dive-b', 'diver-b');
    await db.customStatement(
      "UPDATE dives SET dive_center_id = 'center-a' WHERE id = 'dive-b'",
    );

    await repository.deleteDiverWithReassignment('diver-a');

    expect(await countOf('divers', 'diver-a'), 0);
    final dive = await db
        .customSelect(
          "SELECT dive_center_id, updated_at FROM dives WHERE id = 'dive-b'",
        )
        .getSingle();
    expect(dive.readNullable<String>('dive_center_id'), isNull);
    expect(
      dive.read<int>('updated_at'),
      greaterThan(stale),
      reason: 'a peer cannot see a change that did not move updated_at',
    );
    expect(await pendingCountFor('dives', 'dive-b'), 1);
  });

  test("a surviving plan at the deleted diver's private site is cleared, "
      'stamped and marked', () async {
    // dive_plans.site_id references dive_sites with no ON DELETE action, so
    // a plan at one of Alice's private sites failed the dive_sites step with
    // SqliteException(787).
    await insertDiver('diver-a');
    await insertDiver('diver-b', isDefault: true);
    await insertSite('site-a');
    await db
        .into(db.divePlans)
        .insert(
          DivePlansCompanion.insert(
            id: 'plan-b',
            name: 'Reef',
            gfLow: 30,
            gfHigh: 70,
            diverId: const Value('diver-b'),
            siteId: const Value('site-a'),
            createdAt: stale,
            updatedAt: stale,
          ),
        );

    await repository.deleteDiverWithReassignment('diver-a');

    expect(await countOf('divers', 'diver-a'), 0);
    final plan = await db
        .customSelect(
          "SELECT site_id, updated_at FROM dive_plans WHERE id = 'plan-b'",
        )
        .getSingle();
    expect(plan.readNullable<String>('site_id'), isNull);
    expect(plan.read<int>('updated_at'), greaterThan(stale));
    expect(await pendingCountFor('divePlans', 'plan-b'), 1);
  });
}
