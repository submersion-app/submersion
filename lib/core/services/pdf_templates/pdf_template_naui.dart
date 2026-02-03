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

/// NAUI-style PDF template mimicking NAUI logbook format.
///
/// Uses NAUI's green/teal color scheme with emphasis on dive planning
/// data and decompression information. Displays 4 dives per page.
class PdfTemplateNaui extends PdfTemplateBuilder {
  // NAUI brand colors
  static const _nauiGreen = PdfColor.fromInt(0xFF006B5A);
  static const _nauiLightGreen = PdfColor.fromInt(0xFFE6F2F0);

  @override
  PdfTemplate get templateType => PdfTemplate.nauiStyle;

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
          dives: dives,
        ),
      ),
    );

    // Certification cards page - highlight NAUI certs
    if (certifications != null && certifications.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => PdfSharedComponents.buildCertificationCardsPage(
            certifications: certifications,
            diver: diver,
            highlightAgency: 'naui',
            accentColor: _nauiGreen,
          ),
        ),
      );
    }

    // Dive log pages (4 dives per page)
    const divesPerPage = 4;
    for (var i = 0; i < dives.length; i += divesPerPage) {
      final pageDives = dives.skip(i).take(divesPerPage).toList();

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Page header
              _buildPageHeader(diver: diver),
              pw.SizedBox(height: 8),
              // Dive entries
              ...pageDives.expand(
                (dive) => [
                  _buildNauiDiveEntry(
                    dive,
                    signatures: diveSignatures?[dive.id],
                  ),
                  pw.SizedBox(height: 8),
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
    required List<Dive> dives,
  }) {
    // Calculate summary stats
    final totalBottomTime = dives
        .where((d) => d.duration != null)
        .fold<Duration>(Duration.zero, (sum, d) => sum + d.duration!);
    final maxDepth = dives
        .where((d) => d.maxDepth != null)
        .map((d) => d.maxDepth!)
        .fold<double>(0, (max, depth) => depth > max ? depth : max);

    return pw.Center(
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          // NAUI-style header
          pw.Container(
            width: 280,
            padding: const pw.EdgeInsets.all(30),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _nauiGreen, width: 3),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'NAUI',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    letterSpacing: 6,
                    color: _nauiGreen,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Text(
                  'DIVE LOG',
                  style: pw.TextStyle(
                    fontSize: 32,
                    fontWeight: pw.FontWeight.bold,
                    color: _nauiGreen,
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Divider(color: _nauiGreen, thickness: 1),
                pw.SizedBox(height: 16),
                if (diver != null) ...[
                  pw.Text(diver.name, style: const pw.TextStyle(fontSize: 18)),
                  pw.SizedBox(height: 8),
                ],
              ],
            ),
          ),
          pw.SizedBox(height: 30),
          // Stats boxes
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              _buildStatBox('$diveCount', 'Dives'),
              pw.SizedBox(width: 20),
              _buildStatBox(
                '${totalBottomTime.inHours}:${(totalBottomTime.inMinutes % 60).toString().padLeft(2, '0')}',
                'Hours',
              ),
              pw.SizedBox(width: 20),
              _buildStatBox('${maxDepth.toStringAsFixed(0)}m', 'Max Depth'),
            ],
          ),
          pw.Spacer(),
          pw.Text(
            'Generated ${PdfSharedComponents.formatDateTime(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey500),
          ),
          pw.SizedBox(height: 20),
        ],
      ),
    );
  }

  pw.Widget _buildStatBox(String value, String label) {
    return pw.Container(
      width: 80,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: _nauiLightGreen,
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 18,
              fontWeight: pw.FontWeight.bold,
              color: _nauiGreen,
            ),
          ),
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildPageHeader({Diver? diver}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: _nauiGreen,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'NAUI DIVE LOG',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
          ),
          if (diver != null)
            pw.Text(
              diver.name,
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
            ),
        ],
      ),
    );
  }

  pw.Widget _buildNauiDiveEntry(Dive dive, {List<Signature>? signatures}) {
    final tank = dive.tanks.isNotEmpty ? dive.tanks.first : null;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _nauiGreen),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header with dive number
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: _nauiLightGreen,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'DIVE #${dive.diveNumber ?? '-'}',
                  style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _nauiGreen,
                  ),
                ),
                pw.Text(
                  PdfSharedComponents.formatDateTime(dive.dateTime),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
          // Content
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Left column - Dive Planning Data
                pw.Expanded(
                  flex: 3,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Site
                      pw.Text(
                        dive.site?.name ?? 'Unknown Site',
                        style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      // Planning section
                      pw.Container(
                        padding: const pw.EdgeInsets.all(4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.grey50,
                          borderRadius: pw.BorderRadius.circular(2),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'DIVE DATA',
                              style: pw.TextStyle(
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold,
                                color: _nauiGreen,
                              ),
                            ),
                            pw.SizedBox(height: 2),
                            pw.Row(
                              children: [
                                _buildNauiField(
                                  'Depth',
                                  '${dive.maxDepth?.toStringAsFixed(1) ?? '-'}m',
                                ),
                                _buildNauiField(
                                  'Avg',
                                  '${dive.avgDepth?.toStringAsFixed(1) ?? '-'}m',
                                ),
                                _buildNauiField(
                                  'Time',
                                  '${dive.duration?.inMinutes ?? '-'}min',
                                ),
                              ],
                            ),
                            pw.SizedBox(height: 2),
                            pw.Row(
                              children: [
                                if (tank != null) ...[
                                  _buildNauiField('Gas', tank.gasMix.name),
                                  _buildNauiField(
                                    'Start',
                                    '${tank.startPressure ?? '-'} bar',
                                  ),
                                  _buildNauiField(
                                    'End',
                                    '${tank.endPressure ?? '-'} bar',
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      pw.SizedBox(height: 4),
                      // Conditions
                      pw.Row(
                        children: [
                          _buildNauiField(
                            'Temp',
                            '${dive.waterTemp?.toStringAsFixed(0) ?? '-'}°C',
                          ),
                          _buildNauiField(
                            'Vis',
                            dive.visibility?.displayName ?? '-',
                          ),
                          if (dive.currentStrength != null)
                            _buildNauiField(
                              'Current',
                              dive.currentStrength!.displayName,
                            ),
                        ],
                      ),
                      // Surface interval if present
                      if (dive.surfaceInterval != null) ...[
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'SI: ${dive.surfaceInterval!.inMinutes}min',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                pw.SizedBox(width: 8),
                // Right column - Verification
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(4),
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(color: PdfColors.grey300),
                          borderRadius: pw.BorderRadius.circular(2),
                        ),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              'VERIFICATION',
                              style: pw.TextStyle(
                                fontSize: 7,
                                fontWeight: pw.FontWeight.bold,
                                color: _nauiGreen,
                              ),
                            ),
                            pw.SizedBox(height: 4),
                            _buildVerificationLine(
                              'Instructor',
                              signatures
                                  ?.where((s) => !s.isBuddySignature)
                                  .firstOrNull,
                            ),
                            pw.SizedBox(height: 2),
                            _buildVerificationLine(
                              'NAUI #',
                              null,
                              placeholder: true,
                            ),
                            pw.SizedBox(height: 2),
                            _buildVerificationLine(
                              'Buddy',
                              signatures
                                  ?.where((s) => s.isBuddySignature)
                                  .firstOrNull,
                            ),
                          ],
                        ),
                      ),
                      // Notes
                      if (dive.notes.isNotEmpty) ...[
                        pw.SizedBox(height: 4),
                        pw.Text(
                          dive.notes,
                          style: const pw.TextStyle(
                            fontSize: 7,
                            color: PdfColors.grey700,
                          ),
                          maxLines: 2,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildNauiField(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey600),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 8)),
        ],
      ),
    );
  }

  pw.Widget _buildVerificationLine(
    String label,
    Signature? signature, {
    bool placeholder = false,
  }) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 50,
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
          ),
        ),
        pw.Expanded(
          child: pw.Container(
            height: 14,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
              ),
            ),
            child: signature?.hasImage == true
                ? pw.Image(
                    pw.MemoryImage(signature!.imageData!),
                    fit: pw.BoxFit.contain,
                    height: 12,
                  )
                : placeholder
                ? pw.Text('', style: const pw.TextStyle(fontSize: 7))
                : signature != null
                ? pw.Text(
                    signature.signerName,
                    style: const pw.TextStyle(fontSize: 7),
                  )
                : pw.SizedBox(),
          ),
        ),
      ],
    );
  }
}
