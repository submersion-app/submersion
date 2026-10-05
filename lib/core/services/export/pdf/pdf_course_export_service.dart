import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/services/export/shared/export_file_name.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';
import 'package:submersion/core/services/pdf_templates/pdf_shared_components.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/signatures/data/services/signature_storage_service.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/features/certification_agencies/domain/certification_catalog.dart';
import 'package:submersion/features/certification_agencies/presentation/certification_entry_display.dart';

/// Handles PDF export for training course logs.
class PdfCourseExportService {
  /// Export a training course log to PDF with instructor signatures.
  ///
  /// Creates a professional training log document containing:
  /// - Course information (name, agency, dates, instructor)
  /// - List of training dives with depth, duration, and notes
  /// - Instructor signature on each dive entry
  ///
  /// [localization] is the language the log prints in; the course page passes
  /// the app language (#2252). Null prints English.
  Future<String> exportCourseTrainingLogToPdf(
    Course course,
    List<Dive> trainingDives, {
    required PdfDateFormatter dates,
    required UnitFormatter units,
    PdfLocalization? localization,
    CertificationCatalog? catalog,
  }) async {
    final cat = catalog ?? CertificationCatalog.builtInOnly;
    final loc = localization ?? PdfLocalization.english();
    final l10n = loc.l10n;
    // Month names and AM/PM in the log's language (#2252).
    final localDates = dates.inLanguage(loc.languageCode);
    // Roboto, not the built-in Helvetica: Helvetica stops at U+00FF, so a
    // translated label such as Hungarian "Időtartam" would print boxes.
    await PdfFonts.instance.initialize();
    final pdf = pw.Document(theme: await PdfFonts.instance.themeFor(loc));

    // Load signatures for all training dives in one read
    final diveSignatures = await SignatureStorageService()
        .getSignaturesForDives([for (final dive in trainingDives) dive.id]);

    // Calculate summary statistics
    final totalRuntime = pdfTotalRuntime(trainingDives);
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
        textDirection: loc.textDirection,
        build: (context) => pw.Center(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                l10n.pdf_trainingLog,
                style: const pw.TextStyle(
                  fontSize: 32,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 30),
              pw.Text(
                course.name,
                style: const pw.TextStyle(
                  fontSize: 28,
                  fontWeight: pw.FontWeight.bold,
                ),
                textAlign: pw.TextAlign.center,
              ),
              pw.SizedBox(height: 15),
              pw.Text(
                cat.agency(course.agency).localizedName(l10n),
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
                    _buildInfoRow(
                      l10n.pdf_instructor,
                      course.instructorDisplay,
                    ),
                    if (course.instructorNumber != null)
                      _buildInfoRow(
                        l10n.pdf_instructorNumber,
                        course.instructorNumber!,
                      ),
                    if (course.location != null)
                      _buildInfoRow(l10n.pdf_location, course.location!),
                    pw.SizedBox(height: 10),
                    _buildInfoRow(
                      l10n.pdf_startDate,
                      localDates.date(course.startDate),
                    ),
                    if (course.completionDate != null)
                      _buildInfoRow(
                        l10n.pdf_completionDate,
                        localDates.date(course.completionDate!),
                      ),
                    _buildInfoRow(
                      l10n.pdf_status,
                      course.isCompleted
                          ? l10n.pdf_statusCompleted
                          : l10n.pdf_statusInProgress,
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 40),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  _buildStatBox(
                    '${trainingDives.length}',
                    l10n.pdf_trainingDives,
                  ),
                  pw.SizedBox(width: 30),
                  _buildStatBox(
                    '${totalRuntime.inMinutes}',
                    l10n.pdf_totalMinutes,
                  ),
                  if (maxDepth != null) ...[
                    pw.SizedBox(width: 30),
                    _buildStatBox(
                      units.formatDepth(maxDepth),
                      l10n.pdf_maxDepth,
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
          textDirection: loc.textDirection,
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                l10n.pdf_trainingDives,
                style: const pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue800,
                ),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                '${course.name} - ${cat.agency(course.agency).localizedName(l10n)}',
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Divider(color: PdfColors.grey300),
              pw.SizedBox(height: 10),
              ...pageDives.map(
                (dive) => _buildDiveEntry(
                  dive,
                  diveSignatures[dive.id],
                  localDates,
                  units,
                  l10n,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Notes page (if course has notes). A MultiPage, not a fixed pw.Page, so
    // long notes continue onto another sheet instead of being dropped.
    if (course.notes.isNotEmpty) {
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          textDirection: loc.textDirection,
          build: (context) => [
            pw.Text(
              l10n.pdf_courseNotes,
              style: const pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 15),
            // TextOverflow.span is what lets MultiPage break the notes
            // across sheets.
            pw.Text(
              course.notes,
              style: const pw.TextStyle(fontSize: 11),
              overflow: pw.TextOverflow.span,
            ),
          ],
        ),
      );
    }

    final bytes = await pdf.save();
    return saveAndShareFileBytes(
      bytes,
      trainingLogFileName(course.name, DateTime.now()),
      'application/pdf',
    );
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
            style: const pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
            ),
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
            style: const pw.TextStyle(
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

  pw.Widget _buildDiveEntry(
    Dive dive,
    List<Signature>? signatures,
    PdfDateFormatter dates,
    UnitFormatter units,
    AppLocalizations l10n,
  ) {
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
                l10n.pdf_tripDiveTitle('${dive.diveNumber ?? "-"}'),
                style: const pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                dates.dateTime(dive.dateTime),
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
              style: const pw.TextStyle(
                fontSize: 12,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              if (dive.maxDepth != null)
                _buildInfoChip(
                  l10n.pdf_maxDepth,
                  units.formatDepth(dive.maxDepth),
                ),
              if (dive.effectiveRuntime != null) ...[
                pw.SizedBox(width: 20),
                _buildInfoChip(
                  l10n.pdf_duration,
                  l10n.pdf_minutes(pdfDiveDurationMinutes(dive)),
                ),
              ],
              if (dive.waterTemp != null) ...[
                pw.SizedBox(width: 20),
                _buildInfoChip(
                  l10n.pdf_waterTemp,
                  units.formatTemperature(dive.waterTemp, decimals: 0),
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
                  l10n.pdf_labelValue(l10n.pdf_verifiedBy, ''),
                  style: const pw.TextStyle(
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
                        .map(
                          (sig) => PdfSharedComponents.buildSignatureBlock(
                            sig,
                            dates: dates,
                            l10n: l10n,
                          ),
                        )
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
          style: const pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

/// `training_log_<course>_<yyyy-MM-dd>.pdf`, the course name as a
/// [fileNameSegment] and the date as a [fileNameDate].
String trainingLogFileName(String courseName, DateTime date) => exportFileName([
  'training_log',
  fileNameSegment(courseName),
  fileNameDate(date),
], 'pdf');
