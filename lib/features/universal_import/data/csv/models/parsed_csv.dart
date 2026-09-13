import 'package:equatable/equatable.dart';

/// Output of the Parse stage. Raw CSV data with no interpretation.
class ParsedCsv extends Equatable {
  final List<String> headers;
  final List<List<String>> rows;

  /// The spreadsheet row each entry of [rows] came from, counting the header
  /// as row 1. Blank rows are dropped from [rows] but still occupy a row in a
  /// spreadsheet, so the numbers can have gaps. Null when the rows were built
  /// directly rather than parsed from a file.
  final List<int>? sourceRowNumbers;

  const ParsedCsv({
    required this.headers,
    required this.rows,
    this.sourceRowNumbers,
  });

  /// The spreadsheet row of `rows[index]`, for messages that point the user
  /// at a line in their file. Without recorded numbers, rows are assumed to
  /// follow the header with no gaps.
  int sourceRowNumber(int index) => sourceRowNumbers?[index] ?? index + 2;

  /// Returns the first [count] rows for preview/sampling purposes.
  List<List<String>> sampleRows([int count = 5]) =>
      rows.length <= count ? rows : rows.sublist(0, count);

  /// Returns sample values for a specific column index.
  List<String> sampleValues(int columnIndex, [int count = 10]) {
    final samples = <String>[];
    for (final row in rows) {
      if (columnIndex < row.length) {
        final value = row[columnIndex].trim();
        if (value.isNotEmpty) samples.add(value);
        if (samples.length >= count) break;
      }
    }
    return samples;
  }

  bool get isEmpty => rows.isEmpty;
  bool get isNotEmpty => rows.isNotEmpty;
  int get rowCount => rows.length;

  @override
  List<Object?> get props => [headers, rows, sourceRowNumbers];
}
