import 'dart:io';

import 'package:submersion/core/services/export/export_service.dart';

/// Thin wrapper around [ExportService.importAllDataFromUddf] that handles
/// file I/O and extension validation.
class UddfParserService {
  final ExportService _exportService;

  const UddfParserService(this._exportService);

  /// Valid file extensions for UDDF import.
  static const validExtensions = {'uddf', 'xml'};

  /// Parse a UDDF file at [filePath] and return the structured import result.
  ///
  /// Throws [UddfParseException] if the file extension is invalid
  /// or the file cannot be read/parsed.
  Future<UddfImportResult> parseFile(String filePath) async {
    final extension = filePath.split('.').last.toLowerCase();
    if (!validExtensions.contains(extension)) {
      throw const UddfParseException('Please select a UDDF or XML file');
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw const UddfParseException('File not found');
    }

    final content = await file.readAsString();
    return parseContent(content);
  }

  /// Parse UDDF content string directly.
  ///
  /// Useful for testing or when the content is already in memory.
  Future<UddfImportResult> parseContent(String uddfContent) async {
    return _exportService.importAllDataFromUddf(uddfContent);
  }
}

/// Exception thrown when UDDF parsing fails.
class UddfParseException implements Exception {
  final String message;

  const UddfParseException(this.message);

  @override
  String toString() => 'UddfParseException: $message';
}
