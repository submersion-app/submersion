import 'dart:typed_data';

import 'package:submersion/core/constants/enum_display_lookup.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_unit.dart';
import 'package:submersion/core/services/export/csv/codec/tank_capacity.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/import_payload.dart';
import 'package:submersion/features/universal_import/data/models/import_warning.dart';
import 'package:submersion/features/universal_import/data/parsers/import_parser.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/site_location_text.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_csv_table.dart';

/// Reads Submersion's dives CSV export (either unit mode) back into dive,
/// site and dive type maps for the entity importer.
class SubmersionDivesCsvParser implements ImportParser {
  const SubmersionDivesCsvParser();

  @override
  List<ImportFormat> get supportedFormats => const [
    ImportFormat.submersionDivesCsv,
  ];

  static const _unitColumns = [
    CsvColumns.maxDepth,
    CsvColumns.avgDepth,
    CsvColumns.waterTemp,
    CsvColumns.airTemp,
    CsvColumns.visibility,
    CsvColumns.startPressure,
    CsvColumns.endPressure,
    CsvColumns.tankVolume,
    CsvColumns.workingPressure,
    CsvColumns.windSpeed,
  ];

  /// Plain numeric columns, read without a unit.
  static const _numberColumns = [
    'Dive Number',
    'Bottom Time',
    'Runtime',
    'Rating',
    'O2 %',
    'Humidity',
  ];

  static Duration? _minutes(double? minutes) =>
      minutes == null ? null : Duration(seconds: (minutes * 60).round());

  static String? _enumName<T extends Enum>(
    List<T> values,
    String Function(T) displayName,
    String? text,
  ) => enumByDisplayName(values, displayName, text)?.name;

