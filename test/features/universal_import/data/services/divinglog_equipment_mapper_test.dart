import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_equipment_mapper.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_raw_types.dart';

DivingLogLogbook logbook(
  Map<int, DivingLogRawEquipment> equipment, {
  List<DivingLogRawDive> dives = const [],
}) => DivingLogLogbook(
  dives: dives,
  capabilities: const DivingLogCapabilities(tables: {}, columns: {}),
  equipmentById: equipment,
);

void main() {
  group('DivingLogEquipmentMapper', () {
    test('reads the type from the item name', () {
      final book = logbook({
        3: const DivingLogRawEquipment(
          id: 3,
          object: 'Go Sport Fins',
          manufacturer: 'ScubaPro',
          serial: 'SN1',
          weightKg: 1.4968,
        ),
      });
      final item = DivingLogEquipmentMapper.entities(book).values.single;
      expect(item['name'], 'Go Sport Fins');
      expect(item['brand'], 'ScubaPro');
      expect(item['serialNumber'], 'SN1');
      // Weight rides as a curated attribute, not a top-level key: the
      // importer has no weight field and would drop it.
      final attrs = item['attributes'] as List;
      expect((attrs.single as Map)['valueNum'], closeTo(1.4968, 1e-9));
      expect(item['type'], 'fins');
    });

    test('falls back to other when the name says nothing', () {
      final book = logbook({
        1: const DivingLogRawEquipment(id: 1, object: 'Teric'),
      });
      expect(
        DivingLogEquipmentMapper.entities(book).values.single['type'],
        'other',
      );
    });

    test('keeps the O2 service date in the item notes', () {
      final book = logbook({
        5: DivingLogRawEquipment(
          id: 5,
          object: 'S620Ti Regulator',
          o2ServiceDate: DateTime.utc(2024, 3, 17),
          comments: 'annual service due',
        ),
      });
      final item = DivingLogEquipmentMapper.entities(book).values.single;
      expect(item['notes'], contains('2024-03-17'));
      expect(item['notes'], contains('annual service due'));
    });

    test('carries weight as the curated dry weight attribute', () {
      // EquipmentItem has no weight field: the importer reads only the
      // direct fields plus `attributes`, so a top-level `weight` key is
      // dropped on the way in.
      final book = logbook({
        4: const DivingLogRawEquipment(
          id: 4,
          object: 'SeaHawk 2 w/BPI',
          weightKg: 3.6287,
        ),
      });
      final item = DivingLogEquipmentMapper.entities(book).values.single;
      final attrs = item['attributes'] as List;
      final weight = attrs.singleWhere(
        (a) => (a as Map)['key'] == EquipmentAttrKeys.dryWeightKg,
      );
      expect((weight as Map)['valueNum'], closeTo(3.6287, 1e-9));
    });

    test(
      'omits a zero weight rather than claiming the item weighs nothing',
      () {
        // 6 of the 31 items in the reference logbook carry Weight 0, which
        // means not recorded. Emitting it would feed a real zero to the
        // buoyancy maths.
        final book = logbook({
          1: const DivingLogRawEquipment(id: 1, object: 'Teric', weightKg: 0),
        });
        final item = DivingLogEquipmentMapper.entities(book).values.single;
        expect(item.containsKey('attributes'), isFalse);
      },
    );

    test('omits a zero price rather than importing the item as free', () {
      // 3 of the 31 items in the reference logbook carry Price 0, which in
      // this format means not recorded.
      final book = logbook({
        2: const DivingLogRawEquipment(id: 2, object: 'MK25', price: 0),
      });
      final item = DivingLogEquipmentMapper.entities(book).values.single;
      expect(item.containsKey('purchasePrice'), isFalse);
    });

    test('marks an inactive item retired the way the importer reads it', () {
      // The importer reads `status` and `isActive`; `isRetired` reaches
      // nothing, so an inactive item would import as active.
      final book = logbook({
        7: const DivingLogRawEquipment(
          id: 7,
          object: 'Wet Suit (5mm full body)',
          inactive: true,
        ),
      });
      final item = DivingLogEquipmentMapper.entities(book).values.single;
      expect(item['status'], EquipmentStatus.retired.name);
      expect(item['isActive'], isFalse);
    });

    test('emits no ref for a row that produces no entity', () {
      // A blank Object is skipped by entities(), so a ref to it would
      // dangle: the importer silently drops it and nothing counts the loss.
      final book = logbook(
        {
          3: const DivingLogRawEquipment(id: 3, object: 'Go Sport Fins'),
          8: const DivingLogRawEquipment(id: 8, object: '   '),
        },
        dives: [
          const DivingLogRawDive(id: 1, equipmentIds: [3, 8]),
        ],
      );
      expect(DivingLogEquipmentMapper.refsFor(book, book.dives.single), [
        'divinglog_gear_3',
      ]);
    });

    test('skips an item with no name', () {
      final book = logbook({1: const DivingLogRawEquipment(id: 1)});
      expect(DivingLogEquipmentMapper.entities(book), isEmpty);
    });

    test('resolves a dive UsedEquip list to refs, skipping unknown ids', () {
      final book = logbook(
        {
          3: const DivingLogRawEquipment(id: 3, object: 'Go Sport Fins'),
          7: const DivingLogRawEquipment(id: 7, object: 'Booties'),
        },
        dives: [
          const DivingLogRawDive(id: 1, equipmentIds: [3, 99, 7]),
        ],
      );
      expect(DivingLogEquipmentMapper.refsFor(book, book.dives.single), [
        'divinglog_gear_3',
        'divinglog_gear_7',
      ]);
    });
  });
}
