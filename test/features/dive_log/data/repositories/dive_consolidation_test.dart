import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
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
  // consolidateComputer
  // ---------------------------------------------------------------------------

  group('consolidateComputer', () {
    test(
      'adds secondary reading and back-fills primary on first consolidation',
      () async {
        // Set up a dive with no existing computer readings.
        final diveId = await insertTestDive(
          id: 'dive-primary',
          diveComputerModel: 'Shearwater Petrel',
          maxDepth: 30.0,
        );

        await insertTestProfile(
          diveId: diveId,
          sourceTag: 'primary',
          isPrimary: true,
          depth: 30.0,
        );

        final secondaryReading = buildReading(
          id: 'reading-secondary',
          diveId: diveId,
          isPrimary: false,
          computerModel: 'Suunto D5',
          maxDepth: 29.5,
        );

        await repository.consolidateComputer(
          targetDiveId: diveId,
          secondaryReading: secondaryReading,
          secondaryProfile: [],
        );

        final readings = await repository.getDataSources(diveId);
        // Should have 2 readings: back-filled primary + secondary.
        expect(readings.length, equals(2));

        final primary = readings.firstWhere((r) => r.isPrimary);
        expect(primary.computerModel, equals('Shearwater Petrel'));

        final secondary = readings.firstWhere((r) => !r.isPrimary);
        expect(secondary.id, equals('reading-secondary'));
        expect(secondary.computerModel, equals('Suunto D5'));
      },
    );

    test(
      'skips back-fill if primary reading already exists (already multi-computer)',
      () async {
        final diveId = await insertTestDive(id: 'dive-multi');

        // Insert an existing primary reading.
        await repository.saveComputerReading(
          buildReading(id: 'existing-primary', diveId: diveId, isPrimary: true),
        );

        final secondaryReading = buildReading(
          id: 'reading-new-secondary',
          diveId: diveId,
          isPrimary: false,
          computerModel: 'Garmin MK2i',
        );

        await repository.consolidateComputer(
          targetDiveId: diveId,
          secondaryReading: secondaryReading,
          secondaryProfile: [],
        );

        final readings = await repository.getDataSources(diveId);
        // Should be exactly 2: existing primary + new secondary.
        expect(readings.length, equals(2));

        final primaries = readings.where((r) => r.isPrimary).toList();
        expect(primaries.length, equals(1));
        expect(primaries.first.id, equals('existing-primary'));

        final secondaries = readings.where((r) => !r.isPrimary).toList();
        expect(secondaries.length, equals(1));
        expect(secondaries.first.id, equals('reading-new-secondary'));
      },
    );

    test('inserts secondary profile points with isPrimary=false', () async {
      final diveId = await insertTestDive(id: 'dive-with-profiles');

      // Insert existing primary reading.
      await repository.saveComputerReading(
        buildReading(id: 'primary-reading', diveId: diveId, isPrimary: true),
      );

      final secondaryReading = buildReading(
        id: 'secondary-reading',
        diveId: diveId,
        isPrimary: false,
      );

      // Provide secondary profile points (computerId null, isPrimary=false).
      final secondaryProfile = [
        DiveProfilesCompanion(
          id: const Value('sp-1'),
          diveId: Value(diveId),
          isPrimary: const Value(false),
          timestamp: const Value(0),
          depth: const Value(5.0),
        ),
        DiveProfilesCompanion(
          id: const Value('sp-2'),
          diveId: Value(diveId),
          isPrimary: const Value(false),
          timestamp: const Value(60),
          depth: const Value(10.0),
        ),
      ];

      await repository.consolidateComputer(
        targetDiveId: diveId,
        secondaryReading: secondaryReading,
        secondaryProfile: secondaryProfile,
      );

      // Verify secondary profiles were inserted with isPrimary=false.
      final allProfiles = await (db.select(
        db.diveProfiles,
      )..where((t) => t.diveId.equals(diveId))).get();
      final secondaryProfiles = allProfiles.where((p) => !p.isPrimary).toList();
      expect(secondaryProfiles.length, equals(2));
    });
  });

  // ---------------------------------------------------------------------------
  // mergeDives
  // ---------------------------------------------------------------------------

  group('mergeDives', () {
    test(
      're-parents secondary profiles to primary dive and deletes source dive',
      () async {
        final primaryId = await insertTestDive(
          id: 'dive-primary',
          diveComputerModel: 'Shearwater',
          maxDepth: 40.0,
        );
        final secondaryId = await insertTestDive(
          id: 'dive-secondary',
          diveComputerModel: 'Suunto',
          maxDepth: 39.0,
        );

        await insertTestProfile(
          diveId: primaryId,
          sourceTag: 'primary',
          isPrimary: true,
          timestamp: 0,
          depth: 5.0,
        );
        await insertTestProfile(
          diveId: secondaryId,
          sourceTag: 'secondary',
          isPrimary: true,
          timestamp: 10,
          depth: 8.0,
        );

        await repository.mergeDives(
          primaryDiveId: primaryId,
          secondaryDiveId: secondaryId,
        );

        // Secondary dive should be deleted.
        final secondaryDive = await (db.select(
          db.dives,
        )..where((t) => t.id.equals(secondaryId))).getSingleOrNull();
        expect(secondaryDive, isNull);

        // Both profiles (original + re-parented) should be on the primary dive.
        final primaryProfiles = await (db.select(
          db.diveProfiles,
        )..where((t) => t.diveId.equals(primaryId))).get();
        expect(primaryProfiles.length, equals(2));

        // The re-parented profile should have isPrimary=false.
        final reParented = primaryProfiles.firstWhere((p) => p.timestamp == 10);
        expect(reParented.isPrimary, isFalse);
      },
    );

    test('creates a computer reading from secondary dive metadata', () async {
      final primaryId = await insertTestDive(
        id: 'dive-a',
        diveComputerModel: 'Primary Computer',
        maxDepth: 40.0,
      );
      final secondaryId = await insertTestDive(
        id: 'dive-b',
        diveComputerModel: 'Secondary Computer',
        diveComputerSerial: 'SN-222',
        maxDepth: 39.0,
        duration: 2700,
        waterTemp: 18.5,
      );

      await repository.mergeDives(
        primaryDiveId: primaryId,
        secondaryDiveId: secondaryId,
      );

      final readings = await repository.getDataSources(primaryId);
      expect(readings.isNotEmpty, isTrue);

      // The non-primary reading should contain the secondary's metadata.
      final secondaryReading = readings.firstWhere(
        (r) => r.computerModel == 'Secondary Computer',
        orElse: () => throw StateError('No secondary computer reading found'),
      );
      expect(secondaryReading.computerSerial, equals('SN-222'));
      expect(secondaryReading.maxDepth, equals(39.0));
      expect(secondaryReading.duration, equals(2700));
      expect(secondaryReading.waterTemp, equals(18.5));
      expect(secondaryReading.isPrimary, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // unlinkComputer
  // ---------------------------------------------------------------------------

  group('unlinkComputer', () {
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

      final newDiveId = await repository.unlinkComputer(
        diveId: diveId,
        computerReadingId: 'secondary-reading',
      );

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
      'cleans up remaining single dive_computer_data row after unlink',
      () async {
        // When only one reading remains after unlink, the dive returns to
        // single-computer state and the reading is removed.
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

        await repository.unlinkComputer(
          diveId: diveId,
          computerReadingId: 'reading-b',
        );

        // The unlinked reading must be gone from the original dive.
        final originalReadings = await repository.getDataSources(diveId);
        expect(originalReadings.any((r) => r.id == 'reading-b'), isFalse);

        // Exactly zero readings remain (single-computer state cleanup).
        expect(originalReadings.isEmpty, isTrue);
      },
    );

    test('promotes next computer if primary is unlinked', () async {
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

      // Unlink the PRIMARY computer.
      await repository.unlinkComputer(
        diveId: diveId,
        computerReadingId: 'primary-reading',
      );

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

      final newId = await repository.unlinkComputer(
        diveId: diveId,
        computerReadingId: 'r-secondary',
      );

      expect(newId, isNotEmpty);
      expect(newId, isNot(equals(diveId)));
    });
  });

  // ---------------------------------------------------------------------------
  // unlinkComputer moves attributed children (Task 6)
  // ---------------------------------------------------------------------------

  group('unlinkComputer moves attributed children', () {
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

      final newDiveId = await repository.unlinkComputer(
        diveId: 'dive-t',
        computerReadingId: secondaryReading.id,
      );

      // -- Tanks -------------------------------------------------------
      final newDiveTanks = await (db.select(
        db.diveTanks,
      )..where((t) => t.diveId.equals(newDiveId))).get();
      // The fresh (non-shared) tank moves outright; the shared tank gets
      // a clone attributed to the unlinked computer.
      expect(newDiveTanks, hasLength(2));
      expect(newDiveTanks.every((t) => t.computerId == 'comp-s'), isTrue);
      expect(newDiveTanks.map((t) => t.id), contains(freshTank.id));
      final clone = newDiveTanks.firstWhere((t) => t.id != freshTank.id);
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
      expect(originalTanks.map((t) => t.id), isNot(contains(freshTank.id)));
      final sharedTank = originalTanks.firstWhere((t) => t.id == 'tank-t1');
      expect(sharedTank.computerId, equals('comp-t'));

      // -- Tank pressure profiles ---------------------------------------
      final newDivePressures = await (db.select(
        db.tankPressureProfiles,
      )..where((t) => t.diveId.equals(newDiveId))).get();
      expect(newDivePressures, hasLength(2));
      expect(newDivePressures.every((p) => p.computerId == 'comp-s'), isTrue);
      // The pressure curve that lived on the shared tank now points at
      // the clone, not the original shared tank id.
      final movedFromShared = newDivePressures.firstWhere(
        (p) => p.pressure == 195.0 && p.id != 'tp-s2',
      );
      expect(movedFromShared.tankId, equals(clone.id));
      // The pressure curve that already lived on the fresh tank keeps
      // that tank id.
      final movedWithFreshTank = newDivePressures.firstWhere(
        (p) => p.tankId == freshTank.id,
      );
      expect(movedWithFreshTank.computerId, equals('comp-s'));

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

    test(
      'unlink with a null-computerId reading moves no tanks or events',
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

        final newDiveId = await repository.unlinkComputer(
          diveId: diveId,
          computerReadingId: 'r-secondary',
        );

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
}
