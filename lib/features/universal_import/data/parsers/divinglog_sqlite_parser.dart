import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_db_reader.dart';
import 'package:submersion/features/universal_import/data/services/divinglog_dive_mapper.dart';

/// Parses a Diving Log 5.0 / DiveLogDT SQLite logbook into an
/// [ImportPayload].
///
/// Orchestrates [DivingLogDbReader] to [DivingLogDiveMapper] with error
/// handling; the same shape as `MacDiveSqliteParser`.
class DivingLogSqliteParser implements ImportParser {
  const DivingLogSqliteParser();

  @override
  List<ImportFormat> get supportedFormats => const [
    ImportFormat.divingLogSqlite,
  ];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    if (fileBytes.isEmpty) {
      return const ImportPayload(
        entities: {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Empty file',
          ),
        ],
      );
    }

    if (!await DivingLogDbReader.isDivingLogDb(fileBytes)) {
      return const ImportPayload(
        entities: {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message:
                'File is not a Diving Log SQLite logbook. Expected a '
                'Logbook table.',
          ),
        ],
      );
    }

    try {
      final logbook = await DivingLogDbReader.readAll(fileBytes);
      if (logbook.dives.isEmpty) {
        // Carry the schema notes through. They say which table or column was
        // missing, which is the only thing that explains an empty import,
        // and returning a bare error would drop them exactly when the diver
        // needs them.
        return ImportPayload(
          entities: const {},
          warnings: [
            const ImportWarning(
              severity: ImportWarningSeverity.error,
              message: 'Diving Log logbook contains no dives.',
            ),
            for (final note in logbook.schemaNotes)
              ImportWarning(
                severity: ImportWarningSeverity.info,
                code: ImportWarningCode.diagnostic,
                message: note,
              ),
          ],
        );
      }
      return DivingLogDiveMapper.toPayload(logbook);
    } catch (e) {
      return ImportPayload(
        entities: const {},
        warnings: [
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Failed to read Diving Log logbook: $e',
          ),
        ],
      );
    }
  }
}
