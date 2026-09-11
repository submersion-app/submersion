import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// The equipment CSV lists an assembly's parts (issue #1487).
void main() {
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Reg',
    type: EquipmentType.regulator,
  );
  const mask = EquipmentItem(
    id: 'mask',
    name: 'Mask',
    type: EquipmentType.mask,
  );

  test('a Components column follows Attributes and lists parts by name', () {
    final csv = CsvExportService().generateEquipmentCsvContent(
      const [reg, mask],
      componentNames: const {
        'reg': ['First stage', 'Long hose'],
      },
    );
    final lines = csv.trim().split('\n');
    final headers = lines.first.split(',');
    expect(headers[headers.indexOf('Attributes') + 1], 'Components');
    expect(lines[1], contains('First stage; Long hose'));
    // An item with no parts gets an empty cell, not a missing one.
    expect(lines[2].split(',').length, headers.length);
    expect(lines[2], isNot(contains('First stage')));
  });

  test('without a map every Components cell is empty', () {
    final csv = CsvExportService().generateEquipmentCsvContent(const [reg]);
    expect(csv.split('\n').first, contains('Components'));
    expect(csv, isNot(contains('First stage')));
  });
}
