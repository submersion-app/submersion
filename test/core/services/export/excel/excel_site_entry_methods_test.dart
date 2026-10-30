import 'package:excel_community/excel_community.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/excel/excel_export_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// A site's entry methods share the Sites sheet's one Entry Type cell
/// (#2054).
void main() {
  Future<String?> entryTypeCell(DiveSite site) async {
    final bytes = await ExcelExportService().generateExcelBytes(
      dives: const [],
      sites: [site],
      equipment: const [],
      depthUnit: DepthUnit.meters,
      temperatureUnit: TemperatureUnit.celsius,
      pressureUnit: PressureUnit.bar,
      volumeUnit: VolumeUnit.liters,
      dateFormat: DateFormatPreference.yyyymmdd,
    );
    final sheet = xl.Excel.decodeBytes(bytes)['Sites'];
    final headers = sheet.rows.first.map((c) => c?.value.toString()).toList();
    return sheet.rows[1][headers.indexOf('Entry Type')]?.value.toString();
  }

  test('writes every entry method', () async {
    expect(
      await entryTypeCell(
        const DiveSite(
          id: 's',
          name: 'Wall',
          entryMethods: [EntryMethod.backRoll, EntryMethod.giantStride],
        ),
      ),
      'Back Roll, Giant Stride',
    );
  });

  test('writes a single method as before', () async {
    expect(
      await entryTypeCell(
        const DiveSite(
          id: 's',
          name: 'Wall',
          entryMethods: [EntryMethod.giantStride],
        ),
      ),
      'Giant Stride',
    );
  });
}
