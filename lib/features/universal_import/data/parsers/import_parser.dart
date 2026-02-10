import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';

/// Abstract interface for all import parsers.
///
/// Each parser handles one or more [ImportFormat]s and produces a unified
/// [ImportPayload] containing all parsed entities. Implementations wrap
/// existing format-specific parsers (CsvImportService, UddfFullImportService,
/// FitParserService) and convert their output to the common payload format.
abstract class ImportParser {
  /// Parse file bytes into a unified import payload.
  ///
  /// [options] provides context about the source app, format, and user
  /// preferences like batch tagging.
  Future<ImportPayload> parse(Uint8List fileBytes, {ImportOptions? options});

  /// The file formats this parser can handle.
  List<ImportFormat> get supportedFormats;
}
