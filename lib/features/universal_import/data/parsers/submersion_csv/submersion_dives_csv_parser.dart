import 'dart:convert';
import 'dart:typed_data';

import 'package:submersion/core/constants/enum_display_lookup.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_unit.dart';
import 'package:submersion/core/services/export/csv/codec/tank_capacity.dart';
import 'package:submersion/core/services/export/csv/dive_csv_columns.dart';
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
    'He %',
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
          code: ImportWarningCode.diagnostic,
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
        // Coded and numbered so the summary can name the dives that are
        // missing: the notice grouper drops an error, which left a skipped
        // row unmentioned and a wholly unreadable file reported by its
        // first row alone (#2152).
        warnings.add(
          ImportWarning(
            severity: ImportWarningSeverity.warning,
            code: ImportWarningCode.unreadableDate,
            message:
                'Row ${table.sourceRowOf(i)} has no readable date and was '
                'skipped',
            entityType: ImportEntityType.dives,
            itemIndex: i,
            field: 'Date',
            sourceRow: table.sourceRowOf(i),
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

      final typeIds = _diveTypes(table, row, diveTypesBySlug);
      if (typeIds.isNotEmpty) dive['diveTypeIds'] = typeIds;

      final tank = _tank(table, row);
      if (tank != null) dive['tanks'] = <Map<String, dynamic>>[tank];

      final custom = _customFields(table, row);
      if (custom.isNotEmpty) dive['customFields'] = custom;

      final siteName = table.text(row, 'Site');
      if (siteName != null) {
        final site = sitesByName.putIfAbsent(
          siteName,
          () => <String, dynamic>{
            'uddfId': 'csv-site-${sitesByName.length}',
            'name': siteName,
            ..._sitePlace(table, row),
          }..removeWhere((_, value) => value == null),
        );
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

  /// The dive's type ids, registering each type in [types]. Files since
  /// #1834 carry the ids verbatim in Dive Type IDs, paired with the names
  /// only when the two lists line up (a name may contain the separator);
  /// an unpaired id keeps a name rebuilt from it. An older file only has the
  /// names, which are slugged.
  static List<String> _diveTypes(
    SubmersionCsvTable table,
    List<String> row,
    Map<String, Map<String, dynamic>> types,
  ) {
    const separator = DiveCsvColumns.diveTypeSeparator;
    final namesCell = table.text(row, DiveCsvColumns.diveType);
    final idsCell = table.text(row, DiveCsvColumns.diveTypeIds);
    final ids = <String>[];
    if (idsCell != null) {
      final listed = [
        for (final id in idsCell.split(separator))
          if (id.trim().isNotEmpty) id.trim(),
      ];
      final names = namesCell?.split(separator).map((n) => n.trim()).toList();
      final paired =
          names != null &&
          names.length == listed.length &&
          names.every((n) => n.isNotEmpty);
      for (final (i, id) in listed.indexed) {
        if (ids.contains(id)) continue;
        ids.add(id);
        types.putIfAbsent(
          id,
          () => {
            'id': id,
            'name': paired ? names[i] : Dive.diveTypeDisplayName(id),
            'uddfId': id,
          },
        );
      }
      return ids;
    }
    for (final name in (namesCell ?? '').split(';')) {
      final trimmed = name.trim();
      final slug = DiveTypeEntity.generateSlug(trimmed);
      if (slug.isEmpty || ids.contains(slug)) continue;
      ids.add(slug);
      types.putIfAbsent(
        slug,
        () => {'id': slug, 'name': trimmed, 'uddfId': slug},
      );
    }
    return ids;
  }

  /// A new site's place fields. Files since #1814 carry them in their own
  /// columns; an older file only has the Location display text, which is
  /// parsed best-effort.
  static Map<String, dynamic> _sitePlace(
    SubmersionCsvTable table,
    List<String> row,
  ) {
    if (table.hasColumn(DiveCsvColumns.siteCountry)) {
      return {
        'city': table.text(row, DiveCsvColumns.siteCity),
        'island': table.text(row, DiveCsvColumns.siteIsland),
        'region': table.text(row, DiveCsvColumns.siteRegion),
        'country': table.text(row, DiveCsvColumns.siteCountry),
      };
    }
    final location = parseSiteLocationText(table.text(row, 'Location'));
    return {'region': location.region, 'country': location.country};
  }

  /// The dive's custom fields. The JSON Custom Fields column keeps empty
  /// values and the diver's order, so it wins when it reads; otherwise the
  /// per-key `custom:<key>` columns (all an older file has) are used.
  static List<Map<String, dynamic>> _customFields(
    SubmersionCsvTable table,
    List<String> row,
  ) {
    final json = table.text(row, DiveCsvColumns.customFields);
    if (json != null) {
      try {
        final decoded = jsonDecode(json);
        if (decoded is List) {
          return [
            for (final entry in decoded)
              if (entry is Map && entry['key'] is String)
                {'key': entry['key'], 'value': '${entry['value'] ?? ''}'},
          ];
        }
      } on FormatException {
        // A hand-edited cell that is no longer JSON: fall back below.
      }
    }
    return [
      for (final c in table.customCells(row)) {'key': c.key, 'value': c.value},
    ];
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
    final he = table.number(row, DiveCsvColumns.hePercent);
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
        o2 == null &&
        he == null) {
      return null;
    }
    return <String, dynamic>{
      'volume': volume,
      'workingPressure': workingPressure,
      'startPressure': start,
      'endPressure': end,
      'gasMix': GasMix(o2: o2 ?? 21, he: he ?? 0),
      'order': 0,
    }..removeWhere((_, value) => value == null);
  }
}
