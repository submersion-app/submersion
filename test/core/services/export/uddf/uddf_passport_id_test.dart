import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/core/services/export/uddf/uddf_import_parsers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:xml/xml.dart';

/// Each item's passport id rides in its `<item>` (issue #2651).
void main() {
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2026, 6, 2, 10),
    bottomTime: const Duration(minutes: 45),
    maxDepth: 18.0,
    tanks: const [],
    profile: const [],
    gear: const [],
    notes: '',
    photoIds: const [],
    sightings: const [],
    weights: const [],
    tags: const [],
  );
  final tagged = EquipmentItem(
    id: 'tank-1',
    name: 'Faber 12',
    type: EquipmentType.tank,
    attributes: [
      EquipmentAttribute.curated(
        equipmentId: 'tank-1',
        key: EquipmentAttrKeys.passportId,
        valueText: 'pp-1',
      ),
    ],
  );
  const untagged = EquipmentItem(
    id: 'bcd-1',
    name: 'Wing',
    type: EquipmentType.bcd,
  );

  Future<Map<String?, XmlElement>> items() async {
    final xml = await UddfFullExportService().generateAllDataXmlForTest(
      dives: [dive],
      equipment: [tagged, untagged],
    );
    return {
      for (final e in XmlDocument.parse(xml).findAllElements('item'))
        e.getAttribute('id'): e,
    };
  }

  test(
    'an item holding a passport id writes it, another writes none',
    () async {
      final byId = await items();
      expect(
        byId['equip_tank-1']!.findElements('passportid').single.innerText,
        'pp-1',
      );
      expect(byId['equip_bcd-1']!.findElements('passportid'), isEmpty);
    },
  );

  test('the parser reads it back onto the item map', () async {
    final byId = await items();
    expect(
      UddfImportParsers.parseEquipmentItem(byId['equip_tank-1']!)['passportId'],
      'pp-1',
    );
    expect(
      UddfImportParsers.parseEquipmentItem(byId['equip_bcd-1']!)['passportId'],
      isNull,
    );
  });
}
