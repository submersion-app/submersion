import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/services/macdive_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/macdive_dive_mapper.dart';

/// Parses a MacDive Core Data SQLite export into an [ImportPayload].
///
/// Orchestrates [MacDiveDbReader] → [MacDiveDiveMapper] with error
/// handling; same shape as [ShearwaterCloudParser].
class MacDiveSqliteParser implements ImportParser {
  const MacDiveSqliteParser();

  @override
  List<ImportFormat> get supportedFormats => const [ImportFormat.macdiveSqlite];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    // 1. Validate schema.
    final valid = await MacDiveDbReader.isMacDiveDb(fileBytes);
    if (!valid) {
      return const ImportPayload(
        entities: {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message:
                'File is not a MacDive SQLite database. '
                'Expected ZDIVE, ZDIVESITE, ZGAS, and ZTANKANDGAS tables.',
          ),
        ],
      );
    }

    // 2. Read + map.
    try {
      final logbook = await MacDiveDbReader.readAll(fileBytes);
      if (logbook.dives.isEmpty) {
        return const ImportPayload(
          entities: {},
          warnings: [
            ImportWarning(
              severity: ImportWarningSeverity.info,
              message: 'MacDive database contains no dives.',
            ),
          ],
        );
      }
      return await MacDiveDiveMapper.toPayload(logbook);
    } catch (e) {
      return ImportPayload(
        entities: const {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Failed to read MacDive database: $e',
          ),
        ],
      );
    }
  }
}
