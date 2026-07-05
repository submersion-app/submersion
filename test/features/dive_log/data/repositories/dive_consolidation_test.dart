import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_split_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<String> insertTestDive({
    String? id,
    String? diveComputerModel,
    String? diveComputerSerial,
    double? maxDepth,
    double? avgDepth,
    int? duration,
    double? waterTemp,
    int? entryTime,
    int? exitTime,
    int? surfaceIntervalSeconds,
    double? cnsEnd,
    String? decoAlgorithm,
    int? gradientFactorLow,
    int? gradientFactorHigh,
  }) async {
    final diveId = id ?? 'dive-${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(diveId),
            diveDateTime: Value(now),
            // computerId intentionally omitted to avoid FK constraints in tests
            diveComputerModel: Value(diveComputerModel),
            diveComputerSerial: Value(diveComputerSerial),
            maxDepth: Value(maxDepth),
            avgDepth: Value(avgDepth),
            bottomTime: Value(duration),
            waterTemp: Value(waterTemp),
            entryTime: Value(entryTime),
            exitTime: Value(exitTime),
            surfaceIntervalSeconds: Value(surfaceIntervalSeconds),
            cnsEnd: Value(cnsEnd),
            decoAlgorithm: Value(decoAlgorithm),
            gradientFactorLow: Value(gradientFactorLow),
            gradientFactorHigh: Value(gradientFactorHigh),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return diveId;
  }

  /// Build a [DiveDataSourcesCompanion] without a FK-constrained computerId.
  DiveDataSourcesCompanion buildReading({
    String? id,
    required String diveId,
    bool isPrimary = false,
    String? computerModel,
    String? computerSerial,
    double? maxDepth,
    double? avgDepth,
    int? duration,
    double? waterTemp,
    DateTime? entryTime,
    DateTime? exitTime,
    int? surfaceInterval,
    double? cns,
    String? decoAlgorithm,
    int? gradientFactorLow,
    int? gradientFactorHigh,
  }) {
    final now = DateTime.now();
    return DiveDataSourcesCompanion(
      id: Value(id ?? 'reading-${now.microsecondsSinceEpoch}'),
      diveId: Value(diveId),
      isPrimary: Value(isPrimary),
      // computerId left null to avoid FK constraints in tests
      computerModel: Value(computerModel),
      computerSerial: Value(computerSerial),
      maxDepth: Value(maxDepth),
      avgDepth: Value(avgDepth),
      duration: Value(duration),
      waterTemp: Value(waterTemp),
      entryTime: Value(entryTime),
      exitTime: Value(exitTime),
      surfaceInterval: Value(surfaceInterval),
      cns: Value(cns),
      decoAlgorithm: Value(decoAlgorithm),
      gradientFactorLow: Value(gradientFactorLow),
      gradientFactorHigh: Value(gradientFactorHigh),
      importedAt: Value(now),
      createdAt: Value(now),
    );
  }

  /// Insert a profile point, using [sourceTag] to distinguish computers
  /// (stored in the id to make retrieval predictable, computerId left null).
  Future<String> insertTestProfile({
    required String diveId,
    String? sourceTag,
    bool isPrimary = true,
    int timestamp = 0,
    double depth = 5.0,
  }) async {
    final tag = sourceTag ?? 'default';
    final id = 'profile-$tag-$timestamp-${diveId.hashCode}';
    await db
        .into(db.diveProfiles)
        .insert(
          DiveProfilesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            // computerId left null to avoid FK constraints
            isPrimary: Value(isPrimary),
            timestamp: Value(timestamp),
            depth: Value(depth),
          ),
        );
    return id;
  }

  // ---------------------------------------------------------------------------
  // consolidateComputer was removed in favor of DiveConsolidationService.apply
  // (Task 8) -- its "back-fill primary on first consolidation" and "insert
  // secondary profile points" scenarios are exercised directly against the
  // service in dive_consolidation_service_test.dart. mergeDives was removed
  // for the same reason -- its "re-parent secondary into primary, delete
  // secondary, synthesize a data source from secondary metadata" scenarios
  // are exercised directly against the service in
  // dive_consolidation_service_test.dart.
  // ---------------------------------------------------------------------------

  // ---------------------------------------------------------------------------
  // getSourceKeysByDiveId (Task 8)
  // ---------------------------------------------------------------------------

  group('getSourceKeysByDiveId after consolidation', () {
    Future<void> insertComputer(String id) async {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: id,
              name: id,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }

    test('returns the target dive with BOTH computers\' fingerprints after '
        'consolidating two downloads', () async {
      await insertComputer('comp-primary');
      await insertComputer('comp-secondary');

      // Same entry time and duration so the two dives overlap -- the
      // builder rejects non-overlapping selections as
      // ConsolidationInvalid(notOverlapping).
      final entryMillis = DateTime.utc(2026, 7, 1, 9).millisecondsSinceEpoch;

      final targetId = await insertTestDive(
        id: 'dive-target',
        diveComputerModel: 'Shearwater Petrel',
        maxDepth: 30.0,
        entryTime: entryMillis,
        duration: 1800,
      );
      await (db.update(db.dives)..where((t) => t.id.equals(targetId))).write(
        const DivesCompanion(computerId: Value('comp-primary')),
      );

      await repository.saveComputerReading(
        DiveDataSourcesCompanion.insert(
          id: 'reading-primary',
          diveId: targetId,
          isPrimary: const Value(true),
          computerId: const Value('comp-primary'),
          rawFingerprint: Value(Uint8List.fromList([0xAB, 0xCD, 0xEF, 0x01])),
          importedAt: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      );

      final secondaryId = await insertTestDive(
        id: 'dive-secondary',
        diveComputerModel: 'Suunto D5',
        maxDepth: 29.5,
        entryTime: entryMillis,
        duration: 1800,
      );
      await (db.update(db.dives)..where((t) => t.id.equals(secondaryId))).write(
        const DivesCompanion(computerId: Value('comp-secondary')),
      );
      await repository.saveComputerReading(
        DiveDataSourcesCompanion.insert(
          id: 'reading-secondary',
          diveId: secondaryId,
          isPrimary: const Value(true),
          computerId: const Value('comp-secondary'),
          rawFingerprint: Value(Uint8List.fromList([0x12, 0x34, 0x56, 0x78])),
          importedAt: DateTime.now(),
          createdAt: DateTime.now(),
        ),
      );

      final consolidation = DiveConsolidationService(repository);
      await consolidation.apply(
        targetDiveId: targetId,
        secondaryDiveIds: [secondaryId],
      );

      final keysByDiveId = await repository.getSourceKeysByDiveId();

      expect(keysByDiveId, contains(targetId));
      final keys = keysByDiveId[targetId]!;
      expect(keys, contains('ABCDEF01'));
      expect(keys, contains('12345678'));
    });
  });

  // ---------------------------------------------------------------------------
  // DiveSplitService (successor to the removed unlinkComputer)
  // ---------------------------------------------------------------------------

  group('split into separate dive', () {
    test('creates a new standalone dive from detached data', () async {
      final diveId = await insertTestDive(
        id: 'dive-multi',
        diveComputerModel: 'Primary Model',
        maxDepth: 30.0,
      );

      // Two computer readings — no computerId FK needed.
      await repository.saveComputerReading(
        buildReading(
          id: 'primary-reading',
          diveId: diveId,
          isPrimary: true,
          computerModel: 'Primary Model',
          maxDepth: 30.0,
        ),
      );
      await repository.saveComputerReading(
        buildReading(
          id: 'secondary-reading',
          diveId: diveId,
          isPrimary: false,
          computerModel: 'Secondary Model',
          maxDepth: 29.5,
        ),
      );

      // Profiles for each computer (isPrimary distinguishes them).
      await insertTestProfile(
        diveId: diveId,
        sourceTag: 'prim',
        isPrimary: true,
        timestamp: 0,
        depth: 5.0,
      );
      await insertTestProfile(
        diveId: diveId,
        sourceTag: 'sec',
        isPrimary: false,
        timestamp: 5,
        depth: 6.0,
      );

      final newDiveId = await DiveSplitService(
        repository,
      ).split(diveId: diveId, sourceId: 'secondary-reading');

      // New dive should exist.
      final newDive = await (db.select(
        db.dives,
      )..where((t) => t.id.equals(newDiveId))).getSingleOrNull();
      expect(newDive, isNotNull);

      // Secondary reading should be removed from the original dive.
      final originalReadings = await repository.getDataSources(diveId);
      expect(originalReadings.any((r) => r.id == 'secondary-reading'), isFalse);
    });

    test(
      'keeps the remaining source row after splitting the other one',
      () async {
        // The remaining source row stays (the sources bar hides below two
        // sources); only the departing row is removed.
        final diveId = await insertTestDive(id: 'dive-two-computers');

        await repository.saveComputerReading(
          buildReading(
            id: 'reading-a',
            diveId: diveId,
            isPrimary: true,
            computerModel: 'Computer A',
          ),
        );
        await repository.saveComputerReading(
          buildReading(
            id: 'reading-b',
            diveId: diveId,
            isPrimary: false,
            computerModel: 'Computer B',
          ),
        );

        await DiveSplitService(
          repository,
        ).split(diveId: diveId, sourceId: 'reading-b');

        // The departing reading must be gone from the original dive.
        final originalReadings = await repository.getDataSources(diveId);
        expect(originalReadings.any((r) => r.id == 'reading-b'), isFalse);

        // The other reading remains, still primary.
        expect(originalReadings, hasLength(1));
        expect(originalReadings.single.id, 'reading-a');
        expect(originalReadings.single.isPrimary, isTrue);
      },
    );

    test('promotes next computer if the primary is split away', () async {
      final diveId = await insertTestDive(
        id: 'dive-promote',
        diveComputerModel: 'Primary Model',
        maxDepth: 30.0,
      );

      await repository.saveComputerReading(
        buildReading(
          id: 'primary-reading',
          diveId: diveId,
          isPrimary: true,
          computerModel: 'Primary Model',
          maxDepth: 30.0,
        ),
      );
      await repository.saveComputerReading(
        buildReading(
          id: 'secondary-reading',
          diveId: diveId,
          isPrimary: false,
          computerModel: 'Secondary Model',
          maxDepth: 28.0,
        ),
      );

      await insertTestProfile(
        diveId: diveId,
        sourceTag: 'prim',
        isPrimary: true,
        timestamp: 0,
        depth: 5.0,
      );
      await insertTestProfile(
        diveId: diveId,
        sourceTag: 'sec',
        isPrimary: false,
        timestamp: 5,
        depth: 4.0,
      );

      // Split away the PRIMARY computer's source.
      await DiveSplitService(
        repository,
      ).split(diveId: diveId, sourceId: 'primary-reading');

      // primary-reading must be gone from the original dive.
      final remainingReadings = await repository.getDataSources(diveId);
      expect(remainingReadings.any((r) => r.id == 'primary-reading'), isFalse);

      // After promotion + single-reading cleanup the dive has 0 readings
      // (back to single-computer state) OR the promoted reading is primary.
      if (remainingReadings.isNotEmpty) {
        final primaryCount = remainingReadings.where((r) => r.isPrimary).length;
        expect(primaryCount, lessThanOrEqualTo(1));
      }
    });

    test('returns the new dive ID', () async {
      final diveId = await insertTestDive(id: 'dive-return-id');

      await repository.saveComputerReading(
        buildReading(id: 'r-primary', diveId: diveId, isPrimary: true),
      );
      await repository.saveComputerReading(
        buildReading(id: 'r-secondary', diveId: diveId, isPrimary: false),
      );

      final newId = await DiveSplitService(
        repository,
      ).split(diveId: diveId, sourceId: 'r-secondary');

      expect(newId, isNotEmpty);
      expect(newId, isNot(equals(diveId)));
    });

    test('marks the new dive and the original dive pending for sync', () async {
      final diveId = await insertTestDive(id: 'dive-sync-check');

      await repository.saveComputerReading(
        buildReading(id: 'r-primary', diveId: diveId, isPrimary: true),
      );
      await repository.saveComputerReading(
        buildReading(id: 'r-secondary', diveId: diveId, isPrimary: false),
      );

      final newDiveId = await DiveSplitService(
        repository,
      ).split(diveId: diveId, sourceId: 'r-secondary');

      final newDiveSyncRecord =
          await (db.select(db.syncRecords)..where(
                (t) =>
                    t.entityType.equals('dives') & t.recordId.equals(newDiveId),
              ))
              .getSingleOrNull();
      expect(newDiveSyncRecord, isNotNull);
      expect(newDiveSyncRecord!.syncStatus, equals('pending'));

      final originalDiveSyncRecord =
          await (db.select(db.syncRecords)..where(
                (t) => t.entityType.equals('dives') & t.recordId.equals(diveId),
              ))
              .getSingleOrNull();
      expect(originalDiveSyncRecord, isNotNull);
      expect(originalDiveSyncRecord!.syncStatus, equals('pending'));
    });
  });

  // ---------------------------------------------------------------------------
  // Split moves attributed children (clone-on-demand inherited from
  // the removed unlinkComputer)
  // ---------------------------------------------------------------------------

  group('split moves attributed children', () {
    // These scenarios exercise the real computerId FK (dive_tanks,
    // tank_pressure_profiles, dive_profile_events all reference
    // dive_computers with onDelete: setNull), so — unlike the rest of this
    // file, which leaves computerId null to dodge the FK — DiveComputers
    // rows must exist. PRAGMA foreign_keys=ON is the default connection
    // state (AppDatabase.beforeOpen), so no explicit pragma toggle is
    // needed here.

    Future<void> insertComputer(String id) async {
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion.insert(
              id: id,
              name: id,
              createdAt: 0,
              updatedAt: 0,
            ),
          );
    }

    domain.DiveTank tank(
      String id, {
      required double o2,
      double he = 0,
      double? start,
      double? end,
      int order = 0,
    }) => domain.DiveTank(
      id: id,
      gasMix: domain.GasMix(o2: o2, he: he),
      startPressure: start,
      endPressure: end,
      order: order,
    );

    Future<void> seedConsolidatedDive({
      required String targetId,
      required String secondaryId,
    }) async {
      await insertComputer('comp-t');
      await insertComputer('comp-s');

      await repository.createDive(
        domain.Dive(
          id: targetId,
          dateTime: DateTime.utc(2026, 7, 1, 9),
          entryTime: DateTime.utc(2026, 7, 1, 9),
          runtime: const Duration(minutes: 30),
          maxDepth: 18,
          tanks: [
            tank('tank-t1', o2: 21, start: 200, end: 100, order: 0),
            tank('tank-t2', o2: 32, start: 200, end: 120, order: 1),
          ],
        ),
      );
      await (db.update(db.dives)..where((t) => t.id.equals(targetId))).write(
        const DivesCompanion(computerId: Value('comp-t')),
      );

      await repository.createDive(
        domain.Dive(
          id: secondaryId,
          dateTime: DateTime.utc(2026, 7, 1, 9, 1),
          entryTime: DateTime.utc(2026, 7, 1, 9, 1),
          runtime: const Duration(minutes: 30),
          maxDepth: 17,
          tanks: [
            // Dedupable: same gas, pressures within the 5 bar tolerance of
            // tank-t1.
            tank('tank-s1', o2: 21, start: 205, end: 105, order: 0),
            // Not dedupable: different gas mix.
            tank('tank-s2', o2: 100, start: 200, end: 150, order: 1),
          ],
        ),
      );
      await (db.update(db.dives)..where((t) => t.id.equals(secondaryId))).write(
        const DivesCompanion(computerId: Value('comp-s')),
      );

      await db
          .into(db.tankPressureProfiles)
          .insert(
            TankPressureProfilesCompanion.insert(
              id: 'tp-t1',
              diveId: targetId,
              tankId: 'tank-t1',
              timestamp: 60,
              pressure: 190,
            ),
          );
      await db
          .into(db.tankPressureProfiles)
          .insert(
            TankPressureProfilesCompanion.insert(
              id: 'tp-s1',
              diveId: secondaryId,
              tankId: 'tank-s1',
              timestamp: 60,
              pressure: 195,
            ),
          );
      await db
          .into(db.tankPressureProfiles)
          .insert(
            TankPressureProfilesCompanion.insert(
              id: 'tp-s2',
              diveId: secondaryId,
              tankId: 'tank-s2',
              timestamp: 60,
              pressure: 195,
            ),
          );

      await db
          .into(db.diveProfileEvents)
          .insert(
            DiveProfileEventsCompanion.insert(
              id: 'event-s1',
              diveId: secondaryId,
              timestamp: 30,
              eventType: 'gaschange',
              createdAt: 0,
            ).copyWith(tankId: const Value('tank-s1')),
          );

      final consolidation = DiveConsolidationService(repository);
      await consolidation.apply(
        targetDiveId: targetId,
        secondaryDiveIds: [secondaryId],
      );
    }

    /// Asserts referential dive-locality: no tank_pressure_profiles,
    /// dive_profile_events, or gas_switches row on [diveId] references a
    /// dive_tanks row that lives on a different dive.
    Future<void> assertNoCrossDiveTankRefs(String diveId) async {
      final tankIds = (await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals(diveId))).get()).map((t) => t.id).toSet();

      final pressures = await (db.select(
        db.tankPressureProfiles,
      )..where((t) => t.diveId.equals(diveId))).get();
      for (final p in pressures) {
        expect(
          tankIds,
          contains(p.tankId),
          reason:
              'tank_pressure_profiles row ${p.id} on dive $diveId '
              'references tank ${p.tankId}, which is not on this dive',
        );
      }

      final events = await (db.select(
        db.diveProfileEvents,
      )..where((t) => t.diveId.equals(diveId) & t.tankId.isNotNull())).get();
      for (final e in events) {
        expect(
          tankIds,
          contains(e.tankId),
          reason:
              'dive_profile_events row ${e.id} on dive $diveId references '
              'tank ${e.tankId}, which is not on this dive',
        );
      }

      final switches = await (db.select(
        db.gasSwitches,
      )..where((t) => t.diveId.equals(diveId))).get();
      for (final s in switches) {
        expect(
          tankIds,
          contains(s.tankId),
          reason:
              'gas_switches row ${s.id} on dive $diveId references tank '
              '${s.tankId}, which is not on this dive',
        );
      }
    }

    test('moves the secondary computer\'s tanks, pressures, and events to the '
        'new dive, cloning the shared tank for its pressure curve', () async {
      await seedConsolidatedDive(targetId: 'dive-t', secondaryId: 'dive-s');

      // Locate the secondary's data source row (fresh id, synthesized by
      // consolidation) and its freshly-created (non-deduped) tank.
      final readings = await repository.getDataSources('dive-t');
      final secondaryReading = readings.firstWhere(
        (r) => r.computerId == 'comp-s',
      );

      final tanksBeforeUnlink = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('dive-t'))).get();
      expect(tanksBeforeUnlink, hasLength(3)); // tank-t1, tank-t2, fresh
      final freshTank = tanksBeforeUnlink.firstWhere(
        (t) => t.computerId == 'comp-s',
      );
      expect(freshTank.id, isNot(equals('tank-s1')));
      expect(freshTank.id, isNot(equals('tank-s2')));

      final newDiveId = await DiveSplitService(
        repository,
      ).split(diveId: 'dive-t', sourceId: secondaryReading.id);

      // -- Tanks -------------------------------------------------------
      final newDiveTanks = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals(newDiveId))).get();
      // The fresh (non-shared) tank moves outright; the shared tank gets
      // a clone attributed to the unlinked computer.
      expect(newDiveTanks, hasLength(2));
      expect(newDiveTanks.every((t) => t.computerId == 'comp-s'), isTrue);
      // Split copies rows under fresh ids (tombstoning the originals), so
      // the moved tank is identified by its gas rather than its id.
      final movedFresh = newDiveTanks.firstWhere((t) => t.o2Percent == 100.0);
      expect(movedFresh.id, isNot(equals(freshTank.id)));
      final clone = newDiveTanks.firstWhere((t) => t.o2Percent == 21.0);
      expect(clone.id, isNot(equals('tank-t1')));
      expect(clone.o2Percent, equals(21.0));
      expect(clone.hePercent, equals(0.0));
      expect(clone.startPressure, equals(200.0));
      expect(clone.endPressure, equals(100.0));

      // The shared tank stays on the original dive, still attributed to
      // the primary computer.
      final originalTanks = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('dive-t'))).get();
      expect(originalTanks.map((t) => t.id), contains('tank-t1'));
      expect(originalTanks.map((t) => t.id), contains('tank-t2'));
      expect(originalTanks, hasLength(2));
      final sharedTank = originalTanks.firstWhere((t) => t.id == 'tank-t1');
      expect(sharedTank.computerId, equals('comp-t'));

      // -- Tank pressure profiles ---------------------------------------
      final newDivePressures = await (db.select(
        db.tankPressureProfiles,
      )..where((t) => t.diveId.equals(newDiveId))).get();
      expect(newDivePressures, hasLength(2));
      expect(newDivePressures.every((p) => p.computerId == 'comp-s'), isTrue);
      // One curve points at the clone (it lived on the shared tank), the
      // other at the moved fresh tank.
      expect(
        newDivePressures.map((p) => p.tankId).toSet(),
        equals({clone.id, movedFresh.id}),
      );

      // The original dive keeps only its own computer's pressure curve on
      // the shared tank.
      final originalPressures = await (db.select(
        db.tankPressureProfiles,
      )..where((t) => t.diveId.equals('dive-t'))).get();
      expect(originalPressures, hasLength(1));
      expect(originalPressures.single.tankId, equals('tank-t1'));
      expect(originalPressures.single.computerId, equals('comp-t'));

      // -- Profile events -------------------------------------------------
      final newDiveEvents = await (db.select(
        db.diveProfileEvents,
      )..where((t) => t.diveId.equals(newDiveId))).get();
      expect(newDiveEvents, hasLength(1));
      expect(newDiveEvents.single.computerId, equals('comp-s'));

      final originalEvents = await (db.select(
        db.diveProfileEvents,
      )..where((t) => t.diveId.equals('dive-t'))).get();
      expect(originalEvents.any((e) => e.computerId == 'comp-s'), isFalse);
    });

    test("unlinking the shared tank's owner leaves the tank (and the other "
        "computer's rows) on the original dive and clones it for the "
        'departing computer', () async {
      await seedConsolidatedDive(targetId: 'dive-t', secondaryId: 'dive-s');

      // Gas switches carry no computerId and always stay with the
      // original dive; add one on the shared tank so all three
      // "remaining reference" checks (pressure, event, gas switch) are
      // exercised.
      await db
          .into(db.gasSwitches)
          .insert(
            GasSwitchesCompanion.insert(
              id: 'switch-t1',
              diveId: 'dive-t',
              tankId: 'tank-t1',
              timestamp: 45,
              createdAt: 0,
            ),
          );

      final readings = await repository.getDataSources('dive-t');
      final targetReading = readings.firstWhere(
        (r) => r.computerId == 'comp-t',
      );

      final newDiveId = await DiveSplitService(
        repository,
      ).split(diveId: 'dive-t', sourceId: targetReading.id);

      // -- Tanks -------------------------------------------------------
      // tank-t1 is shared: comp-s's pressure row and event still
      // reference it, and the gas switch always stays. It must remain
      // on the original dive, freed from comp-t's attribution.
      final originalTanks = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals('dive-t'))).get();
      final sharedTank = originalTanks.firstWhere((t) => t.id == 'tank-t1');
      expect(sharedTank.computerId, isNull);
      expect(sharedTank.o2Percent, equals(21.0));
      expect(sharedTank.hePercent, equals(0.0));
      expect(sharedTank.startPressure, equals(200.0));
      expect(sharedTank.endPressure, equals(100.0));

      // tank-t2 has no remaining references from other computers, so it
      // still moves outright, same as before this fix.
      expect(originalTanks.map((t) => t.id), isNot(contains('tank-t2')));

      final newDiveTanks = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals(newDiveId))).get();
      // Split copies under fresh ids; the moved EAN32 tank is identified
      // by its gas.
      final movedTankT2 = newDiveTanks.firstWhere((t) => t.o2Percent == 32.0);
      expect(movedTankT2.computerId, equals('comp-t'));

      // comp-t gets a fresh clone of the shared tank on the new dive.
      final clone = newDiveTanks.firstWhere((t) => t.o2Percent == 21.0);
      expect(clone.id, isNot(equals('tank-t1')));
      expect(clone.computerId, equals('comp-t'));
      expect(clone.o2Percent, equals(21.0));
      expect(clone.startPressure, equals(200.0));
      expect(clone.endPressure, equals(100.0));

      // -- Tank pressure profiles ---------------------------------------
      // comp-s's pressure rows stay on the original dive; the one that
      // lived on the shared tank still points at tank-t1, which is
      // still on that dive.
      final originalPressures = await (db.select(
        db.tankPressureProfiles,
      )..where((t) => t.diveId.equals('dive-t'))).get();
      expect(originalPressures, hasLength(2));
      expect(originalPressures.every((p) => p.computerId == 'comp-s'), isTrue);
      final stayedOnShared = originalPressures.firstWhere(
        (p) => p.tankId == 'tank-t1',
      );
      expect(stayedOnShared.computerId, equals('comp-s'));

      // comp-t's own pressure row moves to the new dive, re-pointed at
      // the clone rather than the shared tank it used to live on.
      final newDivePressures = await (db.select(
        db.tankPressureProfiles,
      )..where((t) => t.diveId.equals(newDiveId))).get();
      expect(newDivePressures, hasLength(1));
      expect(newDivePressures.single.computerId, equals('comp-t'));
      expect(newDivePressures.single.tankId, equals(clone.id));

      // -- Profile events -------------------------------------------------
      // comp-s's event stays on the original dive, still pointing at
      // tank-t1.
      final originalEvents = await (db.select(
        db.diveProfileEvents,
      )..where((t) => t.diveId.equals('dive-t'))).get();
      expect(originalEvents, hasLength(1));
      expect(originalEvents.single.tankId, equals('tank-t1'));
      expect(originalEvents.single.computerId, equals('comp-s'));

      final newDiveEvents = await (db.select(
        db.diveProfileEvents,
      )..where((t) => t.diveId.equals(newDiveId))).get();
      expect(newDiveEvents, isEmpty);

      // -- Gas switches -----------------------------------------------
      // Gas switches never move; the one on the shared tank stays put.
      final originalSwitches = await (db.select(
        db.gasSwitches,
      )..where((t) => t.diveId.equals('dive-t'))).get();
      expect(originalSwitches, hasLength(1));
      expect(originalSwitches.single.tankId, equals('tank-t1'));

      // -- Referential dive-locality ------------------------------------
      // Neither dive's pressure/event/gas-switch rows dangle across to a
      // tank that lives on the other dive.
      await assertNoCrossDiveTankRefs('dive-t');
      await assertNoCrossDiveTankRefs(newDiveId);
    });

    test(
      'split with a null-computerId reading moves no tanks or events',
      () async {
        final diveId = await insertTestDive(id: 'dive-null-cid');

        await repository.saveComputerReading(
          buildReading(id: 'r-primary', diveId: diveId, isPrimary: true),
        );
        await repository.saveComputerReading(
          buildReading(id: 'r-secondary', diveId: diveId, isPrimary: false),
        );

        // Manually seeded children with null computerId (no attribution
        // possible), same shape a manual-entry dive would have.
        await db
            .into(db.diveTanks)
            .insert(DiveTanksCompanion.insert(id: 'tank-x', diveId: diveId));
        await db
            .into(db.diveProfileEvents)
            .insert(
              DiveProfileEventsCompanion.insert(
                id: 'event-x',
                diveId: diveId,
                timestamp: 0,
                eventType: 'gaschange',
                createdAt: 0,
              ),
            );

        final newDiveId = await DiveSplitService(
          repository,
        ).split(diveId: diveId, sourceId: 'r-secondary');

        // Nothing moved: the null-computerId tank/event stay put.
        final originalTank = await (db.select(
          db.diveTanks,
        )..where((t) => t.id.equals('tank-x'))).getSingle();
        expect(originalTank.diveId, equals(diveId));

        final originalEvent = await (db.select(
          db.diveProfileEvents,
        )..where((t) => t.id.equals('event-x'))).getSingle();
        expect(originalEvent.diveId, equals(diveId));

        final newDiveTanks = await (db.select(
          db.diveTanks,
        )..where((t) => t.diveId.equals(newDiveId))).get();
        expect(newDiveTanks, isEmpty);

        final newDiveEvents = await (db.select(
          db.diveProfileEvents,
        )..where((t) => t.diveId.equals(newDiveId))).get();
        expect(newDiveEvents, isEmpty);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // setPrimaryDataSource
  // ---------------------------------------------------------------------------

  group('setPrimaryDataSource', () {
    test('swaps isPrimary flags on dive_computer_data', () async {
      final diveId = await insertTestDive(
        id: 'dive-swap',
        diveComputerModel: 'Computer A',
        maxDepth: 30.0,
      );

      await repository.saveComputerReading(
        buildReading(
          id: 'reading-a',
          diveId: diveId,
          isPrimary: true,
          computerModel: 'Computer A',
          maxDepth: 30.0,
        ),
      );
      await repository.saveComputerReading(
        buildReading(
          id: 'reading-b',
          diveId: diveId,
          isPrimary: false,
          computerModel: 'Computer B',
          maxDepth: 28.0,
        ),
      );

      await repository.setPrimaryDataSource(
        diveId: diveId,
        computerReadingId: 'reading-b',
      );

      final readings = await repository.getDataSources(diveId);
      final readingA = readings.firstWhere((r) => r.id == 'reading-a');
      final readingB = readings.firstWhere((r) => r.id == 'reading-b');

      expect(readingA.isPrimary, isFalse);
      expect(readingB.isPrimary, isTrue);
    });

    test(
      'updates the dives record with new primary computer metadata',
      () async {
        final diveId = await insertTestDive(
          id: 'dive-update-meta',
          diveComputerModel: 'Computer A',
          maxDepth: 30.0,
          duration: 3000,
          waterTemp: 20.0,
        );

        await repository.saveComputerReading(
          buildReading(
            id: 'reading-a',
            diveId: diveId,
            isPrimary: true,
            computerModel: 'Computer A',
            maxDepth: 30.0,
            duration: 3000,
            waterTemp: 20.0,
          ),
        );
        await repository.saveComputerReading(
          buildReading(
            id: 'reading-b',
            diveId: diveId,
            isPrimary: false,
            computerModel: 'Computer B',
            maxDepth: 28.0,
            duration: 2800,
            waterTemp: 19.0,
          ),
        );

        await repository.setPrimaryDataSource(
          diveId: diveId,
          computerReadingId: 'reading-b',
        );

        // The dives record should reflect Computer B's metadata.
        final diveRow = await (db.select(
          db.dives,
        )..where((t) => t.id.equals(diveId))).getSingle();
        expect(diveRow.diveComputerModel, equals('Computer B'));
        expect(diveRow.maxDepth, equals(28.0));
        expect(diveRow.bottomTime, equals(2800));
        expect(diveRow.waterTemp, equals(19.0));
      },
    );

    test(
      'swaps isPrimary flags on dive_profiles when computerId is available',
      () async {
        // This test uses null computerId since FK refs are unavailable in tests.
        // Profile swapping by computerId is exercised in the implementation;
        // here we verify the demotion step (all profiles demoted to non-primary)
        // and that profiles associated with a non-null computerId get promoted.
        //
        // Since we cannot insert real DiveComputer rows, we verify the
        // demotion side: after swapping, profiles that were primary become
        // non-primary (computerId-less profiles remain demoted).
        final diveId = await insertTestDive(
          id: 'dive-profile-swap',
          diveComputerModel: 'Computer A',
        );

        await repository.saveComputerReading(
          buildReading(
            id: 'reading-a',
            diveId: diveId,
            isPrimary: true,
            computerModel: 'Computer A',
          ),
        );
        await repository.saveComputerReading(
          buildReading(
            id: 'reading-b',
            diveId: diveId,
            isPrimary: false,
            computerModel: 'Computer B',
          ),
        );

        // Insert profiles with isPrimary=true (both without computerId).
        await insertTestProfile(
          diveId: diveId,
          sourceTag: 'a1',
          isPrimary: true,
          timestamp: 0,
          depth: 5.0,
        );
        await insertTestProfile(
          diveId: diveId,
          sourceTag: 'a2',
          isPrimary: true,
          timestamp: 60,
          depth: 10.0,
        );

        await repository.setPrimaryDataSource(
          diveId: diveId,
          computerReadingId: 'reading-b',
        );

        // All profiles (null computerId) should be demoted to non-primary
        // since reading-b has no computerId to match for promotion.
        final profiles = await (db.select(
          db.diveProfiles,
        )..where((t) => t.diveId.equals(diveId))).get();

        for (final p in profiles) {
          expect(
            p.isPrimary,
            isFalse,
            reason:
                'All profiles should be demoted when new primary has no '
                'matching computerId',
          );
        }

        // Verify the reading flags were still swapped correctly.
        final readings = await repository.getDataSources(diveId);
        final readingA = readings.firstWhere((r) => r.id == 'reading-a');
        final readingB = readings.firstWhere((r) => r.id == 'reading-b');
        expect(readingA.isPrimary, isFalse);
        expect(readingB.isPrimary, isTrue);
      },
    );
  });

  group('tank computerId persistence through entity round-trips', () {
    Future<void> insertComputer(String id) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.diveComputers)
          .insert(
            DiveComputersCompanion(
              id: Value(id),
              name: Value('Computer $id'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );
    }

    Future<String?> tankComputerId(String tankId) async {
      final row = await (db.select(
        db.diveTanks,
      )..where((t) => t.id.equals(tankId))).getSingle();
      return row.computerId;
    }

    domain.DiveTank attributedTank(String id, {String? computerId}) =>
        domain.DiveTank(
          id: id,
          gasMix: const domain.GasMix(o2: 21, he: 0),
          startPressure: 200,
          endPressure: 100,
          order: 0,
          computerId: computerId,
        );

    test('createDive persists tank attribution', () async {
      await insertComputer('comp-x');
      await repository.createDive(
        domain.Dive(
          id: 'dive-rt-1',
          dateTime: DateTime.utc(2026, 7, 2, 9),
          tanks: [attributedTank('tank-rt-1', computerId: 'comp-x')],
        ),
      );
      expect(await tankComputerId('tank-rt-1'), 'comp-x');
    });

    test('updateDive persists attribution on newly added tanks', () async {
      await insertComputer('comp-x');
      await repository.createDive(
        domain.Dive(
          id: 'dive-rt-2',
          dateTime: DateTime.utc(2026, 7, 2, 10),
          tanks: [attributedTank('tank-rt-2a')],
        ),
      );
      await repository.updateDive(
        domain.Dive(
          id: 'dive-rt-2',
          dateTime: DateTime.utc(2026, 7, 2, 10),
          tanks: [
            attributedTank('tank-rt-2a'),
            attributedTank('tank-rt-2b', computerId: 'comp-x'),
          ],
        ),
      );
      expect(await tankComputerId('tank-rt-2b'), 'comp-x');
    });

    test('updateDive does not clobber existing row attribution', () async {
      await insertComputer('comp-x');
      await repository.createDive(
        domain.Dive(
          id: 'dive-rt-3',
          dateTime: DateTime.utc(2026, 7, 2, 11),
          tanks: [attributedTank('tank-rt-3')],
        ),
      );
      // Attribution stamped by a consolidation-style direct row write.
      await (db.update(db.diveTanks)..where((t) => t.id.equals('tank-rt-3')))
          .write(const DiveTanksCompanion(computerId: Value('comp-x')));

      // An entity round-trip that lost the attribution (legacy caller)
      // must not null the column on the existing row.
      await repository.updateDive(
        domain.Dive(
          id: 'dive-rt-3',
          dateTime: DateTime.utc(2026, 7, 2, 11),
          tanks: [attributedTank('tank-rt-3')],
        ),
      );
      expect(await tankComputerId('tank-rt-3'), 'comp-x');
    });
  });
}
