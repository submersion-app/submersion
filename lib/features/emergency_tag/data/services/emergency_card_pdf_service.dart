import 'dart:ui' show Rect;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';

/// What the printed emergency card shows (issue #5060).
class EmergencyCardContent {
  const EmergencyCardContent({
    required this.lines,
    required this.qrData,
    required this.qrCaption,
  });

  /// The tag's text, line by line; the first is the header.
  final List<String> lines;

  /// What the QR code carries: the tag's first record.
  final String qrData;
  final String qrCaption;
}

/// Renders the emergency card: an A6 card (105 x 148 mm) outlined with a
/// dashed cut line at the top left of an A4 page, so it prints at its real
/// size on any printer.
class EmergencyCardPdfService {
  /// [loadTheme] picks the fonts. The default is the shared Roboto loader;
  /// tests pass a Helvetica theme so the text can be read back.
  EmergencyCardPdfService({
    Future<pw.ThemeData> Function(PdfLocalization localization)? loadTheme,
  }) : _loadTheme = loadTheme ?? _sharedTheme;

  final Future<pw.ThemeData> Function(PdfLocalization localization) _loadTheme;

  static const double _cardW = 105 * PdfPageFormat.mm;
  static const double _cardH = 148 * PdfPageFormat.mm;
  static const double _qr = 34 * PdfPageFormat.mm;
  static const PdfColor _red = PdfColor.fromInt(0xFFC62828);

  /// Builds the PDF bytes without touching the filesystem. Nothing is left
  /// off: a long card shrinks its text to fit.
  Future<List<int>> generateBytes(
    EmergencyCardContent content, {
    PdfLocalization? localization,
  }) async {
    final loc = localization ?? PdfLocalization.english();
    final theme = await _loadTheme(loc);
    final pdf = pw.Document(theme: theme);
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: loc.textDirection,
        margin: const pw.EdgeInsets.all(10 * PdfPageFormat.mm),
        build: (context) =>
            pw.Align(alignment: pw.Alignment.topLeft, child: _card(content)),
      ),
    );
    return pdf.save();
  }

  pw.Widget _card(EmergencyCardContent content) {
    final header = content.lines.isEmpty ? '' : content.lines.first;
    final body = content.lines.skip(1).toList();
    return pw.Container(
      width: _cardW,
      height: _cardH,
      padding: const pw.EdgeInsets.all(5 * PdfPageFormat.mm),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          width: 0.6,
          color: PdfColors.grey600,
          style: pw.BorderStyle.dashed,
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(
              vertical: 2 * PdfPageFormat.mm,
            ),
            color: _red,
            child: pw.Text(
              header,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(
                color: PdfColors.white,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
          pw.SizedBox(height: 3 * PdfPageFormat.mm),
          pw.Expanded(
            child: pw.FittedBox(
              fit: pw.BoxFit.scaleDown,
              alignment: pw.Alignment.topLeft,
              child: pw.SizedBox(
                width: _cardW - 10 * PdfPageFormat.mm,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    for (final line in body)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(
                          bottom: 1.2 * PdfPageFormat.mm,
                        ),
                        child: pw.Text(
                          line,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 2 * PdfPageFormat.mm),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.BarcodeWidget(
                barcode: pw.Barcode.qrCode(
                  errorCorrectLevel: pw.BarcodeQRCorrectionLevel.medium,
                ),
                data: content.qrData,
                width: _qr,
                height: _qr,
                drawText: false,
              ),
              pw.SizedBox(width: 3 * PdfPageFormat.mm),
              pw.Expanded(
                child: pw.Text(
                  content.qrCaption,
                  style: const pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<pw.ThemeData> _sharedTheme(PdfLocalization localization) async {
    await PdfFonts.instance.initialize();
    return PdfFonts.instance.themeFor(localization);
  }

  /// Writes the PDF to the documents directory and opens the system share
  /// sheet. Returns the saved path.
  Future<String> exportToPdf(
    EmergencyCardContent content, {
    Rect? sharePositionOrigin,
    PdfLocalization? localization,
  }) async {
    final bytes = await generateBytes(content, localization: localization);
    return saveAndShareFileBytes(
      bytes,
      'submersion_emergency_card.pdf',
      'application/pdf',
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}
