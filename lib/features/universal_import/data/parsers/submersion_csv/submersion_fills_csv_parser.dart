import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_csv_table.dart';

/// Reads Submersion's cylinder fills CSV (either unit mode) back into fill
/// maps (cylinder passports phase 5). Each row keeps its fill id, which the
/// importer uses to skip a fill already here or deleted here. A hand-added
/// row without one gets an id named after its readings, so the same file
/// imported twice adds its hand-added fills once. A row whose gas mix the
/// Log fill sheet would refuse is skipped with an error. The cylinder name
/// and serial are display columns and are not read.
///
/// The id is emitted twice: under `uddfId`, which the batch merger prefixes
/// with the file id like every other entity, and under `id`, which stays
/// as written so the stored row keeps the exported id.
class SubmersionFillsCsvParser implements ImportParser {
  const SubmersionFillsCsvParser();

  static const _uuid = Uuid();

  /// Namespace for the ids of hand-added rows. Frozen: changing it would
  /// give every hand-added fill a new id and import it again.
  static const _handAddedFillNamespace = '981bbd69-603c-439d-9b29-b35c4d869922';

  /// What makes a hand-added row the same fill: its cylinder, time and
  /// readings. Notes, station, analyzer and source are left out, so
  /// correcting one of them and importing again adds nothing.
  static const _identityKeys = [
    'passportId',
    'filledAt',
    'o2Percent',
    'hePercent',
    'pressureBar',
    'temperatureC',
  ];

  /// The id of a row without one: the same readings always get the same id.
  static String _idFor(Map<String, dynamic> fill) => _uuid.v5(
    _handAddedFillNamespace,
    [
      for (final key in _identityKeys)
        '$key=${switch (fill[key]) {
          final DateTime at => at.toIso8601String(),
          final value => value ?? '',
        }}',
    ].join('\n'),
  );

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
      // A blank He means none; a He that is there but unreadable is a gas
      // the row cannot name, never quietly helium-free.
      final heWritten = table.text(row, 'He %') != null;
      final heRead = table.number(row, 'He %');
      final (missing, field) = passportId == null
          ? ('passport id', 'Passport ID')
          : date == null
          ? ('readable date', 'Date')
          : o2 == null
          ? ('readable O2 %', 'O2 %')
          : heWritten && heRead == null
          ? ('readable He %', 'He %')
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

      final he = heRead ?? 0.0;
      if (!CylinderFill.isPossibleMix(o2!, he)) {
        warnings.add(
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message:
                'Row ${table.sourceRowOf(i)} has an impossible gas mix '
                '(O2 ${trimFixed(o2, 1)} %, He ${trimFixed(he, 1)} %) and was '
                'skipped',
            entityType: ImportEntityType.fills,
            itemIndex: i,
            // Helium out of range on its own is the He cell's fault; any
            // other impossible mix is reported against O2.
            field: he < 0 || he > 100 ? 'He %' : 'O2 %',
          ),
        );
        continue;
      }

      warnings.addAll(
        table.cellWarnings(
          row,
          i,
          ImportEntityType.fills,
          numbers: const ['Pressure', 'Temperature'],
          times: const ['Time'],
        ),
      );
      final time = table.time(row, 'Time');

      final fill = <String, dynamic>{
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
        'hePercent': he,
        'pressureBar': table.quantity(row, CsvColumns.fillPressure),
        'temperatureC': table.quantity(row, CsvColumns.fillTemperature),
        'stationName': table.text(row, 'Filled By'),
        'analyzer': table.text(row, 'Analyzer'),
        'source': table.text(row, 'Source')?.toLowerCase(),
        'notes': table.text(row, 'Notes'),
      }..removeWhere((_, value) => value == null);
      final id = table.text(row, 'Fill ID') ?? _idFor(fill);
      items.add({'uddfId': id, 'id': id, ...fill});
    }

    return ImportPayload(
      entities: {if (items.isNotEmpty) ImportEntityType.fills: items},
      warnings: warnings,
    );
  }
}
