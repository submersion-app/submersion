import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late EquipmentRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = EquipmentRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  EquipmentItem createTestEquipment({
    String id = '',
    String name = 'Test Regulator',
    EquipmentType type = EquipmentType.regulator,
    String? brand,
    String? model,
    String? serialNumber,
    String? size,
    EquipmentStatus status = EquipmentStatus.active,
    DateTime? purchaseDate,
    double? purchasePrice,
    String purchaseCurrency = 'USD',
    DateTime? lastServiceDate,
    int? serviceIntervalDays,
    String notes = '',
    bool isActive = true,
  }) {
    return EquipmentItem(
      id: id,
      name: name,
      type: type,
      brand: brand,
      model: model,
      serialNumber: serialNumber,
      size: size,
      status: status,
      purchaseDate: purchaseDate,
      purchasePrice: purchasePrice,
      purchaseCurrency: purchaseCurrency,
      lastServiceDate: lastServiceDate,
      serviceIntervalDays: serviceIntervalDays,
      notes: notes,
      isActive: isActive,
    );
  }

  group('EquipmentRepository', () {
    group('createEquipment', () {
      test('should create new equipment with generated ID when ID is empty', () async {
        final equipment = createTestEquipment(name: 'New Regulator');

        final createdEquipment = await repository.createEquipment(equipment);

        expect(createdEquipment.id, isNotEmpty);
        expect(createdEquipment.name, equals('New Regulator'));
      });

      test('should create equipment with provided ID', () async {
        final equipment = createTestEquipment(id: 'custom-equip-id', name: 'Custom Reg');

        final createdEquipment = await repository.createEquipment(equipment);

        expect(createdEquipment.id, equals('custom-equip-id'));
      });

      test('should create equipment with all fields', () async {
        final purchaseDate = DateTime(2023, 1, 15);
        final lastServiceDate = DateTime(2023, 6, 15);
        final equipment = createTestEquipment(
          name: 'Full Regulator',
          type: EquipmentType.regulator,
          brand: 'Scubapro',
          model: 'MK25 EVO',
          serialNumber: 'SP-12345',
          size: 'L',
          status: EquipmentStatus.active,
          purchaseDate: purchaseDate,
          purchasePrice: 899.99,
          purchaseCurrency: 'USD',
          lastServiceDate: lastServiceDate,
          serviceIntervalDays: 365,
          notes: 'Primary regulator',
        );

        final createdEquipment = await repository.createEquipment(equipment);
        final fetchedEquipment = await repository.getEquipmentById(createdEquipment.id);

        expect(fetchedEquipment, isNotNull);
        expect(fetchedEquipment!.name, equals('Full Regulator'));
        expect(fetchedEquipment.type, equals(EquipmentType.regulator));
        expect(fetchedEquipment.brand, equals('Scubapro'));
        expect(fetchedEquipment.model, equals('MK25 EVO'));
        expect(fetchedEquipment.serialNumber, equals('SP-12345'));
        expect(fetchedEquipment.size, equals('L'));
        expect(fetchedEquipment.status, equals(EquipmentStatus.active));
        expect(fetchedEquipment.purchasePrice, equals(899.99));
        expect(fetchedEquipment.purchaseCurrency, equals('USD'));
        expect(fetchedEquipment.serviceIntervalDays, equals(365));
        expect(fetchedEquipment.notes, equals('Primary regulator'));
      });
    });

    group('getEquipmentById', () {
      test('should return equipment when found', () async {
        final equipment = await repository.createEquipment(
          createTestEquipment(name: 'Find Me Equip'),
        );

        final result = await repository.getEquipmentById(equipment.id);

        expect(result, isNotNull);
        expect(result!.name, equals('Find Me Equip'));
      });

      test('should return null when equipment not found', () async {
        final result = await repository.getEquipmentById('non-existent-id');

        expect(result, isNull);
      });
    });

    group('getAllEquipment', () {
      test('should return empty list when no equipment exists', () async {
        final result = await repository.getAllEquipment();

        expect(result, isEmpty);
      });

      test('should return all equipment ordered by type and name', () async {
        await repository.createEquipment(createTestEquipment(
          name: 'Zebra Reg',
          type: EquipmentType.regulator,
        ),);
        await repository.createEquipment(createTestEquipment(
          name: 'Alpha BCD',
          type: EquipmentType.bcd,
        ),);
        await repository.createEquipment(createTestEquipment(
          name: 'Alpha Reg',
          type: EquipmentType.regulator,
        ),);

        final result = await repository.getAllEquipment();

        expect(result.length, equals(3));
        // BCD comes before regulator alphabetically by type
        expect(result[0].name, equals('Alpha BCD'));
        expect(result[1].name, equals('Alpha Reg'));
        expect(result[2].name, equals('Zebra Reg'));
      });
    });

    group('getActiveEquipment', () {
      test('should return only active equipment', () async {
        await repository.createEquipment(createTestEquipment(
          name: 'Active Reg',
          isActive: true,
        ),);
        await repository.createEquipment(createTestEquipment(
          name: 'Retired Reg',
          isActive: false,
        ),);

        final result = await repository.getActiveEquipment();

        expect(result.length, equals(1));
        expect(result[0].name, equals('Active Reg'));
      });
    });

    group('getRetiredEquipment', () {
      test('should return only retired equipment', () async {
        await repository.createEquipment(createTestEquipment(
          name: 'Active Reg',
          isActive: true,
        ),);
        await repository.createEquipment(createTestEquipment(
          name: 'Retired Reg',
          isActive: false,
        ),);

        final result = await repository.getRetiredEquipment();

        expect(result.length, equals(1));
        expect(result[0].name, equals('Retired Reg'));
      });
    });

    group('updateEquipment', () {
      test('should update equipment fields', () async {
        final equipment = await repository.createEquipment(
          createTestEquipment(name: 'Original Name'),
        );

        final updatedEquipment = equipment.copyWith(
          name: 'Updated Name',
          brand: 'New Brand',
          notes: 'Updated notes',
        );

        await repository.updateEquipment(updatedEquipment);
        final result = await repository.getEquipmentById(equipment.id);

        expect(result, isNotNull);
        expect(result!.name, equals('Updated Name'));
        expect(result.brand, equals('New Brand'));
        expect(result.notes, equals('Updated notes'));
      });

      test('should update equipment status', () async {
        final equipment = await repository.createEquipment(
          createTestEquipment(name: 'Status Equip', status: EquipmentStatus.active),
        );

        final updatedEquipment = equipment.copyWith(status: EquipmentStatus.needsService);

        await repository.updateEquipment(updatedEquipment);
        final result = await repository.getEquipmentById(equipment.id);

        expect(result!.status, equals(EquipmentStatus.needsService));
      });
    });

    group('deleteEquipment', () {
      test('should delete existing equipment', () async {
        final equipment = await repository.createEquipment(
          createTestEquipment(name: 'To Delete'),
        );

        await repository.deleteEquipment(equipment.id);
        final result = await repository.getEquipmentById(equipment.id);

        expect(result, isNull);
      });

      test('should not throw when deleting non-existent equipment', () async {
        await expectLater(
          repository.deleteEquipment('non-existent-id'),
          completes,
        );
      });
    });

    group('retireEquipment', () {
      test('should mark equipment as inactive', () async {
        final equipment = await repository.createEquipment(
          createTestEquipment(name: 'To Retire', isActive: true),
        );

        await repository.retireEquipment(equipment.id);
        final result = await repository.getEquipmentById(equipment.id);

        expect(result!.isActive, isFalse);
      });
    });

    group('reactivateEquipment', () {
      test('should mark equipment as active', () async {
        final equipment = await repository.createEquipment(
          createTestEquipment(name: 'To Reactivate', isActive: false),
        );

        await repository.reactivateEquipment(equipment.id);
        final result = await repository.getEquipmentById(equipment.id);

        expect(result!.isActive, isTrue);
      });
    });

    group('markAsServiced', () {
      test('should update last service date', () async {
        final equipment = await repository.createEquipment(
          createTestEquipment(name: 'Service Me'),
        );

        await repository.markAsServiced(equipment.id);
        final result = await repository.getEquipmentById(equipment.id);

        expect(result!.lastServiceDate, isNotNull);
        expect(
          result.lastServiceDate!.difference(DateTime.now()).inMinutes.abs(),
          lessThan(5),
        );
      });
    });

    group('searchEquipment', () {
      setUp(() async {
        await repository.createEquipment(createTestEquipment(
          name: 'MK25 Regulator',
          brand: 'Scubapro',
          model: 'MK25 EVO',
          serialNumber: 'SP-001',
        ),);
        await repository.createEquipment(createTestEquipment(
          name: 'Hydros BCD',
          type: EquipmentType.bcd,
          brand: 'Scubapro',
          model: 'Hydros Pro',
          serialNumber: 'SP-002',
        ),);
        await repository.createEquipment(createTestEquipment(
          name: 'Atomic B2',
          brand: 'Atomic',
          model: 'B2',
          serialNumber: 'AT-001',
        ),);
      });

      test('should find equipment by name', () async {
        final results = await repository.searchEquipment('MK25');

        expect(results.length, equals(1));
        expect(results[0].name, equals('MK25 Regulator'));
      });

      test('should find equipment by brand', () async {
        final results = await repository.searchEquipment('Scubapro');

        expect(results.length, equals(2));
      });

      test('should find equipment by model', () async {
        final results = await repository.searchEquipment('Hydros');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Hydros BCD'));
      });

      test('should find equipment by serial number', () async {
        final results = await repository.searchEquipment('AT-001');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Atomic B2'));
      });

      test('should return empty list for no matches', () async {
        final results = await repository.searchEquipment('NonExistent');

        expect(results, isEmpty);
      });

      test('should be case insensitive', () async {
        final results = await repository.searchEquipment('atomic');

        expect(results.length, equals(1));
        expect(results[0].name, equals('Atomic B2'));
      });
    });

    group('getEquipmentByIds', () {
      test('should return empty list for empty input', () async {
        final results = await repository.getEquipmentByIds([]);

        expect(results, isEmpty);
      });

      test('should return multiple equipment items by IDs', () async {
        final equip1 = await repository.createEquipment(
          createTestEquipment(name: 'Equip 1'),
        );
        final equip2 = await repository.createEquipment(
          createTestEquipment(name: 'Equip 2'),
        );
        await repository.createEquipment(
          createTestEquipment(name: 'Equip 3'),
        );

        final results = await repository.getEquipmentByIds([equip1.id, equip2.id]);

        expect(results.length, equals(2));
        expect(results.map((e) => e.name), containsAll(['Equip 1', 'Equip 2']));
      });
    });

    group('getDiveCountForEquipment', () {
      test('should return 0 when equipment has no dives', () async {
        final equipment = await repository.createEquipment(
          createTestEquipment(name: 'New Equipment'),
        );

        final count = await repository.getDiveCountForEquipment(equipment.id);

        expect(count, equals(0));
      });
    });

    group('getEquipmentWithServiceDue', () {
      test('should return equipment with service overdue', () async {
        // Equipment with service overdue
        await repository.createEquipment(createTestEquipment(
          name: 'Overdue Reg',
          lastServiceDate: DateTime.now().subtract(const Duration(days: 400)),
          serviceIntervalDays: 365,
        ),);

        // Equipment not due
        await repository.createEquipment(createTestEquipment(
          name: 'Fresh Reg',
          lastServiceDate: DateTime.now().subtract(const Duration(days: 30)),
          serviceIntervalDays: 365,
        ),);

        // Equipment with no service date
        await repository.createEquipment(createTestEquipment(
          name: 'No Service Date',
        ),);

        final results = await repository.getEquipmentWithServiceDue();

        expect(results.length, equals(1));
        expect(results[0].name, equals('Overdue Reg'));
      });
    });
  });
}
