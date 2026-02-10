import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';

/// Fallback parser for formats that are detected but not yet supported.
///
/// Returns an empty payload with a helpful message explaining which
/// export format to use as a workaround. The message includes
/// app-specific instructions when available from [SourceApp.exportInstructions].
class PlaceholderParser implements ImportParser {
  const PlaceholderParser();

  @override
  List<ImportFormat> get supportedFormats => [
    ImportFormat.divingLogXml,
    ImportFormat.suuntoSml,
    ImportFormat.suuntoDm5,
    ImportFormat.shearwaterDb,
    ImportFormat.scubapro,
    ImportFormat.danDl7,
    ImportFormat.sqlite,
    ImportFormat.unknown,
  ];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    final format = options?.format ?? ImportFormat.unknown;
    final sourceApp = options?.sourceApp;
    final instructions = sourceApp?.exportInstructions;

    final message = instructions != null
        ? 'Native ${format.displayName} parsing is not yet available. '
              '$instructions'
        : '${format.displayName} format is not yet supported. '
              'Please export your dives in UDDF or CSV format for import.';

    return ImportPayload(
      entities: const {},
      warnings: [
        ImportWarning(severity: ImportWarningSeverity.info, message: message),
      ],
    );
  }
}
