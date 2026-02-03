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

/// Professional PDF template for instructors and divemasters.
///
/// Displays 2 dives per page with large signature and stamp areas for
/// official verification. Suitable for presenting to dive agencies or
/// for professional dive logs.
class PdfTemplateProfessional extends PdfTemplateBuilder {
  @override
  PdfTemplate get templateType => PdfTemplate.professional;

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
        build: (context) => _buildCoverPage(
          title: title,
          diveCount: dives.length,
          diver: diver,
          firstDiveDate: dives.isNotEmpty ? dives.last.dateTime : null,
          lastDiveDate: dives.isNotEmpty ? dives.first.dateTime : null,
        ),
      ),
    );

    // Diver profile page
    if (diver != null) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => _buildDiverProfilePage(
            diver: diver,
            totalDives: dives.length,
            certifications: certifications,
          ),
        ),
      );
    }

    // Certification cards page (if requested and available)
    if (certifications != null && certifications.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => PdfSharedComponents.buildCertificationCardsPage(
            certifications: certifications,
            diver: diver,
            accentColor: PdfColors.grey800,
          ),
        ),
      );
    }

    // Dive log pages (2 dives per page for more space)
    const divesPerPage = 2;
    for (var i = 0; i < dives.length; i += divesPerPage) {
      final pageDives = dives.skip(i).take(divesPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(40),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Page header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Professional Dive Log',
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey700,
                    ),
                  ),
                  if (diver != null)
                    pw.Text(
                      diver.name,
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                ],
              ),
              pw.Divider(color: PdfColors.grey400),
              pw.SizedBox(height: 16),
              // Dive entries
              ...pageDives.expand(
                (dive) => [
                  _buildProfessionalDiveEntry(
                    dive,
                    signatures: diveSignatures?[dive.id],
                  ),
                  pw.SizedBox(height: 24),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return await pdf.save();
  }

  pw.Widget _buildCoverPage({
    required String title,
    required int diveCount,
    Diver? diver,
    DateTime? firstDiveDate,
    DateTime? lastDiveDate,
  }) {
    return pw.Center(
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.all(40),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey800, width: 2),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'PROFESSIONAL',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 4,
                    color: PdfColors.grey600,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  title.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 20),
                if (diver != null) ...[
                  pw.Text(diver.name, style: const pw.TextStyle(fontSize: 20)),
                  pw.SizedBox(height: 8),
                ],
                pw.Text(
                  '$diveCount Logged Dives',
                  style: const pw.TextStyle(
                    fontSize: 16,
                    color: PdfColors.grey700,
                  ),
                ),
                if (firstDiveDate != null && lastDiveDate != null) ...[
                  pw.SizedBox(height: 8),
                  pw.Text(
                    '${PdfSharedComponents.formatDate(firstDiveDate)} - ${PdfSharedComponents.formatDate(lastDiveDate)}',
                    style: const pw.TextStyle(
                      fontSize: 12,
                      color: PdfColors.grey600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 40),
          pw.Text(
            'Generated ${PdfSharedComponents.formatDateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildDiverProfilePage({
    required Diver diver,
    required int totalDives,
    List<Certification>? certifications,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Diver Profile',
          style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 16),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 24),
        // Profile info
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _buildProfileField('Name', diver.name),
                  if (diver.email != null)
                    _buildProfileField('Email', diver.email!),
                  _buildProfileField('Total Dives', '$totalDives'),
                ],
              ),
            ),
            pw.SizedBox(width: 40),
            // Photo placeholder
            pw.Container(
              width: 100,
              height: 120,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: pw.Center(
                child: pw.Text(
                  'Photo',
                  style: const pw.TextStyle(
                    fontSize: 10,
                    color: PdfColors.grey400,
                  ),
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 24),
        // Certifications summary
        if (certifications != null && certifications.isNotEmpty) ...[
          pw.Text(
            'Certifications',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          ...certifications
              .take(5)
              .map(
                (cert) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Row(
                    children: [
                      pw.Container(
                        width: 4,
                        height: 4,
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey600,
                          shape: pw.BoxShape.circle,
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.Text(
                        '${cert.agency.displayName} - ${cert.name}',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      if (cert.issueDate != null) ...[
                        pw.Text(
                          ' (${PdfSharedComponents.formatDate(cert.issueDate!)})',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          if (certifications.length > 5)
            pw.Text(
              '... and ${certifications.length - 5} more',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
        ],
      ],
    );
  }

  pw.Widget _buildProfileField(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
              letterSpacing: 1,
            ),
          ),
          pw.SizedBox(height: 2),
          pw.Text(value, style: const pw.TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  pw.Widget _buildProfessionalDiveEntry(
    Dive dive, {
    List<Signature>? signatures,
  }) {
    final tank = dive.tanks.isNotEmpty ? dive.tanks.first : null;
    final instructorSig = signatures
        ?.where((s) => !s.isBuddySignature)
        .firstOrNull;
    final buddySig = signatures?.where((s) => s.isBuddySignature).firstOrNull;

    return pw.Container(
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'DIVE #${dive.diveNumber ?? '-'}',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                PdfSharedComponents.formatDateTime(dive.dateTime),
                style: const pw.TextStyle(fontSize: 12),
              ),
            ],
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            dive.site?.name ?? 'Unknown Site',
            style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
          pw.Divider(color: PdfColors.grey200),
          pw.SizedBox(height: 12),
          // Metrics grid
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _buildMetricRow(
                      'Max Depth',
                      dive.maxDepth != null
                          ? '${dive.maxDepth!.toStringAsFixed(1)} m'
                          : '-',
                    ),
                    _buildMetricRow(
                      'Avg Depth',
                      dive.avgDepth != null
                          ? '${dive.avgDepth!.toStringAsFixed(1)} m'
                          : '-',
                    ),
                    _buildMetricRow(
                      'Duration',
                      dive.duration != null
                          ? '${dive.duration!.inMinutes} min'
                          : '-',
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                child: pw.Column(
                  children: [
                    _buildMetricRow(
                      'Water Temp',
                      dive.waterTemp != null
                          ? '${dive.waterTemp!.toStringAsFixed(0)}°C'
                          : '-',
                    ),
                    _buildMetricRow(
                      'Visibility',
                      dive.visibility?.displayName ?? '-',
                    ),
                    if (tank != null)
                      _buildMetricRow('Gas', tank.gasMix.name)
                    else
                      _buildMetricRow('Gas', '-'),
                  ],
                ),
              ),
            ],
          ),
          // Notes
          if (dive.notes.isNotEmpty) ...[
            pw.SizedBox(height: 12),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'NOTES',
                    style: pw.TextStyle(
                      fontSize: 8,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.grey600,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    dive.notes,
                    style: const pw.TextStyle(fontSize: 10),
                    maxLines: 4,
                  ),
                ],
              ),
            ),
          ],
          pw.SizedBox(height: 16),
          // Verification section
          pw.Divider(color: PdfColors.grey200),
          pw.SizedBox(height: 12),
          pw.Text(
            'VERIFICATION',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey700,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Instructor signature
              PdfSharedComponents.buildLargeSignatureBlock(
                label: 'Instructor / Verifier Signature',
                signature: instructorSig,
                width: 180,
                height: 50,
              ),
              // Buddy signature
              PdfSharedComponents.buildLargeSignatureBlock(
                label: 'Buddy Signature',
                signature: buddySig,
                width: 140,
                height: 50,
              ),
              // Stamp area
              PdfSharedComponents.buildStampArea(
                size: 70,
                label: 'Official Stamp',
              ),
            ],
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMetricRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 80,
            child: pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
