import 'dart:typed_data';

import 'package:submersion/core/constants/enum_display_lookup.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_csv_table.dart';

/// Reads Submersion's sites CSV export (either unit mode) back into site
/// maps for the entity importer.
class SubmersionSitesCsvParser implements ImportParser {
  const SubmersionSitesCsvParser();

  @override
  List<ImportFormat> get supportedFormats => const [
    ImportFormat.submersionSitesCsv,
  ];

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    final table = SubmersionCsvTable.parse(fileBytes);
    final warnings = <ImportWarning>[
      for (final header in table.unreadableUnitColumns(const [
        CsvColumns.maxDepth,
      ]))
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          message:
              'Column "$header" names a unit that cannot be read; '
              'its values were left out',
          entityType: ImportEntityType.sites,
        ),
    ];
    final sites = <Map<String, dynamic>>[];

    for (final (i, row) in table.rows.indexed) {
      final name = table.text(row, 'Name');
      if (name == null) {
        warnings.add(
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Row ${i + 2} has no site name and was skipped',
            entityType: ImportEntityType.sites,
            itemIndex: i,
            field: 'Name',
          ),
        );
        continue;
      }
      final lat = table.number(row, 'Latitude');
      final lon = table.number(row, 'Longitude');
      sites.add(
        <String, dynamic>{
          'uddfId': 'csv-site-$i',
          'name': name,
          'country': table.text(row, 'Country'),
          'region': table.text(row, 'Region'),
          if (lat != null && lon != null) ...{
            'latitude': lat,
            'longitude': lon,
          },
          'maxDepth': table.quantity(row, CsvColumns.maxDepth),
          'waterType': enumByDisplayName(
            WaterType.values,
            (v) => v.displayName,
            table.text(row, 'Water Type'),
          )?.name,
          'entryMethod': enumByDisplayName(
            EntryMethod.values,
            (v) => v.displayName,
            table.text(row, 'Entry Type'),
          )?.name,
          'rating': table.number(row, 'Rating'),
          'description': table.text(row, 'Description'),
          'notes': table.text(row, 'Notes'),
        }..removeWhere((_, value) => value == null),
      );
    }

    return ImportPayload(
      entities: {if (sites.isNotEmpty) ImportEntityType.sites: sites},
      warnings: warnings,
    );
  }
}
