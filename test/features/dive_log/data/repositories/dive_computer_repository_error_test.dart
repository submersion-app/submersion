import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('DiveComputerRepository error handling', () {
    late DiveComputerRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveComputerRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('methods that rethrow throw on database error', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      await expectLater(repository.getAllComputers(), throwsA(anything));
      await expectLater(
        repository.getComputerById('test-id'),
        throwsA(anything),
      );
      await expectLater(repository.getFavoriteComputer(), throwsA(anything));
      await expectLater(
        repository.findByBluetoothAddress('AA:BB:CC:DD:EE:FF'),
        throwsA(anything),
      );
      await expectLater(
        repository.createComputer(
          DiveComputer(
            id: '',
            name: 'Test Computer',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
        throwsA(anything),
      );
      await expectLater(
        repository.updateComputer(
          DiveComputer(
            id: 'test-id',
            name: 'Test Computer',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ),
        throwsA(anything),
      );
      await expectLater(
        repository.deleteComputer('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.setFavoriteComputer('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.incrementDiveCount('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.updateLastDownload('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.updateLastFingerprint('test-id', 'fingerprint'),
        throwsA(anything),
      );
      await expectLater(
        repository.getProfilesForDive('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.getComputerIdsForDive('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.getComputersForDive('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.setPrimaryProfile('test-id', 'computer-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.importProfile(
          computerId: 'computer-id',
          points: [],
          profileStartTime: DateTime.now(),
          durationSeconds: 60,
          maxDepth: 10.0,
        ),
        throwsA(anything),
      );
      await expectLater(
        repository.findOrCreateComputer(serialNumber: 'SN123'),
        throwsA(anything),
      );
      await expectLater(
        repository.getEventsForDive('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.addProfileEvent(
          diveId: 'test-id',
          timestamp: 0,
          eventType: 'ascent_warning',
        ),
        throwsA(anything),
      );
      await expectLater(
        repository.clearEventsForDive('test-id'),
        throwsA(anything),
      );
    });

    test(
      'methods that return defaults return correct values on error',
      () async {
        await DatabaseService.instance.database.close();
        DatabaseService.instance.resetForTesting();

        // Methods that return null
        expect(await repository.getPrimaryComputerId('test-id'), isNull);
        expect(
          await repository.findMatchingDive(
            profileStartTime: DateTime.now(),
            durationSeconds: 60,
            maxDepth: 10.0,
          ),
          isNull,
        );
        expect(
          await repository.findMatchingDiveWithScore(
            profileStartTime: DateTime.now(),
          ),
          isNull,
        );

        // Methods that return empty list
        expect(await repository.getDiveIdsForComputer('test-id'), isEmpty);
      },
    );
  });
}