  @override
  Future<ImportPayload> parse(
    Uint8List fileBytes, {
    ImportOptions? options,
  }) async {
    final table = SubmersionCsvTable.parse(fileBytes);
    final warnings = <ImportWarning>[
      for (final header in table.unreadableUnitColumns(_unitColumns))
        ImportWarning(
          severity: ImportWarningSeverity.warning,
          message:
              'Column "$header" names a unit that cannot be read; '
              'its values were left out',
          entityType: ImportEntityType.dives,
        ),
    ];
    final dives = <Map<String, dynamic>>[];
    final sitesByName = <String, Map<String, dynamic>>{};
    final diveTypesBySlug = <String, Map<String, dynamic>>{};

    for (final (i, row) in table.rows.indexed) {
      final date = table.date(row, 'Date');
      if (date == null) {
        warnings.add(
          ImportWarning(
            severity: ImportWarningSeverity.error,
            message: 'Row ${i + 2} has no readable date and was skipped',
            entityType: ImportEntityType.dives,
            itemIndex: i,
            field: 'Date',
          ),
        );
        continue;
      }
      warnings.addAll(
        table.cellWarnings(
          row,
          i,
          ImportEntityType.dives,
          numbers: [
            for (final column in _unitColumns) column.base,
            ..._numberColumns,
          ],
          times: const ['Time'],
        ),
      );
      final time = table.time(row, 'Time');
      final visibilityMeters = table.quantity(row, CsvColumns.visibility);

      final dive = <String, dynamic>{
        // Dive times are wall clocks stored UTC-flagged, like every other
        // importer's.
        'dateTime': DateTime.utc(
          date.year,
          date.month,
          date.day,
          time?.hour ?? 0,
          time?.minute ?? 0,
        ),
        'diveNumber': table.integer(row, 'Dive Number'),
        'name': table.text(row, 'Name'),
        'maxDepth': table.quantity(row, CsvColumns.maxDepth),
        'avgDepth': table.quantity(row, CsvColumns.avgDepth),
        'duration': _minutes(table.number(row, 'Bottom Time')),
        'runtime': _minutes(table.number(row, 'Runtime')),
        'waterTemp': table.quantity(row, CsvColumns.waterTemp),
        'airTemp': table.quantity(row, CsvColumns.airTemp),
        'visibilityMeters': visibilityMeters,
        // A pre-v144 dive carries only the bucket; a measured distance wins.
        'visibility': visibilityMeters == null
            ? _enumName(
                Visibility.values,
                (v) => v.displayName,
                table.text(row, 'Visibility Rating'),
              )
            : null,
        'buddy': table.text(row, 'Buddy'),
        'diveMaster': table.text(row, 'Dive Master'),
        'rating': table.integer(row, 'Rating'),
        'notes': table.text(row, 'Notes'),
        'diveComputerModel': table.text(row, 'Dive Computer'),
        'diveComputerSerial': table.text(row, 'Serial Number'),
        'diveComputerFirmware': table.text(row, 'Firmware Version'),
        'windSpeed': table.quantity(row, CsvColumns.windSpeed),
        'windDirection': _enumName(
          CurrentDirection.values,
          (v) => v.displayName,
          table.text(row, 'Wind Direction'),
        ),
        'cloudCover': _enumName(
          CloudCover.values,
          (v) => v.displayName,
          table.text(row, 'Cloud Cover'),
        ),
        'precipitation': _enumName(
          Precipitation.values,
          (v) => v.displayName,
          table.text(row, 'Precipitation'),
        ),
        'humidity': table.number(row, 'Humidity'),
        'weatherDescription': table.text(row, 'Weather Description'),
      }..removeWhere((_, value) => value == null);

      final typeIds = <String>[];
      for (final name in (table.text(row, 'Dive Type') ?? '').split(';')) {
        final trimmed = name.trim();
        final slug = DiveTypeEntity.generateSlug(trimmed);
        if (slug.isEmpty || typeIds.contains(slug)) continue;
        typeIds.add(slug);
        diveTypesBySlug.putIfAbsent(
          slug,
          () => {'id': slug, 'name': trimmed, 'uddfId': slug},
        );
      }
      if (typeIds.isNotEmpty) dive['diveTypeIds'] = typeIds;

      final tank = _tank(table, row);
      if (tank != null) dive['tanks'] = <Map<String, dynamic>>[tank];

      final custom = table.customCells(row);
      if (custom.isNotEmpty) {
        dive['customFields'] = <Map<String, dynamic>>[
          for (final c in custom) {'key': c.key, 'value': c.value},
        ];
      }

      final siteName = table.text(row, 'Site');
      if (siteName != null) {
        final site = sitesByName.putIfAbsent(siteName, () {
          final location = parseSiteLocationText(table.text(row, 'Location'));
          return <String, dynamic>{
            'uddfId': 'csv-site-${sitesByName.length}',
            'name': siteName,
            'region': location.region,
            'country': location.country,
          }..removeWhere((_, value) => value == null);
        });
        dive['site'] = <String, dynamic>{'uddfId': site['uddfId']};
      }

      dives.add(dive);
    }

    return ImportPayload(
      entities: {
        if (dives.isNotEmpty) ImportEntityType.dives: dives,
        if (sitesByName.isNotEmpty)
          ImportEntityType.sites: sitesByName.values.toList(),
        if (diveTypesBySlug.isNotEmpty)
          ImportEntityType.diveTypes: diveTypesBySlug.values.toList(),
      },
      warnings: warnings,
    );
  }

  /// The first tank, or null when every tank cell is blank.
  static Map<String, dynamic>? _tank(
    SubmersionCsvTable table,
    List<String> row,
  ) {
    final workingPressure = table.quantity(row, CsvColumns.workingPressure);
    final start = table.quantity(row, CsvColumns.startPressure);
    final end = table.quantity(row, CsvColumns.endPressure);
    final o2 = table.number(row, 'O2 %');
    final size = table.number(row, CsvColumns.tankVolume.base);
    final double? volume;
    if (size == null) {
      volume = null;
    } else {
      volume = switch (table.unitOf(CsvColumns.tankVolume)) {
        // An imperial file writes rated capacity, not water volume.
        CsvUnit.cubicFeet => volumeLitersFromCapacity(size, workingPressure),
        CsvUnit.liters => size,
        _ => null,
      };
    }
    if (volume == null &&
        workingPressure == null &&
        start == null &&
        end == null &&
        o2 == null) {
      return null;
    }
    return <String, dynamic>{
      'volume': volume,
      'workingPressure': workingPressure,
      'startPressure': start,
      'endPressure': end,
      'gasMix': GasMix(o2: o2 ?? 21),
      'order': 0,
    }..removeWhere((_, value) => value == null);
  }
}
