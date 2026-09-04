import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_profile_series.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_factory.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

/// Handles PDF export for dive logbooks and trip reports.
class PdfExportService {
  /// File names stay ISO no matter what the diver reads in the document, so a
  /// folder of exports still sorts chronologically (#964).
  static final _fileNameDate = DateFormat('yyyy-MM-dd');

  // ==================== Trip PDF ====================

  /// Export trip with dives to PDF.
  Future<String> exportTripToPdf(
    Trip trip,
    List<Dive> dives, {
    required PdfDateFormatter dates,
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
                style: const pw.TextStyle(
                  fontSize: 36,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                '${dates.date(trip.startDate)} - ${dates.date(trip.endDate)}',
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
                style: const pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (stats != null) ...[
                pw.SizedBox(height: 10),
                pw.Text(
                  'Total Runtime: ${stats.formattedRuntime}',
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
                style: const pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Date: ${dates.dateTime(dive.dateTime)}'),
              if (dive.site != null) pw.Text('Site: ${dive.site!.name}'),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (dive.maxDepth != null)
                    pw.Text(
                      'Max Depth: ${dive.maxDepth!.toStringAsFixed(1)} m',
                    ),
                  if (dive.effectiveRuntime != null)
                    pw.Text(
                      'Duration: ${dive.effectiveRuntime!.inMinutes} min',
                    ),
                ],
              ),
              if (dive.waterTemp != null)
                pw.Text(
                  'Water Temp: ${dive.waterTemp!.toStringAsFixed(1)}\u00B0C',
                ),
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
    return saveAndShareFileBytes(bytes, fileName, 'application/pdf');
  }

  // ==================== Dive Logbook PDF ====================

  /// Generate PDF dive logbook bytes without sharing.
  ///
  /// Routes through [PdfTemplateFactory] like the Transfer page export does,
  /// so the dive-list bulk export and the single-dive export produce the same
  /// document the diver picked. This replaced a duplicated copy of the old
  /// layout that hardcoded A4 and shipped without a Unicode font theme.
  Future<({List<int> bytes, String fileName})> generateDivePdfBytes(
    List<Dive> dives, {
    required PdfDateFormatter dates,
    required UnitFormatter units,
    PdfExportOptions options = const PdfExportOptions(),
    String title = 'Dive Logbook',
    Map<String, PdfProfileSeries>? profiles,
    List<Certification>? certifications,
    Diver? diver,
    Uint8List? diverPhoto,
  }) async {
    final signatureService = SignatureStorageService();
    final diveSignatures = <String, List<Signature>>{};

    for (final dive in dives) {
      final sigs = await signatureService.getAllSignaturesForDive(dive.id);
      if (sigs.isNotEmpty) {
        diveSignatures[dive.id] = sigs;
      }
    }

    // The legacy builder never did this, so accented site names were dropped.
    await PdfFonts.instance.initialize();

    final builder = PdfTemplateFactory().getBuilder(options.template);
    final pdfBytes = await builder.buildPdf(
      dives: dives,
      pageSize: options.pageSize,
      dates: dates,
      units: units,
      title: title,
      diveSignatures: diveSignatures.isNotEmpty ? diveSignatures : null,
      profiles: profiles,
      // Only honored when the diver asked for the cards, matching the
      // settings export path.
      certifications: options.includeCertificationCards ? certifications : null,
      diver: diver,
      diverPhoto: diverPhoto,
      includeVerificationAreas: options.includeVerificationAreas,
    );

    final fileName =
        'dive_logbook_${options.template.name}_'
        '${_fileNameDate.format(DateTime.now())}.pdf';
    return (bytes: pdfBytes, fileName: fileName);
  }

  /// Generate PDF dive logbook and share via system share sheet.
  Future<String> exportDivesToPdf(
    List<Dive> dives, {
    required PdfDateFormatter dates,
    required UnitFormatter units,
    PdfExportOptions options = const PdfExportOptions(),
    String title = 'Dive Logbook',
    Map<String, PdfProfileSeries>? profiles,
    List<Certification>? certifications,
    Diver? diver,
    Uint8List? diverPhoto,
  }) async {
    final result = await generateDivePdfBytes(
      dives,
      dates: dates,
      units: units,
      options: options,
      title: title,
      profiles: profiles,
      certifications: certifications,
      diver: diver,
      diverPhoto: diverPhoto,
    );
    return saveAndShareFileBytes(
      result.bytes,
      result.fileName,
      'application/pdf',
    );
  }

  /// Save PDF logbook to a user-selected location.
  Future<String?> saveDivesToPdfFile(
    List<Dive> dives, {
    required PdfDateFormatter dates,
    required UnitFormatter units,
    PdfExportOptions options = const PdfExportOptions(),
    String title = 'Dive Logbook',
    Map<String, PdfProfileSeries>? profiles,
    List<Certification>? certifications,
    Diver? diver,
    Uint8List? diverPhoto,
  }) async {
    final result = await generateDivePdfBytes(
      dives,
      dates: dates,
      units: units,
      options: options,
      title: title,
      profiles: profiles,
      certifications: certifications,
      diver: diver,
      diverPhoto: diverPhoto,
    );
    return savePdfBytesToFile(result.bytes, result.fileName);
  }

  /// Save already-built PDF bytes to a user-selected location.
  ///
  /// Used by the template-aware export path so the save-to-file flow honors
  /// the selected detail level instead of falling back to the legacy
  /// single-layout builder (#644).
  Future<String?> savePdfBytesToFile(List<int> bytes, String fileName) async {
    final saveResult = await FilePicker.saveFile(
      dialogTitle: 'Save PDF File',
      fileName: fileName,
      type: FileType.custom,
      bytes: Uint8List.fromList(bytes),
      mimeType: 'application/pdf',
    );

    if (saveResult == null) return null;
    return savedFileLocation(saveResult);
  }
}
