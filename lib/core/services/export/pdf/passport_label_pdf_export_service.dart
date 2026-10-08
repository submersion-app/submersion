import 'dart:ui' show Rect;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';

/// One printable cylinder label (spec section 8, Tag card).
class PassportLabelData {
  const PassportLabelData({
    required this.title,
    this.subtitle,
    this.specLine,
    required this.url,
  });

  final String title;
  final String? subtitle;
  final String? specLine;
  final String url;
}

/// Renders cylinder passport labels, 62 x 32 mm each, 24 to an A4 sheet
/// (three across, eight down, inside 8 mm margins).
/// The QR uses error correction M like the on-screen code.
class PassportLabelPdfExportService {
  /// [loadTheme] picks the fonts. The default is the shared Roboto loader;
  /// tests pass a Helvetica theme because text drawn in an embedded TrueType
  /// font cannot be read back out of the PDF (see pdf_export_set_names_test).
  PassportLabelPdfExportService({
    Future<pw.ThemeData> Function(PdfLocalization localization)? loadTheme,
  }) : _loadTheme = loadTheme ?? _sharedTheme;

  final Future<pw.ThemeData> Function(PdfLocalization localization) _loadTheme;

  static final _fileNameDate = DateFormat('yyyy-MM-dd');
  static const double _labelW = 62 * PdfPageFormat.mm;
  static const double _labelH = 32 * PdfPageFormat.mm;
  static const double _qr = 26 * PdfPageFormat.mm;

  /// Builds the PDF bytes without touching the filesystem.
  ///
  /// The label text arrives already localized; [localization] picks the
  /// fonts and text direction for that language (#2252). Null is English.
  Future<List<int>> generateBytes(
    List<PassportLabelData> labels, {
    PdfLocalization? localization,
  }) async {
    final loc = localization ?? PdfLocalization.english();
    final theme = await _loadTheme(loc);
    final pdf = pw.Document(theme: theme);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: loc.textDirection,
        // 8 mm, not 10: three 62 mm labels and two 3 mm gaps need 192 mm,
        // and a 10 mm margin leaves only 190.
        margin: const pw.EdgeInsets.all(8 * PdfPageFormat.mm),
        build: (context) => [
          pw.Wrap(
            spacing: 3 * PdfPageFormat.mm,
            runSpacing: 3 * PdfPageFormat.mm,
            children: [for (final label in labels) _label(label)],
          ),
        ],
      ),
    );
    return pdf.save();
  }

  pw.Widget _label(PassportLabelData label) => pw.Container(
    width: _labelW,
    height: _labelH,
    padding: const pw.EdgeInsets.all(2 * PdfPageFormat.mm),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(width: 0.5, color: PdfColors.grey700),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(
            errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium,
          ),
          data: label.url,
          width: _qr,
          height: _qr,
          drawText: false,
        ),
        pw.SizedBox(width: 2 * PdfPageFormat.mm),
        pw.Expanded(
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.center,
            children: [
              pw.Text(
                label.title,
                style: const pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                ),
                maxLines: 2,
              ),
              if (label.subtitle != null)
                pw.Text(
                  label.subtitle!,
                  style: const pw.TextStyle(fontSize: 8),
                ),
              if (label.specLine != null)
                pw.Text(
                  label.specLine!,
                  style: const pw.TextStyle(fontSize: 7),
                ),
              pw.SizedBox(height: 1 * PdfPageFormat.mm),
              pw.Text(
                'submersion.app',
                style: const pw.TextStyle(
                  fontSize: 6,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  /// Roboto through the shared loader (names outside Latin-1 need it), which
  /// falls back to Helvetica when the font cannot be fetched.
  static Future<pw.ThemeData> _sharedTheme(PdfLocalization localization) async {
    await PdfFonts.instance.initialize();
    return PdfFonts.instance.themeFor(localization);
  }

  /// Writes the PDF to the documents directory and opens the system share
  /// sheet. Returns the saved path.
  Future<String> exportToPdf(
    List<PassportLabelData> labels, {
    Rect? sharePositionOrigin,
    PdfLocalization? localization,
  }) async {
    final bytes = await generateBytes(labels, localization: localization);
    return saveAndShareFileBytes(
      bytes,
      'submersion_cylinder_labels_${_fileNameDate.format(DateTime.now())}.pdf',
      'application/pdf',
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
