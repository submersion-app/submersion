import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// The layout the equipment reports share, so the inventory and the service
/// report read as one family.

const reportMutedColor = PdfColors.grey700;
const _groupFill = PdfColor.fromInt(0xFFEEF4F6);
const _bodySize = 9.0;

/// A report runs as long as the locker is. The `pdf` package stops at 20 pages
/// unless told otherwise, and a long service history passes that.
const reportMaxPages = 1000;

const reportMargin = pw.EdgeInsets.all(15 * PdfPageFormat.mm);

pw.Widget reportHeader({
  required String title,
  required String? diverName,
  required String printedLine,
  String? detail,
}) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    pw.Text(
      title,
      style: const pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
    ),
    pw.SizedBox(height: 2),
    pw.Text(
      [?diverName, printedLine].join(' · '),
      style: const pw.TextStyle(fontSize: _bodySize, color: reportMutedColor),
    ),
    if (detail != null)
      pw.Text(
        detail,
        style: const pw.TextStyle(fontSize: _bodySize, color: reportMutedColor),
      ),
    pw.SizedBox(height: 8),
  ],
);

/// A band of headline figures. [label] is null when [value] already reads as
/// a whole phrase, such as "38 items".
pw.Widget summaryStrip(List<({String value, String? label})> items) =>
    pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(vertical: 5),
      margin: const pw.EdgeInsets.only(bottom: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(width: 0.5, color: PdfColors.grey400),
          bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey400),
        ),
      ),
      child: pw.Wrap(
        spacing: 18,
        runSpacing: 4,
        children: [
          for (final item in items)
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  item.value,
                  style: const pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                if (item.label != null)
                  pw.Text(
                    item.label!,
                    style: const pw.TextStyle(
                      fontSize: _bodySize,
                      color: reportMutedColor,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );

pw.Widget groupHeading(String left, String? right) => pw.Container(
  color: _groupFill,
  padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
  margin: const pw.EdgeInsets.only(top: 8),
  child: pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Expanded(
        child: pw.Text(
          left,
          style: const pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
      if (right != null)
        pw.Text(
          right,
          style: const pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
    ],
  ),
);

/// One body cell. [end] pushes a figure to the trailing edge, which is the
/// left on a right-to-left page.
pw.Widget reportCell(String text, {bool end = false, PdfColor? color}) =>
    pw.Align(
      alignment: end
          ? pw.AlignmentDirectional.centerEnd
          : pw.AlignmentDirectional.centerStart,
      child: pw.Text(
        text,
        style: pw.TextStyle(fontSize: _bodySize, color: color),
      ),
    );

/// A table whose heading row repeats on every page it runs onto.
pw.Widget reportTable({
  required List<String> headers,
  required List<List<pw.Widget>> rows,
  required Map<int, pw.TableColumnWidth> columnWidths,
  Set<int> endAligned = const {},
}) {
  pw.Widget pad(pw.Widget child) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 2),
    child: child,
  );

  return pw.Table(
    columnWidths: columnWidths,
    border: const pw.TableBorder(
      horizontalInside: pw.BorderSide(width: 0.3, color: PdfColors.grey300),
    ),
    children: [
      pw.TableRow(
        repeat: true,
        decoration: const pw.BoxDecoration(
          border: pw.Border(
            bottom: pw.BorderSide(width: 0.5, color: PdfColors.grey500),
          ),
        ),
        children: [
          for (final (index, header) in headers.indexed)
            pad(
              reportCell(
                header,
                end: endAligned.contains(index),
                color: reportMutedColor,
              ),
            ),
        ],
      ),
      for (final row in rows)
        pw.TableRow(children: [for (final cell in row) pad(cell)]),
    ],
  );
}

pw.Widget reportFootnote(String text) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 8),
  child: pw.Text(
    text,
    style: const pw.TextStyle(fontSize: 8, color: reportMutedColor),
  ),
);
