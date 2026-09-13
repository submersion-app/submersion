import 'package:csv/csv.dart';

import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

/// Writes the sites CSV; only Max Depth carries a unit. Free-text cells go
/// through [sanitizeCsvField] so a spreadsheet never evaluates them as
/// formulas; the importer reverses it.
class CsvSitesWriter {
  CsvSitesWriter(this.units);

  final CsvExportUnits units;

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
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }
}
