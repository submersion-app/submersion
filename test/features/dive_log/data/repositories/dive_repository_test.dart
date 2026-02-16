import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/performance/perf_timer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/performance_data_generator.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;
  late SiteRepository siteRepository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
    siteRepository = SiteRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Dive createTestDive({
    String id = '',
    int? diveNumber,
    DateTime? dateTime,
    Duration? duration,
    double? maxDepth,
    double? avgDepth,
    DiveSite? site,
    List<DiveTank> tanks = const [],
    String notes = '',
    double? waterTemp,
    String diveTypeId = 'recreational',
    String? buddy,
    int? rating,
  }) {
    return Dive(
      id: id,
      diveNumber: diveNumber,
      dateTime: dateTime ?? DateTime.now(),
      duration: duration,
      maxDepth: maxDepth,
      avgDepth: avgDepth,
      site: site,
      tanks: tanks,
      notes: notes,
      waterTemp: waterTemp,
      diveTypeId: diveTypeId,
      buddy: buddy,
      rating: rating,
    );
  }

  group('DiveRepository', () {
    group('createDive', () {
      test(
        'should create a new dive with generated ID when ID is empty',
        () async {
          final dive = createTestDive(diveNumber: 1, maxDepth: 18.5);

          final createdDive = await repository.createDive(dive);

          expect(createdDive.id, isNotEmpty);
          expect(createdDive.diveNumber, equals(1));
        },
      );

      test('should create a dive with provided ID', () async {
        final dive = createTestDive(id: 'custom-dive-id');

        final createdDive = await repository.createDive(dive);

        expect(createdDive.id, equals('custom-dive-id'));
      });

      test('should create a dive with all basic fields', () async {
        final dateTime = DateTime(2024, 6, 15, 10, 30);
        final dive = createTestDive(
          diveNumber: 100,
          dateTime: dateTime,
          duration: const Duration(minutes: 45),
          maxDepth: 25.5,
          avgDepth: 15.0,
          notes: 'Great visibility today',
          waterTemp: 24.0,
          diveTypeId: 'recreational',
          buddy: 'John Doe',
          rating: 5,
        );

        final createdDive = await repository.createDive(dive);
        final fetchedDive = await repository.getDiveById(createdDive.id);

        expect(fetchedDive, isNotNull);
        expect(fetchedDive!.diveNumber, equals(100));
        expect(fetchedDive.maxDepth, equals(25.5));
        expect(fetchedDive.avgDepth, equals(15.0));
        expect(fetchedDive.duration?.inMinutes, equals(45));
        expect(fetchedDive.notes, equals('Great visibility today'));
        expect(fetchedDive.waterTemp, equals(24.0));
        expect(fetchedDive.diveTypeId, equals('recreational'));
        expect(fetchedDive.buddy, equals('John Doe'));
        expect(fetchedDive.rating, equals(5));
      });

      test('should create a dive with tanks', () async {
        final dive = createTestDive(
          tanks: [
            const DiveTank(
              id: '',
              volume: 12.0,
              startPressure: 200,
              endPressure: 50,
              gasMix: GasMix(o2: 32.0),
              order: 0,
            ),
          ],
        );

        final createdDive = await repository.createDive(dive);
        final fetchedDive = await repository.getDiveById(createdDive.id);

        expect(fetchedDive, isNotNull);
        expect(fetchedDive!.tanks.length, equals(1));
        expect(fetchedDive.tanks[0].volume, equals(12.0));
        expect(fetchedDive.tanks[0].startPressure, equals(200));
        expect(fetchedDive.tanks[0].endPressure, equals(50));
        expect(fetchedDive.tanks[0].gasMix.o2, equals(32.0));
      });

      test('should create a dive with site', () async {
        final site = await siteRepository.createSite(
          const DiveSite(id: '', name: 'Test Site'),
        );

        final dive = createTestDive(site: site);

        final createdDive = await repository.createDive(dive);
        final fetchedDive = await repository.getDiveById(createdDive.id);

        expect(fetchedDive, isNotNull);
        expect(fetchedDive!.site, isNotNull);
        expect(fetchedDive.site!.name, equals('Test Site'));
      });
    });

    group('getDiveById', () {
      test('should return dive when found', () async {
        final dive = await repository.createDive(
          createTestDive(diveNumber: 42, maxDepth: 30.0),
        );

        final result = await repository.getDiveById(dive.id);

        expect(result, isNotNull);
        expect(result!.diveNumber, equals(42));
        expect(result.maxDepth, equals(30.0));
      });

      test('should return null when dive not found', () async {
        final result = await repository.getDiveById('non-existent-id');

        expect(result, isNull);
      });
    });

    group('getAllDives', () {
      test('should return empty list when no dives exist', () async {
        final result = await repository.getAllDives();

        expect(result, isEmpty);
      });

      test('should return all dives ordered by date (newest first)', () async {
        await repository.createDive(
          createTestDive(diveNumber: 1, dateTime: DateTime(2024, 1, 1)),
        );
        await repository.createDive(
          createTestDive(diveNumber: 3, dateTime: DateTime(2024, 3, 1)),
        );
        await repository.createDive(
          createTestDive(diveNumber: 2, dateTime: DateTime(2024, 2, 1)),
        );

        final result = await repository.getAllDives();

        expect(result.length, equals(3));
        expect(result[0].diveNumber, equals(3)); // Most recent
        expect(result[1].diveNumber, equals(2));
        expect(result[2].diveNumber, equals(1)); // Oldest
      });
    });

    group('updateDive', () {
      test('should update dive fields', () async {
        final dive = await repository.createDive(
          createTestDive(
            diveNumber: 1,
            maxDepth: 20.0,
            notes: 'Original notes',
          ),
        );

        final updatedDive = dive.copyWith(
          maxDepth: 25.0,
          notes: 'Updated notes',
          rating: 4,
        );

        await repository.updateDive(updatedDive);
        final result = await repository.getDiveById(dive.id);

        expect(result, isNotNull);
        expect(result!.maxDepth, equals(25.0));
        expect(result.notes, equals('Updated notes'));
        expect(result.rating, equals(4));
      });

      test('should update dive tanks', () async {
        final dive = await repository.createDive(
          createTestDive(
            tanks: [
              const DiveTank(
                id: '',
                volume: 12.0,
                startPressure: 200,
                endPressure: 50,
              ),
            ],
          ),
        );

        final updatedDive = dive.copyWith(
          tanks: [
            const DiveTank(
              id: '',
              volume: 15.0,
              startPressure: 210,
              endPressure: 40,
            ),
          ],
        );

        await repository.updateDive(updatedDive);
        final result = await repository.getDiveById(dive.id);

        expect(result!.tanks.length, equals(1));
        expect(result.tanks[0].volume, equals(15.0));
        expect(result.tanks[0].startPressure, equals(210));
      });
    });

    group('deleteDive', () {
      test('should delete existing dive', () async {
        final dive = await repository.createDive(createTestDive(diveNumber: 1));

        await repository.deleteDive(dive.id);
        final result = await repository.getDiveById(dive.id);

        expect(result, isNull);
      });

      test('should not throw when deleting non-existent dive', () async {
        await expectLater(repository.deleteDive('non-existent-id'), completes);
      });

      test('should cascade delete tanks', () async {
        final dive = await repository.createDive(
          createTestDive(
            tanks: [
              const DiveTank(
                id: '',
                volume: 12.0,
                startPressure: 200,
                endPressure: 50,
              ),
            ],
          ),
        );

        await repository.deleteDive(dive.id);
        final result = await repository.getDiveById(dive.id);

        expect(result, isNull);
        // Tanks are cascade deleted with the dive
      });
    });

    group('getDivesForSite', () {
      test('should return dives for specific site', () async {
        final site = await siteRepository.createSite(
          const DiveSite(id: '', name: 'Site A'),
        );
        final otherSite = await siteRepository.createSite(
          const DiveSite(id: '', name: 'Site B'),
        );

        await repository.createDive(createTestDive(diveNumber: 1, site: site));
        await repository.createDive(createTestDive(diveNumber: 2, site: site));
        await repository.createDive(
          createTestDive(diveNumber: 3, site: otherSite),
        );

        final result = await repository.getDivesForSite(site.id);

        expect(result.length, equals(2));
        expect(result.every((d) => d.site?.id == site.id), isTrue);
      });

      test('should return empty list when site has no dives', () async {
        final site = await siteRepository.createSite(
          const DiveSite(id: '', name: 'Empty Site'),
        );

        final result = await repository.getDivesForSite(site.id);

        expect(result, isEmpty);
      });
    });

    group('getDivesInRange', () {
      test('should return dives within date range', () async {
        await repository.createDive(
          createTestDive(diveNumber: 1, dateTime: DateTime(2024, 1, 15)),
        );
        await repository.createDive(
          createTestDive(diveNumber: 2, dateTime: DateTime(2024, 2, 15)),
        );
        await repository.createDive(
          createTestDive(diveNumber: 3, dateTime: DateTime(2024, 3, 15)),
        );

        final result = await repository.getDivesInRange(
          DateTime(2024, 2, 1),
          DateTime(2024, 2, 28),
        );

        expect(result.length, equals(1));
        expect(result[0].diveNumber, equals(2));
      });

      test('should return empty list when no dives in range', () async {
        await repository.createDive(
          createTestDive(diveNumber: 1, dateTime: DateTime(2024, 1, 15)),
        );

        final result = await repository.getDivesInRange(
          DateTime(2024, 6, 1),
          DateTime(2024, 6, 30),
        );

        expect(result, isEmpty);
      });
    });

    group('getNextDiveNumber', () {
      test('should return 1 when no dives exist', () async {
        final nextNumber = await repository.getNextDiveNumber();

        expect(nextNumber, equals(1));
      });

      test('should return next number after highest', () async {
        await repository.createDive(createTestDive(diveNumber: 5));
        await repository.createDive(createTestDive(diveNumber: 10));
        await repository.createDive(createTestDive(diveNumber: 3));

        final nextNumber = await repository.getNextDiveNumber();

        expect(nextNumber, equals(11));
      });
    });

    group('searchDives', () {
      setUp(() async {
        await repository.createDive(
          createTestDive(
            diveNumber: 1,
            notes: 'Saw amazing coral reef',
            buddy: 'Alice',
          ),
        );
        await repository.createDive(
          createTestDive(
            diveNumber: 2,
            notes: 'Night dive with turtle',
            buddy: 'Bob',
          ),
        );
        await repository.createDive(
          createTestDive(
            diveNumber: 3,
            notes: 'Deep dive on wreck',
            buddy: 'Charlie',
          ),
        );
      });

      test('should find dives by notes', () async {
        final results = await repository.searchDives('coral');

        expect(results.length, equals(1));
        expect(results[0].diveNumber, equals(1));
      });

      test('should find dives by buddy', () async {
        final results = await repository.searchDives('Bob');

        expect(results.length, equals(1));
        expect(results[0].diveNumber, equals(2));
      });

      test('should return empty list for no matches', () async {
        final results = await repository.searchDives('NonExistent');

        expect(results, isEmpty);
      });
    });

    group('getStatistics', () {
      test('should return zero stats when no dives exist', () async {
        final stats = await repository.getStatistics();

        expect(stats.totalDives, equals(0));
        expect(stats.totalTimeSeconds, equals(0));
      });

      test('should calculate correct statistics', () async {
        await repository.createDive(
          createTestDive(
            diveNumber: 1,
            duration: const Duration(minutes: 30),
            maxDepth: 20.0,
            waterTemp: 25.0,
          ),
        );
        await repository.createDive(
          createTestDive(
            diveNumber: 2,
            duration: const Duration(minutes: 45),
            maxDepth: 30.0,
            waterTemp: 23.0,
          ),
        );

        final stats = await repository.getStatistics();

        expect(stats.totalDives, equals(2));
        expect(
          stats.totalTimeSeconds,
          equals(75 * 60),
        ); // 75 minutes in seconds
        expect(stats.maxDepth, equals(30.0));
      });
    });

    group('getRecords', () {
      test('should return null records when no dives exist', () async {
        final records = await repository.getRecords();

        expect(records.deepestDive, isNull);
        expect(records.longestDive, isNull);
      });

      test('should return correct records', () async {
        await repository.createDive(
          createTestDive(
            diveNumber: 1,
            duration: const Duration(minutes: 30),
            maxDepth: 20.0,
            waterTemp: 25.0,
            dateTime: DateTime(2024, 1, 15),
          ),
        );
        await repository.createDive(
          createTestDive(
            diveNumber: 2,
            duration: const Duration(minutes: 60),
            maxDepth: 35.0,
            waterTemp: 28.0,
            dateTime: DateTime(2024, 2, 15),
          ),
        );
        await repository.createDive(
          createTestDive(
            diveNumber: 3,
            duration: const Duration(minutes: 45),
            maxDepth: 25.0,
            waterTemp: 18.0,
            dateTime: DateTime(2024, 3, 15),
          ),
        );

        final records = await repository.getRecords();

        expect(records.deepestDive, isNotNull);
        expect(records.deepestDive!.maxDepth, equals(35.0));
        expect(records.longestDive, isNotNull);
        expect(records.longestDive!.duration?.inMinutes, equals(60));
        expect(records.coldestDive, isNotNull);
        expect(records.coldestDive!.waterTemp, equals(18.0));
        expect(records.warmestDive, isNotNull);
        expect(records.warmestDive!.waterTemp, equals(28.0));
      });
    });
  });

  group('Performance smoke tests (light preset)', () {
    late GeneratedDataSummary summary;

    setUp(() async {
      final generator = PerformanceDataGenerator(DataProfile.light);
      summary = await generator.generate();
    });

    test('getDiveSummaries loads page in under 100ms', () async {
      PerfTimer.reset();
      await repository.getDiveSummaries(diverId: summary.diverId, limit: 50);
      final duration = PerfTimer.lastResult('getDiveSummaries');
      expect(duration, isNotNull);
      expect(duration!.inMilliseconds, lessThan(100));
    });

    test('getDiveById loads in under 50ms', () async {
      final dives = await repository.getAllDives(diverId: summary.diverId);
      PerfTimer.reset();
      await repository.getDiveById(dives.first.id);
      final duration = PerfTimer.lastResult('getDiveById');
      expect(duration, isNotNull);
      expect(duration!.inMilliseconds, lessThan(50));
    });

    test('getDiveProfile loads in under 50ms', () async {
      final dives = await repository.getAllDives(diverId: summary.diverId);
      PerfTimer.reset();
      await repository.getDiveProfile(dives.first.id);
      final duration = PerfTimer.lastResult('getDiveProfile');
      expect(duration, isNotNull);
      expect(duration!.inMilliseconds, lessThan(50));
    });
  });

  group('profile editing persistence', () {
    test('saveEditedProfile stores edited points as primary', () async {
      final dive = createTestDive(maxDepth: 20.0, avgDepth: 15.0);
      final createdDive = await repository.createDive(
        dive.copyWith(
          profile: [
            const DiveProfilePoint(timestamp: 0, depth: 0.0),
            const DiveProfilePoint(timestamp: 4, depth: 10.0),
            const DiveProfilePoint(timestamp: 8, depth: 20.0),
            const DiveProfilePoint(timestamp: 12, depth: 10.0),
            const DiveProfilePoint(timestamp: 16, depth: 0.0),
          ],
        ),
      );

      // Save edited profile
      final editedPoints = [
        const DiveProfilePoint(timestamp: 0, depth: 0.0),
        const DiveProfilePoint(timestamp: 4, depth: 8.0),
        const DiveProfilePoint(timestamp: 8, depth: 15.0),
        const DiveProfilePoint(timestamp: 12, depth: 8.0),
        const DiveProfilePoint(timestamp: 16, depth: 0.0),
      ];
      await repository.saveEditedProfile(createdDive.id, editedPoints);

      // getDiveProfile should return edited profile (primary)
      final profile = await repository.getDiveProfile(createdDive.id);
      expect(profile.length, 5);
      expect(profile[2].depth, 15.0); // edited max depth
    });

    test('saveEditedProfile demotes original to non-primary', () async {
      final dive = createTestDive();
      final createdDive = await repository.createDive(
        dive.copyWith(
          profile: [
            const DiveProfilePoint(timestamp: 0, depth: 0.0),
            const DiveProfilePoint(timestamp: 4, depth: 10.0),
          ],
        ),
      );

      await repository.saveEditedProfile(createdDive.id, [
        const DiveProfilePoint(timestamp: 0, depth: 0.0),
        const DiveProfilePoint(timestamp: 4, depth: 5.0),
      ]);

      // getProfilesBySource should show both
      final sources = await repository.getProfilesBySource(createdDive.id);
      expect(sources.length, 2); // original + edited
      expect(sources.containsKey('user-edited'), isTrue);
    });

    test(
      'restoreOriginalProfile deletes edited and restores original',
      () async {
        final dive = createTestDive();
        final createdDive = await repository.createDive(
          dive.copyWith(
            profile: [
              const DiveProfilePoint(timestamp: 0, depth: 0.0),
              const DiveProfilePoint(timestamp: 4, depth: 20.0),
            ],
          ),
        );

        // Save edited then restore
        await repository.saveEditedProfile(createdDive.id, [
          const DiveProfilePoint(timestamp: 0, depth: 0.0),
          const DiveProfilePoint(timestamp: 4, depth: 10.0),
        ]);
        await repository.restoreOriginalProfile(createdDive.id);

        // getDiveProfile should return original
        final profile = await repository.getDiveProfile(createdDive.id);
        expect(profile.length, 2);
        expect(profile[1].depth, 20.0); // original depth restored
      },
    );

    test('getProfilesBySource returns both original and edited', () async {
      final dive = createTestDive();
      final createdDive = await repository.createDive(
        dive.copyWith(
          profile: [
            const DiveProfilePoint(timestamp: 0, depth: 0.0),
            const DiveProfilePoint(timestamp: 4, depth: 10.0),
            const DiveProfilePoint(timestamp: 8, depth: 20.0),
          ],
        ),
      );

      await repository.saveEditedProfile(createdDive.id, [
        const DiveProfilePoint(timestamp: 0, depth: 0.0),
        const DiveProfilePoint(timestamp: 4, depth: 8.0),
        const DiveProfilePoint(timestamp: 8, depth: 15.0),
      ]);

      final sources = await repository.getProfilesBySource(createdDive.id);
      expect(sources.length, 2);
      // Check user-edited source
      expect(sources['user-edited']!.length, 3);
      expect(sources['user-edited']![2].depth, 15.0);
    });

    test('saveEditedProfile recalculates dive stats', () async {
      final dive = createTestDive(maxDepth: 20.0, avgDepth: 10.0);
      final createdDive = await repository.createDive(
        dive.copyWith(
          profile: [
            const DiveProfilePoint(timestamp: 0, depth: 0.0),
            const DiveProfilePoint(timestamp: 4, depth: 20.0),
            const DiveProfilePoint(timestamp: 8, depth: 0.0),
          ],
        ),
      );

      // Save edited with lower max depth
      await repository.saveEditedProfile(createdDive.id, [
        const DiveProfilePoint(timestamp: 0, depth: 0.0),
        const DiveProfilePoint(timestamp: 4, depth: 12.0),
        const DiveProfilePoint(timestamp: 8, depth: 0.0),
      ]);

      // Dive stats should be recalculated
      final updatedDive = await repository.getDiveById(createdDive.id);
      expect(updatedDive!.maxDepth, 12.0);
      expect(updatedDive.avgDepth, 4.0); // (0 + 12 + 0) / 3 = 4.0
    });
  });
}
