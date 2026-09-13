import 'dart:convert';

import 'package:csv/csv.dart';

import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart';
import 'package:submersion/core/services/export/csv/codec/csv_unit.dart';
import 'package:submersion/core/services/export/csv/codec/tank_capacity.dart';
import 'package:submersion/core/services/export/csv/dive_csv_columns.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_custom_field.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';

/// Writes the dives CSV. Every unit-bearing cell and every date and time
/// goes through [units], so Metric mode reproduces the historical file and
/// My units follows the diver with the unit named in each header. Every
/// free-text cell goes through [sanitizeCsvField] so a spreadsheet never
/// evaluates it as a formula; the importer reverses it.
class CsvDivesWriter {
  CsvDivesWriter(this.units, {this.diveTypesById = const {}});

  final CsvExportUnits units;

  /// The loaded `dive_types` rows, so each type is written under the name
  /// the diver gave it (#1834); an id with no row falls back to a name
  /// rebuilt from the id.
  final Map<String, DiveTypeEntity> diveTypesById;

  bool get _cuft => units.unitFor(CsvQuantity.volume) == CsvUnit.cubicFeet;

  String write(List<Dive> dives) {
    // Collect all distinct custom field keys across exported dives
    final sortedCustomKeys = {
      for (final dive in dives)
        for (final field in dive.customFields) field.key,
    }.toList()..sort();

    // Non-unit headers are the shared constants the built-in Submersion
    // import preset reads (#1814); unit headers follow [units], and in
    // Metric mode equal those constants.
    final headers = [
      DiveCsvColumns.diveNumber,
      DiveCsvColumns.name,
      units.dateHeader(DiveCsvColumns.date),
      units.timeHeader(DiveCsvColumns.time),
      DiveCsvColumns.site,
      DiveCsvColumns.location,
      units.header(CsvColumns.maxDepth),
      units.header(CsvColumns.avgDepth),
      DiveCsvColumns.bottomTime,
      DiveCsvColumns.runtime,
      units.header(CsvColumns.waterTemp),
      units.header(CsvColumns.airTemp),
      // Split at v144: the measured distance is machine-readable, the rating
      // column carries a pre-v144 dive's bucket label.
      units.header(CsvColumns.visibility),
      DiveCsvColumns.visibilityRating,
      DiveCsvColumns.diveType,
      DiveCsvColumns.buddy,
      DiveCsvColumns.diveMaster,
      DiveCsvColumns.rating,
      units.header(CsvColumns.startPressure),
      units.header(CsvColumns.endPressure),
      units.header(CsvColumns.tankVolume),
      // My units only: a rated cuft needs the pressure to become litres
      // again. Metric keeps its historical columns.
      if (!units.isMetric) units.header(CsvColumns.workingPressure),
      DiveCsvColumns.o2Percent,
      DiveCsvColumns.diveComputer,
      DiveCsvColumns.serialNumber,
      DiveCsvColumns.firmwareVersion,
      DiveCsvColumns.notes,
      units.header(CsvColumns.windSpeed),
      DiveCsvColumns.windDirection,
      DiveCsvColumns.cloudCover,
      DiveCsvColumns.precipitation,
      DiveCsvColumns.humidity,
      DiveCsvColumns.weatherDescription,
      // Appended after the pre-#1814 columns so spreadsheets that address
      // the export by column position keep their offsets.
      DiveCsvColumns.siteCity,
      DiveCsvColumns.siteRegion,
      DiveCsvColumns.siteCountry,
      DiveCsvColumns.siteIsland,
      DiveCsvColumns.hePercent,
      DiveCsvColumns.customFields,
      DiveCsvColumns.diveTypeIds,
      ...sortedCustomKeys.map(
        (key) => sanitizeCsvField('${DiveCsvColumns.customFieldPrefix}$key'),
      ),
    ];

    final rows = <List<dynamic>>[headers];

    for (final dive in dives) {
      final tank = dive.tanks.isNotEmpty ? dive.tanks.first : null;
      rows.add([
        dive.diveNumber ?? '',
        sanitizeCsvField(dive.effectiveName?.replaceAll('\n', ' ')),
        units.date(dive.dateTime),
        units.time(dive.dateTime),
        sanitizeCsvField(dive.site?.name),
        sanitizeCsvField(dive.site?.locationString),
        units.value(CsvColumns.maxDepth, dive.maxDepth),
        units.value(CsvColumns.avgDepth, dive.avgDepth),
        dive.bottomTime?.inMinutes ?? '',
        dive.runtime?.inMinutes ?? '',
        units.value(CsvColumns.waterTemp, dive.waterTemp),
        units.value(CsvColumns.airTemp, dive.airTemp),
        units.value(CsvColumns.visibility, dive.visibilityMeters),
        dive.visibility?.displayName ?? '',
        sanitizeCsvField(
          dive
              .diveTypeNamesFrom(diveTypesById)
              .join(DiveCsvColumns.diveTypeSeparator),
        ),
        sanitizeCsvField(dive.buddy),
        sanitizeCsvField(dive.diveMaster),
        dive.rating ?? '',
        units.value(CsvColumns.startPressure, tank?.startPressure),
        units.value(CsvColumns.endPressure, tank?.endPressure),
        _tankVolume(tank),
        if (!units.isMetric)
          units.value(CsvColumns.workingPressure, tank?.workingPressure),
        tank?.gasMix.o2.toStringAsFixed(0) ?? '',
        sanitizeCsvField(dive.diveComputerModel),
        sanitizeCsvField(dive.diveComputerSerial),
        sanitizeCsvField(dive.diveComputerFirmware),
        sanitizeCsvField(dive.notes.replaceAll('\n', ' ')),
        units.value(CsvColumns.windSpeed, dive.windSpeed),
        dive.windDirection?.displayName ?? '',
        dive.cloudCover?.displayName ?? '',
        dive.precipitation?.displayName ?? '',
        dive.humidity?.toStringAsFixed(0) ?? '',
        sanitizeCsvField(dive.weatherDescription),
        sanitizeCsvField(dive.site?.city),
        sanitizeCsvField(dive.site?.region),
        sanitizeCsvField(dive.site?.country),
        sanitizeCsvField(dive.site?.island),
        tank?.gasMix.he.toStringAsFixed(0) ?? '',
        _customFieldsJson(dive.customFields),
        // A name cannot be turned back into its id, so the ids ride along.
        sanitizeCsvField(
          dive.diveTypeIds.join(DiveCsvColumns.diveTypeSeparator),
        ),
        ...sortedCustomKeys.map((key) {
          final field = dive.customFields
              .where((f) => f.key == key)
              .firstOrNull;
          return sanitizeCsvField(field?.value ?? '');
        }),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// The [DiveCsvColumns.customFields] cell: [fields] as a JSON list of
  /// `{key, value}` objects in sort order, or empty when there are none.
  /// It always starts with `[`, so it needs no formula guard.
  static String _customFieldsJson(List<DiveCustomField> fields) {
    if (fields.isEmpty) return '';
    final ordered = [...fields]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return jsonEncode([
      for (final field in ordered) {'key': field.key, 'value': field.value},
    ]);
  }

  /// Litres, or the rated gas capacity an imperial diver knows the cylinder
  /// by (the number the app shows).
  String _tankVolume(DiveTank? tank) {
    final volume = tank?.volume;
    if (volume == null) return '';
    if (!_cuft) return units.value(CsvColumns.tankVolume, volume);
    return ratedCapacityCuft(
      volume,
      tank!.workingPressure,
    ).toStringAsFixed(CsvUnit.cubicFeet.myUnitsDecimals);
  }
}
