import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/csv/csv_export_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/parsers/submersion_csv/submersion_equipment_csv_parser.dart';

/// The equipment CSV carries each item's current location both ways (v268).
void main() {
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Reg',
    type: EquipmentType.regulator,
  );
  const mask = EquipmentItem(
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

  String csvOf(Map<String, String> locationNames) =>
      CsvExportService().generateEquipmentCsvContent(const [
        reg,
        mask,
      ], locationNames: locationNames);

  test('a Location column is appended last and holds the current place', () {
    final table = rows(csvOf(const {'reg': 'Garage bin 2'}));
    final at = table.first.indexOf('Location');
    expect(at, table.first.length - 1);
    expect(table.first[at - 1], 'Notes');
    expect(table[1][at], 'Garage bin 2');
    expect(table[2][at], '', reason: 'no location gets an empty cell');
  });

  test('a place name starting with a formula character is guarded', () {
    final table = rows(csvOf(const {'reg': '=Garage'}));
    expect(table[1][table.first.indexOf('Location')], "'=Garage");
  });

  test('the importer reads the place name back, blank cells add '
      'nothing', () async {
    final payload = await const SubmersionEquipmentCsvParser().parse(
      Uint8List.fromList(utf8.encode(csvOf(const {'reg': '=Garage'}))),
    );
    final items = payload.entitiesOf(ImportEntityType.equipment);
    final byName = {for (final i in items) i['name']: i};
    expect(byName['Reg']!['locationName'], '=Garage');
    expect(byName['Mask']!.containsKey('locationName'), isFalse);
  });
}
