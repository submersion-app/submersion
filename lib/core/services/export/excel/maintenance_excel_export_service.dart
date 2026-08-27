import 'dart:typed_data';

import 'package:excel_community/excel_community.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/export/shared/unit_converters.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';

/// One maintenance entry, flattened with the names it needs.
///
/// The sheet wants the equipment name and the resolved service kind name,
/// neither of which lives on [ServiceRecord]. Resolving them at the call site
/// keeps this service free of repository dependencies and trivially testable.
typedef MaintenanceLogRow = ({
  String equipmentName,
  String equipmentType,
  String serviceTypeName,
  ServiceCategory serviceCategory,
  ServiceRecord record,
});

/// Exports maintenance history to a spreadsheet.
///
/// One row per service record, carrying both classifications the diver cares
/// about: the service type (which of my maintenance jobs, from the catalog)
/// and the category (what kind of work it was).
///
/// Column headers and the category are English constants, matching
/// [ExcelExportService]: the workbook is an analysis target, not a UI surface.
class MaintenanceExcelExportService {
  static const maintenanceSheet = 'Maintenance Log';

  static const _mimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  final _fileDateFormat = DateFormat('yyyy-MM-dd');

  /// Writes the sheet into an existing [excel] workbook, so the whole-library
  /// export can carry maintenance history alongside its other sheets.
  void buildSheet(
    xl.Excel excel, {
    required List<MaintenanceLogRow> rows,
    required DateFormatPreference dateFormat,
  }) {
    final sheet = excel[maintenanceSheet];

    _writeRow(sheet, 0, const [
      'Equipment',
      'Equipment Type',
      'Service Type',
      'Category',
      'Date',
      'Provider',
      'Cost',
      'Currency',
      'Next Due',
      'Notes',
    ]);

    for (var i = 0; i < rows.length; i++) {
      final entry = rows[i];
      final record = entry.record;
      _writeRow(sheet, i + 1, [
        entry.equipmentName,
        entry.equipmentType,
        entry.serviceTypeName,
        entry.serviceCategory.displayName,
        formatDateForExport(record.serviceDate, dateFormat),
        record.provider ?? '',
        record.cost,
        record.currency,
        record.nextServiceDue == null
            ? ''
            : formatDateForExport(record.nextServiceDue!, dateFormat),
        record.notes.replaceAll('\n', ' '),
      ]);
    }
  }

  /// Builds a standalone maintenance workbook.
  List<int> generateBytes({
    required List<MaintenanceLogRow> rows,
    required DateFormatPreference dateFormat,
  }) {
    final excel = xl.Excel.createExcel();
    buildSheet(excel, rows: rows, dateFormat: dateFormat);
    // Deleted only after the real sheet exists: the excel package refuses to
    // remove a workbook's last remaining sheet, so deleting first is a no-op
    // that leaves a stray empty "Sheet1" in the output.
    excel.delete('Sheet1');
    return excel.encode() ?? const <int>[];
  }

  /// Writes the workbook to the documents directory and opens the system share
  /// sheet. Share-only by contract; see [saveToFile] for the save path.
  Future<String> exportToExcel({
    required List<MaintenanceLogRow> rows,
    required DateFormatPreference dateFormat,
  }) {
    final bytes = generateBytes(rows: rows, dateFormat: dateFormat);
    return saveAndShareFileBytes(bytes, _fileName(), _mimeType);
  }

  /// Prompts for a destination. Returns null when the diver cancelled, which
  /// callers must treat as a no-op rather than as success.
  Future<String?> saveToFile({
    required List<MaintenanceLogRow> rows,
    required DateFormatPreference dateFormat,
  }) async {
    final bytes = generateBytes(rows: rows, dateFormat: dateFormat);
    final result = await FilePicker.saveFile(
      dialogTitle: 'Save Maintenance Log',
      fileName: _fileName(),
      type: FileType.custom,
      bytes: Uint8List.fromList(bytes),
      mimeType: _mimeType,
    );

    if (result == null) return null;
    return savedFileLocation(result);
  }

  String _fileName() =>
      'submersion_maintenance_${_fileDateFormat.format(DateTime.now())}.xlsx';

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
