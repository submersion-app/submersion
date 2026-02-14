import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';

/// Handles PDF export for dive logbooks and trip reports.
class PdfExportService {
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

  // ==================== Trip PDF ====================

  /// Export trip with dives to PDF.
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
              if (dive.site != null) pw.Text('Site: ${dive.site!.name}'),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (dive.maxDepth != null)
                    pw.Text(
                      'Max Depth: ${dive.maxDepth!.toStringAsFixed(1)} m',
                    ),
                  if (dive.duration != null)
                    pw.Text('Duration: ${dive.duration!.inMinutes} min'),
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
  Future<({List<int> bytes, String fileName})> generateDivePdfBytes(
    List<Dive> dives, {
    String title = 'Dive Logbook',
    List<Sighting>? allSightings,
  }) async {
    final signatureService = SignatureStorageService();
    final diveSignatures = <String, List<Signature>>{};

    for (final dive in dives) {
      final sigs = await signatureService.getAllSignaturesForDive(dive.id);
      if (sigs.isNotEmpty) {
        diveSignatures[dive.id] = sigs;
      }
    }

    final pdfBytes = await _buildDivePdf(
      dives,
      title: title,
      allSightings: allSightings,
      diveSignatures: diveSignatures.isNotEmpty ? diveSignatures : null,
    );
    final fileName = 'dive_logbook_${_dateFormat.format(DateTime.now())}.pdf';
    return (bytes: pdfBytes, fileName: fileName);
  }

  /// Generate PDF dive logbook and share via system share sheet.
  Future<String> exportDivesToPdf(
    List<Dive> dives, {
    String title = 'Dive Logbook',
    List<Sighting>? allSightings,
  }) async {
    final result = await generateDivePdfBytes(
      dives,
      title: title,
      allSightings: allSightings,
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
    String title = 'Dive Logbook',
    List<Sighting>? allSightings,
  }) async {
    final result = await generateDivePdfBytes(
      dives,
      title: title,
      allSightings: allSightings,
    );

    final saveResult = await FilePicker.platform.saveFile(
      dialogTitle: 'Save PDF File',
      fileName: result.fileName,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: Uint8List.fromList(result.bytes),
    );

    if (saveResult == null) return null;

    if (!Platform.isAndroid) {
      final file = File(saveResult);
      await file.writeAsBytes(result.bytes);
    }

    return saveResult;
  }

  // ==================== Internal PDF Building ====================

  Future<List<int>> _buildDivePdf(
    List<Dive> dives, {
    String title = 'Dive Logbook',
    List<Sighting>? allSightings,
    Map<String, List<Signature>>? diveSignatures,
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
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
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
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 20),
              _buildPdfStatRow('Total Dives', '${dives.length}'),
              _buildPdfStatRow(
                'Total Dive Time',
                '${totalDiveTime.inHours}h ${totalDiveTime.inMinutes % 60}m',
              ),
              _buildPdfStatRow(
                'Deepest Dive',
                '${maxDepth.toStringAsFixed(1)}m',
              ),
              _buildPdfStatRow(
                'Average Depth',
                '${avgDepth.toStringAsFixed(1)}m',
              ),
              _buildPdfStatRow(
                'Unique Sites',
                '${dives.map((d) => d.site?.id).where((id) => id != null).toSet().length}',
              ),
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
              ...pageDives.expand(
                (dive) => [
                  _buildPdfDiveEntry(
                    dive,
                    signatures: diveSignatures?[dive.id],
                  ),
                  pw.SizedBox(height: 16),
                  pw.Divider(),
                  pw.SizedBox(height: 16),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return await pdf.save();
  }

  // ==================== PDF Widget Helpers ====================

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

  pw.Widget _buildPdfDiveEntry(Dive dive, {List<Signature>? signatures}) {
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
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                _dateTimeFormat.format(dive.dateTime),
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _buildPdfInfoChip(
                'Depth',
                '${dive.maxDepth?.toStringAsFixed(1) ?? '-'}m',
              ),
              pw.SizedBox(width: 16),
              _buildPdfInfoChip(
                'Duration',
                '${dive.duration?.inMinutes ?? '-'} min',
              ),
              pw.SizedBox(width: 16),
              _buildPdfInfoChip(
                'Temp',
                '${dive.waterTemp?.toStringAsFixed(0) ?? '-'}\u00B0C',
              ),
              if (tank != null) ...[
                pw.SizedBox(width: 16),
                _buildPdfInfoChip(
                  'Air',
                  '${tank.startPressure ?? '-'} \u2192 ${tank.endPressure ?? '-'} bar',
                ),
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
          if (dive.customFields.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: dive.customFields
                  .map(
                    (field) => pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 1),
                      child: pw.Row(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '${field.key}: ',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey700,
                            ),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              field.value,
                              style: const pw.TextStyle(
                                fontSize: 9,
                                color: PdfColors.grey700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (dive.rating != null && dive.rating! > 0) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              '${'\u2605' * dive.rating!}${'\u2606' * (5 - dive.rating!)}',
              style: const pw.TextStyle(fontSize: 12, color: PdfColors.amber),
            ),
          ],
          if (signatures != null && signatures.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Verified by:',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Wrap(
              spacing: 8,
              runSpacing: 8,
              children: signatures
                  .map((sig) => _buildPdfSignatureBlock(sig))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildPdfSignatureBlock(Signature signature) {
    pw.ImageProvider? signatureImage;
    if (signature.hasImage) {
      try {
        signatureImage = pw.MemoryImage(signature.imageData!);
      } catch (_) {
        // Ignore image load errors
      }
    }

    return pw.Container(
      width: 80,
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (signatureImage != null)
            pw.SizedBox(
              height: 30,
              child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
            )
          else
            pw.SizedBox(
              height: 30,
              child: pw.Center(
                child: pw.Text(
                  '[Signature]',
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey500,
                  ),
                ),
              ),
            ),
          pw.SizedBox(height: 2),
          pw.Text(
            signature.signerName,
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
            textAlign: pw.TextAlign.center,
          ),
          pw.Text(
            signature.isBuddySignature ? 'Buddy' : 'Instructor',
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
          pw.Text(
            _dateFormat.format(signature.signedAt),
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
            textAlign: pw.TextAlign.center,
          ),
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
}
