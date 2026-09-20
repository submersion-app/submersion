import 'package:flutter_test/flutter_test.dart';
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
      expect(item['weight'], closeTo(1.4968, 1e-9));
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

    test('marks an inactive item retired', () {
      final book = logbook({
        7: const DivingLogRawEquipment(
          id: 7,
          object: 'Wet Suit (5mm full body)',
          inactive: true,
        ),
      });
      final item = DivingLogEquipmentMapper.entities(book).values.single;
      expect(item['isRetired'], isTrue);
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
