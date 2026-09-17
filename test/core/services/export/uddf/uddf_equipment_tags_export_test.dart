import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/services/export/uddf/uddf_full_export_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_observation.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:xml/xml.dart';

/// Equipment tags in the full backup (issue #1942).
void main() {
  final now = DateTime.utc(2026, 3, 1);
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Reg',
    type: EquipmentType.regulator,
  );
  const fins = EquipmentItem(
    id: 'fins',
    name: 'Fins',
    type: EquipmentType.fins,
  );
  final rental = Tag(
    id: 't1',
    name: 'Rental',
    createdAt: now,
    updatedAt: now,
    scopes: const {TagScope.equipment},
  );
  final night = Tag(id: 't2', name: 'Night', createdAt: now, updatedAt: now);
  final checkIn = EquipmentObservation(
    id: 'o1',
    equipmentId: 'reg',
    observedAt: now,
    status: ObservationStatus.issue,
    issueTags: const [ObservationTag.freeFlow],
    createdAt: now,
    updatedAt: now,
  );

  Future<XmlDocument> export() async => XmlDocument.parse(
    await UddfFullExportService().generateAllDataXmlForTest(
      dives: const [],
      equipment: const [reg, fins],
      observations: [checkIn],
      tags: [rental, night],
      equipmentTagIdsByItem: const {
        'reg': ['t1'],
      },
    ),
  );

  XmlElement item(XmlDocument doc, String id) => doc
      .findAllElements('item')
      .singleWhere((e) => e.getAttribute('id') == 'equip_$id');

  test('a tagged item carries its tag refs as a direct child', () async {
    final doc = await export();
    final refs = item(
      doc,
      'reg',
    ).findElements('tags').expand((t) => t.findElements('tagref'));
    expect(refs.map((e) => e.innerText), ['tag_t1']);
    expect(item(doc, 'fins').findElements('tags'), isEmpty);
  });

  test("a check-in's tags stay inside the check-in", () async {
    final doc = await export();
    final observation = item(doc, 'reg').findAllElements('observation').single;
    expect(
      observation
          .findElements('tags')
          .single
          .findElements('tag')
          .map((e) => e.innerText),
      ['freeFlow'],
    );
    expect(
      item(doc, 'reg').findElements('tags').single.findElements('tag'),
      isEmpty,
    );
  });

  test('each tag definition says whether it applies to equipment', () async {
    final doc = await export();
    String flag(String id) => doc
        .findAllElements('tag')
        .singleWhere((e) => e.getAttribute('id') == 'tag_$id')
        .findElements('appliestoequipment')
        .single
        .innerText;
    expect(flag('t1'), 'true');
    expect(flag('t2'), 'false');
  });
}
