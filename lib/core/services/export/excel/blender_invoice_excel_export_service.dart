import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:excel_community/excel_community.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/services/export/models/blender_invoice_export_data.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';

/// Exports a trimix blender's running bill to a spreadsheet.
///
/// One row per gas line, with the fill it belongs to repeated on every row of
/// that fill: a flat sheet, matching [MaintenanceExcelExportService], is
/// easier to sort and pivot than one that nests fills under a merged header.
class BlenderInvoiceExcelExportService {
  static const invoiceSheet = 'Invoice';

  static const _mimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  final _fileDateFormat = DateFormat('yyyy-MM-dd');

  List<int> generateBytes(BlenderInvoiceExportData data) {
    final excel = xl.Excel.createExcel();
    final sheet = excel[invoiceSheet];

    _writeRow(sheet, 0, [data.date]);
    if (data.billedTo.isNotEmpty) {
      _writeRow(sheet, 1, ['Billed to', data.billedTo]);
    }
    if (data.tariff.isNotEmpty) {
      _writeRow(sheet, 2, ['Tariff', data.tariff]);
    }

    var row = 4;
    _writeRow(sheet, row, const ['Fill', 'Gas', 'Volume', 'Cost', 'Total']);
    row++;
    for (final fill in data.fills) {
      // A lump-sum fill (BilledFill.isManual) has no gas lines, so its label
      // still belongs in the Fill column with the rest blank.
      if (fill.lines.isEmpty) {
        _writeRow(sheet, row, [fill.label, '', '', '', fill.total]);
        row++;
        continue;
      }
      for (var i = 0; i < fill.lines.length; i++) {
        final line = fill.lines[i];
        _writeRow(sheet, row, [
          i == 0 ? fill.label : '',
          line.gas,
          line.volume,
          line.cost,
          i == 0 ? fill.total : '',
        ]);
        row++;
      }
    }

    row++;
    _writeRow(sheet, row, ['Total', '', '', '', data.total]);
    if (data.incomplete) {
      row++;
      _writeRow(sheet, row, ['Incomplete: one or more lines have no price.']);
    }

    // Deleted only after the real sheet exists: the excel package refuses to
    // remove a workbook's last remaining sheet.
    excel.delete('Sheet1');
    return excel.encode() ?? const <int>[];
  }

  Future<String> exportToExcel(
    BlenderInvoiceExportData data, {
    Rect? sharePositionOrigin,
  }) {
    final bytes = generateBytes(data);
    return saveAndShareFileBytes(
      bytes,
      _fileName(),
      _mimeType,
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  /// Prompts for a destination. Returns null when the diver cancelled.
  Future<String?> saveToFile(BlenderInvoiceExportData data) async {
    final bytes = generateBytes(data);
    final result = await FilePicker.saveFile(
      dialogTitle: 'Save Invoice',
      fileName: _fileName(),
      type: FileType.custom,
      bytes: Uint8List.fromList(bytes),
      mimeType: _mimeType,
    );

    if (result == null) return null;
    return savedFileLocation(result);
  }

  String _fileName() =>
      'submersion_blender_invoice_${_fileDateFormat.format(DateTime.now())}.xlsx';

  void _writeRow(xl.Sheet sheet, int rowIndex, List<dynamic> values) {
    for (var col = 0; col < values.length; col++) {
      sheet
          .cell(
            xl.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex),
          )
          .value = xl.TextCellValue(
        values[col]?.toString() ?? '',
      );
    }
  }
}
