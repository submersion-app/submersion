import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser.dart';

/// The equipment CSV carries what an item cost, both ways.
void main() {
  const priced = EquipmentItem(
    id: 'reg',
    name: 'Reg',
    type: EquipmentType.regulator,
    purchasePrice: 1290.5,
    purchaseCurrency: 'EUR',
  );
  const unpriced = EquipmentItem(
    id: 'mask',
    name: 'Mask',
    type: EquipmentType.mask,
  );

  List<List<String>> rows(String csv) => [
    for (final row in const CsvToListConverter(
      shouldParseNumbers: false,
    ).convert(csv))
      [for (final cell in row) '$cell'],
  ];

  String csvOf(List<EquipmentItem> items) =>
      CsvExportService().generateEquipmentCsvContent(items);

  Future<List<Map<String, dynamic>>> parse(String csv) async {
    final payload = await const SubmersionEquipmentCsvParser().parse(
      Uint8List.fromList(utf8.encode(csv)),
    );
    return payload.entitiesOf(ImportEntityType.equipment);
  }

  test('writes price and currency as the last two columns', () {
    final table = rows(csvOf(const [priced]));
    final header = table.first;

    expect(header.sublist(header.length - 2), [
      'Purchase Price',
      'Purchase Currency',
    ]);
    expect(header[header.length - 3], 'Location');
    expect(table[1].sublist(header.length - 2), ['1290.5', 'EUR']);
  });

  test('a blank price writes empty cells', () {
    final table = rows(csvOf(const [unpriced]));
    final width = table.first.length;

    expect(table[1].sublist(width - 2), ['', '']);
  });

  test('price and currency survive an export and import', () async {
    final items = await parse(csvOf(const [priced, unpriced]));
    final byName = {for (final item in items) item['name']: item};

    expect(byName['Reg']!['purchasePrice'], 1290.5);
    expect(byName['Reg']!['purchaseCurrency'], 'EUR');
    expect(byName['Mask']!.containsKey('purchasePrice'), isFalse);
    expect(byName['Mask']!.containsKey('purchaseCurrency'), isFalse);
  });

  test('a file without the columns imports as before', () async {
    final items = await parse('Name,Type\nOld reg,Regulator\n');

    expect(items.single['name'], 'Old reg');
    expect(items.single.containsKey('purchasePrice'), isFalse);
  });

  test('an unreadable price is left out rather than failing', () async {
    final items = await parse(
      'Name,Type,Purchase Price\nOld reg,Regulator,lots\n',
    );

    expect(items.single.containsKey('purchasePrice'), isFalse);
  });
}
