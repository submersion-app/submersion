import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/parsers/divinglog_sqlite_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';

/// Parses a DiveMate `.ddb` logbook (#3110).
///
/// DiveMate writes Diving Log's SQLite schema, so the file goes through the
/// same reader and mapper. The reader recognises DiveMate itself
/// (`DiveMateSchema`) and adds what only DiveMate stores; this parser gives
/// the file its own format and names DiveMate in what the diver reads.
class DiveMateDdbParser implements ImportParser {
  const DiveMateDdbParser();

  @override
  List<ImportFormat> get supportedFormats => const [ImportFormat.diveMateDdb];

  @override
  Future<ImportPayload> parse(Uint8List fileBytes, {ImportOptions? options}) =>
      parseDivingLogFamily(fileBytes, product: 'DiveMate');
}
