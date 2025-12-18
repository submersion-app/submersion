import 'dart:io';

import 'package:csv/csv.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:xml/xml.dart';

import '../constants/enums.dart' hide Visibility;
import '../constants/enums.dart' as enums;
import '../../features/dive_log/domain/entities/dive.dart';
import '../../features/dive_sites/domain/entities/dive_site.dart';
import '../../features/equipment/domain/entities/equipment_item.dart';
import '../../features/marine_life/domain/entities/species.dart';
import '../../features/buddies/domain/entities/buddy.dart';
import '../../features/certifications/domain/entities/certification.dart';
import '../../features/dive_centers/domain/entities/dive_center.dart';
import '../../features/trips/domain/entities/trip.dart';

/// Result class for comprehensive UDDF import
class UddfImportResult {
  final List<Map<String, dynamic>> dives;
  final List<Map<String, dynamic>> sites;
  final List<Map<String, dynamic>> equipment;
  final List<Map<String, dynamic>> buddies;
  final List<Map<String, dynamic>> certifications;
  final List<Map<String, dynamic>> diveCenters;
  final List<Map<String, dynamic>> species;
  final List<Map<String, dynamic>> sightings;
  final List<Map<String, dynamic>> serviceRecords;
  final Map<String, String> settings;

  const UddfImportResult({
    this.dives = const [],
    this.sites = const [],
    this.equipment = const [],
    this.buddies = const [],
    this.certifications = const [],
    this.diveCenters = const [],
    this.species = const [],
    this.sightings = const [],
    this.serviceRecords = const [],
    this.settings = const {},
  });

  /// Check if any data was imported
  bool get isEmpty =>
      dives.isEmpty &&
      sites.isEmpty &&
      equipment.isEmpty &&
      buddies.isEmpty &&
      certifications.isEmpty &&
      diveCenters.isEmpty &&
      species.isEmpty &&
      serviceRecords.isEmpty &&
      settings.isEmpty;

  /// Get total count of all items
  int get totalItems =>
      dives.length +
      sites.length +
      equipment.length +
      buddies.length +
      certifications.length +
      diveCenters.length +
      species.length +
      serviceRecords.length +
      settings.length;

  /// Summary string for display
  String get summary {
    final parts = <String>[];
    if (dives.isNotEmpty) parts.add('${dives.length} dives');
    if (sites.isNotEmpty) parts.add('${sites.length} sites');
    if (equipment.isNotEmpty) parts.add('${equipment.length} equipment');
    if (buddies.isNotEmpty) parts.add('${buddies.length} buddies');
    if (certifications.isNotEmpty) parts.add('${certifications.length} certifications');
    if (diveCenters.isNotEmpty) parts.add('${diveCenters.length} dive centers');
    if (species.isNotEmpty) parts.add('${species.length} species');
    if (serviceRecords.isNotEmpty) parts.add('${serviceRecords.length} service records');
    if (settings.isNotEmpty) parts.add('${settings.length} settings');
    return parts.isEmpty ? 'No data' : parts.join(', ');
  }
}

/// Service record for equipment maintenance
class ServiceRecord {
  final String id;
  final String equipmentId;
  final enums.ServiceType serviceType;
  final DateTime serviceDate;
  final String? provider;
  final double? cost;
  final String currency;
  final DateTime? nextServiceDue;
  final String notes;

