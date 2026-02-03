import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/constants/pdf_templates.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_shared_components.dart';
import 'package:submersion/core/services/pdf_templates/pdf_template_builder.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/signatures/domain/entities/signature.dart';

/// Detailed PDF template with full dive information.
///
/// This is the default template that displays 3 dives per page in a card
/// format with all available information including notes, gas info, tank
/// data, ratings, and signatures.
class PdfTemplateDetailed extends PdfTemplateBuilder {
  @override
  PdfTemplate get templateType => PdfTemplate.detailed;

  @override
  Future<List<int>> buildPdf({
    required List<Dive> dives,
    required PdfPageSize pageSize,
    String title = 'Dive Logbook',
    Map<String, List<Signature>>? diveSignatures,
    List<Certification>? certifications,
    Diver? diver,
  }) async {
    final pdf = pw.Document(theme: PdfFonts.instance.theme);
    final pageFormat = getPageFormat(pageSize);

    // Cover page
    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        build: (context) => PdfSharedComponents.buildCoverPage(
          title: title,
          diveCount: dives.length,
          pageFormat: pageFormat,
          firstDiveDate: dives.isNotEmpty ? dives.last.dateTime : null,
          lastDiveDate: dives.isNotEmpty ? dives.first.dateTime : null,
          diver: diver,
        ),
      ),
    );

    // Summary page
    if (dives.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (context) =>
              PdfSharedComponents.buildSummaryPage(dives: dives),
        ),
      );
    }

    // Certification cards page (if requested and available)
    if (certifications != null && certifications.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => PdfSharedComponents.buildCertificationCardsPage(
            certifications: certifications,
            diver: diver,
          ),
        ),
      );
    }

    // Dive log pages (3 dives per page)
    const divesPerPage = 3;
    for (var i = 0; i < dives.length; i += divesPerPage) {
      final pageDives = dives.skip(i).take(divesPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              ...pageDives.expand(
                (dive) => [
                  _buildDiveEntry(dive, signatures: diveSignatures?[dive.id]),
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

  pw.Widget _buildDiveEntry(Dive dive, {List<Signature>? signatures}) {
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
          // Header row
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
                PdfSharedComponents.formatDateTime(dive.dateTime),
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 8),
          // Metrics row
          pw.Row(
            children: [
              PdfSharedComponents.buildInfoChip(
                'Depth',
                '${dive.maxDepth?.toStringAsFixed(1) ?? '-'}m',
              ),
              pw.SizedBox(width: 16),
              PdfSharedComponents.buildInfoChip(
                'Duration',
                '${dive.duration?.inMinutes ?? '-'} min',
              ),
              pw.SizedBox(width: 16),
              PdfSharedComponents.buildInfoChip(
                'Temp',
                '${dive.waterTemp?.toStringAsFixed(0) ?? '-'}°C',
              ),
              if (tank != null) ...[
                pw.SizedBox(width: 16),
                PdfSharedComponents.buildInfoChip(
                  'Air',
                  '${tank.startPressure ?? '-'} - ${tank.endPressure ?? '-'} bar',
                ),
              ],
            ],
          ),
          // Notes
          if (dive.notes.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              dive.notes,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
              maxLines: 2,
            ),
          ],
          // Rating
          if (dive.rating != null && dive.rating! > 0) ...[
            pw.SizedBox(height: 4),
            PdfSharedComponents.buildRating(dive.rating),
          ],
          // Signatures section
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
                  .map((sig) => PdfSharedComponents.buildSignatureBlock(sig))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}
