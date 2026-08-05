import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

void main() {
  test('equipment CSV includes size, thickness, and extra attributes', () {
    final csv = CsvExportService().generateEquipmentCsvContent([
      EquipmentItem(
        id: 'e1',
        name: 'Suit',
        type: EquipmentType.wetsuit,
        attributes: [
          EquipmentAttribute.curated(
            equipmentId: 'e1',
            key: 'size',
            valueText: 'L',
          ),
          EquipmentAttribute.curated(
            equipmentId: 'e1',
            key: 'thickness_mm',
            valueText: '5/4',
            valueNum: 5.0,
          ),
          EquipmentAttribute.curated(
            equipmentId: 'e1',
            key: 'suit_style',
            valueText: 'full',
          ),
          EquipmentAttribute.curated(
            equipmentId: 'e1',
            key: 'buoyancy_kg',
            valueNum: 2.5,
          ),
        ],
      ),
    ]);

    final lines = csv.split('\n');
    expect(lines.first, contains('Size'));
    expect(lines.first, contains('Thickness'));
    expect(lines.first, contains('Attributes'));
    expect(lines[1], contains('L'));
    expect(lines[1], contains('5/4'));
    expect(lines[1], contains('suit_style=full'));
    expect(lines[1], contains('2.5'));
  });

  test('custom field colliding with a curated key is not dropped', () {
    final csv = CsvExportService().generateEquipmentCsvContent([
      const EquipmentItem(
        id: 'e1',
        name: 'Suit',
        type: EquipmentType.wetsuit,
        attributes: [
          // Curated size fills the dedicated Size column.
          EquipmentAttribute(
            id: 'attr_e1_size',
            equipmentId: 'e1',
            key: 'size',
            valueText: 'L',
          ),
          // Custom field that happens to share the "size" key: must still
          // appear in the combined Attributes column.
          EquipmentAttribute(
            id: 'c1',
            equipmentId: 'e1',
            key: 'size',
            isCustom: true,
            valueText: 'legacy-tag',
          ),
        ],
      ),
    ]);

    final line = csv.split('\n')[1];
    expect(line, contains('L')); // dedicated Size column (curated)
    expect(line, contains('size=legacy-tag')); // custom, in Attributes column
  });
}
