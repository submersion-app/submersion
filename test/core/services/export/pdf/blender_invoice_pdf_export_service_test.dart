import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/export/models/blender_invoice_export_data.dart';
import 'package:submersion/core/services/export/pdf/blender_invoice_pdf_export_service.dart';

import '../../../../helpers/pdf_text.dart';

void main() {
  late BlenderInvoicePdfExportService service;

  setUp(() => service = BlenderInvoicePdfExportService());

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
                cost: 'CHF 10.00',
              ),
              BlenderInvoiceExportLine(
                gas: 'He',
                volume: '240 L',
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

  test('an incomplete total is flagged in the document', () async {
    final bytes = await service.generateBytes(data(incomplete: true));
    final text = pdfVisibleText(bytes);

    expect(text, contains('Incomplete'));
  });
}
