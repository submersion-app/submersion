import 'package:excel_community/excel_community.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/excel/excel_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';

/// The Dives sheet names each dive type as the diver did, not by a name
/// rebuilt from its id (#1834).
void main() {
  Future<String?> diveTypeCell(
    List<String> ids,
    Map<String, DiveTypeEntity> typesById,
  ) async {
    final bytes = await ExcelExportService().generateExcelBytes(
      dives: [Dive(id: 'd', dateTime: DateTime(2026, 1, 1), diveTypeIds: ids)],
      sites: const [],
      equipment: const [],
      depthUnit: DepthUnit.meters,
      temperatureUnit: TemperatureUnit.celsius,
      pressureUnit: PressureUnit.bar,
      volumeUnit: VolumeUnit.liters,
      dateFormat: DateFormatPreference.yyyymmdd,
      diveTypesById: typesById,
    );
    final sheet = xl.Excel.decodeBytes(bytes)['Dives'];
    final headers = sheet.rows.first.map((c) => c?.value.toString()).toList();
    final col = headers.indexOf('Dive Type');
    return sheet.rows[1][col]?.value.toString();
  }

  test('writes a custom type under its own name', () async {
    final cell = await diveTypeCell(
      const ['search_recovery', 'night'],
      {
        'search_recovery': DiveTypeEntity(
          id: 'search_recovery',
          name: 'Search & Recovery',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      },
    );
    expect(cell, 'Search & Recovery; Night');
  });

  test('rebuilds the name from the id when no row is loaded', () async {
    expect(await diveTypeCell(const ['deep_wreck'], const {}), 'Deep wreck');
  });
}
