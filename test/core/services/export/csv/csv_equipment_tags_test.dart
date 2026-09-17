import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// The equipment CSV lists each item's tags (issue #1942).
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

  List<List<String>> rows(String csv) => [
    for (final row in const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(csv))
      [for (final cell in row) '$cell'],
  ];

  test('a Tags column follows Components and joins names with the list '
      'codec', () {
    final table = rows(
      CsvExportService().generateEquipmentCsvContent(
        const [reg, mask],
        tagNames: const {
          'reg': ['Salt; fresh', 'Travel'],
        },
      ),
    );
    final at = table.first.indexOf('Tags');
    expect(table.first[at - 1], 'Components');
    expect(table[1][at], r'Salt\; fresh; Travel');
    expect(table[2][at], '', reason: 'an item with no tags gets an empty cell');
  });

  test('a cell starting with a formula character is guarded', () {
    final table = rows(
      CsvExportService().generateEquipmentCsvContent(
        const [reg],
        tagNames: const {
          'reg': ['=Deep'],
        },
      ),
    );
    expect(table[1][table.first.indexOf('Tags')], "'=Deep");
  });
}
