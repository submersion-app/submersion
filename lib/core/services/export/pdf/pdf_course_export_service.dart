import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';

/// Handles PDF export for training course logs.
class PdfCourseExportService {
  final _dateFormat = DateFormat('yyyy-MM-dd');
  final _dateTimeFormat = DateFormat('yyyy-MM-dd HH:mm');

  /// Export a training course log to PDF with instructor signatures.
  ///
  /// Creates a professional training log document containing:
  /// - Course information (name, agency, dates, instructor)
  /// - List of training dives with depth, duration, and notes
  /// - Instructor signature on each dive entry
  Future<String> exportCourseTrainingLogToPdf(
    Course course,
    List<Dive> trainingDives,
  ) async {
    final pdf = pw.Document();
    final signatureService = SignatureStorageService();

    // Load signatures for all training dives
    final diveSignatures = <String, List<Signature>>{};
    for (final dive in trainingDives) {
      final sigs = await signatureService.getAllSignaturesForDive(dive.id);
      if (sigs.isNotEmpty) {
        diveSignatures[dive.id] = sigs;
      }
    }

    // Calculate summary statistics
    final totalBottomTime = trainingDives.fold<Duration>(
      Duration.zero,
      (sum, dive) => sum + (dive.duration ?? Duration.zero),
    );
    final maxDepth = trainingDives.fold<double?>(
      null,
      (max, dive) => dive.maxDepth != null
          ? (max == null
                ? dive.maxDepth
                : (dive.maxDepth! > max ? dive.maxDepth : max))
          : max,
    );

    // Cover/Title page
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                'Training Log',
                style: pw.TextStyle(
                  fontSize: 32,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                course.name,
                style: pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 15),
              pw.Text(
                course.agency.displayName,
                style: const pw.TextStyle(
                  fontSize: 18,
                  color: PdfColors.grey700,
                ),
              ),
              pw.SizedBox(height: 40),
              pw.Container(
                padding: const pw.EdgeInsets.all(20),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    _buildInfoRow('Instructor', course.instructorDisplay),
                    if (course.instructorNumber != null)
                      _buildInfoRow('Instructor #', course.instructorNumber!),
                    if (course.location != null)
                      _buildInfoRow('Location', course.location!),
                    pw.SizedBox(height: 10),
                    _buildInfoRow(
                      'Start Date',
                      _dateFormat.format(course.startDate),
                    ),
                    if (course.completionDate != null)
                      _buildInfoRow(
                        'Completion Date',
                        _dateFormat.format(course.completionDate!),
                      ),
                    _buildInfoRow(
                      'Status',
                      course.isCompleted ? 'Completed' : 'In Progress',
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  _buildStatBox('${trainingDives.length}', 'Training Dives'),
                  pw.SizedBox(width: 30),
                  _buildStatBox(
                    '${totalBottomTime.inMinutes}',
                    'Total Minutes',
                  ),
                  if (maxDepth != null) ...[
                    pw.SizedBox(width: 30),
                    _buildStatBox(
                      '${maxDepth.toStringAsFixed(1)}m',
                      'Max Depth',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Training dives pages (multiple dives per page)
    const divesPerPage = 3;
    for (var i = 0; i < trainingDives.length; i += divesPerPage) {
      final pageDives = trainingDives.skip(i).take(divesPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Training Dives',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                '${course.name} - ${course.agency.displayName}',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),
              ...pageDives.map(
                (dive) => _buildDiveEntry(dive, diveSignatures[dive.id]),
              ),
            ],
          ),
        ),
      );
    }

    // Notes page (if course has notes)
    if (course.notes.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Course Notes',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 15),
              pw.Text(course.notes, style: const pw.TextStyle(fontSize: 11)),
            ],
          ),
        ),
      );
    }

    final bytes = await pdf.save();
    final fileName =
        'training_log_${course.name.replaceAll(RegExp(r'[^\w]'), '_')}_${_dateFormat.format(DateTime.now())}.pdf';
    return saveAndShareFileBytes(bytes, fileName, 'application/pdf');
  }

  // ==================== Widget Helpers ====================

  pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildStatBox(String value, String label) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        color: PdfColors.blue50,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue800,
            ),
          ),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDiveEntry(Dive dive, List<Signature>? signatures) {
    return pw.Container(
      margin: const pw.EdgeInsets.only(bottom: 15),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Dive ${dive.diveNumber ?? "-"}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                _dateTimeFormat.format(dive.dateTime),
                style: const pw.TextStyle(
                  fontSize: 11,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          if (dive.site != null)
            pw.Text(
              dive.site!.name,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
            ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              if (dive.maxDepth != null)
                _buildInfoChip(
                  'Max Depth',
                  '${dive.maxDepth!.toStringAsFixed(1)} m',
                ),
              if (dive.duration != null) ...[
                pw.SizedBox(width: 20),
                _buildInfoChip('Duration', '${dive.duration!.inMinutes} min'),
              ],
              if (dive.waterTemp != null) ...[
                pw.SizedBox(width: 20),
                _buildInfoChip(
                  'Water Temp',
                  '${dive.waterTemp!.toStringAsFixed(0)}\u00B0C',
                ),
              ],
            ],
          ),
          if (dive.notes.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              dive.notes,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              maxLines: 3,
            ),
          ],
          if (signatures != null && signatures.isNotEmpty) ...[
            pw.SizedBox(height: 10),
            pw.Divider(color: PdfColors.grey200),
            pw.SizedBox(height: 6),
            pw.Row(
              children: [
                pw.Text(
                  'Verified by: ',
                  style: pw.TextStyle(
                    fontSize: 9,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.Expanded(
                  child: pw.Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: signatures
                        .map((sig) => _buildSignatureBlock(sig))
                        .toList(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  pw.Widget _buildSignatureBlock(Signature signature) {
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

  pw.Widget _buildInfoChip(String label, String value) {
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
