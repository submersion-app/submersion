import 'package:excel_community/excel_community.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/excel/excel_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Issue #4007: the Dives sheet writes a fractional mix as logged, and never
/// a total above 100%.
void main() {
  Future<({String o2, String he})> cellsFor(GasMix mix) async {
    final bytes = await ExcelExportService().generateExcelBytes(
      dives: [
        Dive(
          id: 'd1',
          dateTime: DateTime.utc(2026, 10, 31, 10),
          tanks: [DiveTank(id: 't1', volume: 12, gasMix: mix)],
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
    return (o2: cell('O2 %'), he: cell('He %'));
  }

  test('a fractional mix keeps its decimal', () async {
    expect(await cellsFor(const GasMix(o2: 10.5, he: 89.5)), (
      o2: '10.5',
      he: '89.5',
    ));
  });

  test('a whole mix keeps its whole numbers', () async {
    expect(await cellsFor(const GasMix(o2: 32)), (o2: '32', he: '0'));
  });

  test('helium gives way when both round up past 100', () async {
    expect(await cellsFor(const GasMix(o2: 10.25, he: 89.75)), (
      o2: '10.3',
      he: '89.7',
    ));
  });
}
