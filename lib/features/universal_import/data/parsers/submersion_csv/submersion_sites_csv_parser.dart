import 'dart:typed_data';

import 'package:submersion/core/constants/enum_display_lookup.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_list_codec.dart';
import 'package:submersion/core/services/export/csv/codec/csv_site_feature_codec.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_csv_table.dart';

/// The names in a joined cell, or null when it carries none.
///
/// Null rather than an empty list for the same reason as [_featuresOf]: an
/// absent column must leave its key off the map entirely.
List<String>? _namesOf(String? cell) {
  if (cell == null || cell.trim().isEmpty) return null;
  final names = [
    for (final item in splitCsvList(cell))
      if (unescapeCsvListItem(item).trim().isNotEmpty)
        unescapeCsvListItem(item).trim(),
  ];
  return names.isEmpty ? null : names;
}

/// The features in a `Site Features` cell, or null when it carries none.
///
/// Null rather than an empty list so a site with no features leaves the key
/// off its map entirely, the way every other absent column does.
List<Map<String, dynamic>>? _featuresOf(String? cell) {
  if (cell == null || cell.trim().isEmpty) return null;
  final features = decodeSiteFeatures(cell);
  return features.isEmpty ? null : features;
}

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
        CsvColumns.minDepth,
        CsvColumns.altitude,
      ]))
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          code: ImportWarningCode.diagnostic,
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
            message:
                'Row ${table.sourceRowOf(i)} has no site name and was skipped',
            entityType: ImportEntityType.sites,
            itemIndex: i,
            field: 'Name',
          ),
        );
        continue;
      }
      warnings.addAll(
        table.cellWarnings(
          row,
          i,
          ImportEntityType.sites,
          numbers: const [
            'Latitude',
            'Longitude',
            'Max Depth',
            'Rating',
            'Min Depth',
            'Altitude',
          ],
        ),
      );
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
          // Restored by issue #2201; every one of these used to be dropped.
          'minDepth': table.quantity(row, CsvColumns.minDepth),
          // SiteDifficulty.fromString lowercases, and every display name
          // lowercases to its own enum name, so the cell goes through as is.
          'difficulty': table.text(row, 'Difficulty'),
          'altitude': table.quantity(row, CsvColumns.altitude),
          'city': table.text(row, 'City'),
          'island': table.text(row, 'Island'),
          'bodyOfWater': table.text(row, 'Body of Water'),
          'hazards': table.text(row, 'Hazards'),
          'accessNotes': table.text(row, 'Access Notes'),
          'mooringNumber': table.text(row, 'Mooring Number'),
          'parkingInfo': table.text(row, 'Parking Info'),
          'exitMethod': enumByDisplayName(
            EntryMethod.values,
            (v) => v.displayName,
            table.text(row, 'Exit Type'),
          )?.name,
          // Site features (issue #2200) ride in one cell, decoded into the
          // same maps the UDDF parser produces.
          // Site types and tags (issue #2201) travel as names, resolved on
          // import: an id from another library would mean nothing here.
          'siteTypeNames': _namesOf(table.text(row, 'Site Types')),
          'siteTagNames': _namesOf(table.text(row, 'Site Tags')),
          'siteFeatures': _featuresOf(table.text(row, 'Site Features')),
        }..removeWhere((_, value) => value == null),
      );
    }

    return ImportPayload(
      entities: {if (sites.isNotEmpty) ImportEntityType.sites: sites},
      warnings: warnings,
    );
  }
}
