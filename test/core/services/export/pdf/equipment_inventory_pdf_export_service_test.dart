import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/pdf/equipment_inventory_pdf_export_service.dart';
import 'package:submersion/core/services/export/pdf/equipment_report_pdf_parts.dart';
import 'package:submersion/core/services/pdf_templates/pdf_localization.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/reports/inventory_report.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/pdf_roboto.dart';
import '../../../../helpers/pdf_text.dart';

EquipmentItem _item(
  String name, {
  String? serial,
  double? price,
  DateTime? bought,
  String? parent,
  String? brand,
  String? model,
  String currency = 'USD',
}) => EquipmentItem(
  id: name,
  diverId: 'me',
  name: name,
  type: EquipmentType.regulator,
  serialNumber: serial,
  purchasePrice: price,
  purchaseDate: bought,
  parentEquipmentId: parent,
  brand: brand,
  model: model,
  purchaseCurrency: currency,
);

InventoryReport _report(
  List<EquipmentItem> items, {
  InventoryReportOptions options = const InventoryReportOptions(),
  Map<String, EquipmentLocation> locations = const {},
}) => buildInventoryReport(
  items: items,
  locations: locations,
  options: options,
  diverId: 'me',
  fallbackCurrency: 'USD',
);

void main() {
  late EquipmentInventoryPdfExportService service;
  const units = UnitFormatter(AppSettings());

  setUpAll(loadPdfRoboto);
  tearDownAll(unloadPdfRoboto);

  setUp(
    () => service = EquipmentInventoryPdfExportService(
      loadTheme: (_) async => pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
    ),
  );

  Future<String> text(
    InventoryReport report, {
    InventoryReportOptions options = const InventoryReportOptions(),
    String? diverName = 'Sam Diver',
  }) async => pdfVisibleText(
    await service.generateBytes(
      report,
      options: options,
      settings: ReportPrintSettings(
        diverName: diverName,
        units: units,
        printedAt: DateTime(2026, 10, 30),
      ),
    ),
  );

  test('prints the title, diver, serial and total', () async {
    final out = await text(
      _report([
        _item(
          'Apex',
          serial: 'F-20419',
          price: 1290,
          bought: DateTime(2023, 3),
        ),
      ]),
    );

    expect(out, contains('Equipment inventory'));
    expect(out, contains('Sam Diver'));
    expect(out, contains('F-20419'));
    expect(out, contains('USD total'));
    expect(out, contains('1,290'));
    expect(out, contains('Regulator'));
    expect(out, contains('Prices are what was paid, not current value.'));
  });

  test('names the one location it covers', () async {
    final bag = EquipmentLocation(
      id: 'bag',
      name: 'Travel bag',
      kind: EquipmentLocationKind.storage,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    const options = InventoryReportOptions(locationId: 'bag');

    final out = await text(
      _report([_item('Apex')], options: options, locations: {'Apex': bag}),
      options: options,
    );

    expect(out, contains('Travel bag'));
  });

  test('prints brand and model under the item name', () async {
    final out = await text(
      _report([_item('Apex', brand: 'Apeks', model: 'XTX200')]),
    );
    expect(out, contains('Apeks XTX200'));
  });

  test('subtotals in two currencies never read as a sum', () async {
    final out = await text(
      _report([_item('a', price: 100), _item('b', price: 50, currency: 'EUR')]),
    );
    expect(out, isNot(contains(' + ')));
    expect(out, isNot(contains('+')));
  });

  test('a part prints with its own serial', () async {
    final out = await text(
      _report([
        _item('Apex'),
        _item('First stage', serial: 'F-1', parent: 'Apex'),
      ]),
    );
    expect(out, contains('First stage'));
    expect(out, contains('F-1'));
  });

  test('says how many items have no price', () async {
    final out = await text(_report([_item('a'), _item('b')]));
    expect(out, contains('2 items have no price.'));
  });

  test('a blank currency prints in the default currency', () async {
    final out = await text(_report([_item('a', price: 10, currency: '')]));
    expect(out, contains(r'$10'));
  });

  test('show prices off leaves out every amount and the note', () async {
    const options = InventoryReportOptions(showPrices: false);
    final out = await text(
      _report([_item('Apex', serial: 'S1', price: 1290)], options: options),
      options: options,
    );

    expect(out, contains('Apex'));
    expect(out, contains('S1'));
    expect(out, isNot(contains('1,290')));
    expect(out, isNot(contains('Paid')));
    expect(out, isNot(contains('total')));
    expect(out, isNot(contains('Prices are what was paid')));
  });

  test('300 items and a very long name flow onto several pages', () async {
    final out = await text(
      _report([
        for (var i = 0; i < 300; i++)
          _item('Item $i ${'with a long name ' * 6}', serial: 'SERIAL-$i'),
      ]),
    );

    expect(out, contains('SERIAL-299'));
  });

  test('the Paid column heading repeats on later pages', () async {
    final out = await text(
      _report([for (var i = 0; i < 200; i++) _item('Item $i', price: 1)]),
    );
    expect('Paid'.allMatches(out).length, greaterThan(1));
  });

  test('an Arabic localization still builds, with no diver name', () async {
    final bytes = await service.generateBytes(
      _report([_item('Apex')]),
      options: const InventoryReportOptions(),
      settings: ReportPrintSettings(
        diverName: null,
        units: units,
        printedAt: DateTime(2026, 10, 30),
        localization: PdfLocalization.forLanguageCode('ar'),
      ),
    );
    expect(bytes, isNotEmpty);
  });
}
