import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('DiveRepository error handling', () {
    late DiveRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('methods that rethrow throw on database error', () async {
      // Reset DB to null so _db access throws StateError
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      await expectLater(repository.getAllDives(), throwsA(anything));
      await expectLater(repository.getDiveById('test-id'), throwsA(anything));
      await expectLater(
        repository.saveEditedProfile('test-id', []),
        throwsA(anything),
      );
      await expectLater(
        repository.restoreOriginalProfile('test-id'),
        throwsA(anything),
      );
      await expectLater(repository.getDiveCount(), throwsA(anything));
      await expectLater(
        repository.getDivesForSite('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.getDivesForCourse('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.getDivesInRange(DateTime.now(), DateTime.now()),
        throwsA(anything),
      );
      await expectLater(repository.getNextDiveNumber(), throwsA(anything));
      await expectLater(repository.searchDives('test'), throwsA(anything));
      await expectLater(repository.getStatistics(), throwsA(anything));
      await expectLater(repository.getRecords(), throwsA(anything));
      final dummyDive = Dive(id: 'test-id', dateTime: DateTime.now());
      await expectLater(repository.createDive(dummyDive), throwsA(anything));
      await expectLater(repository.updateDive(dummyDive), throwsA(anything));
      await expectLater(
        repository.deletePlannedDive('test-id'),
        throwsA(anything),
      );
      await expectLater(repository.deleteDive('test-id'), throwsA(anything));
      await expectLater(
        repository.bulkDeleteDives(['test-id']),
        throwsA(anything),
      );
      await expectLater(
        repository.getDivesByIds(['test-id']),
        throwsA(anything),
      );
      await expectLater(repository.getDiveSummaries(), throwsA(anything));
      await expectLater(
        repository.toggleFavorite('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.setFavorite('test-id', true),
        throwsA(anything),
      );
      await expectLater(repository.getFavoriteDives(), throwsA(anything));
      await expectLater(repository.getPlannedDives(), throwsA(anything));
      await expectLater(repository.getDiveNumberingInfo(), throwsA(anything));
      await expectLater(repository.renumberAllDives(), throwsA(anything));
      await expectLater(
        repository.assignMissingDiveNumbers(),
        throwsA(anything),
      );
      await expectLater(
        repository.bulkUpdateTrip(['test-id'], 'trip-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.bulkAddTags(['test-id'], ['tag-id']),
        throwsA(anything),
      );
      await expectLater(
        repository.bulkRemoveTags(['test-id'], ['tag-id']),
        throwsA(anything),
      );
      await expectLater(
        repository.getDataSources('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.hasMultipleDataSources('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.deleteComputerReading('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.backfillPrimaryDataSource('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.deleteGasSwitch('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.deleteGasSwitchesForDive('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.setPrimaryDataSource(
          diveId: 'test-id',
          computerReadingId: 'reading-id',
        ),
        throwsA(anything),
      );
    });

    test(
      'should throw ArgumentError when updating dive with a tank that has an empty id',
      () async {
        final createdDive = await repository.createDive(
          Dive(
            id: 'test-dive',
            dateTime: DateTime.now(),
            tanks: const [
              DiveTank(
                id: '',
                volume: 12.0,
                startPressure: 200,
                endPressure: 50,
              ),
            ],
          ),
        );

        final updatedDive = createdDive.copyWith(
          tanks: [createdDive.tanks[0].copyWith(id: '')],
          notes: 'Attempt update with empty tank id',
        );

        await expectLater(
          repository.updateDive(updatedDive),
          throwsA(isA<ArgumentError>()),
        );
      },
    );

    test(
      'methods that return defaults return correct values on error',
      () async {
        await DatabaseService.instance.database.close();
        DatabaseService.instance.resetForTesting();

        // Methods that return empty list
        expect(await repository.getDiveProfile('test-id'), isEmpty);
        expect(await repository.getGasSwitchesForDive('test-id'), isEmpty);

        // Methods that return empty map
        expect(await repository.getProfilesBySource('test-id'), isEmpty);
        expect(await repository.getBatchProfileSummaries(['test-id']), isEmpty);

        // Methods that return null
        expect(await repository.getPreviousDive('test-id'), isNull);
        expect(await repository.getSurfaceInterval('test-id'), isNull);
      },
    );
  });
}
