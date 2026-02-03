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

/// PADI-style PDF template mimicking PADI logbook format.
///
/// Uses PADI's blue color scheme and layout structure familiar to
/// PADI-certified divers. Displays 4 dives per page with sections
/// for dive data, conditions, equipment, and comments.
class PdfTemplatePadi extends PdfTemplateBuilder {
  // PADI brand color
  static const _padiBlue = PdfColor.fromInt(0xFF003087);
  static const _padiLightBlue = PdfColor.fromInt(0xFFE6EDF5);

  @override
  PdfTemplate get templateType => PdfTemplate.padiStyle;

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

    // Certification cards page - highlight PADI certs
    if (certifications != null && certifications.isNotEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(32),
          build: (context) => PdfSharedComponents.buildCertificationCardsPage(
            certifications: certifications,
            diver: diver,
            highlightAgency: 'padi',
            accentColor: _padiBlue,
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
                  _buildPadiDiveEntry(
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
    DateTime? firstDiveDate,
    DateTime? lastDiveDate,
  }) {
    return pw.Center(
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: [
          // PADI-style header bar
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(vertical: 40),
            color: _padiBlue,
            child: pw.Center(
              child: pw.Text(
                'DIVE LOG',
                style: pw.TextStyle(
                  fontSize: 36,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                  letterSpacing: 4,
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 40),
          if (diver != null) ...[
            pw.Text(
              diver.name,
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight: pw.FontWeight.bold,
                color: _padiBlue,
              ),
            ),
            pw.SizedBox(height: 16),
          ],
          pw.Container(
            padding: const pw.EdgeInsets.all(20),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: _padiBlue, width: 2),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  '$diveCount',
                  style: pw.TextStyle(
                    fontSize: 48,
                    fontWeight: pw.FontWeight.bold,
                    color: _padiBlue,
                  ),
                ),
                pw.Text(
                  'Logged Dives',
                  style: const pw.TextStyle(
                    fontSize: 16,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          if (firstDiveDate != null && lastDiveDate != null) ...[
            pw.SizedBox(height: 20),
            pw.Text(
              '${PdfSharedComponents.formatDate(firstDiveDate)} - ${PdfSharedComponents.formatDate(lastDiveDate)}',
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
            ),
          ],
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

  pw.Widget _buildPageHeader({Diver? diver}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      color: _padiBlue,
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            'DIVE LOG',
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

  pw.Widget _buildPadiDiveEntry(Dive dive, {List<Signature>? signatures}) {
    final tank = dive.tanks.isNotEmpty ? dive.tanks.first : null;
    final isTrainingDive =
        dive.diveTypeId.toLowerCase().contains('training') ||
        dive.courseId != null;

    return pw.Container(
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _padiBlue),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          // Header row with dive number and date
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            color: _padiLightBlue,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    pw.Text(
                      'Dive #${dive.diveNumber ?? '-'}',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: _padiBlue,
                      ),
                    ),
                    if (isTrainingDive) ...[
                      pw.SizedBox(width: 8),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: pw.BoxDecoration(
                          color: _padiBlue,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text(
                          'TRAINING',
                          style: pw.TextStyle(
                            fontSize: 7,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                pw.Text(
                  PdfSharedComponents.formatDateTime(dive.dateTime),
                  style: const pw.TextStyle(fontSize: 9),
                ),
              ],
            ),
          ),
          // Content in PADI layout
          pw.Padding(
            padding: const pw.EdgeInsets.all(8),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Site name
                pw.Text(
                  dive.site?.name ?? 'Unknown Site',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (dive.site?.country != null || dive.site?.region != null)
                  pw.Text(
                    [
                      dive.site?.region,
                      dive.site?.country,
                    ].where((s) => s != null).join(', '),
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey600,
                    ),
                  ),
                pw.SizedBox(height: 6),
                // Dive data row
                pw.Row(
                  children: [
                    _buildPadiField(
                      'Depth',
                      '${dive.maxDepth?.toStringAsFixed(1) ?? '-'}m',
                    ),
                    _buildPadiField(
                      'Time',
                      '${dive.duration?.inMinutes ?? '-'}min',
                    ),
                    _buildPadiField(
                      'Temp',
                      '${dive.waterTemp?.toStringAsFixed(0) ?? '-'}°C',
                    ),
                    if (tank != null) _buildPadiField('Gas', tank.gasMix.name),
                  ],
                ),
                pw.SizedBox(height: 4),
                // Conditions row
                pw.Row(
                  children: [
                    _buildPadiField('Vis', dive.visibility?.displayName ?? '-'),
                    if (tank != null) ...[
                      _buildPadiField(
                        'Air',
                        '${tank.startPressure ?? '-'}-${tank.endPressure ?? '-'}',
                      ),
                    ],
                    if (dive.waterType != null)
                      _buildPadiField('Water', dive.waterType!.displayName),
                  ],
                ),
                // Notes (compact)
                if (dive.notes.isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    dive.notes,
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey700,
                    ),
                    maxLines: 2,
                  ),
                ],
                // Buddy/Instructor sign-off row
                pw.SizedBox(height: 6),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(4),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: pw.BorderRadius.circular(2),
                  ),
                  child: pw.Row(
                    children: [
                      _buildSignOffField(
                        'Buddy',
                        dive.buddy,
                        signatures
                            ?.where((s) => s.isBuddySignature)
                            .firstOrNull,
                      ),
                      pw.SizedBox(width: 16),
                      _buildSignOffField(
                        'Verified by',
                        dive.diveMaster,
                        signatures
                            ?.where((s) => !s.isBuddySignature)
                            .firstOrNull,
                      ),
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

  pw.Widget _buildPadiField(String label, String value) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: _padiBlue,
            ),
          ),
          pw.Text(value, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _buildSignOffField(
    String label,
    String? name,
    Signature? signature,
  ) {
    return pw.Expanded(
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            '$label: ',
            style: pw.TextStyle(
              fontSize: 7,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey600,
            ),
          ),
          pw.Expanded(
            child: pw.Container(
              height: 20,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
                ),
              ),
              child: pw.Row(
                children: [
                  if (signature?.hasImage == true)
                    pw.SizedBox(
                      height: 18,
                      width: 40,
                      child: pw.Image(
                        pw.MemoryImage(signature!.imageData!),
                        fit: pw.BoxFit.contain,
                      ),
                    )
                  else if (name != null && name.isNotEmpty)
                    pw.Text(name, style: const pw.TextStyle(fontSize: 8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
