import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

void main() {
  // A UnitFormatter backed by metric default settings.
  const units = UnitFormatter(AppSettings());

  // A representative EquipmentItem entity for adapter tests.
  final testItem = EquipmentItem(
    id: 'equip-1',
    name: 'Primary Reg',
    type: EquipmentType.regulator,
    brand: 'Apeks',
    model: 'XTX 200',
    serialNumber: 'SN-12345',
    size: 'DIN',
    status: EquipmentStatus.active,
    isActive: true,
    purchaseDate: DateTime(2023, 1, 15),
    purchasePrice: 599.99,
    purchaseCurrency: 'USD',
    lastServiceDate: DateTime(2024, 6, 1),
    serviceIntervalDays: 365,
    notes: 'Annual service due',
  );

  group('EquipmentFieldAdapter.allFields', () {
    test('has expected count matching EquipmentField.values', () {
      expect(
        EquipmentFieldAdapter.instance.allFields.length,
        equals(EquipmentField.values.length),
      );
    });

    test('contains all EquipmentField values', () {
      expect(
        EquipmentFieldAdapter.instance.allFields,
        containsAll(EquipmentField.values),
      );
    });
  });

  group('EquipmentFieldAdapter.fieldsByCategory', () {
    test('groups core fields together', () {
      final byCategory = EquipmentFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['core'],
        containsAll([
          EquipmentField.itemName,
          EquipmentField.fullName,
          EquipmentField.type,
          EquipmentField.brand,
          EquipmentField.model,
        ]),
      );
    });

    test('groups details fields together', () {
      final byCategory = EquipmentFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['details'],
        containsAll([
          EquipmentField.serialNumber,
          EquipmentField.size,
          EquipmentField.status,
          EquipmentField.isActive,
        ]),
      );
    });

    test('groups purchase fields together', () {
      final byCategory = EquipmentFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['purchase'],
        containsAll([
          EquipmentField.purchaseDate,
          EquipmentField.purchasePrice,
        ]),
      );
    });

    test('groups service fields together', () {
      final byCategory = EquipmentFieldAdapter.instance.fieldsByCategory;
      expect(
        byCategory['service'],
        containsAll([
          EquipmentField.lastServiceDate,
          EquipmentField.nextServiceDue,
          EquipmentField.daysUntilService,
          EquipmentField.serviceIntervalDays,
        ]),
      );
    });

    test('groups other fields together', () {
      final byCategory = EquipmentFieldAdapter.instance.fieldsByCategory;
      expect(byCategory['other'], containsAll([EquipmentField.notes]));
    });

    test('covers all EquipmentField values across categories', () {
      final byCategory = EquipmentFieldAdapter.instance.fieldsByCategory;
      final allGrouped = byCategory.values.expand((v) => v).toList();
      expect(allGrouped.length, equals(EquipmentField.values.length));
    });
  });

  group('EquipmentFieldAdapter.extractValue', () {
    final adapter = EquipmentFieldAdapter.instance;

    test('returns item name', () {
      expect(
        adapter.extractValue(EquipmentField.itemName, testItem),
        equals('Primary Reg'),
      );
    });

    test('returns fullName (brand + model)', () {
      expect(
        adapter.extractValue(EquipmentField.fullName, testItem),
        equals('Apeks XTX 200'),
      );
    });

    test('returns fullName with only brand', () {
      const brandOnly = EquipmentItem(
        id: 'equip-brand',
        name: 'Test',
        type: EquipmentType.regulator,
        brand: 'Apeks',
      );
      expect(
        adapter.extractValue(EquipmentField.fullName, brandOnly),
        equals('Apeks'),
      );
    });

    test('returns fullName with only model', () {
      const modelOnly = EquipmentItem(
        id: 'equip-model',
        name: 'Test',
        type: EquipmentType.regulator,
        model: 'XTX 200',
      );
      expect(
        adapter.extractValue(EquipmentField.fullName, modelOnly),
        equals('XTX 200'),
      );
    });

    test('returns item name when brand and model are empty', () {
      final noBrandModel = testItem.copyWith(brand: '', model: '');
      expect(
        adapter.extractValue(EquipmentField.fullName, noBrandModel),
        equals('Primary Reg'),
      );
    });

    test('returns type enum', () {
      expect(
        adapter.extractValue(EquipmentField.type, testItem),
        equals(EquipmentType.regulator),
      );
    });

    test('returns brand', () {
      expect(
        adapter.extractValue(EquipmentField.brand, testItem),
        equals('Apeks'),
      );
    });

    test('returns model', () {
      expect(
        adapter.extractValue(EquipmentField.model, testItem),
        equals('XTX 200'),
      );
    });

    test('returns serialNumber', () {
      expect(
        adapter.extractValue(EquipmentField.serialNumber, testItem),
        equals('SN-12345'),
      );
    });

    test('returns size', () {
      expect(
        adapter.extractValue(EquipmentField.size, testItem),
        equals('DIN'),
      );
    });

    test('returns status enum', () {
      expect(
        adapter.extractValue(EquipmentField.status, testItem),
        equals(EquipmentStatus.active),
      );
    });

    test('returns isActive', () {
      expect(adapter.extractValue(EquipmentField.isActive, testItem), isTrue);
    });

    test('returns purchaseDate', () {
      expect(
        adapter.extractValue(EquipmentField.purchaseDate, testItem),
        equals(DateTime(2023, 1, 15)),
      );
    });

    test('returns purchasePrice', () {
      expect(
        adapter.extractValue(EquipmentField.purchasePrice, testItem),
        equals(599.99),
      );
    });

    test('returns lastServiceDate', () {
      expect(
        adapter.extractValue(EquipmentField.lastServiceDate, testItem),
        equals(DateTime(2024, 6, 1)),
      );
    });

    test('returns nextServiceDue (computed)', () {
      // lastServiceDate (2024-06-01) + 365 days = 2025-06-01
      expect(
        adapter.extractValue(EquipmentField.nextServiceDue, testItem),
        equals(DateTime(2025, 6, 1)),
      );
    });

    test('returns daysUntilService (computed)', () {
      // nextServiceDue is 2025-06-01, difference from now
      final dueDate = DateTime(2025, 6, 1);
      final expectedDays = dueDate.difference(DateTime.now()).inDays;
      expect(
        adapter.extractValue(EquipmentField.daysUntilService, testItem),
        equals(expectedDays),
      );
    });

    test('returns serviceIntervalDays', () {
      expect(
        adapter.extractValue(EquipmentField.serviceIntervalDays, testItem),
        equals(365),
      );
    });

    test('returns notes when non-empty', () {
      expect(
        adapter.extractValue(EquipmentField.notes, testItem),
        equals('Annual service due'),
      );
    });

    test('returns null for brand when null', () {
      const noBrand = EquipmentItem(
        id: 'equip-2',
        name: 'Test',
        type: EquipmentType.mask,
      );
      expect(adapter.extractValue(EquipmentField.brand, noBrand), isNull);
    });

    test('returns null for nextServiceDue when no lastServiceDate', () {
      const noService = EquipmentItem(
        id: 'equip-3',
        name: 'Test',
        type: EquipmentType.mask,
      );
      expect(
        adapter.extractValue(EquipmentField.nextServiceDue, noService),
        isNull,
      );
    });

    test('returns null for daysUntilService when no service info', () {
      const noService = EquipmentItem(
        id: 'equip-4',
        name: 'Test',
        type: EquipmentType.mask,
      );
      expect(
        adapter.extractValue(EquipmentField.daysUntilService, noService),
        isNull,
      );
    });
  });

  group('EquipmentFieldAdapter.formatValue', () {
    final adapter = EquipmentFieldAdapter.instance;

    test('returns -- for null value', () {
      expect(
        adapter.formatValue(EquipmentField.itemName, null, units),
        equals('--'),
      );
    });

    test('formats itemName as string', () {
      expect(
        adapter.formatValue(EquipmentField.itemName, 'Primary Reg', units),
        equals('Primary Reg'),
      );
    });

    test('formats fullName as string', () {
      expect(
        adapter.formatValue(EquipmentField.fullName, 'Apeks XTX 200', units),
        equals('Apeks XTX 200'),
      );
    });

    test('formats type using displayName', () {
      expect(
        adapter.formatValue(
          EquipmentField.type,
          EquipmentType.regulator,
          units,
        ),
        equals('Regulator'),
      );
    });

    test('formats brand as string', () {
      expect(
        adapter.formatValue(EquipmentField.brand, 'Apeks', units),
        equals('Apeks'),
      );
    });

    test('formats model as string', () {
      expect(
        adapter.formatValue(EquipmentField.model, 'XTX 200', units),
        equals('XTX 200'),
      );
    });

    test('formats serialNumber as string', () {
      expect(
        adapter.formatValue(EquipmentField.serialNumber, 'SN-12345', units),
        equals('SN-12345'),
      );
    });

    test('formats size as string', () {
      expect(
        adapter.formatValue(EquipmentField.size, 'DIN', units),
        equals('DIN'),
      );
    });

    test('formats status using displayName', () {
      expect(
        adapter.formatValue(
          EquipmentField.status,
          EquipmentStatus.active,
          units,
        ),
        equals('Active'),
      );
    });

    test('formats status needsService using displayName', () {
      expect(
        adapter.formatValue(
          EquipmentField.status,
          EquipmentStatus.needsService,
          units,
        ),
        equals('Needs Service'),
      );
    });

    test('formats isActive true as Yes', () {
      expect(
        adapter.formatValue(EquipmentField.isActive, true, units),
        equals('Yes'),
      );
    });

    test('formats isActive false as No', () {
      expect(
        adapter.formatValue(EquipmentField.isActive, false, units),
        equals('No'),
      );
    });

    test('formats purchaseDate with units.formatDate', () {
      final date = DateTime(2023, 1, 15);
      expect(
        adapter.formatValue(EquipmentField.purchaseDate, date, units),
        equals(units.formatDate(date)),
      );
    });

    test('formats purchasePrice as currency', () {
      final expected = NumberFormat.currency(
        symbol: r'$',
        decimalDigits: 2,
      ).format(599.99);
      expect(
        adapter.formatValue(EquipmentField.purchasePrice, 599.99, units),
        equals(expected),
      );
    });

    test('formats lastServiceDate with units.formatDate', () {
      final date = DateTime(2024, 6, 1);
      expect(
        adapter.formatValue(EquipmentField.lastServiceDate, date, units),
        equals(units.formatDate(date)),
      );
    });

    test('formats nextServiceDue with units.formatDate', () {
      final date = DateTime(2025, 6, 1);
      expect(
        adapter.formatValue(EquipmentField.nextServiceDue, date, units),
        equals(units.formatDate(date)),
      );
    });

    test('formats daysUntilService with positive days', () {
      expect(
        adapter.formatValue(EquipmentField.daysUntilService, 30, units),
        equals('30 days'),
      );
    });

    test('formats daysUntilService as Overdue when negative', () {
      expect(
        adapter.formatValue(EquipmentField.daysUntilService, -5, units),
        equals('Overdue'),
      );
    });

    test('formats daysUntilService as 0 days when zero', () {
      expect(
        adapter.formatValue(EquipmentField.daysUntilService, 0, units),
        equals('0 days'),
      );
    });

    test('formats serviceIntervalDays', () {
      expect(
        adapter.formatValue(EquipmentField.serviceIntervalDays, 365, units),
        equals('365 days'),
      );
    });

    test('formats notes as string', () {
      expect(
        adapter.formatValue(EquipmentField.notes, 'Annual service due', units),
        equals('Annual service due'),
      );
    });

    test('returns -- for null purchasePrice', () {
      expect(
        adapter.formatValue(EquipmentField.purchasePrice, null, units),
        equals('--'),
      );
    });

    test('returns -- for null daysUntilService', () {
      expect(
        adapter.formatValue(EquipmentField.daysUntilService, null, units),
        equals('--'),
      );
    });
  });

  group('EquipmentFieldAdapter.fieldFromName', () {
    final adapter = EquipmentFieldAdapter.instance;

    test('resolves itemName', () {
      expect(
        adapter.fieldFromName('itemName'),
        equals(EquipmentField.itemName),
      );
    });

    test('resolves fullName', () {
      expect(
        adapter.fieldFromName('fullName'),
        equals(EquipmentField.fullName),
      );
    });

    test('resolves type', () {
      expect(adapter.fieldFromName('type'), equals(EquipmentField.type));
    });

    test('resolves brand', () {
      expect(adapter.fieldFromName('brand'), equals(EquipmentField.brand));
    });

    test('resolves model', () {
      expect(adapter.fieldFromName('model'), equals(EquipmentField.model));
    });

    test('resolves serialNumber', () {
      expect(
        adapter.fieldFromName('serialNumber'),
        equals(EquipmentField.serialNumber),
      );
    });

    test('resolves size', () {
      expect(adapter.fieldFromName('size'), equals(EquipmentField.size));
    });

    test('resolves status', () {
      expect(adapter.fieldFromName('status'), equals(EquipmentField.status));
    });

    test('resolves isActive', () {
      expect(
        adapter.fieldFromName('isActive'),
        equals(EquipmentField.isActive),
      );
    });

    test('resolves purchaseDate', () {
      expect(
        adapter.fieldFromName('purchaseDate'),
        equals(EquipmentField.purchaseDate),
      );
    });

    test('resolves purchasePrice', () {
      expect(
        adapter.fieldFromName('purchasePrice'),
        equals(EquipmentField.purchasePrice),
      );
    });

    test('resolves lastServiceDate', () {
      expect(
        adapter.fieldFromName('lastServiceDate'),
        equals(EquipmentField.lastServiceDate),
      );
    });

    test('resolves nextServiceDue', () {
      expect(
        adapter.fieldFromName('nextServiceDue'),
        equals(EquipmentField.nextServiceDue),
      );
    });

    test('resolves daysUntilService', () {
      expect(
        adapter.fieldFromName('daysUntilService'),
        equals(EquipmentField.daysUntilService),
      );
    });

    test('resolves serviceIntervalDays', () {
      expect(
        adapter.fieldFromName('serviceIntervalDays'),
        equals(EquipmentField.serviceIntervalDays),
      );
    });

    test('resolves notes', () {
      expect(adapter.fieldFromName('notes'), equals(EquipmentField.notes));
    });

    test('throws for unknown field name', () {
      expect(() => adapter.fieldFromName('nonExistentField'), throwsStateError);
    });
  });

  group('EquipmentField EntityField properties', () {
    test('displayName is non-empty for all fields', () {
      for (final field in EquipmentField.values) {
        expect(field.displayName, isNotEmpty, reason: field.name);
      }
    });

    test('shortLabel is non-empty for all fields', () {
      for (final field in EquipmentField.values) {
        expect(field.shortLabel, isNotEmpty, reason: field.name);
      }
    });

    test('icon is non-null for all fields', () {
      for (final field in EquipmentField.values) {
        expect(field.icon, isNotNull, reason: field.name);
      }
    });

    test('defaultWidth is positive for all fields', () {
      for (final field in EquipmentField.values) {
        expect(field.defaultWidth, greaterThan(0), reason: field.name);
      }
    });

    test('minWidth is positive and <= defaultWidth for all fields', () {
      for (final field in EquipmentField.values) {
        expect(field.minWidth, greaterThan(0), reason: field.name);
        expect(
          field.minWidth,
          lessThanOrEqualTo(field.defaultWidth),
          reason: field.name,
        );
      }
    });

    test('categoryName is non-empty for all fields', () {
      for (final field in EquipmentField.values) {
        expect(field.categoryName, isNotEmpty, reason: field.name);
      }
    });

    test('notes is not sortable', () {
      expect(EquipmentField.notes.sortable, isFalse);
    });

    test('all fields except notes are sortable', () {
      for (final field in EquipmentField.values) {
        if (field == EquipmentField.notes) continue;
        expect(field.sortable, isTrue, reason: field.name);
      }
    });

    test('purchasePrice is right-aligned', () {
      expect(EquipmentField.purchasePrice.isRightAligned, isTrue);
    });

    test('daysUntilService is right-aligned', () {
      expect(EquipmentField.daysUntilService.isRightAligned, isTrue);
    });

    test('text fields are not right-aligned', () {
      expect(EquipmentField.itemName.isRightAligned, isFalse);
      expect(EquipmentField.brand.isRightAligned, isFalse);
      expect(EquipmentField.notes.isRightAligned, isFalse);
    });

    test('specific displayName values', () {
      expect(EquipmentField.itemName.displayName, equals('Name'));
      expect(EquipmentField.fullName.displayName, equals('Full Name'));
      expect(EquipmentField.type.displayName, equals('Type'));
      expect(EquipmentField.brand.displayName, equals('Brand'));
      expect(EquipmentField.model.displayName, equals('Model'));
      expect(EquipmentField.serialNumber.displayName, equals('Serial Number'));
      expect(EquipmentField.size.displayName, equals('Size'));
      expect(EquipmentField.status.displayName, equals('Status'));
      expect(EquipmentField.isActive.displayName, equals('Active'));
      expect(EquipmentField.purchaseDate.displayName, equals('Purchase Date'));
      expect(
        EquipmentField.purchasePrice.displayName,
        equals('Purchase Price'),
      );
      expect(
        EquipmentField.lastServiceDate.displayName,
        equals('Last Service'),
      );
      expect(
        EquipmentField.nextServiceDue.displayName,
        equals('Next Service Due'),
      );
      expect(
        EquipmentField.daysUntilService.displayName,
        equals('Days Until Service'),
      );
      expect(
        EquipmentField.serviceIntervalDays.displayName,
        equals('Service Interval'),
      );
      expect(EquipmentField.notes.displayName, equals('Notes'));
    });

    test('specific shortLabel values', () {
      expect(EquipmentField.itemName.shortLabel, equals('Name'));
      expect(EquipmentField.serialNumber.shortLabel, equals('Serial #'));
      expect(EquipmentField.purchaseDate.shortLabel, equals('Purchased'));
      expect(EquipmentField.purchasePrice.shortLabel, equals('Price'));
      expect(EquipmentField.lastServiceDate.shortLabel, equals('Serviced'));
      expect(EquipmentField.nextServiceDue.shortLabel, equals('Next Svc'));
      expect(EquipmentField.daysUntilService.shortLabel, equals('Days Left'));
      expect(EquipmentField.serviceIntervalDays.shortLabel, equals('Interval'));
    });

    test('specific icon values', () {
      expect(EquipmentField.itemName.icon, equals(Icons.label));
      expect(EquipmentField.fullName.icon, equals(Icons.badge));
      expect(EquipmentField.type.icon, equals(Icons.category));
      expect(EquipmentField.brand.icon, equals(Icons.business));
      expect(EquipmentField.model.icon, equals(Icons.info_outline));
      expect(EquipmentField.serialNumber.icon, equals(Icons.pin));
      expect(EquipmentField.size.icon, equals(Icons.straighten));
      expect(EquipmentField.status.icon, equals(Icons.circle));
      expect(EquipmentField.isActive.icon, equals(Icons.check_circle_outline));
      expect(EquipmentField.purchaseDate.icon, equals(Icons.calendar_today));
      expect(EquipmentField.purchasePrice.icon, equals(Icons.attach_money));
      expect(EquipmentField.lastServiceDate.icon, equals(Icons.build));
      expect(EquipmentField.nextServiceDue.icon, equals(Icons.event));
      expect(EquipmentField.daysUntilService.icon, equals(Icons.timelapse));
      expect(EquipmentField.serviceIntervalDays.icon, equals(Icons.repeat));
      expect(EquipmentField.notes.icon, equals(Icons.notes));
    });

    test('specific defaultWidth values', () {
      expect(EquipmentField.itemName.defaultWidth, equals(150));
      expect(EquipmentField.fullName.defaultWidth, equals(180));
      expect(EquipmentField.type.defaultWidth, equals(100));
      expect(EquipmentField.size.defaultWidth, equals(70));
      expect(EquipmentField.isActive.defaultWidth, equals(70));
      expect(EquipmentField.notes.defaultWidth, equals(150));
    });

    test('specific minWidth values', () {
      expect(EquipmentField.itemName.minWidth, equals(80));
      expect(EquipmentField.fullName.minWidth, equals(100));
      expect(EquipmentField.size.minWidth, equals(50));
      expect(EquipmentField.isActive.minWidth, equals(50));
      expect(EquipmentField.notes.minWidth, equals(80));
    });

    test('specific categoryName values', () {
      expect(EquipmentField.itemName.categoryName, equals('core'));
      expect(EquipmentField.fullName.categoryName, equals('core'));
      expect(EquipmentField.type.categoryName, equals('core'));
      expect(EquipmentField.brand.categoryName, equals('core'));
      expect(EquipmentField.model.categoryName, equals('core'));
      expect(EquipmentField.serialNumber.categoryName, equals('details'));
      expect(EquipmentField.size.categoryName, equals('details'));
      expect(EquipmentField.status.categoryName, equals('details'));
      expect(EquipmentField.isActive.categoryName, equals('details'));
      expect(EquipmentField.purchaseDate.categoryName, equals('purchase'));
      expect(EquipmentField.purchasePrice.categoryName, equals('purchase'));
      expect(EquipmentField.lastServiceDate.categoryName, equals('service'));
      expect(EquipmentField.nextServiceDue.categoryName, equals('service'));
      expect(EquipmentField.daysUntilService.categoryName, equals('service'));
      expect(
        EquipmentField.serviceIntervalDays.categoryName,
        equals('service'),
      );
      expect(EquipmentField.notes.categoryName, equals('other'));
    });
  });
}
