import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_types/data/repositories/dive_type_repository.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('DiveTypeRepository error handling', () {
    late DiveTypeRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = DiveTypeRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('methods handle database errors gracefully', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      final now = DateTime.now();
      final diveType = DiveTypeEntity(
        id: 'dt1',
        diverId: 'diver1',
        name: 'Reef Dive',
        createdAt: now,
        updatedAt: now,
      );

      // getAllDiveTypes - rethrows
      await expectLater(repository.getAllDiveTypes(), throwsA(anything));

      // getBuiltInDiveTypes - rethrows
      await expectLater(repository.getBuiltInDiveTypes(), throwsA(anything));

      // getCustomDiveTypes - rethrows
      await expectLater(
        repository.getCustomDiveTypes(diverId: 'diver1'),
        throwsA(anything),
      );

      // getDiveTypeById - rethrows
      await expectLater(repository.getDiveTypeById('dt1'), throwsA(anything));

      // getDiveTypeByName - rethrows
      await expectLater(
        repository.getDiveTypeByName('Reef Dive'),
        throwsA(anything),
      );

      // createDiveType - rethrows
      await expectLater(repository.createDiveType(diveType), throwsA(anything));

      // updateDiveType - rethrows
      await expectLater(repository.updateDiveType(diveType), throwsA(anything));

      // deleteDiveType - rethrows
      await expectLater(repository.deleteDiveType('dt1'), throwsA(anything));

      // getDiveTypeStatistics - rethrows
      await expectLater(repository.getDiveTypeStatistics(), throwsA(anything));

      // isDiveTypeInUse - rethrows
      await expectLater(repository.isDiveTypeInUse('dt1'), throwsA(anything));
    });
  });
}
