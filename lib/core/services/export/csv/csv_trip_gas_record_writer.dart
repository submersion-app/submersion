import 'package:csv/csv.dart';

import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart';
import 'package:submersion/core/services/export/shared/export_file_name.dart';
import 'package:submersion/core/services/export/shared/gas_percent_cells.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show GasMix;
import 'package:submersion/features/trips/domain/entities/trip_gas_record.dart';

/// The trip gas record as a CSV: one line per dive tank breathed from a
/// trip cylinder (decided 2026-09-30: rows only, totals stay on screen).
/// Always a Diver column, so the layout is the same for every trip.
/// Each mix pair (ordered, analyzed) is blank only when there is no mix;
/// otherwise both cells are numbers, so a nitrox fill reads He 0.
class CsvTripGasRecordWriter {
  CsvTripGasRecordWriter(this.units);

  final CsvExportUnits units;

  String write(
    TripGasRecord record, {
    Map<String, String> centerNames = const {},
  }) {
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
      final ordered = _cells(r.orderedMix);
      final analyzed = _cells(r.analyzedMix);
      rows.add([
        units.date(r.tank.entryTime),
        units.time(r.tank.entryTime),
        sanitizeCsvField(r.tank.diverName),
        sanitizeCsvField(r.tank.siteName),
        sanitizeCsvField(r.cylinder.label),
        sanitizeCsvField(r.namedBottle),
        ordered?.o2 ?? '',
        ordered?.he ?? '',
        analyzed?.o2 ?? '',
        analyzed?.he ?? '',
        units.value(CsvColumns.recordFillPressure, r.fillPressure),
        units.value(CsvColumns.startPressure, r.tank.startPressure),
        units.value(CsvColumns.endPressure, r.tank.endPressure),
        units.value(CsvColumns.gasBreathed, r.litres),
        sanitizeCsvField(centerNames[r.diveCenterId]),
      ]);
    }
    return const ListToCsvConverter().convert(rows);
  }

  static ({String o2, String he})? _cells(GasMix? mix) =>
      mix == null ? null : gasPercentCells(mix.o2, mix.he);
}

/// `gas_record_<trip>_<yyyy-MM-dd>.csv`, the trip name as a
/// [fileNameSegment]; `gas_record_<yyyy-MM-dd>.csv` when it has none.
String tripGasRecordFileName(String tripName, DateTime date) => exportFileName([
  'gas_record',
  fileNameSegment(tripName),
  fileNameDate(date),
], 'csv');
