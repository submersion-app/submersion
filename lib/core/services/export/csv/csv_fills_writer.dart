import 'package:csv/csv.dart';

import 'package:submersion/core/services/export/csv/codec/csv_column.dart';
import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

/// Writes the cylinder fills CSV (spec section 10.2, PR 5): one row per
/// fill. The fill id and passport id are the row's identity and survive a
/// re-import; the cylinder name and serial are for the reader and are
/// ignored on import. The reserved `station_key` and `signed_record`
/// columns are never written. Free-text cells go through
/// [sanitizeCsvField] so a spreadsheet never evaluates them as formulas;
/// the importer reverses it.
class CsvFillsWriter {
  CsvFillsWriter(this.units);

  final CsvExportUnits units;

  /// [equipmentById] supplies the name and serial of each fill's linked
  /// cylinder; a fill whose cylinder is unknown gets empty cells.
  String write(
    List<CylinderFill> fills, {
    Map<String, EquipmentItem> equipmentById = const {},
  }) {
    final rows = <List<dynamic>>[
      [
        'Fill ID',
        'Passport ID',
        'Cylinder',
        'Serial Number',
        units.dateHeader('Date'),
        units.timeHeader('Time'),
        'O2 %',
        'He %',
        units.header(CsvColumns.fillPressure),
        units.header(CsvColumns.fillTemperature),
        'Filled By',
        'Analyzer',
        'Source',
        'Notes',
      ],
    ];

    for (final fill in fills) {
      final cylinder = fill.equipmentId == null
          ? null
          : equipmentById[fill.equipmentId];
      rows.add([
        fill.id,
        sanitizeCsvField(fill.passportId),
        sanitizeCsvField(cylinder?.name),
        sanitizeCsvField(cylinder?.serialNumber),
        units.date(fill.filledAt),
        units.time(fill.filledAt),
        trimFixed(fill.o2Percent, 1),
        trimFixed(fill.hePercent, 1),
        units.value(CsvColumns.fillPressure, fill.pressureBar),
        units.value(CsvColumns.fillTemperature, fill.temperatureC),
        sanitizeCsvField(fill.stationName),
        sanitizeCsvField(fill.analyzer),
        fill.source.name,
        sanitizeCsvField(fill.notes.replaceAll('\n', ' ')),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }
}
