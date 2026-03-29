import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('DiverRepository error handling', () {
    late DiverRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiverRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('methods handle database errors gracefully', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      final now = DateTime.now();
      final diver = Diver(
        id: 'd1',
        name: 'Test Diver',
        createdAt: now,
        updatedAt: now,
      );

      // getAllDivers - rethrows
      await expectLater(repository.getAllDivers(), throwsA(anything));

      // getDefaultDiver - rethrows
      await expectLater(repository.getDefaultDiver(), throwsA(anything));

      // getDiverById - rethrows
      await expectLater(repository.getDiverById('d1'), throwsA(anything));

      // createDiver - rethrows
      await expectLater(repository.createDiver(diver), throwsA(anything));

      // updateDiver - rethrows
      await expectLater(repository.updateDiver(diver), throwsA(anything));

      // deleteDiver - rethrows
      await expectLater(repository.deleteDiver('d1'), throwsA(anything));

      // setDefaultDiver - rethrows
      await expectLater(repository.setDefaultDiver('d1'), throwsA(anything));

      // getDiveCountForDiver - rethrows
      await expectLater(
        repository.getDiveCountForDiver('d1'),
        throwsA(anything),
      );

      // getTotalBottomTimeForDiver - rethrows
      await expectLater(
        repository.getTotalBottomTimeForDiver('d1'),
        throwsA(anything),
      );

      // getActiveDiverIdFromSettings - returns null on error
      expect(await repository.getActiveDiverIdFromSettings(), isNull);

      // setActiveDiverIdInSettings - swallows error (no rethrow)
      await repository.setActiveDiverIdInSettings('d1');
    });
  });
}
