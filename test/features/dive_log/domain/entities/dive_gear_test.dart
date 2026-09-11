import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/gear_link.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';

void main() {
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
  const fins = EquipmentItem(
    id: 'fins',
    name: 'Fins',
    type: EquipmentType.fins,
  );
  final dive = Dive(
    id: 'd1',
    dateTime: DateTime(2026, 1, 1),
    gear: const [
      GearLink(item: reg, viaSetId: 'winter'),
      GearLink(item: hose, viaEquipmentId: 'reg', viaSetId: 'winter'),
      GearLink(item: fins),
    ],
  );

  test('equipment is the flat view of gear, in gear order', () {
    expect(dive.equipment, const [reg, hose, fins]);
  });

  test('gearProvenance carries the ids only', () {
    expect(dive.gearProvenance, const [
      GearProvenance(equipmentId: 'reg', viaSetId: 'winter'),
      GearProvenance(
        equipmentId: 'hose',
        viaEquipmentId: 'reg',
        viaSetId: 'winter',
      ),
      GearProvenance(equipmentId: 'fins'),
    ]);
  });

  test('looseGear wraps items as top-level rows with no set', () {
    final loose = looseGear(const [reg, fins]);
    expect(loose.map((g) => g.item), const [reg, fins]);
    expect(loose.every((g) => g.isTopLevel && g.viaSetId == null), isTrue);
  });

  test('gearLinksFor pairs items with provenance and tolerates gaps', () {
    final links = gearLinksFor(
      const [reg, hose, fins],
      const [
        GearProvenance(equipmentId: 'hose', viaEquipmentId: 'reg'),
        GearProvenance(equipmentId: 'gone', viaEquipmentId: 'reg'),
      ],
    );
    expect(links.map((g) => g.item.id), ['reg', 'hose', 'fins']);
    expect(links[0].isTopLevel, isTrue);
    expect(links[1].viaEquipmentId, 'reg');
    expect(links[2].isTopLevel, isTrue);
  });

  test('copyWith(gear:) replaces the list and equality sees it', () {
    final trimmed = dive.copyWith(gear: looseGear(const [fins]));
    expect(trimmed.equipment, const [fins]);
    expect(trimmed, isNot(equals(dive)));
    expect(dive.copyWith(), equals(dive));
  });
}
