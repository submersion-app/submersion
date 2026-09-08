import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/services/pdf_templates/pdf_date_formatter.dart';
import 'package:submersion/features/certifications/domain/certification_title.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';

/// Front-matter pages shared by the logbook templates.
///
/// The diver page originated in the Professional template, which drew an
/// empty placeholder box where the portrait belongs and capped the
/// certification list at five entries. Both limitations are lifted here so
/// every template can present the diver the same way (#1017).
class PdfFrontMatter {
  const PdfFrontMatter._();

  /// Build the diver information page.
  ///
  /// [photoBytes] is the decoded portrait. Callers load it from
  /// [Diver.photoPath]; templates never touch the file system. When it is
  /// null an empty frame is drawn so the layout keeps its shape.
  /// Body widgets for a [pw.MultiPage].
  ///
  /// A list rather than one column so a diver with many certifications
  /// paginates instead of overflowing a fixed page, the same reason
  /// [PdfSharedComponents.buildCertificationCardsBody] returns a list.
  static List<pw.Widget> buildDiverPageBody({
    required Diver diver,
    required PdfDateFormatter dates,
    required int diveCount,
    List<Certification> certifications = const [],
    Uint8List? photoBytes,
    PdfColor accentColor = PdfColors.blue800,
  }) {
    return [
      buildDiverPage(
        diver: diver,
        dates: dates,
        diveCount: diveCount,
        photoBytes: photoBytes,
        accentColor: accentColor,
      ),
      if (certifications.isNotEmpty) ...[
        pw.Text(
          'Certifications',
          style: const pw.TextStyle(
            fontSize: 14,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 8),
        ...certifications.map((cert) => _buildCertificationLine(cert, dates)),
      ],
    ];
  }

  static pw.Widget buildDiverPage({
    required Diver diver,
    required PdfDateFormatter dates,
    required int diveCount,
    List<Certification> certifications = const [],
    Uint8List? photoBytes,
    PdfColor accentColor = PdfColors.blue800,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Diver Profile',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight: pw.FontWeight.bold,
            color: accentColor,
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 24),
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
                  _buildProfileField('Total Dives', '$diveCount'),
                ],
              ),
            ),
            pw.SizedBox(width: 40),
            _buildPortrait(photoBytes),
          ],
        ),
        pw.SizedBox(height: 24),
        if (certifications.isNotEmpty) ...[
          pw.Text(
            'Certifications',
            style: const pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          ...certifications.map((cert) => _buildCertificationLine(cert, dates)),
        ],
      ],
    );
  }

  static pw.Widget _buildPortrait(Uint8List? photoBytes) {
    if (photoBytes == null) {
      return pw.Container(
        width: 100,
        height: 120,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400),
        ),
        child: pw.Center(
          child: pw.Text(
            'Photo',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey400),
          ),
        ),
      );
    }

    return pw.Container(
      width: 100,
      height: 120,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
      ),
      child: pw.Image(pw.MemoryImage(photoBytes), fit: pw.BoxFit.cover),
    );
  }

  static pw.Widget _buildCertificationLine(
    Certification cert,
    PdfDateFormatter dates,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 4,
            height: 4,
            margin: const pw.EdgeInsets.only(top: 4),
            decoration: const pw.BoxDecoration(
              color: PdfColors.grey600,
              shape: pw.BoxShape.circle,
            ),
          ),
          pw.SizedBox(width: 8),
          // This bullet is a single line with no separate agency field,
          // unlike the certifications section in PdfSharedComponents, so the
          // agency stays here. The title is derived so it is not printed
          // twice.
          pw.Expanded(
            child: pw.Text(
              '${cert.agency.displayName} - ${certificationTitle(cert)}',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
          if (cert.cardNumber != null)
            pw.Text(
              ' Card #: ${cert.cardNumber}',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            ),
          if (cert.issueDate != null)
            pw.Text(
              ' (${dates.date(cert.issueDate!)})',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
            ),
        ],
      ),
    );
  }

  static pw.Widget _buildProfileField(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 12),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: const pw.TextStyle(
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
}
