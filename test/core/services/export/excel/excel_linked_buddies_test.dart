import 'package:excel_community/excel_community.dart' as xl;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/excel/excel_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../../../../helpers/dive_participants.dart';

/// Issue #1861: the Excel export read only the legacy `buddy` / `diveMaster`
/// scalars, so a dive whose team was linked through the buddy picker exported
/// with an empty Buddy and Dive Master.
void main() {
  /// The Buddy and Dive Master cells of the Dives sheet's first data row.
  Future<({String buddy, String diveMaster})> teamCells(Dive dive) async {
    final bytes = await ExcelExportService().generateExcelBytes(
      dives: [dive],
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
    return (buddy: cell('Buddy'), diveMaster: cell('Dive Master'));
  }

  test('linked participants fill the Buddy and Dive Master columns', () async {
    final cells = await teamCells(diveWithLinkedTeam());

    expect(cells.buddy, 'Ana');
    expect(cells.diveMaster, 'Gil, Mia');
  });

  test('a dive with no linked team falls back to the legacy scalars', () async {
    final cells = await teamCells(diveWithLegacyScalarsOnly());

    expect(cells.buddy, 'Oldbuddy');
    expect(cells.diveMaster, 'Olddm');
  });
}
