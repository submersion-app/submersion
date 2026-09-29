import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_csv_table.dart';

/// Reads Submersion's cylinder fills CSV (either unit mode) back into fill
/// maps (cylinder passports phase 5). Each row keeps its fill id, which the
/// importer uses to skip a fill already here or deleted here; a hand-added
/// row without one is given a fresh id. The cylinder name and serial are
/// display columns and are not read.
///
/// The id is emitted twice: under `uddfId`, which the batch merger prefixes
/// with the file id like every other entity, and under `id`, which stays
/// as written so the stored row keeps the exported id.
class SubmersionFillsCsvParser implements ImportParser {
  const SubmersionFillsCsvParser();

  static const _uuid = Uuid();

  @override
  List<ImportFormat> get supportedFormats => const [
    ImportFormat.submersionFillsCsv,
  ];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    final table = SubmersionCsvTable.parse(fileBytes);
    final warnings = <ImportWarning>[
      for (final header in table.unreadableUnitColumns(const [
        CsvColumns.fillPressure,
        CsvColumns.fillTemperature,
      ]))
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          code: ImportWarningCode.diagnostic,
          message:
              'Column "$header" names a unit that cannot be read; '
              'its values were left out',
          entityType: ImportEntityType.fills,
        ),
    ];
    final items = <Map<String, dynamic>>[];

    for (final (i, row) in table.rows.indexed) {
      final passportId = table.text(row, 'Passport ID');
      final date = table.date(row, 'Date');
      final o2 = table.number(row, 'O2 %');
      final (missing, field) = passportId == null
          ? ('passport id', 'Passport ID')
          : date == null
          ? ('readable date', 'Date')
          : o2 == null
          ? ('readable O2 %', 'O2 %')
          : (null, null);
      if (missing != null) {
        warnings.add(
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message:
                'Row ${table.sourceRowOf(i)} has no $missing and was skipped',
            entityType: ImportEntityType.fills,
            itemIndex: i,
            field: field,
          ),
        );
        continue;
      }

      warnings.addAll(
        table.cellWarnings(
          row,
          i,
          ImportEntityType.fills,
          numbers: const ['He %', 'Pressure', 'Temperature'],
          times: const ['Time'],
        ),
      );
      final time = table.time(row, 'Time');
      final id = table.text(row, 'Fill ID') ?? _uuid.v4();

      items.add(
        <String, dynamic>{
          'uddfId': id,
          'id': id,
          'passportId': passportId,
          // A fill time is a wall clock stored as a local instant, the way
          // LogFillSheet stores it and the equipment dates come back; not
          // UTC-flagged like a dive.
          'filledAt': DateTime(
            date!.year,
            date.month,
            date.day,
            time?.hour ?? 0,
            time?.minute ?? 0,
          ),
          'o2Percent': o2,
          'hePercent': table.number(row, 'He %') ?? 0.0,
          'pressureBar': table.quantity(row, CsvColumns.fillPressure),
          'temperatureC': table.quantity(row, CsvColumns.fillTemperature),
          'stationName': table.text(row, 'Filled By'),
          'analyzer': table.text(row, 'Analyzer'),
          'source': table.text(row, 'Source')?.toLowerCase(),
          'notes': table.text(row, 'Notes'),
        }..removeWhere((_, value) => value == null),
      );
    }

    return ImportPayload(
      entities: {if (items.isNotEmpty) ImportEntityType.fills: items},
      warnings: warnings,
    );
  }
}
