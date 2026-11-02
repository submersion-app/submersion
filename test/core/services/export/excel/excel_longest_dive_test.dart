import 'package:excel_community/excel_community.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/excel/excel_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Issue #3304: the Statistics sheet's Longest Dive is a runtime, so a bottom
/// time cannot win it.
void main() {
  Future<xl.Excel> workbook(List<Dive> dives) async {
    final bytes = await ExcelExportService().generateExcelBytes(
      dives: dives,
      sites: const [],
      equipment: const [],
      depthUnit: DepthUnit.meters,
      temperatureUnit: TemperatureUnit.celsius,
      pressureUnit: PressureUnit.bar,
      volumeUnit: VolumeUnit.liters,
      dateFormat: DateFormatPreference.yyyymmdd,
    );
    return xl.Excel.decodeBytes(bytes);
  }

  Future<String?> longestDive(List<Dive> dives) async {
    final sheet = (await workbook(dives)).tables['Statistics']!;
    for (final row in sheet.rows) {
      if (row.first?.value?.toString() == 'Longest Dive') {
        return row[1]?.value?.toString();
      }
    }
    return null;
  }

  final measured = Dive(
    id: 'measured',
    dateTime: DateTime.utc(2026, 7, 1, 10),
    runtime: const Duration(minutes: 50),
  );
  final handLogged = Dive(
    id: 'logged',
    dateTime: DateTime.utc(2026, 7, 2, 10),
    bottomTime: const Duration(minutes: 90),
  );

  test('a bottom time cannot be the longest dive', () async {
    expect(await longestDive([handLogged, measured]), '50 min');
  });

  test('no measured dive leaves the row out', () async {
    expect(await longestDive([handLogged]), isNull);
  });

  test(
    'the Dives sheet reports the runtime the Statistics sheet does',
    () async {
      final entry = DateTime.utc(2026, 7, 3, 10);
      final stamped = Dive(
        id: 'stamped',
        dateTime: entry,
        entryTime: entry,
        exitTime: entry.add(const Duration(minutes: 40)),
      );
      final sheet = (await workbook([stamped])).tables['Dives']!;
      final headers = [for (final c in sheet.rows.first) c?.value?.toString()];
      final runtime = sheet.rows[1][headers.indexOf('Runtime (min)')];
      expect(runtime?.value?.toString(), '40');
    },
  );
}
