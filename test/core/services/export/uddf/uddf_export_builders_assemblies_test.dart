import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_export_builders.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

/// Assemblies in the private block (issue #1487): `<components>` carries
/// the template, `<gearlinks>` carries each dive's provenance rows.
void main() {
  final t0 = DateTime(2026, 1, 1);
  final part = EquipmentComponent(
    id: 'c1',
    parentEquipmentId: 'reg',
    componentEquipmentId: 'hose',
    role: 'Primary hose',
    sortOrder: 0,
    createdAt: t0,
    updatedAt: t0,
  );
  final blankRole = EquipmentComponent(
    id: 'c2',
    parentEquipmentId: 'reg',
    componentEquipmentId: 'first',
    sortOrder: 1,
    createdAt: t0,
    updatedAt: t0,
  );
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Reg',
    type: EquipmentType.regulator,
  );
  const hose = EquipmentItem(
    id: 'hose',
    name: 'Hose',
    type: EquipmentType.hose,
  );
  final dive = Dive(
    id: 'd1',
    dateTime: DateTime(2026, 3, 1),
    gear: gearLinksFor(
      const [reg, hose],
      const [
        GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
        GearProvenance(
          equipmentId: 'hose',
          viaEquipmentId: 'reg',
          viaSetId: 'winter',
        ),
      ],
    ),
  );
  final loose = Dive(
    id: 'd2',
    dateTime: DateTime(2026, 3, 2),
    gear: looseGear(const [reg]),
  );

  XmlDocument build({
    List<EquipmentComponent>? components,
    List<Dive>? gearLinkDives,
  }) {
    final builder = XmlBuilder();
    builder.element(
      'root',
      nest: () => UddfExportBuilders.buildApplicationData(
        builder,
        components: components,
        gearLinkDives: gearLinkDives,
      ),
    );
    return XmlDocument.parse(builder.buildDocument().toXmlString());
  }

  test('writes components with prefixed refs, role and order', () {
    final xml = build(components: [part, blankRole]);
    final elements = xml.findAllElements('component').toList();
    expect(elements, hasLength(2));
    expect(elements[0].getAttribute('parent'), 'equip_reg');
    expect(elements[0].getAttribute('component'), 'equip_hose');
    expect(elements[0].getAttribute('order'), '0');
    expect(elements[0].findElements('role').single.innerText, 'Primary hose');
    expect(elements[1].getAttribute('order'), '1');
    expect(elements[1].findElements('role'), isEmpty);
  });

  test('writes gear links per dive, only for rows with provenance', () {
    final xml = build(gearLinkDives: [dive, loose]);
    final dives = xml
        .findAllElements('gearlinks')
        .single
        .findElements('dive')
        .toList();
    expect(dives, hasLength(1));
    expect(dives.single.getAttribute('ref'), 'dive_d1');
    final links = dives.single.findElements('link').toList();
    expect(links, hasLength(2));
    expect(links[0].getAttribute('item'), 'equip_reg');
    expect(links[0].getAttribute('via'), isNull);
    expect(links[0].getAttribute('set'), 'set_winter');
    expect(links[1].getAttribute('item'), 'equip_hose');
    expect(links[1].getAttribute('via'), 'equip_reg');
    expect(links[1].getAttribute('set'), 'set_winter');
  });

  test('omits both sections, and the block, when there is nothing', () {
    final xml = build(gearLinkDives: [loose]);
    expect(xml.findAllElements('applicationdata'), isEmpty);
    expect(xml.findAllElements('components'), isEmpty);
    expect(xml.findAllElements('gearlinks'), isEmpty);
  });
}
