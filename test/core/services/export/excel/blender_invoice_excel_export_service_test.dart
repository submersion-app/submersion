import 'package:excel_community/excel_community.dart' as xl;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/services/export/excel/blender_invoice_excel_export_service.dart';
import 'package:submersion/core/services/export/models/blender_invoice_export_data.dart';

void main() {
  late BlenderInvoiceExcelExportService service;

  setUp(() => service = BlenderInvoiceExcelExportService());

  BlenderInvoiceExportData data({bool incomplete = false}) =>
      BlenderInvoiceExportData(
        date: 'Invoice dated Mar 5, 2026',
        billedTo: 'Ada',
        tariff: 'O₂ CHF 1.20/100L',
        fills: const [
          BlenderInvoiceExportFill(
            label: 'Tx 18/45',
            total: 'CHF 35.00',
            lines: [
              BlenderInvoiceExportLine(
                gas: 'O₂',
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

  /// A fill entered as a lump sum: `BilledFill.isManual` is exactly
  /// `lines.isEmpty`, so this shape reaches the export whenever a diver bills
  /// a fill without itemising its gases.
  BlenderInvoiceExportData manualFillData() => const BlenderInvoiceExportData(
    date: 'Invoice dated Mar 5, 2026',
    billedTo: '',
    tariff: '',
    fills: [
      BlenderInvoiceExportFill(
        label: 'Bench fill',
        total: 'CHF 20.00',
        lines: [],
      ),
    ],
    total: 'CHF 20.00',
    incomplete: false,
  );

  String? cellText(xl.Sheet sheet, int rowIndex, int col) {
    final value = sheet.rows[rowIndex][col]?.value;
    return value is xl.TextCellValue ? value.value.toString() : null;
  }

  test('generateBytes produces a decodable workbook without Sheet1', () {
    final bytes = service.generateBytes(data());

    expect(bytes, isNotEmpty);
    final decoded = xl.Excel.decodeBytes(bytes);
    expect(
      decoded.tables.keys,
      contains(BlenderInvoiceExcelExportService.invoiceSheet),
    );
    expect(decoded.tables.keys, isNot(contains('Sheet1')));
  });

  test('writes the invoice date, billed-to and tariff header lines', () {
    final bytes = service.generateBytes(data());
    final decoded = xl.Excel.decodeBytes(bytes);
    final sheet = decoded[BlenderInvoiceExcelExportService.invoiceSheet];

    expect(cellText(sheet, 0, 0), 'Invoice dated Mar 5, 2026');
    expect(cellText(sheet, 1, 1), 'Ada');
    expect(cellText(sheet, 2, 1), 'O₂ CHF 1.20/100L');
  });

  test('one row per gas line, with the fill label only on the first', () {
    final bytes = service.generateBytes(data());
    final decoded = xl.Excel.decodeBytes(bytes);
    final sheet = decoded[BlenderInvoiceExcelExportService.invoiceSheet];

    // Row 4 is the column header ('Fill', 'Gas', 'Volume', 'Cost', 'Total').
    expect(cellText(sheet, 5, 0), 'Tx 18/45');
    expect(cellText(sheet, 5, 1), 'O₂');
    expect(cellText(sheet, 5, 2), '30 L');
    expect(cellText(sheet, 5, 4), 'CHF 35.00');
    expect(cellText(sheet, 6, 0), '');
    expect(cellText(sheet, 6, 1), 'He');
    expect(cellText(sheet, 6, 4), '');
  });

  test('a fill with no lines keeps its label under the Fill column', () {
    final bytes = service.generateBytes(manualFillData());
    final decoded = xl.Excel.decodeBytes(bytes);
    final sheet = decoded[BlenderInvoiceExcelExportService.invoiceSheet];

    // Row 4 is the column header ('Fill', 'Gas', 'Volume', 'Cost', 'Total').
    expect(cellText(sheet, 4, 0), 'Fill');
    expect(cellText(sheet, 5, 0), 'Bench fill');
    expect(cellText(sheet, 5, 1), '');
    expect(cellText(sheet, 5, 2), '');
    expect(cellText(sheet, 5, 3), '');
    expect(cellText(sheet, 5, 4), 'CHF 20.00');
  });

  test('an incomplete total is flagged on its own row', () {
    final bytes = service.generateBytes(data(incomplete: true));
    final decoded = xl.Excel.decodeBytes(bytes);
    final sheet = decoded[BlenderInvoiceExcelExportService.invoiceSheet];

    final flagged = sheet.rows.any(
      (row) => row.any(
        (cell) =>
            cell?.value is xl.TextCellValue &&
            (cell!.value as xl.TextCellValue).value.toString().contains(
              'Incomplete',
            ),
      ),
    );
    expect(flagged, isTrue);
  });
}
