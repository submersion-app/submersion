import 'package:csv/csv.dart';

import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart';
import 'package:submersion/core/services/export/csv/codec/csv_unit.dart';
import 'package:submersion/core/services/export/csv/codec/tank_capacity.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Writes the dives CSV. Every unit-bearing cell and every date and time
/// goes through [units], so Metric mode reproduces the historical file and
/// My units follows the diver with the unit named in each header.
class CsvDivesWriter {
  CsvDivesWriter(this.units);

  final CsvExportUnits units;

  bool get _cuft => units.unitFor(CsvQuantity.volume) == CsvUnit.cubicFeet;

  String write(List<Dive> dives) {
    // Collect all distinct custom field keys across exported dives
    final sortedCustomKeys = {
      for (final dive in dives)
        for (final field in dive.customFields) field.key,
    }.toList()..sort();

    final headers = [
      'Dive Number',
      'Name',
      units.dateHeader('Date'),
      units.timeHeader('Time'),
      'Site',
      'Location',
      units.header(CsvColumns.maxDepth),
      units.header(CsvColumns.avgDepth),
      'Bottom Time (min)',
      'Runtime (min)',
      units.header(CsvColumns.waterTemp),
      units.header(CsvColumns.airTemp),
      // Split at v144: the measured distance is machine-readable, the rating
      // column carries a pre-v144 dive's bucket label.
      units.header(CsvColumns.visibility),
      'Visibility Rating',
      'Dive Type',
      'Buddy',
      'Dive Master',
      'Rating',
      units.header(CsvColumns.startPressure),
      units.header(CsvColumns.endPressure),
      units.header(CsvColumns.tankVolume),
      // My units only: a rated cuft needs the pressure to become litres
      // again. Metric keeps its historical columns.
      if (!units.isMetric) units.header(CsvColumns.workingPressure),
      'O2 %',
      'Dive Computer',
      'Serial Number',
      'Firmware Version',
      'Notes',
      units.header(CsvColumns.windSpeed),
      'Wind Direction',
      'Cloud Cover',
      'Precipitation',
      'Humidity (%)',
      'Weather Description',
      ...sortedCustomKeys.map((key) => sanitizeCsvField('custom:$key')),
    ];

    final rows = <List<dynamic>>[headers];

    for (final dive in dives) {
      final tank = dive.tanks.isNotEmpty ? dive.tanks.first : null;
      rows.add([
        dive.diveNumber ?? '',
        dive.effectiveName?.replaceAll('\n', ' ') ?? '',
        units.date(dive.dateTime),
        units.time(dive.dateTime),
        dive.site?.name ?? '',
        dive.site?.locationString ?? '',
        units.value(CsvColumns.maxDepth, dive.maxDepth),
        units.value(CsvColumns.avgDepth, dive.avgDepth),
        dive.bottomTime?.inMinutes ?? '',
        dive.runtime?.inMinutes ?? '',
        units.value(CsvColumns.waterTemp, dive.waterTemp),
        units.value(CsvColumns.airTemp, dive.airTemp),
        units.value(CsvColumns.visibility, dive.visibilityMeters),
        dive.visibility?.displayName ?? '',
        dive.diveTypeNames.join('; '),
        dive.buddy ?? '',
        dive.diveMaster ?? '',
        dive.rating ?? '',
        units.value(CsvColumns.startPressure, tank?.startPressure),
        units.value(CsvColumns.endPressure, tank?.endPressure),
        _tankVolume(tank),
        if (!units.isMetric)
          units.value(CsvColumns.workingPressure, tank?.workingPressure),
        tank?.gasMix.o2.toStringAsFixed(0) ?? '',
        dive.diveComputerModel ?? '',
        dive.diveComputerSerial ?? '',
        dive.diveComputerFirmware ?? '',
        dive.notes.replaceAll('\n', ' '),
        units.value(CsvColumns.windSpeed, dive.windSpeed),
        dive.windDirection?.displayName ?? '',
        dive.cloudCover?.displayName ?? '',
        dive.precipitation?.displayName ?? '',
        dive.humidity?.toStringAsFixed(0) ?? '',
        dive.weatherDescription ?? '',
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
