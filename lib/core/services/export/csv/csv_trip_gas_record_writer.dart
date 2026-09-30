import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart';
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';

/// The trip gas record as a CSV: one line per dive tank breathed from a
/// trip cylinder (decided 2026-09-30: rows only, totals stay on screen).
/// Always a Diver column, so the layout is the same for every trip.
class CsvTripGasRecordWriter {
  CsvTripGasRecordWriter(this.units);

  final CsvExportUnits units;

  String write(
    TripGasRecord record, {
    Map<String, String> centerNames = const {},
  }) {
    String percent(double? v) => v == null ? '' : trimFixed(v, 1);
    final rows = <List<dynamic>>[
      [
        units.dateHeader('Date'),
        units.timeHeader('Time'),
        'Diver',
        'Site',
        'Cylinder',
        'Bottle',
        'O2 %',
        'He %',
        'Analyzed O2 %',
        'Analyzed He %',
        units.header(CsvColumns.recordFillPressure),
        units.header(CsvColumns.startPressure),
        units.header(CsvColumns.endPressure),
        units.header(CsvColumns.gasBreathed),
        'Fill Station',
      ],
    ];
    for (final r in record.rows) {
      final ordered = r.orderedMix;
      final analyzed = r.analyzedMix;
      rows.add([
        units.date(r.tank.entryTime),
        units.time(r.tank.entryTime),
        sanitizeCsvField(r.tank.diverName),
        sanitizeCsvField(r.tank.siteName),
        sanitizeCsvField(r.cylinder.label),
        sanitizeCsvField(r.bottleLabel),
        percent(ordered?.o2),
        percent(ordered?.he),
        percent(analyzed?.o2),
        analyzed == null || analyzed.he == 0 ? '' : percent(analyzed.he),
        units.value(CsvColumns.recordFillPressure, r.fillPressure),
        units.value(CsvColumns.startPressure, r.tank.startPressure),
        units.value(CsvColumns.endPressure, r.tank.endPressure),
        units.value(CsvColumns.gasBreathed, r.litres),
        sanitizeCsvField(centerNames[r.diveCenterId]),
      ]);
    }
    return const ListToCsvConverter().convert(rows);
  }
}

/// `gas_record_<trip>_<yyyy-MM-dd>.csv`, the trip name reduced to letters,
/// digits and underscores so every platform accepts it.
String tripGasRecordFileName(String tripName, DateTime date) =>
    'gas_record_${tripName.replaceAll(RegExp(r'[^\w]'), '_')}_'
    '${DateFormat('yyyy-MM-dd').format(date)}.csv';
