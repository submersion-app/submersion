import 'dart:typed_data';

import 'package:excel_community/excel_community.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/export/shared/unit_converters.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_session.dart';

/// Exports pre-dive checklist runs to a spreadsheet.
///
/// Two sheets, because the two questions divers ask of checklist history are
/// different: "which runs happened and how did they end" (one row per run) and
/// "what exactly was flagged, measured or skipped" (one row per item). The
/// item sheet carries the notes and flags, which are the audit evidence.
///
/// Column headers are English constants, matching [ExcelExportService]: the
/// workbook is an analysis target, not a UI surface.
class PreDiveExcelExportService {
  static const runsSheet = 'Checklist Runs';
  static const itemsSheet = 'Checklist Items';

  static const _mimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  final _fileDateFormat = DateFormat('yyyy-MM-dd');
  final _timeFormat = DateFormat('HH:mm');

  /// Writes both sheets into an existing [excel] workbook, so the whole-library
  /// export can carry checklist history alongside its other sheets.
  void buildSheets(
    xl.Excel excel, {
    required List<PreDiveSession> sessions,
    required Map<String, List<PreDiveSessionItem>> itemsBySession,
    required DateFormatPreference dateFormat,
  }) {
    _buildRunsSheet(excel, sessions, itemsBySession, dateFormat);
    _buildItemsSheet(excel, sessions, itemsBySession, dateFormat);
  }

  /// Builds a standalone checklist workbook.
  List<int> generateBytes({
    required List<PreDiveSession> sessions,
    required Map<String, List<PreDiveSessionItem>> itemsBySession,
    required DateFormatPreference dateFormat,
  }) {
    final excel = xl.Excel.createExcel();
    buildSheets(
      excel,
      sessions: sessions,
      itemsBySession: itemsBySession,
      dateFormat: dateFormat,
    );
    // Deleted only after the real sheets exist: the excel package refuses to
    // remove a workbook's last remaining sheet, so deleting first is a no-op
    // that leaves a stray empty "Sheet1" in the output.
    excel.delete('Sheet1');
    return excel.encode() ?? const <int>[];
  }

  /// Writes the workbook to the documents directory and opens the system share
  /// sheet. Share-only by contract; see [saveToFile] for the save path.
  Future<String> exportToExcel({
    required List<PreDiveSession> sessions,
    required Map<String, List<PreDiveSessionItem>> itemsBySession,
    required DateFormatPreference dateFormat,
  }) {
    final bytes = generateBytes(
      sessions: sessions,
      itemsBySession: itemsBySession,
      dateFormat: dateFormat,
    );
    return saveAndShareFileBytes(bytes, _fileName(), _mimeType);
  }

  /// Prompts for a destination. Returns null when the diver cancelled, which
  /// callers must treat as a no-op rather than as success.
  Future<String?> saveToFile({
    required List<PreDiveSession> sessions,
    required Map<String, List<PreDiveSessionItem>> itemsBySession,
    required DateFormatPreference dateFormat,
  }) async {
    final bytes = generateBytes(
      sessions: sessions,
      itemsBySession: itemsBySession,
      dateFormat: dateFormat,
    );
    final result = await FilePicker.saveFile(
      dialogTitle: 'Save Checklist Export',
      fileName: _fileName(),
      type: FileType.custom,
      bytes: Uint8List.fromList(bytes),
      mimeType:
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    );

    if (result == null) return null;
    return savedFileLocation(result);
  }

  String _fileName() =>
      'submersion_checklists_${_fileDateFormat.format(DateTime.now())}.xlsx';

  void _buildRunsSheet(
    xl.Excel excel,
    List<PreDiveSession> sessions,
    Map<String, List<PreDiveSessionItem>> itemsBySession,
    DateFormatPreference dateFormat,
  ) {
    final sheet = excel[runsSheet];

    _writeRow(sheet, 0, const [
      'Checklist',
      'Started',
      'Completed',
      'Status',
      'Items',
      'Resolved',
      'Flagged',
      'Linked Dive',
      'Equipment Set',
      'Notes',
    ]);

    for (var row = 0; row < sessions.length; row++) {
      final session = sessions[row];
      final items = itemsBySession[session.id] ?? const <PreDiveSessionItem>[];

      _writeRow(sheet, row + 1, [
        session.templateName,
        _dateTime(session.startedAt, dateFormat),
        _dateTime(session.completedAt, dateFormat),
        _statusLabel(session.status),
        items.length,
        items.where((i) => i.isResolved).length,
        items.where((i) => i.state == PreDiveItemState.flagged).length,
        session.diveId ?? '',
        session.equipmentSetName ?? '',
        session.notes.replaceAll('\n', ' '),
      ]);
    }
  }

  void _buildItemsSheet(
    xl.Excel excel,
    List<PreDiveSession> sessions,
    Map<String, List<PreDiveSessionItem>> itemsBySession,
    DateFormatPreference dateFormat,
  ) {
    final sheet = excel[itemsSheet];

    _writeRow(sheet, 0, const [
      'Checklist',
      'Started',
      'Section',
      'Item',
      'Type',
      'State',
      'Value',
      'Unit',
      'Note',
      'Completed At',
      'Required',
    ]);

    // Rows follow the session order so a filtered export reads top-to-bottom
    // in the same order as the list the diver exported from.
    var row = 1;
    for (final session in sessions) {
      final items = itemsBySession[session.id] ?? const <PreDiveSessionItem>[];
      for (final item in items) {
        _writeRow(sheet, row++, [
          session.templateName,
          _dateTime(session.startedAt, dateFormat),
          item.section ?? '',
          item.title,
          _typeLabel(item.itemType),
          _stateLabel(item.state),
          item.valueNumber ?? '',
          item.valueUnit ?? '',
          item.note.replaceAll('\n', ' '),
          _dateTime(item.completedAt, dateFormat),
          item.isRequired ? 'Yes' : 'No',
        ]);
      }
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

  /// Date and time together: two runs of the same checklist on the same day is
  /// the normal case on a liveaboard, so the day alone does not identify a run.
  String _dateTime(DateTime? value, DateFormatPreference dateFormat) {
    if (value == null) return '';
    return '${formatDateForExport(value, dateFormat)} '
        '${_timeFormat.format(value)}';
  }

  String _statusLabel(PreDiveSessionStatus status) => switch (status) {
    PreDiveSessionStatus.inProgress => 'In progress',
    PreDiveSessionStatus.completed => 'Completed',
    PreDiveSessionStatus.aborted => 'Aborted',
  };

  String _stateLabel(PreDiveItemState state) => switch (state) {
    PreDiveItemState.pending => 'Pending',
    PreDiveItemState.done => 'Done',
    PreDiveItemState.skipped => 'Skipped',
    PreDiveItemState.flagged => 'Flagged',
  };

  String _typeLabel(PreDiveItemType type) => switch (type) {
    PreDiveItemType.check => 'Check',
    PreDiveItemType.value => 'Value',
    PreDiveItemType.equipmentSet => 'Equipment',
  };

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
