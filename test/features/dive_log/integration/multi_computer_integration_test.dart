import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/data/services/dive_consolidation_service.dart';
import 'package:submersion/features/dive_log/data/services/dive_split_service.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late DiveRepository repository;
  late ProfileSeriesRepository profileSeries;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = DiveRepository();
    profileSeries = ProfileSeriesRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> insertComputer({
    required String id,
    required String name,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.diveComputers)
        .insert(
          DiveComputersCompanion(
            id: Value(id),
            name: Value(name),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<String> insertTestDive({
    required String id,
    String? computerId,
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
            computerId: Value(computerId),
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

  /// Series twin of the retired legacy `insertProfile`: same parameters,
  /// one single-sample series per call through the series repository, which
  /// is what consolidation, setPrimaryDataSource, and split now read and
  /// write. Returns the series id.
  Future<String> insertProfileSeries({
    required String id,
    required String diveId,
    bool isPrimary = true,
    int timestamp = 0,
    double depth = 5.0,
  }) {
    return profileSeries.insertSeries(
      id: id,
      diveId: diveId,
      isPrimary: isPrimary,
      samples: [ProfileSample(timestamp: timestamp, depth: depth)],
      now: 1000,
    );
  }

  // ---------------------------------------------------------------------------
  // Test 1: Full consolidation workflow
  // ---------------------------------------------------------------------------

  test(
    'full multi-computer workflow: consolidate, set primary, split',
    () async {
      // 1. Create a dive with profile data (simulating first computer import).
      await insertComputer(id: 'dc-petrel', name: 'My Petrel');
      await insertComputer(id: 'dc-d5', name: 'My D5');
      final diveId = await insertTestDive(
        id: 'dive-main',
        computerId: 'dc-petrel',
        diveComputerModel: 'Shearwater Petrel',
        diveComputerSerial: 'SW-001',
        maxDepth: 30.0,
        duration: 3600,
        waterTemp: 22.0,
      );

      await insertProfileSeries(
        id: 'profile-primary-0',
        diveId: diveId,
        isPrimary: true,
        timestamp: 0,
        depth: 0.0,
      );
      await insertProfileSeries(
        id: 'profile-primary-60',
        diveId: diveId,
        isPrimary: true,
        timestamp: 60,
        depth: 30.0,
      );

      // 2. Consolidate a second computer's download into the dive via
      // DiveConsolidationService (the consolidateComputer repository method
      // it replaced was removed; see dive_consolidation_service_test.dart
      // for the service's own suite).
      final secondaryDiveId = await insertTestDive(
        id: 'dive-secondary-download',
        computerId: 'dc-d5',
        diveComputerModel: 'Suunto D5',
        diveComputerSerial: 'SU-002',
        maxDepth: 29.5,
        duration: 3580,
        waterTemp: 21.8,
      );
      await insertProfileSeries(
        id: 'profile-secondary-0',
        diveId: secondaryDiveId,
        isPrimary: true,
        timestamp: 0,
        depth: 0.0,
      );
      await insertProfileSeries(
        id: 'profile-secondary-60',
        diveId: secondaryDiveId,
        isPrimary: true,
        timestamp: 60,
        depth: 29.5,
      );

      final consolidation = DiveConsolidationService(repository);
      await consolidation.apply(
        targetDiveId: diveId,
        secondaryDiveIds: [secondaryDiveId],
      );

      // 3. Verify: 2 computer readings exist.
      final readings = await repository.getDataSources(diveId);
      expect(readings.length, equals(2));

      // 4. Verify: getProfilesByDataSource returns 2 entries
      // (primary profiles vs secondary profiles are two distinct sources).
      final profileSources = await repository.getProfilesByDataSource(diveId);
      expect(profileSources.length, equals(2));

      // 5. Call setPrimaryDataSource to swap primary to the secondary reading.
      final secondaryReadingId = readings.firstWhere((r) => !r.isPrimary).id;
      await repository.setPrimaryDataSource(
        diveId: diveId,
        computerReadingId: secondaryReadingId,
      );

      // 6. Verify: dives record updated with new primary's metadata.
      final updatedDive = await repository.getDiveById(diveId);
      expect(updatedDive, isNotNull);
      expect(updatedDive!.diveComputerModel, equals('Suunto D5'));

      // Confirm reading flags were swapped.
      final readingsAfterSwap = await repository.getDataSources(diveId);
      final newPrimary = readingsAfterSwap.firstWhere((r) => r.isPrimary);
      expect(newPrimary.id, equals(secondaryReadingId));

      // The swap also promotes the new primary's own series. The promoted
      // computer contributed two single-sample series over disjoint times,
      // and neither supersedes the other, so both go live: promoting just
      // one would leave this dive rendering half the samples it has.
      final primarySeriesAfterSwap = (await profileSeries.getSeriesForDive(
        diveId,
      )).where((s) => s.isPrimary).toList();
      expect(primarySeriesAfterSwap, hasLength(2));
      expect(
        primarySeriesAfterSwap.map((s) => s.computerId),
        everyElement('dc-d5'),
      );
      expect(
        primarySeriesAfterSwap.expand((s) => s.samples).map((s) => s.timestamp),
        [0, 60],
      );

      // 7. Split the (now secondary) original reading into its own dive.
      final originalReading = readingsAfterSwap.firstWhere((r) => !r.isPrimary);
      await DiveSplitService(
        repository,
      ).split(diveId: diveId, sourceId: originalReading.id);

      // 8. Verify: only the remaining reading is left on the original
      // dive, still primary (split keeps the last source row; the sources
      // bar hides below two sources).
      final finalReadings = await repository.getDataSources(diveId);
      expect(finalReadings, hasLength(1));
      expect(finalReadings.single.isPrimary, isTrue);

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

  test('full merge workflow: create two dives, merge, verify, split', () async {
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

    await insertProfileSeries(
      id: 'profile-a-0',
      diveId: diveAId,
      isPrimary: true,
      timestamp: 0,
      depth: 0.0,
    );
    await insertProfileSeries(
      id: 'profile-a-120',
      diveId: diveAId,
      isPrimary: true,
      timestamp: 120,
      depth: 40.0,
    );

    await insertProfileSeries(
      id: 'profile-b-0',
      diveId: diveBId,
      isPrimary: true,
      timestamp: 0,
      depth: 0.0,
    );
    await insertProfileSeries(
      id: 'profile-b-120',
      diveId: diveBId,
      isPrimary: true,
      timestamp: 120,
      depth: 39.5,
    );

    // 2. Consolidate dive B into dive A via DiveConsolidationService
    // (the mergeDives repository method it replaced was removed; see
    // dive_consolidation_service_test.dart for the service's own suite).
    final consolidation = DiveConsolidationService(repository);
    await consolidation.apply(
      targetDiveId: diveAId,
      secondaryDiveIds: [diveBId],
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

    // 5. Split the merged (secondary) computer reading back out.
    final newDiveId = await DiveSplitService(
      repository,
    ).split(diveId: diveAId, sourceId: secondaryReading.id);

    // 6. Verify: both dives exist again as standalone entries.
    final diveA = await repository.getDiveById(diveAId);
    expect(diveA, isNotNull);

    final restoredDive = await repository.getDiveById(newDiveId);
    expect(restoredDive, isNotNull);

    // The original dive keeps its own (primary) reading only.
    final remainingReadings = await repository.getDataSources(diveAId);
    expect(remainingReadings, hasLength(1));
    expect(remainingReadings.single.isPrimary, isTrue);

    // The split-off dive carries the series consolidation copied over from
    // dive B (both single-sample series, moved back out as a unit).
    final newDiveSeries = await profileSeries.getSeriesForDive(newDiveId);
    expect(newDiveSeries, hasLength(2));
  });
}
