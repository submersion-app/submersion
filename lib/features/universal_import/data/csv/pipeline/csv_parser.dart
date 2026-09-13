import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:submersion/features/universal_import/data/csv/models/parsed_csv.dart';

/// Exception thrown when CSV parsing fails.
class CsvParseException implements Exception {
  final String message;
  const CsvParseException(this.message);

  @override
  String toString() => 'CsvParseException: $message';
}

/// Stage 1: Parse raw CSV bytes into headers and rows.
///
/// Handles encoding, line ending normalization, and basic validation.
/// Does NOT interpret values - all output is raw strings.
class CsvParser {
  const CsvParser();

  /// Parse [fileBytes] into a [ParsedCsv].
  ///
  /// Throws [CsvParseException] if the file is empty or has no data rows.
  ParsedCsv parse(Uint8List fileBytes) {
    if (fileBytes.isEmpty) {
      throw const CsvParseException('CSV file is empty');
    }

    final content = utf8.decode(fileBytes, allowMalformed: true);
    final normalized = _normalizeLineEndings(content);

    final List<List<dynamic>> allRows;
    try {
      allRows = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(normalized);
    } on Exception catch (e) {
      throw CsvParseException('Could not parse CSV: $e');
    }

    if (allRows.isEmpty) {
      throw const CsvParseException('CSV file is empty');
    }

    final headers = allRows.first
        .map((h) => (h?.toString() ?? '').trim())
        .toList();

    // Each record is one spreadsheet row (a quoted multi-line cell included),
    // so record index + 1 is the row number the user sees, header = row 1.
    final dataRows = <List<String>>[];
    final sourceRowNumbers = <int>[];
    for (var i = 1; i < allRows.length; i++) {
      final row = allRows[i];
      if (_isEmptyRow(row)) continue;
      dataRows.add(row.map((cell) => cell?.toString() ?? '').toList());
      sourceRowNumbers.add(i + 1);
    }

    if (dataRows.isEmpty) {
      throw const CsvParseException('CSV file has headers but no data rows');
    }

    return ParsedCsv(
      headers: headers,
      rows: dataRows,
      sourceRowNumbers: sourceRowNumbers,
    );
  }

  /// Normalize all line endings to \n.
  String _normalizeLineEndings(String content) {
    return content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  }

  /// Check if a row is entirely empty or whitespace.
  bool _isEmptyRow(List<dynamic> row) {
    return row.every((cell) => cell == null || cell.toString().trim().isEmpty);
  }
}
