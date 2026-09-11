import 'package:excel_community/excel_community.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/excel/excel_export_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// The Equipment sheet lists an assembly's parts (issue #1487).
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

  test('a Components column follows Status and lists parts by name', () async {
    final bytes = await ExcelExportService().generateExcelBytes(
      dives: const [],
      sites: const [],
      equipment: const [reg, mask],
      depthUnit: DepthUnit.meters,
      temperatureUnit: TemperatureUnit.celsius,
      pressureUnit: PressureUnit.bar,
      volumeUnit: VolumeUnit.liters,
      dateFormat: DateFormatPreference.yyyymmdd,
      componentNames: const {
        'reg': ['First stage', 'Long hose'],
      },
    );
    final sheet = xl.Excel.decodeBytes(bytes).tables['Equipment']!;
    final headers = [
      for (final cell in sheet.rows.first) cell?.value?.toString() ?? '',
    ];
    final column = headers.indexOf('Components');
    expect(column, headers.indexOf('Status') + 1);
    String cell(int row) => sheet.rows[row][column]?.value?.toString() ?? '';
    expect(cell(1), 'First stage; Long hose');
    expect(cell(2), '');
  });
}
