import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';

final _first = EquipmentItem(
  id: 'first',
  name: 'First',
  type: EquipmentType.firstStage,
  serialNumber: 'FS-1',
  purchaseDate: DateTime(2025, 5, 1),
  purchasePrice: 450,
  purchaseCurrency: 'EUR',
  parentEquipmentId: 'reg',
);
const _reg = EquipmentItem(
  id: 'reg',
  name: 'Reg',
  type: EquipmentType.regulator,
);

XmlElement _item(
  List<EquipmentItem> equipment,
  String id, {
  bool omitPurchaseDetails = false,
}) {
  final builder = XmlBuilder();
  builder.element(
    'uddf',
    nest: () => UddfExportBuilders.buildApplicationData(
      builder,
      equipment: equipment,
      omitPurchaseDetails: omitPurchaseDetails,
    ),
  );
  return builder
      .buildDocument()
      .findAllElements('item')
      .singleWhere((e) => e.getAttribute('id') == 'equip_$id');
}

void main() {
  test('a backup keeps the purchase details', () {
    final item = _item([_reg, _first], 'first');
    expect(item.findElements('purchasedate'), hasLength(1));
    expect(item.findElements('purchaseprice').single.innerText, '450.0');
    expect(item.findElements('purchasecurrency').single.innerText, 'EUR');
  });

  test('omitPurchaseDetails drops them and keeps everything else', () {
    final item = _item([_reg, _first], 'first', omitPurchaseDetails: true);
    expect(item.findElements('purchasedate'), isEmpty);
    expect(item.findElements('purchaseprice'), isEmpty);
    expect(item.findElements('purchasecurrency'), isEmpty);
    expect(item.findElements('name').single.innerText, 'First');
    expect(item.findElements('serialnumber').single.innerText, 'FS-1');
  });

  test('parentref is written when the parent is in the file', () {
    final item = _item([_reg, _first], 'first');
    expect(item.findElements('parentref').single.innerText, 'equip_reg');
  });

  test('parentref is dropped when the parent is not in the file', () {
    final item = _item([_first], 'first');
    expect(item.findElements('parentref'), isEmpty);
  });
}
