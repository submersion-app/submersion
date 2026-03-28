import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('DiveCenterRepository error handling', () {
    late DiveCenterRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveCenterRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('methods handle database errors gracefully', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      final now = DateTime.now();
      final center = DiveCenter(
        id: 'dc1',
        name: 'Test Dive Center',
        createdAt: now,
        updatedAt: now,
      );

      // getAllDiveCenters - rethrows
      await expectLater(repository.getAllDiveCenters(), throwsA(anything));

      // getDiveCenterById - rethrows
      await expectLater(repository.getDiveCenterById('dc1'), throwsA(anything));

      // createDiveCenter - rethrows
      await expectLater(repository.createDiveCenter(center), throwsA(anything));

      // updateDiveCenter - rethrows
      await expectLater(repository.updateDiveCenter(center), throwsA(anything));

      // deleteDiveCenter - rethrows
      await expectLater(repository.deleteDiveCenter('dc1'), throwsA(anything));
    });
  });
}
