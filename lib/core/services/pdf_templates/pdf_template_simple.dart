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

/// Simple PDF template with high-density table format.
///
/// Displays dives in a compact table with 15-20 dives per page. Contains
/// only essential information: dive number, date, site, depth, duration,
/// and temperature. No notes, signatures, or decorations.
class PdfTemplateSimple extends PdfTemplateBuilder {
  @override
  PdfTemplate get templateType => PdfTemplate.simple;

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

    // Calculate dives per page based on page size
    final divesPerPage = pageSize == PdfPageSize.a4 ? 20 : 18;

    // Header row for the table
    final headerStyle = pw.TextStyle(
      fontSize: 9,
      fontWeight: pw.FontWeight.bold,
      color: PdfColors.grey800,
    );

    const cellStyle = pw.TextStyle(fontSize: 9);

    // Process dives in pages
    for (
      var pageStart = 0;
      pageStart < dives.length;
      pageStart += divesPerPage
    ) {
      final pageDives = dives.skip(pageStart).take(divesPerPage).toList();
      final isFirstPage = pageStart == 0;

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.all(24),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header (only on first page or if space allows)
              if (isFirstPage) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      title,
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    if (diver != null)
                      pw.Text(
                        diver.name,
                        style: const pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.grey600,
                        ),
                      ),
                  ],
                ),
                pw.SizedBox(height: 4),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${dives.length} dives',
                      style: const pw.TextStyle(
                        fontSize: 10,
                        color: PdfColors.grey600,
                      ),
                    ),
                    if (dives.isNotEmpty)
                      pw.Text(
                        '${PdfSharedComponents.formatDate(dives.last.dateTime)} - ${PdfSharedComponents.formatDate(dives.first.dateTime)}',
                        style: const pw.TextStyle(
                          fontSize: 10,
                          color: PdfColors.grey600,
                        ),
                      ),
                  ],
                ),
                pw.SizedBox(height: 12),
                pw.Divider(color: PdfColors.grey400),
                pw.SizedBox(height: 8),
              ],
              // Table
              pw.Table(
                border: pw.TableBorder.all(
                  color: PdfColors.grey300,
                  width: 0.5,
                ),
                columnWidths: {
                  0: const pw.FixedColumnWidth(35), // #
                  1: const pw.FixedColumnWidth(70), // Date
                  2: const pw.FlexColumnWidth(3), // Site
                  3: const pw.FixedColumnWidth(50), // Depth
                  4: const pw.FixedColumnWidth(45), // Time
                  5: const pw.FixedColumnWidth(45), // Temp
                },
                children: [
                  // Header row
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(
                      color: PdfColors.grey100,
                    ),
                    children: [
                      _buildHeaderCell('#', headerStyle),
                      _buildHeaderCell('Date', headerStyle),
                      _buildHeaderCell('Site', headerStyle),
                      _buildHeaderCell('Depth', headerStyle),
                      _buildHeaderCell('Time', headerStyle),
                      _buildHeaderCell('Temp', headerStyle),
                    ],
                  ),
                  // Data rows
                  ...pageDives.map(
                    (dive) => pw.TableRow(
                      children: [
                        _buildCell('${dive.diveNumber ?? '-'}', cellStyle),
                        _buildCell(
                          PdfSharedComponents.formatDate(dive.dateTime),
                          cellStyle,
                        ),
                        _buildCell(
                          dive.site?.name ?? '-',
                          cellStyle,
                          align: pw.TextAlign.left,
                        ),
                        _buildCell(
                          dive.maxDepth != null
                              ? '${dive.maxDepth!.toStringAsFixed(1)}m'
                              : '-',
                          cellStyle,
                        ),
                        _buildCell(
                          dive.duration != null
                              ? '${dive.duration!.inMinutes}min'
                              : '-',
                          cellStyle,
                        ),
                        _buildCell(
                          dive.waterTemp != null
                              ? '${dive.waterTemp!.toStringAsFixed(0)}°C'
                              : '-',
                          cellStyle,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              pw.Spacer(),
              // Footer
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Generated ${PdfSharedComponents.formatDate(DateTime.now())}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey500,
                    ),
                  ),
                  pw.Text(
                    'Page ${(pageStart ~/ divesPerPage) + 1} of ${((dives.length - 1) ~/ divesPerPage) + 1}',
                    style: const pw.TextStyle(
                      fontSize: 8,
                      color: PdfColors.grey500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    // Handle empty dive list
    if (dives.isEmpty) {
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          build: (context) => pw.Center(
            child: pw.Text(
              'No dives to display',
              style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey600),
            ),
          ),
        ),
      );
    }

    return await pdf.save();
  }

  pw.Widget _buildHeaderCell(String text, pw.TextStyle style) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: pw.Text(text, style: style, textAlign: pw.TextAlign.center),
    );
  }

  pw.Widget _buildCell(
    String text,
    pw.TextStyle style, {
    pw.TextAlign align = pw.TextAlign.center,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        style: style,
        textAlign: align,
        maxLines: 1,
        overflow: pw.TextOverflow.clip,
      ),
    );
  }
}
