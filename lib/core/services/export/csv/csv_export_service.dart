import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

/// Handles all CSV export operations: share, generate content, and save to file.
class CsvExportService {
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _timeFormat = DateFormat('HH:mm');

  // ==================== CSV Injection Prevention ====================

  /// Sanitize a string value to prevent CSV injection attacks.
  ///
  /// Prefixes values starting with dangerous characters (=, +, -, @, tab,
  /// carriage return, pipe) with a single quote, which forces spreadsheet
  /// applications to treat the value as plain text.
  ///
  /// References:
  /// - OWASP CSV Injection: https://owasp.org/www-community/attacks/CSV_Injection
  String sanitizeCsvField(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }

    final firstChar = value[0];
    if (firstChar == '=' ||
        firstChar == '+' ||
        firstChar == '-' ||
        firstChar == '@' ||
        firstChar == '\t' ||
        firstChar == '\r' ||
        firstChar == '|') {
      return "'$value";
    }

    return value;
  }

  // ==================== Share via System Sheet ====================

  /// Export dives to CSV format and share via system sheet.
  Future<String> exportDivesToCsv(List<Dive> dives) async {
    final csvData = generateDivesCsvContent(dives);
    return saveAndShareFile(csvData, 'dives_export.csv', 'text/csv');
  }

  /// Export dive sites to CSV format and share via system sheet.
  Future<String> exportSitesToCsv(List<DiveSite> sites) async {
    final csvData = generateSitesCsvContent(sites);
    return saveAndShareFile(csvData, 'sites_export.csv', 'text/csv');
  }

  /// Export equipment to CSV format and share via system sheet.
  Future<String> exportEquipmentToCsv(List<EquipmentItem> equipment) async {
    final csvData = generateEquipmentCsvContent(equipment);
    return saveAndShareFile(csvData, 'equipment_export.csv', 'text/csv');
  }

  /// Export trips to CSV format and share via system sheet.
  Future<String> exportTripsToCsv(List<Trip> trips) async {
    final headers = [
      'Name',
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

  /// Generate CSV content for dives (without sharing).
  String generateDivesCsvContent(List<Dive> dives) {
    // Collect all distinct custom field keys across exported dives
    final allCustomFieldKeys = <String>{};
    for (final dive in dives) {
      for (final field in dive.customFields) {
        allCustomFieldKeys.add(field.key);
      }
    }
    final sortedCustomKeys = allCustomFieldKeys.toList()..sort();

    final headers = [
      'Dive Number',
      'Date',
      'Time',
      'Site',
      'Location',
      'Max Depth (m)',
      'Avg Depth (m)',
      'Bottom Time (min)',
      'Runtime (min)',
      'Water Temp (°C)',
      'Air Temp (°C)',
      'Visibility',
      'Dive Type',
      'Buddy',
      'Dive Master',
      'Rating',
      'Start Pressure (bar)',
      'End Pressure (bar)',
      'Tank Volume (L)',
      'O2 %',
      'Notes',
      ...sortedCustomKeys.map((key) => 'custom:$key'),
    ];

    final rows = <List<dynamic>>[headers];

    for (final dive in dives) {
      final tank = dive.tanks.isNotEmpty ? dive.tanks.first : null;
      rows.add([
        dive.diveNumber ?? '',
        _dateFormat.format(dive.dateTime),
        _timeFormat.format(dive.dateTime),
        dive.site?.name ?? '',
        dive.site?.locationString ?? '',
        dive.maxDepth?.toStringAsFixed(1) ?? '',
        dive.avgDepth?.toStringAsFixed(1) ?? '',
        dive.duration?.inMinutes ?? '',
        dive.runtime?.inMinutes ?? '',
        dive.waterTemp?.toStringAsFixed(0) ?? '',
        dive.airTemp?.toStringAsFixed(0) ?? '',
        dive.visibility?.displayName ?? '',
        dive.diveTypeName,
        dive.buddy ?? '',
        dive.diveMaster ?? '',
        dive.rating ?? '',
        tank?.startPressure ?? '',
        tank?.endPressure ?? '',
        tank?.volume?.toStringAsFixed(0) ?? '',
        tank?.gasMix.o2.toStringAsFixed(0) ?? '',
        dive.notes.replaceAll('\n', ' '),
        ...sortedCustomKeys.map((key) {
          final field = dive.customFields
              .where((f) => f.key == key)
              .firstOrNull;
          return field?.value ?? '';
        }),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Generate CSV content for sites (without sharing).
  String generateSitesCsvContent(List<DiveSite> sites) {
    final headers = [
      'Name',
      'Country',
      'Region',
      'Latitude',
      'Longitude',
      'Max Depth (m)',
      'Water Type',
      'Current',
      'Entry Type',
      'Rating',
      'Description',
      'Notes',
    ];

    final rows = <List<dynamic>>[headers];

    for (final site in sites) {
      rows.add([
        site.name,
        site.country ?? '',
        site.region ?? '',
        site.location?.latitude.toStringAsFixed(6) ?? '',
        site.location?.longitude.toStringAsFixed(6) ?? '',
        site.maxDepth?.toStringAsFixed(1) ?? '',
        site.conditions?.waterType ?? '',
        site.conditions?.typicalCurrent ?? '',
        site.conditions?.entryType ?? '',
        site.rating?.toStringAsFixed(1) ?? '',
        site.description.replaceAll('\n', ' '),
        site.notes.replaceAll('\n', ' '),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  /// Generate CSV content for equipment (without sharing).
  String generateEquipmentCsvContent(List<EquipmentItem> equipment) {
    final headers = [
      'Name',
      'Type',
      'Brand',
      'Model',
      'Serial Number',
      'Purchase Date',
      'Last Service',
      'Next Service Due',
      'Active',
      'Notes',
    ];

    final rows = <List<dynamic>>[headers];

    for (final item in equipment) {
      rows.add([
        item.name,
        item.type.displayName,
        item.brand ?? '',
        item.model ?? '',
        item.serialNumber ?? '',
        item.purchaseDate != null ? _dateFormat.format(item.purchaseDate!) : '',
        item.lastServiceDate != null
            ? _dateFormat.format(item.lastServiceDate!)
            : '',
        item.nextServiceDue != null
            ? _dateFormat.format(item.nextServiceDue!)
            : '',
        item.isActive ? 'Yes' : 'No',
        item.notes.replaceAll('\n', ' '),
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  // ==================== Save to File ====================

  /// Save dives CSV to a user-selected location.
  Future<String?> saveDivesCsvToFile(List<Dive> dives) async {
    final csvContent = generateDivesCsvContent(dives);
    final dateStr = _dateFormat.format(DateTime.now());
    final fileName = 'dives_export_$dateStr.csv';

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Dives CSV',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: Uint8List.fromList(utf8.encode(csvContent)),
    );

    if (result == null) return null;

    if (!Platform.isAndroid) {
      final file = File(result);
      await file.writeAsString(csvContent);
    }

    return result;
  }

  /// Save sites CSV to a user-selected location.
  Future<String?> saveSitesCsvToFile(List<DiveSite> sites) async {
    final csvContent = generateSitesCsvContent(sites);
    final dateStr = _dateFormat.format(DateTime.now());
    final fileName = 'sites_export_$dateStr.csv';

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Sites CSV',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: Uint8List.fromList(utf8.encode(csvContent)),
    );

    if (result == null) return null;

    if (!Platform.isAndroid) {
      final file = File(result);
      await file.writeAsString(csvContent);
    }

    return result;
  }

  /// Save equipment CSV to a user-selected location.
  Future<String?> saveEquipmentCsvToFile(List<EquipmentItem> equipment) async {
    final csvContent = generateEquipmentCsvContent(equipment);
    final dateStr = _dateFormat.format(DateTime.now());
    final fileName = 'equipment_export_$dateStr.csv';

    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Save Equipment CSV',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: Uint8List.fromList(utf8.encode(csvContent)),
    );

    if (result == null) return null;

    if (!Platform.isAndroid) {
      final file = File(result);
      await file.writeAsString(csvContent);
    }

    return result;
  }
}
