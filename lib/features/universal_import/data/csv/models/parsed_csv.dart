import 'package:equatable/equatable.dart';

/// Output of the Parse stage. Raw CSV data with no interpretation.
class ParsedCsv extends Equatable {
  final List<String> headers;
  final List<List<String>> rows;

  const ParsedCsv({required this.headers, required this.rows});

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
  List<Object?> get props => [headers, rows];
}
