import 'package:excel_community/excel_community.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/excel/excel_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Issue #3229: the Dives sheet carries the boat fields and surface
/// conditions.
void main() {
  test('the Dives sheet has a column for each', () async {
    final bytes = await ExcelExportService().generateExcelBytes(
      dives: [
        Dive(
          id: 'd1',
          dateTime: DateTime.utc(2026, 7, 1, 10),
          diveOperator: 'Buddy Dive',
          boatName: 'Bonaire Breeze',
          boatCaptain: 'Rik',
          surfaceConditions: 'Calm',
        ),
      ],
      sites: const [],
      equipment: const [],
      depthUnit: DepthUnit.meters,
      temperatureUnit: TemperatureUnit.celsius,
      pressureUnit: PressureUnit.bar,
      volumeUnit: VolumeUnit.liters,
      dateFormat: DateFormatPreference.yyyymmdd,
    );
    final sheet = xl.Excel.decodeBytes(bytes).tables['Dives']!;
    final headers = [
      for (final cell in sheet.rows.first) cell?.value?.toString() ?? '',
    ];
    String cell(String header) =>
        sheet.rows[1][headers.indexOf(header)]?.value?.toString() ?? '';

    expect(cell('Dive Operator'), 'Buddy Dive');
    expect(cell('Boat Name'), 'Bonaire Breeze');
    expect(cell('Boat Captain'), 'Rik');
    expect(cell('Surface Conditions'), 'Calm');
  });
}
