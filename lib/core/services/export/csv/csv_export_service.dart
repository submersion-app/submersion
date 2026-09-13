import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/services/export/csv/codec/csv_export_units.dart';
import 'package:submersion/core/services/export/csv/codec/csv_text.dart'
    as csv_text;
import 'package:submersion/core/services/export/csv/csv_dives_writer.dart';
import 'package:submersion/core/services/export/csv/csv_equipment_writer.dart';
import 'package:submersion/core/services/export/csv/csv_sites_writer.dart';
import 'package:submersion/core/services/export/excel/observations_excel_export_service.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

/// Handles all CSV export operations: share, generate content, and save to file.
class CsvExportService {
  final _dateFormat = DateFormat('yyyy-MM-dd');

  // ==================== CSV Injection Prevention ====================

  /// Sanitize a string value to prevent CSV injection attacks.
  ///
  /// Prefixes values starting with dangerous characters (=, +, -, @, tab,
  /// carriage return, pipe) with a single quote, which forces spreadsheet
  /// applications to treat the value as plain text.
  ///
  /// References:
  /// - OWASP CSV Injection: https://owasp.org/www-community/attacks/CSV_Injection
  String sanitizeCsvField(String? value) => csv_text.sanitizeCsvField(value);

  // ==================== Share via System Sheet ====================

