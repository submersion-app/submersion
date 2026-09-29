import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';

import 'package:submersion/core/services/export/models/blender_invoice_export_data.dart';
import 'package:submersion/core/services/export/pdf/blender_invoice_pdf_export_service.dart';

import '../../../../helpers/pdf_roboto.dart';
import '../../../../helpers/pdf_text.dart';

void main() {
  late BlenderInvoicePdfExportService service;

  // The Unicode font test uses the production theme, which loads Roboto.
  // Loading it from the Flutter SDK keeps that test off the network.
  setUpAll(loadPdfRoboto);
  tearDownAll(unloadPdfRoboto);

  // Helvetica keeps the text readable by pdfVisibleText; production embeds
  // Roboto (asserted by the Unicode font test below).
  setUp(
    () => service = BlenderInvoicePdfExportService(
      loadTheme: (_) async => pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    ),
  );

  BlenderInvoiceExportData data({bool incomplete = false}) =>
      BlenderInvoiceExportData(
        date: 'Invoice dated Mar 5, 2026',
        billedTo: 'Ada',
        tariff: 'O2 CHF 1.20/100L',
        fills: const [
          BlenderInvoiceExportFill(
            label: 'Tx 18/45',
            total: 'CHF 35.00',
            lines: [
              BlenderInvoiceExportLine(
                gas: 'O2',
                volume: '30 L',
                cylinder: '12 L',
                cost: 'CHF 10.00',
              ),
              BlenderInvoiceExportLine(
                gas: 'He',
                volume: '240 L',
                cylinder: '',
                cost: 'CHF 25.00',
              ),
            ],
          ),
        ],
        total: incomplete ? '' : 'CHF 35.00',
        incomplete: incomplete,
      );

  test('the invoice date, billed-to and tariff appear at the top', () async {
    final bytes = await service.generateBytes(data());
    final text = pdfVisibleText(bytes);

    expect(text, contains('Invoice dated Mar 5, 2026'));
    expect(text, contains('Ada'));
    expect(text, contains('CHF 1.20/100L'));
  });

  test('every fill and its gas lines are itemised', () async {
    final bytes = await service.generateBytes(data());
    final text = pdfVisibleText(bytes);

    expect(text, contains('Tx 18/45'));
    expect(text, contains('30 L'));
    expect(text, contains('240 L'));
    expect(text, contains('Total'));
    expect(text, contains('35.00'));
  });

  test('the cylinder size prints for a line that has one, a dash for one '
      'that predates cylinder tracking', () async {
    final bytes = await service.generateBytes(data());
    final text = pdfVisibleText(bytes);

    expect(text, contains('12 L'));
    // A plain hyphen, not an em dash: Helvetica in the pdf package has no
    // glyph for U+2014 and silently drops it from the rendered text.
    expect(text, contains('-'));
  });

  test('an incomplete total is flagged in the document', () async {
    final bytes = await service.generateBytes(data(incomplete: true));
    final text = pdfVisibleText(bytes);

    expect(text, contains('Incomplete'));
  });

  test('prints its own labels in the app language (#2252)', () async {
    final de = PdfLocalization.forLanguageCode('de');

    final text = pdfVisibleText(
      await service.generateBytes(data(incomplete: true), localization: de),
    );

    expect(text, contains(de.l10n.pdf_blenderIncomplete));
    expect(text, isNot(contains('Incomplete')));
  });

  test('embeds a Unicode font, so Hungarian ő and ű print (#2252)', () async {
    // Built-in Helvetica stops at U+00FF and prints a box for anything past
    // it, which Hungarian labels such as "Időtartam" need.
    final bytes = await BlenderInvoicePdfExportService().generateBytes(
      data(incomplete: true),
      localization: PdfLocalization.forLanguageCode('hu'),
    );

    expect(
      String.fromCharCodes(bytes.map((b) => b & 0xFF)),
      contains('FontFile'),
    );
  });
}
