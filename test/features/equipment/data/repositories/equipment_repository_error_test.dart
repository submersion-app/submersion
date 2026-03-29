import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/test_database.dart';

void main() {
  group('EquipmentRepository error handling', () {
    late EquipmentRepository repository;

    setUp(() async {
      await setUpTestDatabase();
      repository = EquipmentRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test('all methods rethrow on database error', () async {
      await DatabaseService.instance.database.close();
      DatabaseService.instance.resetForTesting();

      const testEquipment = EquipmentItem(
        id: 'test-id',
        name: 'Test BCD',
        type: EquipmentType.bcd,
        status: EquipmentStatus.active,
      );

      await expectLater(repository.getActiveEquipment(), throwsA(anything));
      await expectLater(repository.getRetiredEquipment(), throwsA(anything));
      await expectLater(repository.getAllEquipment(), throwsA(anything));
      await expectLater(
        repository.getEquipmentByStatus(EquipmentStatus.active),
        throwsA(anything),
      );
      await expectLater(
        repository.getEquipmentById('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.getEquipmentByIds(['test-id']),
        throwsA(anything),
      );
      await expectLater(
        repository.createEquipment(testEquipment),
        throwsA(anything),
      );
      await expectLater(
        repository.updateEquipment(testEquipment),
        throwsA(anything),
      );
      await expectLater(
        repository.deleteEquipment('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.markAsServiced('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.retireEquipment('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.reactivateEquipment('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.getEquipmentWithServiceDates(),
        throwsA(anything),
      );
      await expectLater(repository.searchEquipment('test'), throwsA(anything));
      await expectLater(
        repository.getDiveCountForEquipment('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.getTripCountForEquipment('test-id'),
        throwsA(anything),
      );
      await expectLater(
        repository.getTripIdsForEquipment('test-id'),
        throwsA(anything),
      );
    });
  });
}
