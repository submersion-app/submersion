import 'dart:ui' show Rect;

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:submersion/core/services/export/models/blender_invoice_export_data.dart';
import 'package:submersion/core/services/export/shared/file_export_utils.dart';

/// Renders a trimix blender's running bill to a one-page PDF.
class BlenderInvoicePdfExportService {
  static final _fileNameDate = DateFormat('yyyy-MM-dd');

  /// Builds the PDF bytes without touching the filesystem, so this half is
  /// independently testable (see [pdfVisibleText] in the test helpers).
  Future<List<int>> generateBytes(BlenderInvoiceExportData data) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
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
                  'Total',
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
                'Incomplete: one or more lines have no price.',
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
  }) async {
    final bytes = await generateBytes(data);
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
