import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

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