  /// Export dives to CSV format and share via system sheet.
  Future<String> exportDivesToCsv(
    List<Dive> dives, {
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    final csvData = generateDivesCsvContent(dives, units: units);
    return saveAndShareFile(csvData, 'dives_export.csv', 'text/csv');
  }

  /// Export dive sites to CSV format and share via system sheet.
  Future<String> exportSitesToCsv(
    List<DiveSite> sites, {
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    final csvData = generateSitesCsvContent(sites, units: units);
    return saveAndShareFile(csvData, 'sites_export.csv', 'text/csv');
  }

  /// Export equipment to CSV format and share via system sheet.
  Future<String> exportEquipmentToCsv(
    List<EquipmentItem> equipment, {
    Map<String, List<String>> componentNames = const {},
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    final csvData = generateEquipmentCsvContent(
      equipment,
      componentNames: componentNames,
      units: units,
    );
    return saveAndShareFile(csvData, 'equipment_export.csv', 'text/csv');
  }

  /// Export gear check-ins to CSV format and share via system sheet
  /// (condition phase 3a).
  Future<String> exportObservationsToCsv(List<ObservationExportRow> rows) {
    final csvData = generateObservationsCsvContent(rows);
    return saveAndShareFile(csvData, 'observations_export.csv', 'text/csv');
  }

  /// Generate CSV content for gear check-ins (without sharing). Same
  /// columns as the workbook's Observations sheet; tag names are the stored
  /// values, joined by "; ". The diver's own text is sanitised against
  /// formula injection, and a note's line breaks are flattened to spaces as
  /// the trips export does, so each check-in stays on one row.
  String generateObservationsCsvContent(List<ObservationExportRow> rows) {
    final table = <List<dynamic>>[
      ObservationsExcelExportService.headers,
      for (final row in rows)
        [
          sanitizeCsvField(row.equipmentName),
          row.equipmentType,
          _dateFormat.format(row.observation.observedAt),
          row.diveNumber ?? '',
          row.observation.status.dbValue,
          // A newer peer's names ride along, and came from another device,
          // so the cell is neutralised like the free text around it.
          sanitizeCsvField(row.observation.storedTagNames.join('; ')),
          sanitizeCsvField(
            row.observation.note.replaceAll(RegExp(r'\s*[\r\n]+\s*'), ' '),
          ),
        ],
    ];
    return const ListToCsvConverter().convert(table);
  }

  /// Save gear check-ins CSV to a user-selected location.
  Future<String?> saveObservationsCsvToFile(
    List<ObservationExportRow> rows, {
    required String dialogTitle,
  }) async {
    final csvContent = generateObservationsCsvContent(rows);
    final dateStr = _dateFormat.format(DateTime.now());
    final fileName = 'observations_export_$dateStr.csv';

    final result = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      bytes: Uint8List.fromList(utf8.encode(csvContent)),
      mimeType: 'text/csv',
    );

    if (result == null) return null;
    return savedFileLocation(result);
  }

  /// Export trips to CSV format and share via system sheet.
  Future<String> exportTripsToCsv(List<Trip> trips) async {
    final headers = [
      'Name',
      'Trip Type',
      'Start Date',
      'End Date',
      'Duration (days)',
      'Location',
      'Resort',
      'Liveaboard',
      'Notes',
    ];

    final rows = <List<dynamic>>[headers];

    for (final trip in trips) {
      rows.add([
        sanitizeCsvField(trip.name),
        trip.tripType.name,
        _dateFormat.format(trip.startDate),
        _dateFormat.format(trip.endDate),
        trip.durationDays,
        sanitizeCsvField(trip.location),
        sanitizeCsvField(trip.resortName),
        sanitizeCsvField(trip.liveaboardName),
        sanitizeCsvField(trip.notes.replaceAll('\n', ' ')),
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    return saveAndShareFile(csvData, 'trips_export.csv', 'text/csv');
  }

  // ==================== Content Generation ====================

  /// Generate CSV content for dives (without sharing). [units] defaults to
  /// the historical metric format.
  String generateDivesCsvContent(
    List<Dive> dives, {
    CsvExportUnits units = CsvExportUnits.metric,
  }) => CsvDivesWriter(units).write(dives);

  /// Generate CSV content for sites (without sharing).
  String generateSitesCsvContent(
    List<DiveSite> sites, {
    CsvExportUnits units = CsvExportUnits.metric,
  }) => CsvSitesWriter(units).write(sites);

  /// Generate CSV content for equipment (without sharing).
  /// [componentNames] maps an assembly's id to its parts' names in template
  /// order (issue #1487); items absent from it get an empty cell.
  String generateEquipmentCsvContent(
    List<EquipmentItem> equipment, {
    Map<String, List<String>> componentNames = const {},
    CsvExportUnits units = CsvExportUnits.metric,
  }) => CsvEquipmentWriter(
    units,
  ).write(equipment, componentNames: componentNames);

  // ==================== Save to File ====================

  /// Save dives CSV to a user-selected location.
  Future<String?> saveDivesCsvToFile(
    List<Dive> dives, {
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    final csvContent = generateDivesCsvContent(dives, units: units);
    final dateStr = _dateFormat.format(DateTime.now());
    final fileName = 'dives_export_$dateStr.csv';

    final result = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      bytes: Uint8List.fromList(utf8.encode(csvContent)),
      mimeType: 'text/csv',
    );

    if (result == null) return null;
    return savedFileLocation(result);
  }

  /// Save sites CSV to a user-selected location.
  Future<String?> saveSitesCsvToFile(
    List<DiveSite> sites, {
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    final csvContent = generateSitesCsvContent(sites, units: units);
    final dateStr = _dateFormat.format(DateTime.now());
    final fileName = 'sites_export_$dateStr.csv';

    final result = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      bytes: Uint8List.fromList(utf8.encode(csvContent)),
      mimeType: 'text/csv',
    );

    if (result == null) return null;
    return savedFileLocation(result);
  }

  /// Save equipment CSV to a user-selected location.
  Future<String?> saveEquipmentCsvToFile(
    List<EquipmentItem> equipment, {
    Map<String, List<String>> componentNames = const {},
    required String dialogTitle,
    CsvExportUnits units = CsvExportUnits.metric,
  }) async {
    final csvContent = generateEquipmentCsvContent(
      equipment,
      componentNames: componentNames,
      units: units,
    );
    final dateStr = _dateFormat.format(DateTime.now());
    final fileName = 'equipment_export_$dateStr.csv';

    final result = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: fileName,
      type: FileType.custom,
      bytes: Uint8List.fromList(utf8.encode(csvContent)),
      mimeType: 'text/csv',
    );

    if (result == null) return null;
    return savedFileLocation(result);
  }
}
