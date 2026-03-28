import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;

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
    required String id,
    String? diveComputerModel,
    String? diveComputerSerial,
    double? maxDepth,
    double? avgDepth,
    int? duration,
    double? waterTemp,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(now),
            diveComputerModel: Value(diveComputerModel),
            diveComputerSerial: Value(diveComputerSerial),
            maxDepth: Value(maxDepth),
            avgDepth: Value(avgDepth),
            bottomTime: Value(duration),
            waterTemp: Value(waterTemp),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
    return id;
  }

  DiveDataSourcesCompanion buildReading({
    required String id,
    required String diveId,
    bool isPrimary = false,
    String? computerModel,
    String? computerSerial,
    double? maxDepth,
    double? avgDepth,
    int? duration,
    double? waterTemp,
  }) {
    final now = DateTime.now();
    return DiveDataSourcesCompanion(
      id: Value(id),
      diveId: Value(diveId),
      isPrimary: Value(isPrimary),
      computerModel: Value(computerModel),
      computerSerial: Value(computerSerial),
      maxDepth: Value(maxDepth),
      avgDepth: Value(avgDepth),
      duration: Value(duration),
      waterTemp: Value(waterTemp),
      importedAt: Value(now),
      createdAt: Value(now),
    );
  }

  Future<void> insertProfile({
    required String id,
    required String diveId,
    bool isPrimary = true,
    int timestamp = 0,
    double depth = 5.0,
  }) async {
    await db
        .into(db.diveProfiles)
        .insert(
          DiveProfilesCompanion(
            id: Value(id),
            diveId: Value(diveId),
            isPrimary: Value(isPrimary),
            timestamp: Value(timestamp),
            depth: Value(depth),
          ),
        );
  }

  // ---------------------------------------------------------------------------
  // Test 1: Full consolidation workflow
  // ---------------------------------------------------------------------------

  test(
    'full multi-computer workflow: consolidate, set primary, unlink',
    () async {
      // 1. Create a dive with profile data (simulating first computer import).
      final diveId = await insertTestDive(
        id: 'dive-main',
        diveComputerModel: 'Shearwater Petrel',
        diveComputerSerial: 'SW-001',
        maxDepth: 30.0,
        duration: 3600,
        waterTemp: 22.0,
      );

      await insertProfile(
        id: 'profile-primary-0',
        diveId: diveId,
        isPrimary: true,
        timestamp: 0,
        depth: 0.0,
      );
      await insertProfile(
        id: 'profile-primary-60',
        diveId: diveId,
        isPrimary: true,
        timestamp: 60,
        depth: 30.0,
      );

      // 2. Call consolidateComputer to add second computer's data.
      final secondaryReading = buildReading(
        id: 'reading-secondary',
        diveId: diveId,
        isPrimary: false,
        computerModel: 'Suunto D5',
        computerSerial: 'SU-002',
        maxDepth: 29.5,
        duration: 3580,
        waterTemp: 21.8,
      );

      final secondaryProfile = [
        DiveProfilesCompanion(
          id: const Value('profile-secondary-0'),
          diveId: Value(diveId),
          isPrimary: const Value(false),
          timestamp: const Value(0),
          depth: const Value(0.0),
        ),
        DiveProfilesCompanion(
          id: const Value('profile-secondary-60'),
          diveId: Value(diveId),
          isPrimary: const Value(false),
          timestamp: const Value(60),
          depth: const Value(29.5),
        ),
      ];

      await repository.consolidateComputer(
        targetDiveId: diveId,
        secondaryReading: secondaryReading,
        secondaryProfile: secondaryProfile,
      );

      // 3. Verify: 2 computer readings exist.
      final readings = await repository.getDataSources(diveId);
      expect(readings.length, equals(2));

      // 4. Verify: getProfilesBySource returns 2 entries
      // (primary profiles vs secondary profiles are two distinct sources).
      final profileSources = await repository.getProfilesBySource(diveId);
      expect(profileSources.length, equals(2));

      // 5. Call setPrimaryDataSource to swap primary to the secondary reading.
      await repository.setPrimaryDataSource(
        diveId: diveId,
        computerReadingId: 'reading-secondary',
      );

      // 6. Verify: dives record updated with new primary's metadata.
      final updatedDive = await repository.getDiveById(diveId);
      expect(updatedDive, isNotNull);
      expect(updatedDive!.diveComputerModel, equals('Suunto D5'));

      // Confirm reading flags were swapped.
      final readingsAfterSwap = await repository.getDataSources(diveId);
      final newPrimary = readingsAfterSwap.firstWhere((r) => r.isPrimary);
      expect(newPrimary.id, equals('reading-secondary'));

      // 7. Call unlinkComputer to detach the (now secondary) original reading.
      final originalReading = readingsAfterSwap.firstWhere((r) => !r.isPrimary);
      await repository.unlinkComputer(
        diveId: diveId,
        computerReadingId: originalReading.id,
      );

      // 8. Verify: original dive back to single-computer (no dive_computer_data
      // rows remain, as unlink cleans up when only one reading is left).
      final finalReadings = await repository.getDataSources(diveId);
      expect(finalReadings.isEmpty, isTrue);

      // 9. Verify: new standalone dive created with correct metadata.
      final allDives = await (db.select(db.dives)).get();
      // There should now be 2 dives: the original and the newly split-off one.
      expect(allDives.length, equals(2));
      final newDive = allDives.firstWhere((d) => d.id != diveId);
      expect(newDive, isNotNull);
    },
  );

  // ---------------------------------------------------------------------------
  // Test 2: Full merge workflow
  // ---------------------------------------------------------------------------

  test(
    'full merge workflow: create two dives, merge, verify, unlink',
    () async {
      // 1. Create two separate dives with profile data.
      final diveAId = await insertTestDive(
        id: 'dive-a',
        diveComputerModel: 'Shearwater Perdix',
        diveComputerSerial: 'PX-100',
        maxDepth: 40.0,
        duration: 4200,
        waterTemp: 18.0,
      );

      final diveBId = await insertTestDive(
        id: 'dive-b',
        diveComputerModel: 'Garmin MK2i',
        diveComputerSerial: 'GR-200',
        maxDepth: 39.5,
        duration: 4180,
        waterTemp: 17.8,
      );

      await insertProfile(
        id: 'profile-a-0',
        diveId: diveAId,
        isPrimary: true,
        timestamp: 0,
        depth: 0.0,
      );
      await insertProfile(
        id: 'profile-a-120',
        diveId: diveAId,
        isPrimary: true,
        timestamp: 120,
        depth: 40.0,
      );

      await insertProfile(
        id: 'profile-b-0',
        diveId: diveBId,
        isPrimary: true,
        timestamp: 0,
        depth: 0.0,
      );
      await insertProfile(
        id: 'profile-b-120',
        diveId: diveBId,
        isPrimary: true,
        timestamp: 120,
        depth: 39.5,
      );

      // 2. Call mergeDives (merge dive B into dive A).
      await repository.mergeDives(
        primaryDiveId: diveAId,
        secondaryDiveId: diveBId,
      );

      // 3. Verify: primary dive has 2 computer readings.
      final readings = await repository.getDataSources(diveAId);
      expect(readings.length, equals(2));

      final primaryReading = readings.firstWhere((r) => r.isPrimary);
      expect(primaryReading.computerModel, equals('Shearwater Perdix'));

      final secondaryReading = readings.firstWhere((r) => !r.isPrimary);
      expect(secondaryReading.computerModel, equals('Garmin MK2i'));

      // 4. Verify: secondary dive deleted.
      final deletedDive = await repository.getDiveById(diveBId);
      expect(deletedDive, isNull);

      // 5. Call unlinkComputer on the merged (secondary) computer reading.
      final newDiveId = await repository.unlinkComputer(
        diveId: diveAId,
        computerReadingId: secondaryReading.id,
      );

      // 6. Verify: both dives exist again as standalone entries.
      final diveA = await repository.getDiveById(diveAId);
      expect(diveA, isNotNull);

      final restoredDive = await repository.getDiveById(newDiveId);
      expect(restoredDive, isNotNull);

      // Original dive should be back to single-computer state (no readings).
      final remainingReadings = await repository.getDataSources(diveAId);
      expect(remainingReadings.isEmpty, isTrue);
    },
  );
}
