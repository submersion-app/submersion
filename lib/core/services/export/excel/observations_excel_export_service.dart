import 'package:excel_community/excel_community.dart' as xl;

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/shared/unit_converters.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';

/// One gear check-in, flattened with the names the sheet needs.
///
/// The item name, its type label and the dive number do not live on
/// [EquipmentObservation]; resolving them at the call site keeps this
/// service free of repository dependencies, like the maintenance sheet.
typedef ObservationExportRow = ({
  String equipmentName,
  String equipmentType,
  int? diveNumber,
  EquipmentObservation observation,
});

/// The "Observations" sheet of the whole-library workbook (condition phase
/// 3a): one row per check-in. Headers and the stored tag names are English
/// constants, matching the maintenance sheet: the workbook is an analysis
/// target, not a UI surface.
class ObservationsExcelExportService {
  static const observationsSheet = 'Observations';

  static const headers = [
    'Equipment',
    'Equipment Type',
    'Date',
    'Dive Number',
    'Status',
    'Tags',
    'Note',
  ];

  void buildSheet(
    xl.Excel excel, {
    required List<ObservationExportRow> rows,
    required DateFormatPreference dateFormat,
  }) {
    final sheet = excel[observationsSheet];
    _writeRow(sheet, 0, headers);
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final o = row.observation;
      _writeRow(sheet, i + 1, [
        row.equipmentName,
        row.equipmentType,
        formatDateForExport(o.observedAt, dateFormat),
        row.diveNumber,
        o.status.dbValue,
        o.storedTagNames.join('; '),
        o.note.replaceAll('\n', ' '),
      ]);
    }
  }

  void _writeRow(xl.Sheet sheet, int rowIndex, List<dynamic> values) {
    for (var col = 0; col < values.length; col++) {
      sheet
          .cell(
            xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
          )
          .value = _toCellValue(
        values[col],
      );
    }
  }

  xl.CellValue _toCellValue(dynamic value) {
    if (value == null || value == '') {
      return xl.TextCellValue('');
    } else if (value is int) {
      return xl.IntCellValue(value);
    } else if (value is double) {
      return xl.DoubleCellValue(value);
    } else {
      return xl.TextCellValue(value.toString());
    }
  }
}
