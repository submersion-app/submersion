import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';

import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_date_formats.dart';
import 'package:submersion/core/services/export/csv/codec/csv_header.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart';
import 'package:submersion/core/services/export/csv/codec/csv_unit.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';

/// A Submersion CSV export read as text cells, looked up by column base
/// name, with every unit and date/time format taken from the headers. A
/// header with no suffix is metric and ISO, which is what a Metric-mode
/// file (and every file before #1813) contains.
class SubmersionCsvTable {
  SubmersionCsvTable._(this._headers, this.rows);

  factory SubmersionCsvTable.parse(Uint8List bytes) {
    var text = utf8.decode(bytes, allowMalformed: true);
    if (text.startsWith('\u{FEFF}')) text = text.substring(1);
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    // shouldParseNumbers: false keeps "00123" and "0.5588" exactly as
    // written; every cell is parsed by the column that owns it.
    final all = const CsvToListConverter(
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(normalized);
    if (all.isEmpty) return SubmersionCsvTable._(const [], const []);
    final headers = [for (final h in all.first) '$h'.trim()];
    final rows = [
      for (final r in all.skip(1))
        if (r.any((c) => '$c'.trim().isNotEmpty)) [for (final c in r) '$c'],
    ];
    return SubmersionCsvTable._(headers, rows);
  }

  final List<String> _headers;
  final List<List<String>> rows;

  static const _customPrefix = 'custom:';

  bool _isCustom(String header) =>
      header.toLowerCase().startsWith(_customPrefix);

  late final Map<String, int> _indexByKey = () {
    final index = <String, int>{};
    for (var i = 0; i < _headers.length; i++) {
      if (_isCustom(_headers[i])) continue;
      index.putIfAbsent(CsvHeader.parse(_headers[i]).key, () => i);
    }
    return index;
  }();

  CsvHeader? _header(String base) {
    final i = _indexByKey[base.toLowerCase()];
    return i == null ? null : CsvHeader.parse(_headers[i]);
  }

  /// The trimmed cell under [base], or null when blank or absent. The
  /// export's formula guard (a quote before `=`, `+`, `-` or `@`) is
  /// removed; a number never carries one, so numeric cells are unchanged.
  String? text(List<String> row, String base) {
    final i = _indexByKey[base.toLowerCase()];
    if (i == null || i >= row.length) return null;
    final value = unsanitizeCsvField(row[i].trim());
    return value.isEmpty ? null : value;
  }

  double? number(List<String> row, String base) {
    final value = text(row, base);
    return value == null ? null : double.tryParse(value);
  }

  int? integer(List<String> row, String base) {
    final value = text(row, base);
    if (value == null) return null;
    return int.tryParse(value) ?? double.tryParse(value)?.round();
  }

  /// The unit [column]'s header names (metric when it names none), or null
  /// when the column is absent or its unit does not measure its quantity.
  CsvUnit? unitOf(CsvColumn column) {
    final header = _header(column.base);
    if (header == null) return null;
    final suffix = header.suffix;
    if (suffix == null) return CsvUnit.metricFor(column.quantity);
    final unit = CsvUnit.fromSymbol(suffix);
    return unit?.quantity == column.quantity ? unit : null;
  }

  /// [column]'s cell converted to canonical metric.
  double? quantity(List<String> row, CsvColumn column) {
    final unit = unitOf(column);
    final value = number(row, column.base);
    if (unit == null || value == null) return null;
    return unit.toMetric(value);
  }

  /// Headers among [columns] that are present but name a unit that cannot
  /// be read, for one warning per column.
  List<String> unreadableUnitColumns(List<CsvColumn> columns) => [
    for (final column in columns)
      if (_header(column.base) case final header? when unitOf(column) == null)
        header.toString(),
  ];

  DateFormatPreference? dateFormatOf(String base) =>
      dateFormatForSuffix(_header(base)?.suffix);

  DateTime? date(List<String> row, String base) {
    final value = text(row, base);
    return value == null ? null : parseCsvDate(value, dateFormatOf(base));
  }

  ({int hour, int minute})? time(List<String> row, String base) {
    final value = text(row, base);
    return value == null
        ? null
        : parseCsvTime(value, timeFormatForSuffix(_header(base)?.suffix));
  }

  /// One warning per cell in [row] that has text but cannot be read as the
  /// kind its column holds: a number under [numbers], a date under [dates],
  /// a time under [times]. Such a cell is left out of the import, so a
  /// spreadsheet edit never drops a value without saying so. [rowIndex] is
  /// the row's index in [rows]; messages count the header as row 1.
  List<ImportWarning> cellWarnings(
    List<String> row,
    int rowIndex,
    ImportEntityType entityType, {
    Iterable<String> numbers = const [],
    Iterable<String> dates = const [],
    Iterable<String> times = const [],
  }) {
    ImportWarning warn(String base, String value) => ImportWarning(
      severity: ImportWarningSeverity.warning,
      message:
          'Row ${rowIndex + 2}: "$value" under "${_header(base)}" could not '
          'be read and was left out',
      entityType: entityType,
      itemIndex: rowIndex,
      field: base,
    );
    return [
      for (final base in numbers)
        if (text(row, base) case final value?
            when double.tryParse(value) == null)
          warn(base, value),
      for (final base in dates)
        if (text(row, base) case final value? when date(row, base) == null)
          warn(base, value),
      for (final base in times)
        if (text(row, base) case final value? when time(row, base) == null)
          warn(base, value),
    ];
  }

  /// `custom:<key>` cells with a value, in column order. A value keeps its
  /// own spacing; only a blank cell is skipped.
  List<({String key, String value})> customCells(List<String> row) => [
    for (var i = 0; i < _headers.length && i < row.length; i++)
      if (_isCustom(_headers[i]) && row[i].trim().isNotEmpty)
        (
          key: _headers[i].substring(_customPrefix.length),
          value: unsanitizeCsvField(row[i]),
        ),
  ];
}
