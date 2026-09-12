import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/models/uddf_export_options.dart';
import 'package:submersion/core/services/export/uddf/uddf_dives_extras.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_source_export.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';

/// Issue #1718: the dives-only UDDF carries the gear and dive computer used
/// on each dive, in the full export's shapes, without purchase details.
final _epoch = DateTime(2024, 1, 1);

const _reg = EquipmentItem(
  id: 'reg',
  name: 'Reg',
  type: EquipmentType.regulator,
);
final _first = EquipmentItem(
  id: 'first',
  name: 'First',
  type: EquipmentType.firstStage,
  purchasePrice: 450,
  purchaseDate: DateTime(2025, 5, 1),
  parentEquipmentId: 'reg',
);
const _fins = EquipmentItem(id: 'fins', name: 'Fins', type: EquipmentType.fins);

final _dive = Dive(
  id: 'd1',
  dateTime: DateTime(2026, 3, 1, 9),
  diveComputerModel: 'Perdix AI',
  diveComputerSerial: 'SN1',
  gear: [
    const GearLink(item: _reg),
    GearLink(item: _first, viaEquipmentId: 'reg'),
  ],
);
final _other = Dive(
  id: 'd2',
  dateTime: DateTime(2026, 3, 1, 14),
  gear: looseGear([_fins]),
);

final _extras = UddfDivesExtras(
  components: [
    EquipmentComponent(
      id: 'c1',
      parentEquipmentId: 'reg',
      componentEquipmentId: 'first',
      role: 'First stage',
      createdAt: _epoch,
      updatedAt: _epoch,
    ),
    // Its parent is not on an exported dive, so it must not be written.
    EquipmentComponent(
      id: 'c2',
      parentEquipmentId: 'not-exported',
      componentEquipmentId: 'fins',
      createdAt: _epoch,
      updatedAt: _epoch,
    ),
  ],
);

final _source = DiveSourceExport(
  id: 'src-a',
  diveId: 'd1',
  ordinal: 0,
  isPrimary: true,
  importedAt: DateTime(2026, 3, 1, 18),
  createdAt: DateTime(2026, 3, 1, 18),
  rawData: Uint8List.fromList([1, 2, 3, 4]),
  computerModel: 'Perdix AI',
  computerSerial: 'SN1',
);

Future<XmlDocument> _export({
  UddfExportOptions options = const UddfExportOptions(),
}) async => XmlDocument.parse(
  await UddfExportService().generateDivesUddfContent(
    [_dive, _other],
    extras: _extras,
    dataSources: [_source],
    options: options,
  ),
);

XmlElement _submersion(XmlDocument doc) => doc.rootElement.childElements
    .singleWhere((e) => e.name.local == 'applicationdata')
    .findElements('submersion')
    .single;

void main() {
  test('declares the computer under an id-only owner', () async {
    final doc = await _export();
    final owner = doc.rootElement
        .findElements('diver')
        .single
        .findElements('owner')
        .single;
    expect(owner.getAttribute('id'), 'owner');
    expect(owner.findElements('personal'), isEmpty);
    expect(
      owner.findAllElements('divecomputer').single.getAttribute('id'),
      'dc_Perdix_AI_SN1',
    );
  });

  test('the dump links to the declared computer', () async {
    final doc = await _export();
    final dump = doc.findAllElements('divecomputerdump').single;
    expect(dump.findElements('link').map((e) => e.getAttribute('ref')), [
      'dive_d1',
      'dc_Perdix_AI_SN1',
    ]);
  });

  test('each dive lists its gear and computer', () async {
    final doc = await _export();
    final used = doc
        .findAllElements('dive')
        .singleWhere((e) => e.getAttribute('id') == 'dive_d1')
        .findAllElements('equipmentused')
        .single;
    expect(used.findElements('equipmentref').map((e) => e.innerText), [
      'equip_reg',
      'equip_first',
    ]);
    expect(
      used.findElements('link').single.getAttribute('ref'),
      'dc_Perdix_AI_SN1',
    );
  });

  test('items are declared once, without purchase details', () async {
    final submersion = _submersion(await _export());
    final items = submersion
        .findElements('equipment')
        .single
        .findElements('item')
        .toList();
    expect(items.map((e) => e.getAttribute('id')), [
      'equip_reg',
      'equip_first',
      'equip_fins',
    ]);
    expect(submersion.findAllElements('purchaseprice'), isEmpty);
    expect(submersion.findAllElements('purchasedate'), isEmpty);
    expect(items[1].findElements('parentref').single.innerText, 'equip_reg');
  });

  test('components and gear links cover exported items only', () async {
    final submersion = _submersion(await _export());
    final components = submersion
        .findElements('components')
        .single
        .findElements('component')
        .toList();
    expect(components, hasLength(1));
    expect(components.single.getAttribute('parent'), 'equip_reg');
    final links = submersion.findElements('gearlinks').single;
    expect(links.findElements('dive').single.getAttribute('ref'), 'dive_d1');
    expect(
      links.findAllElements('link').single.getAttribute('via'),
      'equip_reg',
    );
  });

  test('every private section shares the one wrapper', () async {
    final doc = await _export();
    expect(
      doc.rootElement.childElements.where(
        (e) => e.name.local == 'applicationdata',
      ),
      hasLength(1),
    );
    expect(_submersion(doc).findElements('datasources'), hasLength(1));
    expect(
      doc.rootElement.childElements.last.name.local,
      'divecomputercontrol',
    );
  });

  test('leaving gear out writes none of it', () async {
    final doc = await _export(
      options: const UddfExportOptions(includeGear: false),
    );
    expect(doc.findAllElements('owner'), isEmpty);
    expect(doc.findAllElements('divecomputer'), isEmpty);
    expect(doc.findAllElements('equipmentused'), isEmpty);
    expect(doc.findAllElements('item'), isEmpty);
    expect(doc.findAllElements('components'), isEmpty);
    expect(doc.findAllElements('gearlinks'), isEmpty);
    final dump = doc.findAllElements('divecomputerdump').single;
    expect(dump.findElements('link').map((e) => e.getAttribute('ref')), [
      'dive_d1',
    ]);
  });
}
