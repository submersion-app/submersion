import 'package:csv/csv.dart';

import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_list_codec.dart';
import 'package:submersion/core/services/export/csv/codec/csv_site_feature_codec.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_feature.dart';

/// Writes the sites CSV. Free-text cells go through [sanitizeCsvField] so a
/// spreadsheet never evaluates them as formulas; the importer reverses it.
///
/// The first twelve columns are the historical set and keep their order, so
/// a consumer reading this export by column offset is unaffected. Everything
/// issue #2201 restored is appended after them, and the site's own features
/// (issue #2200) come last, encoded into one cell.
class CsvSitesWriter {
  CsvSitesWriter(
    this.units, {
    this.featuresBySite = const {},
    this.typeNamesBySite = const {},
    this.tagNamesBySite = const {},
  });

  final CsvExportUnits units;

  /// Each site's features, by site id. Empty when the caller has none to
  /// write, which leaves the column present but blank.
  final Map<String, List<SiteFeature>> featuresBySite;

  /// Each site's type and tag NAMES, by site id (issue #2201).
  ///
  /// Names rather than ids, because a CSV is read by people and by other
  /// apps, and an id from this library means nothing in another one. The
  /// importer resolves a name back to a built-in type, or to a custom type
  /// or tag it reuses or creates.
  final Map<String, List<String>> typeNamesBySite;
  final Map<String, List<String>> tagNamesBySite;

  String write(List<DiveSite> sites) {
    final rows = <List<dynamic>>[
      [
        'Name',
        'Country',
        'Region',
        'Latitude',
        'Longitude',
        units.header(CsvColumns.maxDepth),
        'Water Type',
        'Current',
        'Entry Type',
        'Rating',
        'Description',
        'Notes',
        units.header(CsvColumns.minDepth),
        'Difficulty',
        units.header(CsvColumns.altitude),
        'City',
        'Island',
        'Body of Water',
        'Hazards',
        'Access Notes',
        'Mooring Number',
        'Parking Info',
        'Exit Type',
        'Site Types',
        'Site Tags',
        'Site Features',
      ],
    ];

    for (final site in sites) {
      rows.add([
        sanitizeCsvField(site.name),
        sanitizeCsvField(site.country),
        sanitizeCsvField(site.region),
        site.location?.latitude.toStringAsFixed(6) ?? '',
        site.location?.longitude.toStringAsFixed(6) ?? '',
        units.value(CsvColumns.maxDepth, site.maxDepth),
        site.waterType?.displayName ?? '',
        // Typical current has no backing column; the header position is kept
        // so existing consumers of this CSV keep their column offsets.
        '',
        site.entryMethod?.displayName ?? '',
        site.rating?.toStringAsFixed(1) ?? '',
        sanitizeCsvField(site.description.replaceAll('\n', ' ')),
        sanitizeCsvField(site.notes.replaceAll('\n', ' ')),
        units.value(CsvColumns.minDepth, site.minDepth),
        site.difficulty?.displayName ?? '',
        units.value(CsvColumns.altitude, site.altitude),
        sanitizeCsvField(site.city),
        sanitizeCsvField(site.island),
        sanitizeCsvField(site.bodyOfWater),
        sanitizeCsvField(site.hazards?.replaceAll('\n', ' ')),
        sanitizeCsvField(site.accessNotes?.replaceAll('\n', ' ')),
        sanitizeCsvField(site.mooringNumber),
        sanitizeCsvField(site.parkingInfo?.replaceAll('\n', ' ')),
        site.exitMethod?.displayName ?? '',
        sanitizeCsvField(joinCsvList(typeNamesBySite[site.id] ?? const [])),
        sanitizeCsvField(joinCsvList(tagNamesBySite[site.id] ?? const [])),
        sanitizeCsvField(
          encodeSiteFeatures(featuresBySite[site.id] ?? const []),
        ),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }
}
