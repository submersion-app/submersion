import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:submersion/core/services/export/pdf/passport_label_pdf_export_service.dart';

import '../../../../helpers/pdf_text.dart';

void main() {
  // Helvetica keeps the text readable by pdfVisibleText; production uses the
  // shared Roboto loader.
  PassportLabelPdfExportService service() => PassportLabelPdfExportService(
    loadTheme: () async => pw.ThemeData.withFont(
      base: pw.Font.helvetica(),
      bold: pw.Font.helveticaBold(),
    ),
  );

  const url =
      'https://submersion.app/c#f=1&p=8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';

  test('one label carries the title, subtitle and spec', () async {
    final bytes = await service().generateBytes([
      const PassportLabelData(
        title: 'Faber 12',
        subtitle: 'S12-A',
        specLine: '12 L, 232 bar, steel',
        url: url,
      ),
    ]);
    final text = pdfVisibleText(bytes);
    expect(text, contains('Faber 12'));
    expect(text, contains('S12-A'));
    expect(text, contains('12 L, 232 bar, steel'));
    expect(pdfPageCount(bytes), 1);
  });

  test('twenty-four labels fill one A4 sheet, three to a row', () async {
    final page = await service().generateBytes([
      for (var i = 0; i < 24; i++)
        PassportLabelData(title: 'Tank $i', url: '$url&n=Tank+$i'),
    ]);
    expect(pdfPageCount(page), 1);
    final more = await service().generateBytes([
      for (var i = 0; i < 25; i++)
        PassportLabelData(title: 'Tank $i', url: '$url&n=Tank+$i'),
    ]);
    expect(pdfPageCount(more), 2);
  });

  test('ten labels fit on one A4 sheet', () async {
    final bytes = await service().generateBytes([
      for (var i = 0; i < 10; i++)
        PassportLabelData(title: 'Tank $i', url: '$url&n=Tank+$i'),
    ]);
    expect(pdfPageCount(bytes), 1);
  });

  test('an empty list still produces a document', () async {
    final bytes = await service().generateBytes(const []);
    expect(pdfPageCount(bytes), 1);
  });
}
