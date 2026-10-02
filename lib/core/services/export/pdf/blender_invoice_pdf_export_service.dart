import 'dart:ui' show Rect;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/services/export/models/blender_invoice_export_data.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';
import 'package:submersion/core/services/pdf_templates/pdf_fonts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';

/// Renders a trimix blender's running bill to a one-page PDF.
class BlenderInvoicePdfExportService {
  /// [loadTheme] picks the fonts. The default loads Roboto plus the script
  /// font the language needs; tests pass a Helvetica theme because text drawn
  /// in an embedded TrueType font cannot be read back out of the PDF (the
  /// same seam as PassportLabelPdfExportService).
  BlenderInvoicePdfExportService({
    Future<pw.ThemeData> Function(PdfLocalization localization)? loadTheme,
  }) : _loadTheme = loadTheme ?? _sharedTheme;

  final Future<pw.ThemeData> Function(PdfLocalization localization) _loadTheme;

  /// Roboto, not the built-in Helvetica: Helvetica stops at U+00FF, so a
  /// translated label such as Hungarian "Időtartam" would print boxes.
  static Future<pw.ThemeData> _sharedTheme(PdfLocalization localization) async {
    await PdfFonts.instance.initialize();
    return PdfFonts.instance.themeFor(localization);
  }

  static final _fileNameDate = DateFormat('yyyy-MM-dd');

  /// Builds the PDF bytes without touching the filesystem, so this half is
  /// independently testable (see [pdfVisibleText] in the test helpers).
  ///
  /// [data] arrives already localized; [localization] supplies the few labels
  /// the layout adds itself, plus the fonts and text direction (#2252). Null
  /// prints English.
  Future<List<int>> generateBytes(
    BlenderInvoiceExportData data, {
    PdfLocalization? localization,
  }) async {
    final loc = localization ?? PdfLocalization.english();
    final l10n = loc.l10n;
    final pdf = pw.Document(theme: await _loadTheme(loc));
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        textDirection: loc.textDirection,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              data.date,
              style: const pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blue800,
              ),
            ),
            if (data.billedTo.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                data.billedTo,
                style: const pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
            ],
            if (data.tariff.isNotEmpty) ...[
              pw.SizedBox(height: 10),
              pw.Text(
                data.tariff,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: PdfColors.grey600,
                ),
              ),
            ],
            pw.SizedBox(height: 16),
            pw.Divider(color: PdfColors.grey300),
            for (final fill in data.fills) _buildFill(fill),
            pw.Divider(color: PdfColors.grey300),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  l10n.gasCalculators_blender_billedTotal,
                  style: const pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  data.total,
                  style: const pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            if (data.incomplete) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                l10n.pdf_blenderIncomplete,
                style: const pw.TextStyle(fontSize: 9, color: PdfColors.red700),
              ),
            ],
          ],
        ),
      ),
    );
    return pdf.save();
  }

  pw.Widget _buildFill(BlenderInvoiceExportFill fill) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 10, bottom: 4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                fill.label,
                style: const pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                fill.total,
                style: const pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ],
          ),
          for (final line in fill.lines)
            pw.Padding(
              padding: const pw.EdgeInsets.only(left: 12, top: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    line.gas,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    line.volume,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    // A plain hyphen, not the app's em dash: the PDF's
                    // Helvetica font has no glyph for U+2014 and silently
                    // drops it.
                    line.cylinder.isEmpty ? '-' : line.cylinder,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                  pw.Text(
                    line.cost,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Writes the PDF to the documents directory and opens the system share
  /// sheet.
  Future<String> exportToPdf(
    BlenderInvoiceExportData data, {
    Rect? sharePositionOrigin,
    PdfLocalization? localization,
  }) async {
    final bytes = await generateBytes(data, localization: localization);
    return saveAndShareFileBytes(
      bytes,
      _fileName(),
      'application/pdf',
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  String _fileName() =>
      'submersion_blender_invoice_${_fileNameDate.format(DateTime.now())}.pdf';
}