  const ServiceRecord({
    required this.id,
    required this.equipmentId,
    required this.serviceType,
    required this.serviceDate,
    this.provider,
    this.cost,
    this.currency = 'USD',
    this.nextServiceDue,
    this.notes = '',
  });
}

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _timeFormat = DateFormat('HH:mm');
  final _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

  // ==================== CSV EXPORT ====================

  /// Sanitize a string value to prevent CSV injection attacks.
  /// 
  /// This method prevents formula injection by prefixing values that start
  /// with dangerous characters (=, +, -, @, tab, carriage return) with a
  /// single quote, which forces spreadsheet applications to treat the value
  /// as plain text instead of a formula.
  /// 
  /// References:
  /// - OWASP CSV Injection: https://owasp.org/www-community/attacks/CSV_Injection
  String _sanitizeCsvField(String? value) {
    if (value == null || value.isEmpty) {
      return '';
    }
    
    // Check if the value starts with a dangerous character
    final firstChar = value[0];
    if (firstChar == '=' || 
        firstChar == '+' || 
        firstChar == '-' || 
        firstChar == '@' ||
        firstChar == '\t' ||
        firstChar == '\r' ||
        firstChar == '|') {
      // Prefix with single quote to neutralize formula execution
      return "'$value";
    }
    
    return value;
  }

  /// Export dives to CSV format
  Future<String> exportDivesToCsv(List<Dive> dives) async {
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
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    return _saveAndShareFile(csvData, 'dives_export.csv', 'text/csv');
  }

  /// Export dive sites to CSV format
  Future<String> exportSitesToCsv(List<DiveSite> sites) async {
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

    final csvData = const ListToCsvConverter().convert(rows);
    return _saveAndShareFile(csvData, 'sites_export.csv', 'text/csv');
  }

  /// Export equipment to CSV format
  Future<String> exportEquipmentToCsv(List<EquipmentItem> equipment) async {
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
        item.lastServiceDate != null ? _dateFormat.format(item.lastServiceDate!) : '',
        item.nextServiceDue != null ? _dateFormat.format(item.nextServiceDue!) : '',
        item.isActive ? 'Yes' : 'No',
        item.notes.replaceAll('\n', ' '),
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    return _saveAndShareFile(csvData, 'equipment_export.csv', 'text/csv');
  }

  /// Export trips to CSV format
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
        _sanitizeCsvField(trip.name),
        _dateFormat.format(trip.startDate),
        _dateFormat.format(trip.endDate),
        trip.durationDays,
        _sanitizeCsvField(trip.location),
        _sanitizeCsvField(trip.resortName),
        _sanitizeCsvField(trip.liveaboardName),
        _sanitizeCsvField(trip.notes.replaceAll('\n', ' ')),
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    return _saveAndShareFile(csvData, 'trips_export.csv', 'text/csv');
  }

  /// Export trip with dives to PDF
  Future<String> exportTripToPdf(
    Trip trip,
    List<Dive> dives, {
    TripWithStats? stats,
  }) async {
    final pdf = pw.Document();

    // Title page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                trip.name,
                style: pw.TextStyle(
                  fontSize: 36,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                '${_dateFormat.format(trip.startDate)} - ${_dateFormat.format(trip.endDate)}',
                style: const pw.TextStyle(fontSize: 18),
              ),
              if (trip.location != null) ...[
                pw.SizedBox(height: 10),
                pw.Text(
                  trip.location!,
                  style: const pw.TextStyle(fontSize: 16),
                ),
              ],
              if (trip.resortName != null) ...[
                pw.SizedBox(height: 10),
                pw.Text(
                  'Resort: ${trip.resortName}',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
              if (trip.liveaboardName != null) ...[
                pw.SizedBox(height: 10),
                pw.Text(
                  'Liveaboard: ${trip.liveaboardName}',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
              pw.SizedBox(height: 30),
              pw.Text(
                '${dives.length} Dives',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (stats != null) ...[
                pw.SizedBox(height: 10),
                pw.Text(
                  'Total Bottom Time: ${stats.formattedBottomTime}',
                  style: const pw.TextStyle(fontSize: 14),
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // Dive pages
    for (final dive in dives) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Dive ${dive.diveNumber ?? ""}',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Date: ${_dateTimeFormat.format(dive.dateTime)}'),
              if (dive.site != null)
                pw.Text('Site: ${dive.site!.name}'),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (dive.maxDepth != null)
                    pw.Text('Max Depth: ${dive.maxDepth!.toStringAsFixed(1)} m'),
                  if (dive.duration != null)
                    pw.Text('Duration: ${dive.duration!.inMinutes} min'),
                ],
              ),
              if (dive.waterTemp != null)
                pw.Text('Water Temp: ${dive.waterTemp!.toStringAsFixed(1)}°C'),
              if (dive.notes.isNotEmpty) ...[
                pw.SizedBox(height: 10),
                pw.Text('Notes:'),
                pw.Text(dive.notes),
              ],
            ],
          ),
        ),
      );
    }

    final bytes = await pdf.save();
    final fileName = 'trip_${trip.name.replaceAll(RegExp(r'[^\w]'), '_')}.pdf';
    return _saveAndShareFileBytes(bytes, fileName, 'application/pdf');
  }

  // ==================== PDF EXPORT ====================

  /// Generate PDF dive logbook
  Future<String> exportDivesToPdf(
    List<Dive> dives, {
    String title = 'Dive Logbook',
    List<Sighting>? allSightings,
  }) async {
    final pdf = pw.Document();

    // Cover page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(
                  fontSize: 36,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                '${dives.length} Dives',
                style: const pw.TextStyle(fontSize: 24),
              ),
              pw.SizedBox(height: 10),
              if (dives.isNotEmpty) ...[
                pw.Text(
                  '${_dateFormat.format(dives.last.dateTime)} - ${_dateFormat.format(dives.first.dateTime)}',
                  style: const pw.TextStyle(fontSize: 16),
                ),
              ],
              pw.SizedBox(height: 40),
              pw.Text(
                'Generated on ${_dateTimeFormat.format(DateTime.now())}',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
      ),
    );

    // Summary page
    if (dives.isNotEmpty) {
      final totalDiveTime = dives
          .where((d) => d.duration != null)
          .fold<Duration>(Duration.zero, (sum, d) => sum + d.duration!);
      final maxDepth = dives
          .where((d) => d.maxDepth != null)
          .map((d) => d.maxDepth!)
          .fold<double>(0, (max, depth) => depth > max ? depth : max);
      final avgDepth = dives.where((d) => d.avgDepth != null).isEmpty
          ? 0.0
          : dives
                  .where((d) => d.avgDepth != null)
                  .map((d) => d.avgDepth!)
                  .reduce((a, b) => a + b) /
              dives.where((d) => d.avgDepth != null).length;

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Summary',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),
              _buildPdfStatRow('Total Dives', '${dives.length}'),
              _buildPdfStatRow('Total Dive Time', '${totalDiveTime.inHours}h ${totalDiveTime.inMinutes % 60}m'),
              _buildPdfStatRow('Deepest Dive', '${maxDepth.toStringAsFixed(1)}m'),
              _buildPdfStatRow('Average Depth', '${avgDepth.toStringAsFixed(1)}m'),
              _buildPdfStatRow('Unique Sites', '${dives.map((d) => d.site?.id).where((id) => id != null).toSet().length}'),
            ],
          ),
        ),
      );
    }

    // Dive log pages (multiple dives per page)
    const divesPerPage = 3;
    for (var i = 0; i < dives.length; i += divesPerPage) {
      final pageDives = dives.skip(i).take(divesPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              ...pageDives.expand((dive) => [
                _buildPdfDiveEntry(dive),
                pw.SizedBox(height: 16),
                pw.Divider(),
                pw.SizedBox(height: 16),
              ],),
            ],
          ),
        ),
      );
    }

    final pdfBytes = await pdf.save();
    final fileName = 'dive_logbook_${_dateFormat.format(DateTime.now())}.pdf';
    return _saveAndShareFileBytes(pdfBytes, fileName, 'application/pdf');
  }

  pw.Widget _buildPdfStatRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 14)),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPdfDiveEntry(Dive dive) {
    final tank = dive.tanks.isNotEmpty ? dive.tanks.first : null;

    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '#${dive.diveNumber ?? '-'} - ${dive.site?.name ?? 'Unknown Site'}',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                _dateTimeFormat.format(dive.dateTime),
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey600),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _buildPdfInfoChip('Depth', '${dive.maxDepth?.toStringAsFixed(1) ?? '-'}m'),
              pw.SizedBox(width: 16),
              _buildPdfInfoChip('Duration', '${dive.duration?.inMinutes ?? '-'} min'),
              pw.SizedBox(width: 16),
              _buildPdfInfoChip('Temp', '${dive.waterTemp?.toStringAsFixed(0) ?? '-'}°C'),
              if (tank != null) ...[
                pw.SizedBox(width: 16),
                _buildPdfInfoChip('Air', '${tank.startPressure ?? '-'} → ${tank.endPressure ?? '-'} bar'),
              ],
            ],
          ),
          if (dive.notes.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              dive.notes,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              maxLines: 2,
            ),
          ],
          if (dive.rating != null && dive.rating! > 0) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              '${'★' * dive.rating!}${'☆' * (5 - dive.rating!)}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.amber),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildPdfInfoChip(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }

  // ==================== UDDF EXPORT ====================

  /// Export dives to UDDF format (Universal Dive Data Format)
  Future<String> exportDivesToUddf(List<Dive> dives, {List<DiveSite>? sites}) async {
    final builder = XmlBuilder();

    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('uddf', attributes: {
      'version': '3.2.0',
      'xmlns': 'http://www.streit.cc/uddf/3.2/',
    }, nest: () {
      // Generator info
      builder.element('generator', nest: () {
        builder.element('name', nest: 'Submersion');
        builder.element('version', nest: '0.1.0');
        builder.element('datetime', nest: DateTime.now().toIso8601String());
        builder.element('manufacturer', nest: () {
          builder.element('name', nest: 'Submersion App');
        },);
      },);

      // Dive sites
      if (sites != null || dives.any((d) => d.site != null)) {
        builder.element('divesite', nest: () {
          final allSites = sites ?? dives.map((d) => d.site).whereType<DiveSite>().toSet().toList();
          for (final site in allSites) {
            builder.element('site', attributes: {'id': 'site_${site.id}'}, nest: () {
              builder.element('name', nest: site.name);
              if (site.location != null) {
                builder.element('geography', nest: () {
                  builder.element('latitude', nest: site.location!.latitude.toString());
                  builder.element('longitude', nest: site.location!.longitude.toString());
                },);
              }
              if (site.country != null) {
                builder.element('country', nest: site.country);
              }
              if (site.region != null) {
                builder.element('state', nest: site.region);
              }
              if (site.maxDepth != null) {
                builder.element('maximumdepth', nest: site.maxDepth.toString());
              }
              if (site.rating != null) {
                builder.element('siterating', nest: site.rating.toString());
              }
              if (site.description.isNotEmpty) {
                builder.element('notes', nest: site.description);
              }
              if (site.notes.isNotEmpty && site.notes != site.description) {
                builder.element('sitenotesadditional', nest: site.notes);
              }
            },);
          }
        },);
      }

      // Gas definitions
      builder.element('gasdefinitions', nest: () {
        // Collect all unique gas mixes from dives
        final gasMixes = <String, GasMix>{};
        for (final dive in dives) {
          for (final tank in dive.tanks) {
            final key = 'mix_${tank.gasMix.o2.toInt()}_${tank.gasMix.he.toInt()}';
            gasMixes[key] = tank.gasMix;
          }
        }
        // Add air as default
        gasMixes['mix_21_0'] = const GasMix();

        for (final entry in gasMixes.entries) {
          builder.element('mix', attributes: {'id': entry.key}, nest: () {
            builder.element('name', nest: entry.value.name);
            builder.element('o2', nest: (entry.value.o2 / 100).toString());
            builder.element('n2', nest: (entry.value.n2 / 100).toString());
            builder.element('he', nest: (entry.value.he / 100).toString());
          },);
        }
      },);

      // Profile data (repetition groups and dives)
      builder.element('profiledata', nest: () {
        // Group dives by date for repetition groups
        final divesByDate = <String, List<Dive>>{};
        for (final dive in dives) {
          final dateKey = _dateFormat.format(dive.dateTime);
          divesByDate.putIfAbsent(dateKey, () => []);
          divesByDate[dateKey]!.add(dive);
        }

        for (final dateEntry in divesByDate.entries) {
          builder.element('repetitiongroup', nest: () {
            for (final dive in dateEntry.value) {
              builder.element('dive', attributes: {'id': 'dive_${dive.id}'}, nest: () {
                builder.element('informationbeforedive', nest: () {
                  builder.element('datetime', nest: dive.dateTime.toIso8601String());
                  if (dive.diveNumber != null) {
                    builder.element('divenumber', nest: dive.diveNumber.toString());
                  }
                  if (dive.airTemp != null) {
                    builder.element('airtemperature', nest: (dive.airTemp! + 273.15).toString()); // Kelvin
                  }
                  if (dive.site != null) {
                    builder.element('link', attributes: {'ref': 'site_${dive.site!.id}'});
                  }
                  if (dive.diveMaster != null && dive.diveMaster!.isNotEmpty) {
                    builder.element('divemaster', nest: dive.diveMaster);
                  }
                  if (dive.diveCenter != null) {
                    builder.element('link', attributes: {'ref': 'center_${dive.diveCenter!.id}'});
                  }
                  // Dive type
                  builder.element('divetype', nest: dive.diveTypeId);
                  // Entry method
                  if (dive.entryMethod != null) {
                    builder.element('entrytype', nest: dive.entryMethod!.name);
                  }
                },);

                // Samples (dive profile)
                builder.element('samples', nest: () {
                  final tank = dive.tanks.isNotEmpty ? dive.tanks.first : null;
                  final mixId = tank != null
                      ? 'mix_${tank.gasMix.o2.toInt()}_${tank.gasMix.he.toInt()}'
                      : 'mix_21_0';

                  // Add tank switch at start
                  builder.element('waypoint', nest: () {
                    builder.element('divetime', nest: '0');
                    builder.element('depth', nest: '0');
                    builder.element('switchmix', attributes: {'ref': mixId});
                  },);

                  if (dive.profile.isNotEmpty) {
                    // Use actual profile data
                    for (final point in dive.profile) {
                      builder.element('waypoint', nest: () {
                        builder.element('divetime', nest: point.timestamp.toString());
                        builder.element('depth', nest: point.depth.toString());
                        if (point.temperature != null) {
                          builder.element('temperature', nest: (point.temperature! + 273.15).toString()); // Kelvin
                        }
                        if (point.pressure != null) {
                          builder.element('tankpressure', nest: (point.pressure! * 100000).toString()); // Pascal
                        }
                      },);
                    }
                  } else {
                    // Generate basic profile from dive data
                    final durationSecs = dive.duration?.inSeconds ?? 0;
                    if (dive.maxDepth != null && durationSecs > 0) {
                      // Descent to max depth (assume 1/5 of dive)
                      final descentTime = (durationSecs * 0.2).toInt();
                      builder.element('waypoint', nest: () {
                        builder.element('divetime', nest: descentTime.toString());
                        builder.element('depth', nest: dive.maxDepth.toString());
                        if (dive.waterTemp != null) {
                          builder.element('temperature', nest: (dive.waterTemp! + 273.15).toString());
                        }
                      },);

                      // Bottom time at avg depth (3/5 of dive)
                      final bottomTime = (durationSecs * 0.8).toInt();
                      builder.element('waypoint', nest: () {
                        builder.element('divetime', nest: bottomTime.toString());
                        builder.element('depth', nest: (dive.avgDepth ?? dive.maxDepth! * 0.7).toString());
                      },);

                      // Ascent to surface
                      builder.element('waypoint', nest: () {
                        builder.element('divetime', nest: durationSecs.toString());
                        builder.element('depth', nest: '0');
                      },);
                    }
                  }
                },);

                builder.element('informationafterdive', nest: () {
                  if (dive.maxDepth != null) {
                    builder.element('greatestdepth', nest: dive.maxDepth.toString());
                  }
                  if (dive.avgDepth != null) {
                    builder.element('averagedepth', nest: dive.avgDepth.toString());
                  }
                  if (dive.duration != null) {
                    builder.element('diveduration', nest: dive.duration!.inSeconds.toString());
                  }
                  if (dive.waterTemp != null) {
                    builder.element('lowesttemperature', nest: (dive.waterTemp! + 273.15).toString()); // Kelvin
                  }
                  if (dive.visibility != null) {
                    builder.element('visibility', nest: _visibilityToUddf(dive.visibility!));
                  }
                  if (dive.rating != null) {
                    builder.element('rating', nest: () {
                      builder.element('ratingvalue', nest: dive.rating.toString());
                    },);
                  }
                  // Conditions
                  if (dive.waterType != null) {
                    builder.element('watertype', nest: dive.waterType!.name);
                  }
                  if (dive.currentDirection != null) {
                    builder.element('currentdirection', nest: dive.currentDirection!.name);
                  }
                  if (dive.currentStrength != null) {
                    builder.element('currentstrength', nest: dive.currentStrength!.name);
                  }
                  if (dive.swellHeight != null) {
                    builder.element('swellheight', nest: dive.swellHeight.toString());
                  }
                  if (dive.exitMethod != null) {
                    builder.element('exittype', nest: dive.exitMethod!.name);
                  }
                  // Weight system
                  if (dive.weightAmount != null) {
                    builder.element('weightused', nest: () {
                      builder.element('amount', nest: dive.weightAmount.toString());
                      if (dive.weightType != null) {
                        builder.element('type', nest: dive.weightType!.name);
                      }
                    },);
                  }
                  // Sightings
                  if (dive.sightings.isNotEmpty) {
                    builder.element('sightings', nest: () {
                      for (final sighting in dive.sightings) {
                        builder.element('sighting', attributes: {
                          'speciesref': 'species_${sighting.speciesId}',
                          'count': sighting.count.toString(),
                        }, nest: () {
                          if (sighting.notes.isNotEmpty) {
                            builder.element('notes', nest: sighting.notes);
                          }
                        },);
                      }
                    },);
                  }
                  if (dive.notes.isNotEmpty) {
                    builder.element('notes', nest: () {
                      builder.element('para', nest: dive.notes);
                    },);
                  }
                  if (dive.buddy != null && dive.buddy!.isNotEmpty) {
                    builder.element('buddy', nest: () {
                      builder.element('personal', nest: () {
                        builder.element('firstname', nest: dive.buddy);
                      },);
                    },);
                  }
                },);
              },);
            }
          },);
        }
      },);
    },);

    final xmlDoc = builder.buildDocument();
    final xmlString = xmlDoc.toXmlString(pretty: true, indent: '  ');
    final fileName = 'dives_export_${_dateFormat.format(DateTime.now())}.uddf';
    return _saveAndShareFile(xmlString, fileName, 'application/xml');
  }

  String _visibilityToUddf(enums.Visibility visibility) {
    switch (visibility) {
      case enums.Visibility.excellent:
        return '30'; // meters
      case enums.Visibility.good:
        return '20';
      case enums.Visibility.moderate:
        return '10';
      case enums.Visibility.poor:
        return '5';
      case enums.Visibility.unknown:
        return '0';
    }
  }

  // ==================== COMPREHENSIVE UDDF EXPORT ====================

  /// Export ALL application data to UDDF format
  /// This includes: dives, sites, equipment, buddies, certifications, dive centers, species, service records, settings
  Future<String> exportAllDataToUddf({
    required List<Dive> dives,
    List<DiveSite>? sites,
    List<EquipmentItem>? equipment,
    List<Buddy>? buddies,
    List<Certification>? certifications,
    List<DiveCenter>? diveCenters,
    List<Species>? species,
    List<ServiceRecord>? serviceRecords,
    Map<String, String>? settings,
    /// Map of dive ID to list of buddies with roles for that dive
    Map<String, List<BuddyWithRole>>? diveBuddies,
  }) async {
    final builder = XmlBuilder();

    builder.processing('xml', 'version="1.0" encoding="UTF-8"');
    builder.element('uddf', attributes: {
      'version': '3.2.0',
      'xmlns': 'http://www.streit.cc/uddf/3.2/',
    }, nest: () {
      // Generator info
      builder.element('generator', nest: () {
        builder.element('name', nest: 'Submersion');
        builder.element('version', nest: '1.0.0');
        builder.element('datetime', nest: DateTime.now().toIso8601String());
        builder.element('manufacturer', nest: () {
          builder.element('name', nest: 'Submersion App');
        },);
      },);

      // Diver section with full buddy records
      if (buddies != null && buddies.isNotEmpty) {
        builder.element('diver', nest: () {
          for (final buddy in buddies) {
            builder.element('buddy', attributes: {'id': 'buddy_${buddy.id}'}, nest: () {
              builder.element('personal', nest: () {
                // Split name into first/last
                final nameParts = buddy.name.split(' ');
                builder.element('firstname', nest: nameParts.first);
                if (nameParts.length > 1) {
                  builder.element('lastname', nest: nameParts.sublist(1).join(' '));
                }
                if (buddy.email != null && buddy.email!.isNotEmpty) {
                  builder.element('email', nest: buddy.email);
                }
                if (buddy.phone != null && buddy.phone!.isNotEmpty) {
                  builder.element('phone', nest: buddy.phone);
                }
              },);
              if (buddy.certificationLevel != null || buddy.certificationAgency != null) {
                builder.element('certification', nest: () {
                  if (buddy.certificationLevel != null) {
                    builder.element('level', nest: buddy.certificationLevel!.name);
                  }
                  if (buddy.certificationAgency != null) {
                    builder.element('agency', nest: buddy.certificationAgency!.name);
                  }
                },);
              }
              if (buddy.notes.isNotEmpty) {
                builder.element('notes', nest: buddy.notes);
              }
            },);
          }
        },);
      }

      // Dive sites
      final allSites = sites ?? dives.map((d) => d.site).whereType<DiveSite>().toSet().toList();
      if (allSites.isNotEmpty) {
        builder.element('divesite', nest: () {
          for (final site in allSites) {
            _buildSiteElement(builder, site);
          }
        },);
      }

      // Gas definitions
      builder.element('gasdefinitions', nest: () {
        final gasMixes = <String, GasMix>{};
        for (final dive in dives) {
          for (final tank in dive.tanks) {
            final key = 'mix_${tank.gasMix.o2.toInt()}_${tank.gasMix.he.toInt()}';
            gasMixes[key] = tank.gasMix;
          }
        }
        gasMixes['mix_21_0'] = const GasMix();

        for (final entry in gasMixes.entries) {
          builder.element('mix', attributes: {'id': entry.key}, nest: () {
            builder.element('name', nest: entry.value.name);
            builder.element('o2', nest: (entry.value.o2 / 100).toString());
            builder.element('n2', nest: (entry.value.n2 / 100).toString());
            builder.element('he', nest: (entry.value.he / 100).toString());
          },);
        }
      },);

      // Profile data (dives)
      if (dives.isNotEmpty) {
        builder.element('profiledata', nest: () {
          final divesByDate = <String, List<Dive>>{};
          for (final dive in dives) {
            final dateKey = _dateFormat.format(dive.dateTime);
            divesByDate.putIfAbsent(dateKey, () => []);
            divesByDate[dateKey]!.add(dive);
          }

          for (final dateEntry in divesByDate.entries) {
            builder.element('repetitiongroup', nest: () {
              for (final dive in dateEntry.value) {
                final diveBuddyList = diveBuddies?[dive.id] ?? [];
                _buildDiveElement(builder, dive, buddies, diveBuddyList);
              }
            },);
          }
        },);
      }

      // Application data section for all non-standard data
      _buildApplicationData(
        builder,
        equipment: equipment,
        certifications: certifications,
        diveCenters: diveCenters,
        species: species,
        serviceRecords: serviceRecords,
        settings: settings,
      );
    },);

    final xmlDoc = builder.buildDocument();
    final xmlString = xmlDoc.toXmlString(pretty: true, indent: '  ');
    final fileName = 'submersion_backup_${_dateFormat.format(DateTime.now())}.uddf';
    return _saveAndShareFile(xmlString, fileName, 'application/xml');
  }

  void _buildSiteElement(XmlBuilder builder, DiveSite site) {
    builder.element('site', attributes: {'id': 'site_${site.id}'}, nest: () {
      builder.element('name', nest: site.name);
      if (site.location != null) {
        builder.element('geography', nest: () {
          builder.element('latitude', nest: site.location!.latitude.toString());
          builder.element('longitude', nest: site.location!.longitude.toString());
        },);
      }
      if (site.country != null) {
        builder.element('country', nest: site.country);
      }
      if (site.region != null) {
        builder.element('state', nest: site.region);
      }
      if (site.maxDepth != null) {
        builder.element('maximumdepth', nest: site.maxDepth.toString());
      }
      if (site.rating != null) {
        builder.element('siterating', nest: site.rating.toString());
      }
      if (site.description.isNotEmpty) {
        builder.element('notes', nest: site.description);
      }
      if (site.notes.isNotEmpty && site.notes != site.description) {
        builder.element('sitenotesadditional', nest: site.notes);
      }
    },);
  }

  void _buildDiveElement(XmlBuilder builder, Dive dive, List<Buddy>? buddies, List<BuddyWithRole> diveBuddyList) {
    // Separate buddies by role for UDDF export
    final regularBuddies = diveBuddyList.where((b) => b.role == BuddyRole.buddy || b.role == BuddyRole.student).toList();
    final guidesAndDivemasters = diveBuddyList.where((b) => 
      b.role == BuddyRole.diveGuide || 
      b.role == BuddyRole.diveMaster || 
      b.role == BuddyRole.instructor,
    ).toList();

    builder.element('dive', attributes: {'id': 'dive_${dive.id}'}, nest: () {
      // Information before dive
      builder.element('informationbeforedive', nest: () {
        builder.element('datetime', nest: dive.dateTime.toIso8601String());
        if (dive.diveNumber != null) {
          builder.element('divenumber', nest: dive.diveNumber.toString());
        }
        if (dive.airTemp != null) {
          builder.element('airtemperature', nest: (dive.airTemp! + 273.15).toString());
        }
        if (dive.site != null) {
          builder.element('link', attributes: {'ref': 'site_${dive.site!.id}'});
        }
        // Export guides/divemasters/instructors in the divemaster field
        if (guidesAndDivemasters.isNotEmpty) {
          final names = guidesAndDivemasters.map((b) => b.buddy.name).join(', ');
          builder.element('divemaster', nest: names);
        } else if (dive.diveMaster != null && dive.diveMaster!.isNotEmpty) {
          // Fallback to legacy field if no linked buddies
          builder.element('divemaster', nest: dive.diveMaster);
        }
        if (dive.diveCenter != null) {
          builder.element('link', attributes: {'ref': 'center_${dive.diveCenter!.id}'});
        }
        builder.element('divetype', nest: dive.diveTypeId);
        if (dive.entryMethod != null) {
          builder.element('entrytype', nest: dive.entryMethod!.name);
        }
        // Link to buddy records in diver section
        for (final buddyWithRole in diveBuddyList) {
          builder.element('link', attributes: {'ref': 'buddy_${buddyWithRole.buddy.id}'});
        }
      },);

      // Samples (dive profile)
      builder.element('samples', nest: () {
        final tank = dive.tanks.isNotEmpty ? dive.tanks.first : null;
        final mixId = tank != null
            ? 'mix_${tank.gasMix.o2.toInt()}_${tank.gasMix.he.toInt()}'
            : 'mix_21_0';

        builder.element('waypoint', nest: () {
          builder.element('divetime', nest: '0');
          builder.element('depth', nest: '0');
          builder.element('switchmix', attributes: {'ref': mixId});
        },);

        if (dive.profile.isNotEmpty) {
          for (final point in dive.profile) {
            builder.element('waypoint', nest: () {
              builder.element('divetime', nest: point.timestamp.toString());
              builder.element('depth', nest: point.depth.toString());
              if (point.temperature != null) {
                builder.element('temperature', nest: (point.temperature! + 273.15).toString());
              }
              if (point.pressure != null) {
                builder.element('tankpressure', nest: (point.pressure! * 100000).toString());
              }
            },);
          }
        } else {
          final durationSecs = dive.duration?.inSeconds ?? 0;
          if (dive.maxDepth != null && durationSecs > 0) {
            final descentTime = (durationSecs * 0.2).toInt();
            builder.element('waypoint', nest: () {
              builder.element('divetime', nest: descentTime.toString());
              builder.element('depth', nest: dive.maxDepth.toString());
              if (dive.waterTemp != null) {
                builder.element('temperature', nest: (dive.waterTemp! + 273.15).toString());
              }
            },);

            final bottomTime = (durationSecs * 0.8).toInt();
            builder.element('waypoint', nest: () {
              builder.element('divetime', nest: bottomTime.toString());
              builder.element('depth', nest: (dive.avgDepth ?? dive.maxDepth! * 0.7).toString());
            },);

            builder.element('waypoint', nest: () {
              builder.element('divetime', nest: durationSecs.toString());
              builder.element('depth', nest: '0');
            },);
          }
        }
      },);

      // Information after dive
      builder.element('informationafterdive', nest: () {
        if (dive.maxDepth != null) {
          builder.element('greatestdepth', nest: dive.maxDepth.toString());
        }
        if (dive.avgDepth != null) {
          builder.element('averagedepth', nest: dive.avgDepth.toString());
        }
        if (dive.duration != null) {
          builder.element('diveduration', nest: dive.duration!.inSeconds.toString());
        }
        if (dive.waterTemp != null) {
          builder.element('lowesttemperature', nest: (dive.waterTemp! + 273.15).toString());
        }
        if (dive.visibility != null) {
          builder.element('visibility', nest: _visibilityToUddf(dive.visibility!));
        }
        if (dive.rating != null) {
          builder.element('rating', nest: () {
            builder.element('ratingvalue', nest: dive.rating.toString());
          },);
        }
        // Conditions
        if (dive.waterType != null) {
          builder.element('watertype', nest: dive.waterType!.name);
        }
        if (dive.currentDirection != null) {
          builder.element('currentdirection', nest: dive.currentDirection!.name);
        }
        if (dive.currentStrength != null) {
          builder.element('currentstrength', nest: dive.currentStrength!.name);
        }
        if (dive.swellHeight != null) {
          builder.element('swellheight', nest: dive.swellHeight.toString());
        }
        if (dive.exitMethod != null) {
          builder.element('exittype', nest: dive.exitMethod!.name);
        }
        // Weight system
        if (dive.weightAmount != null) {
          builder.element('weightused', nest: () {
            builder.element('amount', nest: dive.weightAmount.toString());
            if (dive.weightType != null) {
              builder.element('type', nest: dive.weightType!.name);
            }
          },);
        }
        // Sightings
        if (dive.sightings.isNotEmpty) {
          builder.element('sightings', nest: () {
            for (final sighting in dive.sightings) {
              builder.element('sighting', attributes: {
                'speciesref': 'species_${sighting.speciesId}',
                'count': sighting.count.toString(),
              }, nest: () {
                if (sighting.notes.isNotEmpty) {
                  builder.element('notes', nest: sighting.notes);
                }
              },);
            }
          },);
        }
        if (dive.notes.isNotEmpty) {
          builder.element('notes', nest: () {
            builder.element('para', nest: dive.notes);
          },);
        }
        // Export regular buddies in the buddy field for compatibility
        if (regularBuddies.isNotEmpty) {
          for (final buddyWithRole in regularBuddies) {
            builder.element('buddy', nest: () {
              builder.element('personal', nest: () {
                final nameParts = buddyWithRole.buddy.name.split(' ');
                builder.element('firstname', nest: nameParts.first);
                if (nameParts.length > 1) {
                  builder.element('lastname', nest: nameParts.sublist(1).join(' '));
                }
              },);
            },);
          }
        } else if (dive.buddy != null && dive.buddy!.isNotEmpty) {
          // Fallback to legacy field if no linked buddies
          builder.element('buddy', nest: () {
            builder.element('personal', nest: () {
              builder.element('firstname', nest: dive.buddy);
            },);
          },);
        }
      },);
    },);
  }

  void _buildApplicationData(
    XmlBuilder builder, {
    List<EquipmentItem>? equipment,
    List<Certification>? certifications,
    List<DiveCenter>? diveCenters,
    List<Species>? species,
    List<ServiceRecord>? serviceRecords,
    Map<String, String>? settings,
  }) {
    final hasData = (equipment?.isNotEmpty ?? false) ||
        (certifications?.isNotEmpty ?? false) ||
        (diveCenters?.isNotEmpty ?? false) ||
        (species?.isNotEmpty ?? false) ||
        (serviceRecords?.isNotEmpty ?? false) ||
        (settings?.isNotEmpty ?? false);

    if (!hasData) return;

    builder.element('applicationdata', nest: () {
      builder.element('submersion', attributes: {'version': '1.0'}, nest: () {
        // Equipment
        if (equipment != null && equipment.isNotEmpty) {
          builder.element('equipment', nest: () {
            for (final item in equipment) {
              builder.element('item', attributes: {'id': 'equip_${item.id}'}, nest: () {
                builder.element('name', nest: item.name);
                builder.element('type', nest: item.type.name);
                if (item.brand != null) {
                  builder.element('brand', nest: item.brand);
                }
                if (item.model != null) {
                  builder.element('model', nest: item.model);
                }
                if (item.serialNumber != null) {
                  builder.element('serialnumber', nest: item.serialNumber);
                }
                if (item.size != null) {
                  builder.element('size', nest: item.size);
                }
                builder.element('status', nest: item.status.name);
                if (item.purchaseDate != null) {
                  builder.element('purchasedate', nest: item.purchaseDate!.toIso8601String());
                }
                if (item.purchasePrice != null) {
                  builder.element('purchaseprice', nest: item.purchasePrice.toString());
                  builder.element('purchasecurrency', nest: item.purchaseCurrency);
                }
                if (item.lastServiceDate != null) {
                  builder.element('lastservicedate', nest: item.lastServiceDate!.toIso8601String());
                }
                if (item.serviceIntervalDays != null) {
                  builder.element('serviceintervaldays', nest: item.serviceIntervalDays.toString());
                }
                builder.element('isactive', nest: item.isActive.toString());
                if (item.notes.isNotEmpty) {
                  builder.element('notes', nest: item.notes);
                }
              },);
            }
          },);
        }

        // Certifications
        if (certifications != null && certifications.isNotEmpty) {
          builder.element('certifications', nest: () {
            for (final cert in certifications) {
              builder.element('cert', attributes: {'id': 'cert_${cert.id}'}, nest: () {
                builder.element('name', nest: cert.name);
                builder.element('agency', nest: cert.agency.name);
                if (cert.level != null) {
                  builder.element('level', nest: cert.level!.name);
                }
                if (cert.cardNumber != null) {
                  builder.element('cardnumber', nest: cert.cardNumber);
                }
                if (cert.issueDate != null) {
                  builder.element('issuedate', nest: cert.issueDate!.toIso8601String());
                }
                if (cert.expiryDate != null) {
                  builder.element('expirydate', nest: cert.expiryDate!.toIso8601String());
                }
                if (cert.instructorName != null) {
                  builder.element('instructorname', nest: cert.instructorName);
                }
                if (cert.instructorNumber != null) {
                  builder.element('instructornumber', nest: cert.instructorNumber);
                }
                if (cert.notes.isNotEmpty) {
                  builder.element('notes', nest: cert.notes);
                }
              },);
            }
          },);
        }

        // Dive Centers
        if (diveCenters != null && diveCenters.isNotEmpty) {
          builder.element('divecenters', nest: () {
            for (final center in diveCenters) {
              builder.element('center', attributes: {'id': 'center_${center.id}'}, nest: () {
                builder.element('name', nest: center.name);
                if (center.location != null) {
                  builder.element('location', nest: center.location);
                }
                if (center.latitude != null && center.longitude != null) {
                  builder.element('latitude', nest: center.latitude.toString());
                  builder.element('longitude', nest: center.longitude.toString());
                }
                if (center.country != null) {
                  builder.element('country', nest: center.country);
                }
                if (center.phone != null) {
                  builder.element('phone', nest: center.phone);
                }
                if (center.email != null) {
                  builder.element('email', nest: center.email);
                }
                if (center.website != null) {
                  builder.element('website', nest: center.website);
                }
                if (center.affiliations.isNotEmpty) {
                  builder.element('affiliations', nest: center.affiliations.join(','));
                }
                if (center.rating != null) {
                  builder.element('rating', nest: center.rating.toString());
                }
                if (center.notes.isNotEmpty) {
                  builder.element('notes', nest: center.notes);
                }
              },);
            }
          },);
        }

        // Species
        if (species != null && species.isNotEmpty) {
          builder.element('species', nest: () {
            for (final spec in species) {
              builder.element('spec', attributes: {'id': 'species_${spec.id}'}, nest: () {
                builder.element('commonname', nest: spec.commonName);
                if (spec.scientificName != null) {
                  builder.element('scientificname', nest: spec.scientificName);
                }
                builder.element('category', nest: spec.category.name);
                if (spec.description != null) {
                  builder.element('description', nest: spec.description);
                }
              },);
            }
          },);
        }

        // Service Records
        if (serviceRecords != null && serviceRecords.isNotEmpty) {
          builder.element('servicerecords', nest: () {
            for (final record in serviceRecords) {
              builder.element('record', attributes: {'id': 'service_${record.id}'}, nest: () {
                builder.element('equipmentref', nest: 'equip_${record.equipmentId}');
                builder.element('servicetype', nest: record.serviceType.name);
                builder.element('servicedate', nest: record.serviceDate.toIso8601String());
                if (record.provider != null) {
                  builder.element('provider', nest: record.provider);
                }
                if (record.cost != null) {
                  builder.element('cost', nest: record.cost.toString());
                  builder.element('currency', nest: record.currency);
                }
                if (record.nextServiceDue != null) {
                  builder.element('nextservicedue', nest: record.nextServiceDue!.toIso8601String());
                }
                if (record.notes.isNotEmpty) {
                  builder.element('notes', nest: record.notes);
                }
              },);
            }
          },);
        }

        // Settings
        if (settings != null && settings.isNotEmpty) {
          builder.element('settings', nest: () {
            for (final entry in settings.entries) {
              builder.element('setting', attributes: {'key': entry.key}, nest: entry.value);
            }
          },);
        }
      },);
    },);
  }

  // ==================== UDDF IMPORT ====================

  /// Result class for UDDF import containing both dives and sites
  /// Import dives from UDDF file
  /// Returns a map with 'dives' and 'sites' lists
  Future<Map<String, List<Map<String, dynamic>>>> importDivesFromUddf(String uddfContent) async {
    final document = XmlDocument.parse(uddfContent);
    final uddfElement = document.findElements('uddf').firstOrNull;
    if (uddfElement == null) {
      throw const FormatException('Invalid UDDF file: missing uddf root element');
    }

    // Parse buddies from diver section
    final buddies = <String, Map<String, dynamic>>{};
    final diverElement = uddfElement.findElements('diver').firstOrNull;
    if (diverElement != null) {
      for (final buddyElement in diverElement.findElements('buddy')) {
        final buddyId = buddyElement.getAttribute('id');
        if (buddyId != null) {
          final personalElement = buddyElement.findElements('personal').firstOrNull;
          if (personalElement != null) {
            final firstName = _getElementText(personalElement, 'firstname');
            final lastName = _getElementText(personalElement, 'lastname');
            final buddyName = [firstName, lastName].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim();
            if (buddyName.isNotEmpty) {
              buddies[buddyId] = {'name': buddyName};
            }
          }
        }
      }
    }

    // Parse dive sites
    final sites = <String, Map<String, dynamic>>{};
    final divesiteElement = uddfElement.findElements('divesite').firstOrNull;
    if (divesiteElement != null) {
      for (final siteElement in divesiteElement.findElements('site')) {
        final siteId = siteElement.getAttribute('id');
        if (siteId != null) {
          final siteData = _parseUddfSite(siteElement);
          siteData['uddfId'] = siteId; // Keep track of original ID for linking
          sites[siteId] = siteData;
        }
      }
    }

    // Parse gas definitions
    final gasMixes = <String, GasMix>{};
    final gasDefsElement = uddfElement.findElements('gasdefinitions').firstOrNull;
    if (gasDefsElement != null) {
      for (final mixElement in gasDefsElement.findElements('mix')) {
        final mixId = mixElement.getAttribute('id');
        if (mixId != null) {
          gasMixes[mixId] = _parseUddfGasMix(mixElement);
        }
      }
    }

    // Parse dives from profile data
    final dives = <Map<String, dynamic>>[];
    final profileDataElement = uddfElement.findElements('profiledata').firstOrNull;
    if (profileDataElement != null) {
      for (final repGroup in profileDataElement.findElements('repetitiongroup')) {
        for (final diveElement in repGroup.findElements('dive')) {
          final diveData = _parseUddfDive(diveElement, sites, buddies, gasMixes);
          if (diveData.isNotEmpty) {
            dives.add(diveData);
          }
        }
      }
    }

    // Return both dives and unique sites
    return {
      'dives': dives,
      'sites': sites.values.toList(),
    };
  }

  Map<String, dynamic> _parseUddfSite(XmlElement siteElement) {
    final site = <String, dynamic>{};

    site['name'] = _getElementText(siteElement, 'name');

    final geoElement = siteElement.findElements('geography').firstOrNull;
    if (geoElement != null) {
      final lat = _getElementText(geoElement, 'latitude');
      final lon = _getElementText(geoElement, 'longitude');
      if (lat != null && lon != null) {
        site['latitude'] = double.tryParse(lat);
        site['longitude'] = double.tryParse(lon);
      }
    }

    site['country'] = _getElementText(siteElement, 'country');
    site['region'] = _getElementText(siteElement, 'state');
    final maxDepth = _getElementText(siteElement, 'maximumdepth');
    if (maxDepth != null) {
      site['maxDepth'] = double.tryParse(maxDepth);
    }
    site['description'] = _getElementText(siteElement, 'notes');

    return site;
  }

  GasMix _parseUddfGasMix(XmlElement mixElement) {
    final o2Text = _getElementText(mixElement, 'o2');
    final heText = _getElementText(mixElement, 'he');

    // UDDF stores as fractions (0.21 for 21%)
    final o2 = o2Text != null ? (double.tryParse(o2Text) ?? 0.21) * 100 : 21.0;
    final he = heText != null ? (double.tryParse(heText) ?? 0.0) * 100 : 0.0;

    return GasMix(o2: o2, he: he);
  }

  Map<String, dynamic> _parseUddfDive(
    XmlElement diveElement,
    Map<String, Map<String, dynamic>> sites,
    Map<String, Map<String, dynamic>> buddies,
    Map<String, GasMix> gasMixes,
  ) {
    final diveData = <String, dynamic>{};
    final buddyNames = <String>[];

    // Parse information before dive
    final beforeElement = diveElement.findElements('informationbeforedive').firstOrNull;
    if (beforeElement != null) {
      final dateTimeText = _getElementText(beforeElement, 'datetime');
      if (dateTimeText != null) {
        diveData['dateTime'] = DateTime.tryParse(dateTimeText);
      }

      final diveNumText = _getElementText(beforeElement, 'divenumber');
      if (diveNumText != null) {
        diveData['diveNumber'] = int.tryParse(diveNumText);
      }

      final airTempText = _getElementText(beforeElement, 'airtemperature');
      if (airTempText != null) {
        // UDDF stores temps in Kelvin
        final kelvin = double.tryParse(airTempText);
        if (kelvin != null) {
          diveData['airTemp'] = kelvin - 273.15;
        }
      }

      // Parse equipment used (e.g., lead weight)
      final equipmentElement = beforeElement.findElements('equipmentused').firstOrNull;
      if (equipmentElement != null) {
        final leadText = _getElementText(equipmentElement, 'leadquantity');
        if (leadText != null) {
          final leadKg = double.tryParse(leadText);
          if (leadKg != null) {
            diveData['weightUsed'] = leadKg;
          }
        }
      }

      // Get all linked references (can be sites or buddies)
      for (final linkElement in beforeElement.findElements('link')) {
        final ref = linkElement.getAttribute('ref');
        if (ref != null) {
          // Check if it's a site reference
          if (sites.containsKey(ref)) {
            diveData['site'] = sites[ref];
          }
          // Check if it's a buddy reference
          else if (buddies.containsKey(ref)) {
            final buddyName = buddies[ref]?['name'] as String?;
            if (buddyName != null && buddyName.isNotEmpty) {
              buddyNames.add(buddyName);
            }
          }
        }
      }
    }

    // Parse tank data
    final tanks = <Map<String, dynamic>>[];
    for (final tankDataElement in diveElement.findElements('tankdata')) {
      final tankInfo = <String, dynamic>{};

      // Get tank volume (in liters)
      final volumeText = _getElementText(tankDataElement, 'tankvolume');
      if (volumeText != null) {
        tankInfo['volume'] = double.tryParse(volumeText);
      }

      // Get linked gas mix
      final mixLink = tankDataElement.findElements('link').firstOrNull;
      if (mixLink != null) {
        final mixRef = mixLink.getAttribute('ref');
        if (mixRef != null && gasMixes.containsKey(mixRef)) {
          tankInfo['gasMix'] = gasMixes[mixRef];
        }
      }

      // Get start/end pressure if available
      final startPressureText = _getElementText(tankDataElement, 'tankpressurebegin');
      if (startPressureText != null) {
        // UDDF stores in Pascal, convert to bar
        final pascal = double.tryParse(startPressureText);
        if (pascal != null) {
          tankInfo['startPressure'] = (pascal / 100000).round();
        }
      }

      final endPressureText = _getElementText(tankDataElement, 'tankpressureend');
      if (endPressureText != null) {
        final pascal = double.tryParse(endPressureText);
        if (pascal != null) {
          tankInfo['endPressure'] = (pascal / 100000).round();
        }
      }

      // Only add tank if it has meaningful data
      if (tankInfo['volume'] != null || tankInfo['gasMix'] != null) {
        tanks.add(tankInfo);
      }
    }

    if (tanks.isNotEmpty) {
      diveData['tanks'] = tanks;
    }

    // Parse samples (dive profile)
    final samplesElement = diveElement.findElements('samples').firstOrNull;
    if (samplesElement != null) {
      final profile = <Map<String, dynamic>>[];
      GasMix? currentMix;

      for (final waypoint in samplesElement.findElements('waypoint')) {
        final point = <String, dynamic>{};

        final timeText = _getElementText(waypoint, 'divetime');
        if (timeText != null) {
          point['timestamp'] = int.tryParse(timeText) ?? 0;
        }

        final depthText = _getElementText(waypoint, 'depth');
        if (depthText != null) {
          point['depth'] = double.tryParse(depthText) ?? 0.0;
        }

        final tempText = _getElementText(waypoint, 'temperature');
        if (tempText != null) {
          final kelvin = double.tryParse(tempText);
          if (kelvin != null) {
            point['temperature'] = kelvin - 273.15;
          }
        }

        final pressureText = _getElementText(waypoint, 'tankpressure');
        if (pressureText != null) {
          // UDDF stores pressure in Pascal, convert to bar
          final pascal = double.tryParse(pressureText);
          if (pascal != null) {
            point['pressure'] = pascal / 100000;
          }
        }

        // Check for gas switch
        final switchMix = waypoint.findElements('switchmix').firstOrNull;
        if (switchMix != null) {
          final mixRef = switchMix.getAttribute('ref');
          if (mixRef != null && gasMixes.containsKey(mixRef)) {
            currentMix = gasMixes[mixRef];
          }
        }

        if (point.containsKey('timestamp') && point.containsKey('depth')) {
          profile.add(point);
        }
      }

      if (profile.isNotEmpty) {
        diveData['profile'] = profile;
      }
      // Use gas mix from samples if no tank data was found
      if (currentMix != null && !diveData.containsKey('tanks')) {
        diveData['gasMix'] = currentMix;
      }
    }

    // Parse information after dive
    final afterElement = diveElement.findElements('informationafterdive').firstOrNull;
    if (afterElement != null) {
      final maxDepthText = _getElementText(afterElement, 'greatestdepth');
      if (maxDepthText != null) {
        diveData['maxDepth'] = double.tryParse(maxDepthText);
      }

      final avgDepthText = _getElementText(afterElement, 'averagedepth');
      if (avgDepthText != null) {
        diveData['avgDepth'] = double.tryParse(avgDepthText);
      }

      // UDDF diveduration is total dive time (runtime), not bottom time
      final durationText = _getElementText(afterElement, 'diveduration');
      if (durationText != null) {
        final seconds = int.tryParse(durationText);
        if (seconds != null) {
          diveData['runtime'] = Duration(seconds: seconds);
        }
      }

      final waterTempText = _getElementText(afterElement, 'lowesttemperature');
      if (waterTempText != null) {
        final kelvin = double.tryParse(waterTempText);
        if (kelvin != null) {
          diveData['waterTemp'] = kelvin - 273.15;
        }
      }

      final visibilityText = _getElementText(afterElement, 'visibility');
      if (visibilityText != null) {
        diveData['visibility'] = _parseUddfVisibility(visibilityText);
      }

      // Parse rating
      final ratingElement = afterElement.findElements('rating').firstOrNull;
      if (ratingElement != null) {
        final ratingValue = _getElementText(ratingElement, 'ratingvalue');
        if (ratingValue != null) {
          diveData['rating'] = int.tryParse(ratingValue);
        }
      }

      // Parse notes
      final notesElement = afterElement.findElements('notes').firstOrNull;
      if (notesElement != null) {
        final para = _getElementText(notesElement, 'para');
        if (para != null) {
          diveData['notes'] = para;
        }
      }

      // Parse buddy from informationafterdive (backup if not found in links)
      if (buddyNames.isEmpty) {
        final buddyElement = afterElement.findElements('buddy').firstOrNull;
        if (buddyElement != null) {
          final personalElement = buddyElement.findElements('personal').firstOrNull;
          if (personalElement != null) {
            final firstName = _getElementText(personalElement, 'firstname');
            final lastName = _getElementText(personalElement, 'lastname');
            final buddyName = [firstName, lastName].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim();
            if (buddyName.isNotEmpty) {
              buddyNames.add(buddyName);
            }
          }
        }
      }
    }

    // Set buddy names (join multiple buddies with comma)
    if (buddyNames.isNotEmpty) {
      diveData['buddy'] = buddyNames.join(', ');
    }

    return diveData;
  }

  enums.Visibility _parseUddfVisibility(String value) {
    final meters = double.tryParse(value) ?? 0;
    if (meters >= 30) {
      return enums.Visibility.excellent;
    } else if (meters >= 15) {
      return enums.Visibility.good;
    } else if (meters >= 5) {
      return enums.Visibility.moderate;
    } else if (meters > 0) {
      return enums.Visibility.poor;
    }
    return enums.Visibility.unknown;
  }

  String? _getElementText(XmlElement parent, String elementName) {
    final element = parent.findElements(elementName).firstOrNull;
    return element?.innerText.trim().isEmpty == true ? null : element?.innerText.trim();
  }

  // ==================== COMPREHENSIVE UDDF IMPORT ====================

  /// Import ALL application data from UDDF file
  /// Returns UddfImportResult with all parsed data
  Future<UddfImportResult> importAllDataFromUddf(String uddfContent) async {
    final document = XmlDocument.parse(uddfContent);
    final uddfElement = document.findElements('uddf').firstOrNull;
    if (uddfElement == null) {
      throw const FormatException('Invalid UDDF file: missing uddf root element');
    }

    // Parse full buddy records from diver section
    final buddies = <Map<String, dynamic>>[];
    final buddyMap = <String, Map<String, dynamic>>{};
    final diverElement = uddfElement.findElements('diver').firstOrNull;
    if (diverElement != null) {
      for (final buddyElement in diverElement.findElements('buddy')) {
        final buddyData = _parseFullBuddy(buddyElement);
        if (buddyData.isNotEmpty) {
          final buddyId = buddyElement.getAttribute('id');
          if (buddyId != null) {
            buddyMap[buddyId] = buddyData;
          }
          buddies.add(buddyData);
        }
      }
    }

    // Parse dive sites with extended fields
    final sites = <Map<String, dynamic>>[];
    final siteMap = <String, Map<String, dynamic>>{};
    final divesiteElement = uddfElement.findElements('divesite').firstOrNull;
    if (divesiteElement != null) {
      for (final siteElement in divesiteElement.findElements('site')) {
        final siteData = _parseFullSite(siteElement);
        final siteId = siteElement.getAttribute('id');
        if (siteId != null) {
          siteData['uddfId'] = siteId;
          siteMap[siteId] = siteData;
        }
        sites.add(siteData);
      }
    }

    // Parse gas definitions
    final gasMixes = <String, GasMix>{};
    final gasDefsElement = uddfElement.findElements('gasdefinitions').firstOrNull;
    if (gasDefsElement != null) {
      for (final mixElement in gasDefsElement.findElements('mix')) {
        final mixId = mixElement.getAttribute('id');
        if (mixId != null) {
          gasMixes[mixId] = _parseUddfGasMix(mixElement);
        }
      }
    }

    // Parse dives with extended fields
    final dives = <Map<String, dynamic>>[];
    final sightings = <Map<String, dynamic>>[];
    final profileDataElement = uddfElement.findElements('profiledata').firstOrNull;
    if (profileDataElement != null) {
      for (final repGroup in profileDataElement.findElements('repetitiongroup')) {
        for (final diveElement in repGroup.findElements('dive')) {
          final diveData = _parseFullDive(diveElement, siteMap, buddyMap, gasMixes);
          if (diveData.isNotEmpty) {
            dives.add(diveData);
            // Extract sightings from dive
            if (diveData.containsKey('sightings')) {
              final diveSightings = diveData['sightings'] as List<Map<String, dynamic>>?;
              if (diveSightings != null) {
                for (final sighting in diveSightings) {
                  sighting['diveId'] = diveData['id'] ?? diveElement.getAttribute('id');
                  sightings.add(sighting);
                }
              }
            }
          }
        }
      }
    }

    // Parse applicationdata section
    final equipment = <Map<String, dynamic>>[];
    final certifications = <Map<String, dynamic>>[];
    final diveCenters = <Map<String, dynamic>>[];
    final species = <Map<String, dynamic>>[];
    final serviceRecords = <Map<String, dynamic>>[];
    final settings = <String, String>{};

    final appDataElement = uddfElement.findElements('applicationdata').firstOrNull;
    if (appDataElement != null) {
      final submersionElement = appDataElement.findElements('submersion').firstOrNull;
      if (submersionElement != null) {
        // Parse equipment
        final equipmentSection = submersionElement.findElements('equipment').firstOrNull;
        if (equipmentSection != null) {
          for (final itemElement in equipmentSection.findElements('item')) {
            final itemData = _parseEquipmentItem(itemElement);
            if (itemData.isNotEmpty) {
              equipment.add(itemData);
            }
          }
        }

        // Parse certifications
        final certsSection = submersionElement.findElements('certifications').firstOrNull;
        if (certsSection != null) {
          for (final certElement in certsSection.findElements('cert')) {
            final certData = _parseCertification(certElement);
            if (certData.isNotEmpty) {
              certifications.add(certData);
            }
          }
        }

        // Parse dive centers
        final centersSection = submersionElement.findElements('divecenters').firstOrNull;
        if (centersSection != null) {
          for (final centerElement in centersSection.findElements('center')) {
            final centerData = _parseDiveCenter(centerElement);
            if (centerData.isNotEmpty) {
              diveCenters.add(centerData);
            }
          }
        }

        // Parse species
        final speciesSection = submersionElement.findElements('species').firstOrNull;
        if (speciesSection != null) {
          for (final specElement in speciesSection.findElements('spec')) {
            final specData = _parseSpecies(specElement);
            if (specData.isNotEmpty) {
              species.add(specData);
            }
          }
        }

        // Parse service records
        final serviceSection = submersionElement.findElements('servicerecords').firstOrNull;
        if (serviceSection != null) {
          for (final recordElement in serviceSection.findElements('record')) {
            final recordData = _parseServiceRecord(recordElement);
            if (recordData.isNotEmpty) {
              serviceRecords.add(recordData);
            }
          }
        }

        // Parse settings
        final settingsSection = submersionElement.findElements('settings').firstOrNull;
        if (settingsSection != null) {
          for (final settingElement in settingsSection.findElements('setting')) {
            final key = settingElement.getAttribute('key');
            final value = settingElement.innerText.trim();
            if (key != null && value.isNotEmpty) {
              settings[key] = value;
            }
          }
        }
      }
    }

    return UddfImportResult(
      dives: dives,
      sites: sites,
      equipment: equipment,
      buddies: buddies,
      certifications: certifications,
      diveCenters: diveCenters,
      species: species,
      sightings: sightings,
      serviceRecords: serviceRecords,
      settings: settings,
    );
  }

  Map<String, dynamic> _parseFullBuddy(XmlElement buddyElement) {
    final buddy = <String, dynamic>{};
    final buddyId = buddyElement.getAttribute('id');
    if (buddyId != null) {
      buddy['uddfId'] = buddyId;
    }

    final personalElement = buddyElement.findElements('personal').firstOrNull;
    if (personalElement != null) {
      final firstName = _getElementText(personalElement, 'firstname');
      final lastName = _getElementText(personalElement, 'lastname');
      final name = [firstName, lastName].whereType<String>().where((s) => s.isNotEmpty).join(' ').trim();
      if (name.isNotEmpty) {
        buddy['name'] = name;
      }
      buddy['email'] = _getElementText(personalElement, 'email');
      buddy['phone'] = _getElementText(personalElement, 'phone');
    }

    final certElement = buddyElement.findElements('certification').firstOrNull;
    if (certElement != null) {
      final level = _getElementText(certElement, 'level');
      if (level != null) {
        buddy['certificationLevel'] = _parseEnumValue(level, enums.CertificationLevel.values);
      }
      final agency = _getElementText(certElement, 'agency');
      if (agency != null) {
        buddy['certificationAgency'] = _parseEnumValue(agency, enums.CertificationAgency.values);
      }
    }

    buddy['notes'] = _getElementText(buddyElement, 'notes') ?? '';

    return buddy;
  }

  Map<String, dynamic> _parseFullSite(XmlElement siteElement) {
    final site = _parseUddfSite(siteElement);

    // Parse additional fields
    final rating = _getElementText(siteElement, 'siterating');
    if (rating != null) {
      site['rating'] = double.tryParse(rating);
    }

    final additionalNotes = _getElementText(siteElement, 'sitenotesadditional');
    if (additionalNotes != null) {
      site['notes'] = additionalNotes;
    }

    return site;
  }

  Map<String, dynamic> _parseFullDive(
    XmlElement diveElement,
    Map<String, Map<String, dynamic>> sites,
    Map<String, Map<String, dynamic>> buddies,
    Map<String, GasMix> gasMixes,
  ) {
    // Start with existing parse
    final diveData = _parseUddfDive(diveElement, sites, buddies, gasMixes);

    // Parse additional fields from informationbeforedive
    final beforeElement = diveElement.findElements('informationbeforedive').firstOrNull;
    if (beforeElement != null) {
      diveData['diveMaster'] = _getElementText(beforeElement, 'divemaster');

      final diveType = _getElementText(beforeElement, 'divetype');
      if (diveType != null) {
        diveData['diveType'] = _parseDiveType(diveType);
      }

      final entryType = _getElementText(beforeElement, 'entrytype');
      if (entryType != null) {
        diveData['entryMethod'] = _parseEnumValue(entryType, enums.EntryMethod.values);
      }
    }

    // Parse additional fields from informationafterdive
    final afterElement = diveElement.findElements('informationafterdive').firstOrNull;
    if (afterElement != null) {
      final waterType = _getElementText(afterElement, 'watertype');
      if (waterType != null) {
        diveData['waterType'] = _parseEnumValue(waterType, enums.WaterType.values);
      }

      final currentDir = _getElementText(afterElement, 'currentdirection');
      if (currentDir != null) {
        diveData['currentDirection'] = _parseEnumValue(currentDir, enums.CurrentDirection.values);
      }

      final currentStrength = _getElementText(afterElement, 'currentstrength');
      if (currentStrength != null) {
        diveData['currentStrength'] = _parseEnumValue(currentStrength, enums.CurrentStrength.values);
      }

      final swellHeight = _getElementText(afterElement, 'swellheight');
      if (swellHeight != null) {
        diveData['swellHeight'] = double.tryParse(swellHeight);
      }

      final exitType = _getElementText(afterElement, 'exittype');
      if (exitType != null) {
        diveData['exitMethod'] = _parseEnumValue(exitType, enums.EntryMethod.values);
      }

      // Parse weight used
      final weightElement = afterElement.findElements('weightused').firstOrNull;
      if (weightElement != null) {
        final amount = _getElementText(weightElement, 'amount');
        if (amount != null) {
          diveData['weightAmount'] = double.tryParse(amount);
        }
        final weightType = _getElementText(weightElement, 'type');
        if (weightType != null) {
          diveData['weightType'] = _parseEnumValue(weightType, enums.WeightType.values);
        }
      }

      // Parse sightings
      final sightingsElement = afterElement.findElements('sightings').firstOrNull;
      if (sightingsElement != null) {
        final sightingsList = <Map<String, dynamic>>[];
        for (final sightingElement in sightingsElement.findElements('sighting')) {
          final sighting = <String, dynamic>{};
          sighting['speciesRef'] = sightingElement.getAttribute('speciesref');
          final countStr = sightingElement.getAttribute('count');
          sighting['count'] = countStr != null ? int.tryParse(countStr) ?? 1 : 1;
          sighting['notes'] = _getElementText(sightingElement, 'notes') ?? '';
          sightingsList.add(sighting);
        }
        if (sightingsList.isNotEmpty) {
          diveData['sightings'] = sightingsList;
        }
      }
    }

    return diveData;
  }

  Map<String, dynamic> _parseEquipmentItem(XmlElement itemElement) {
    final item = <String, dynamic>{};
    final itemId = itemElement.getAttribute('id');
    if (itemId != null) {
      item['uddfId'] = itemId;
    }

    item['name'] = _getElementText(itemElement, 'name');

    final typeStr = _getElementText(itemElement, 'type');
    if (typeStr != null) {
      item['type'] = _parseEnumValue(typeStr, enums.EquipmentType.values);
    }

    item['brand'] = _getElementText(itemElement, 'brand');
    item['model'] = _getElementText(itemElement, 'model');
    item['serialNumber'] = _getElementText(itemElement, 'serialnumber');
    item['size'] = _getElementText(itemElement, 'size');

    final statusStr = _getElementText(itemElement, 'status');
    if (statusStr != null) {
      item['status'] = _parseEnumValue(statusStr, enums.EquipmentStatus.values);
    }

    final purchaseDate = _getElementText(itemElement, 'purchasedate');
    if (purchaseDate != null) {
      item['purchaseDate'] = DateTime.tryParse(purchaseDate);
    }

    final purchasePrice = _getElementText(itemElement, 'purchaseprice');
    if (purchasePrice != null) {
      item['purchasePrice'] = double.tryParse(purchasePrice);
    }

    item['purchaseCurrency'] = _getElementText(itemElement, 'purchasecurrency') ?? 'USD';

    final lastServiceDate = _getElementText(itemElement, 'lastservicedate');
    if (lastServiceDate != null) {
      item['lastServiceDate'] = DateTime.tryParse(lastServiceDate);
    }

    final serviceInterval = _getElementText(itemElement, 'serviceintervaldays');
    if (serviceInterval != null) {
      item['serviceIntervalDays'] = int.tryParse(serviceInterval);
    }

    final isActive = _getElementText(itemElement, 'isactive');
    item['isActive'] = isActive?.toLowerCase() != 'false';

    item['notes'] = _getElementText(itemElement, 'notes') ?? '';

    return item;
  }

  Map<String, dynamic> _parseCertification(XmlElement certElement) {
    final cert = <String, dynamic>{};
    final certId = certElement.getAttribute('id');
    if (certId != null) {
      cert['uddfId'] = certId;
    }

    cert['name'] = _getElementText(certElement, 'name');

    final agencyStr = _getElementText(certElement, 'agency');
    if (agencyStr != null) {
      cert['agency'] = _parseEnumValue(agencyStr, enums.CertificationAgency.values);
    }

    final levelStr = _getElementText(certElement, 'level');
    if (levelStr != null) {
      cert['level'] = _parseEnumValue(levelStr, enums.CertificationLevel.values);
    }

    cert['cardNumber'] = _getElementText(certElement, 'cardnumber');

    final issueDate = _getElementText(certElement, 'issuedate');
    if (issueDate != null) {
      cert['issueDate'] = DateTime.tryParse(issueDate);
    }

    final expiryDate = _getElementText(certElement, 'expirydate');
    if (expiryDate != null) {
      cert['expiryDate'] = DateTime.tryParse(expiryDate);
    }

    cert['instructorName'] = _getElementText(certElement, 'instructorname');
    cert['instructorNumber'] = _getElementText(certElement, 'instructornumber');
    cert['notes'] = _getElementText(certElement, 'notes') ?? '';

    return cert;
  }

  Map<String, dynamic> _parseDiveCenter(XmlElement centerElement) {
    final center = <String, dynamic>{};
    final centerId = centerElement.getAttribute('id');
    if (centerId != null) {
      center['uddfId'] = centerId;
    }

    center['name'] = _getElementText(centerElement, 'name');
    center['location'] = _getElementText(centerElement, 'location');

    final lat = _getElementText(centerElement, 'latitude');
    final lon = _getElementText(centerElement, 'longitude');
    if (lat != null) {
      center['latitude'] = double.tryParse(lat);
    }
    if (lon != null) {
      center['longitude'] = double.tryParse(lon);
    }

    center['country'] = _getElementText(centerElement, 'country');
    center['phone'] = _getElementText(centerElement, 'phone');
    center['email'] = _getElementText(centerElement, 'email');
    center['website'] = _getElementText(centerElement, 'website');

    final affiliations = _getElementText(centerElement, 'affiliations');
    if (affiliations != null && affiliations.isNotEmpty) {
      center['affiliations'] = affiliations.split(',').map((s) => s.trim()).toList();
    }

    final rating = _getElementText(centerElement, 'rating');
    if (rating != null) {
      center['rating'] = double.tryParse(rating);
    }

    center['notes'] = _getElementText(centerElement, 'notes') ?? '';

    return center;
  }

  Map<String, dynamic> _parseSpecies(XmlElement specElement) {
    final spec = <String, dynamic>{};
    final specId = specElement.getAttribute('id');
    if (specId != null) {
      spec['uddfId'] = specId;
    }

    spec['commonName'] = _getElementText(specElement, 'commonname');
    spec['scientificName'] = _getElementText(specElement, 'scientificname');

    final categoryStr = _getElementText(specElement, 'category');
    if (categoryStr != null) {
      spec['category'] = _parseEnumValue(categoryStr, enums.SpeciesCategory.values);
    }

    spec['description'] = _getElementText(specElement, 'description');

    return spec;
  }

  Map<String, dynamic> _parseServiceRecord(XmlElement recordElement) {
    final record = <String, dynamic>{};
    final recordId = recordElement.getAttribute('id');
    if (recordId != null) {
      record['uddfId'] = recordId;
    }

    record['equipmentRef'] = _getElementText(recordElement, 'equipmentref');

    final serviceType = _getElementText(recordElement, 'servicetype');
    if (serviceType != null) {
      record['serviceType'] = _parseEnumValue(serviceType, enums.ServiceType.values);
    }

    final serviceDate = _getElementText(recordElement, 'servicedate');
    if (serviceDate != null) {
      record['serviceDate'] = DateTime.tryParse(serviceDate);
    }

    record['provider'] = _getElementText(recordElement, 'provider');

    final cost = _getElementText(recordElement, 'cost');
    if (cost != null) {
      record['cost'] = double.tryParse(cost);
    }

    record['currency'] = _getElementText(recordElement, 'currency') ?? 'USD';

    final nextDue = _getElementText(recordElement, 'nextservicedue');
    if (nextDue != null) {
      record['nextServiceDue'] = DateTime.tryParse(nextDue);
    }

    record['notes'] = _getElementText(recordElement, 'notes') ?? '';

    return record;
  }

  T? _parseEnumValue<T extends Enum>(String value, List<T> values) {
    final lowerValue = value.toLowerCase();
    for (final v in values) {
      if (v.name.toLowerCase() == lowerValue) {
        return v;
      }
    }
    return null;
  }

  // ==================== CSV IMPORT ====================

  /// Import dives from CSV file
  /// Returns a list of imported Dive objects (without IDs - caller must assign)
  Future<List<Map<String, dynamic>>> importDivesFromCsv(String csvContent) async {
    final rows = const CsvToListConverter().convert(csvContent);
    if (rows.isEmpty) {
      throw const FormatException('CSV file is empty');
    }

    final headers = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
    final dataRows = rows.skip(1);

    final dives = <Map<String, dynamic>>[];

    for (final row in dataRows) {
      if (row.isEmpty || row.every((cell) => cell == null || cell.toString().isEmpty)) {
        continue; // Skip empty rows
      }

      final diveData = <String, dynamic>{};

      // Map CSV columns to dive fields
      for (var i = 0; i < headers.length && i < row.length; i++) {
        final header = headers[i];
        final value = row[i]?.toString().trim() ?? '';

        if (value.isEmpty) continue;

        // Parse based on header name
        if (header.contains('dive') && header.contains('number')) {
          diveData['diveNumber'] = int.tryParse(value);
        } else if (header == 'date' || header.contains('date') && !header.contains('time')) {
          diveData['date'] = _parseDate(value);
        } else if (header == 'time' || header.contains('time') && !header.contains('date')) {
          diveData['time'] = _parseTime(value);
        } else if (header.contains('max') && header.contains('depth')) {
          diveData['maxDepth'] = _parseDouble(value);
        } else if (header.contains('avg') && header.contains('depth')) {
          diveData['avgDepth'] = _parseDouble(value);
        } else if (header.contains('bottom') && header.contains('time')) {
          diveData['duration'] = _parseDuration(value);
        } else if (header.contains('runtime')) {
          diveData['runtime'] = _parseDuration(value);
        } else if (header.contains('duration') || header.contains('time') && header.contains('min')) {
          diveData['duration'] = _parseDuration(value);
        } else if (header.contains('water') && header.contains('temp')) {
          diveData['waterTemp'] = _parseDouble(value);
        } else if (header.contains('air') && header.contains('temp')) {
          diveData['airTemp'] = _parseDouble(value);
        } else if (header.contains('site') || header.contains('location')) {
          diveData['siteName'] = value;
        } else if (header.contains('buddy')) {
          diveData['buddy'] = value;
        } else if (header.contains('dive') && header.contains('master')) {
          diveData['diveMaster'] = value;
        } else if (header.contains('rating')) {
          diveData['rating'] = int.tryParse(value);
        } else if (header.contains('note')) {
          diveData['notes'] = value;
        } else if (header.contains('visibility')) {
          diveData['visibility'] = _parseVisibility(value);
        } else if (header.contains('type')) {
          diveData['diveType'] = _parseDiveType(value);
        } else if (header.contains('start') && header.contains('pressure')) {
          diveData['startPressure'] = int.tryParse(value);
        } else if (header.contains('end') && header.contains('pressure')) {
          diveData['endPressure'] = int.tryParse(value);
        } else if (header.contains('tank') && header.contains('volume')) {
          diveData['tankVolume'] = _parseDouble(value);
        } else if (header.contains('o2') || header.contains('oxygen')) {
          diveData['o2Percent'] = _parseDouble(value);
        }
      }

      // Combine date and time if both present
      if (diveData['date'] != null) {
        DateTime dateTime = diveData['date'] as DateTime;
        if (diveData['time'] != null) {
          final time = diveData['time'] as DateTime;
          dateTime = DateTime(
            dateTime.year,
            dateTime.month,
            dateTime.day,
            time.hour,
            time.minute,
          );
        }
        diveData['dateTime'] = dateTime;
        diveData.remove('date');
        diveData.remove('time');
      }

      if (diveData.isNotEmpty) {
        dives.add(diveData);
      }
    }

    return dives;
  }

  DateTime? _parseDate(String value) {
    // Try common date formats
    final formats = [
      'yyyy-MM-dd',
      'MM/dd/yyyy',
      'dd/MM/yyyy',
      'yyyy/MM/dd',
      'dd-MM-yyyy',
      'MM-dd-yyyy',
    ];

    for (final format in formats) {
      try {
        return DateFormat(format).parse(value);
      } catch (_) {
        continue;
      }
    }

    return DateTime.tryParse(value);
  }

  DateTime? _parseTime(String value) {
    final formats = ['HH:mm', 'H:mm', 'hh:mm a', 'h:mm a'];

    for (final format in formats) {
      try {
        return DateFormat(format).parse(value);
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  double? _parseDouble(String value) {
    // Remove units like 'm', 'ft', '°C', '°F', 'bar', 'psi'
    final cleanValue = value.replaceAll(RegExp(r'[^\d.-]'), '');
    return double.tryParse(cleanValue);
  }

  Duration? _parseDuration(String value) {
    // Try to parse as minutes
    final minutes = int.tryParse(value.replaceAll(RegExp(r'[^\d]'), ''));
    if (minutes != null) {
      return Duration(minutes: minutes);
    }

    // Try to parse as HH:mm
    final parts = value.split(':');
    if (parts.length == 2) {
      final hours = int.tryParse(parts[0]);
      final mins = int.tryParse(parts[1]);
      if (hours != null && mins != null) {
        return Duration(hours: hours, minutes: mins);
      }
    }

    return null;
  }

  enums.Visibility? _parseVisibility(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('excellent') || lower.contains('>30') || lower.contains('>100')) {
      return enums.Visibility.excellent;
    } else if (lower.contains('good') || lower.contains('15-30') || lower.contains('50-100')) {
      return enums.Visibility.good;
    } else if (lower.contains('moderate') || lower.contains('fair') || lower.contains('5-15') || lower.contains('15-50')) {
      return enums.Visibility.moderate;
    } else if (lower.contains('poor') || lower.contains('<5') || lower.contains('<15')) {
      return enums.Visibility.poor;
    }
    return enums.Visibility.unknown;
  }

  String _parseDiveType(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('training') || lower.contains('course')) {
      return 'training';
    } else if (lower.contains('night')) {
      return 'night';
    } else if (lower.contains('deep')) {
      return 'deep';
    } else if (lower.contains('wreck')) {
      return 'wreck';
    } else if (lower.contains('drift')) {
      return 'drift';
    } else if (lower.contains('cave') || lower.contains('cavern')) {
      return 'cave';
    } else if (lower.contains('tech')) {
      return 'technical';
    } else if (lower.contains('free')) {
      return 'freedive';
    } else if (lower.contains('ice')) {
      return 'ice';
    } else if (lower.contains('altitude')) {
      return 'altitude';
    } else if (lower.contains('shore')) {
      return 'shore';
    } else if (lower.contains('boat')) {
      return 'boat';
    } else if (lower.contains('liveaboard')) {
      return 'liveaboard';
    }
    return 'recreational';
  }

  // ==================== FILE UTILITIES ====================

  Future<String> _saveAndShareFile(String content, String fileName, String mimeType) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(content);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType)],
      subject: fileName,
    );

    return file.path;
  }

  Future<String> _saveAndShareFileBytes(List<int> bytes, String fileName, String mimeType) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: mimeType)],
      subject: fileName,
    );

    return file.path;
  }

  /// Get temporary file path for export
  Future<String> getExportFilePath(String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/$fileName';
  }
}
