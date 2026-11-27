import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/equipment_detail_sections.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/equipment_detail_section_cards.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_edit_cards.dart';

EquipmentItem _item(EquipmentType type, {bool wanted = false}) => EquipmentItem(
  id: 'g1',
  name: 'Item',
  type: type,
  status: wanted ? EquipmentStatus.wanted : EquipmentStatus.active,
  createdAt: DateTime(2026),
);

Set<EquipmentDetailSectionId> _applying(
  EquipmentItem item, {
  bool creating = false,
  bool multipleDivers = false,
}) => {
  for (final id in EquipmentDetailSectionId.values)
    if (equipmentDetailSectionApplies(
      id,
      item,
      creating: creating,
      multipleDivers: multipleDivers,
    ))
      id,
};

void main() {
  test('every mapped card is one the page edits', () {
    for (final card in equipmentDetailSectionCards.values) {
      expect(gearItemEditCards.containsKey(card), isTrue, reason: card.name);
    }
  });

  test('a regulator has none of the type-bound cards', () {
    final shown = _applying(_item(EquipmentType.regulator));
    expect(shown, isNot(contains(EquipmentDetailSectionId.diveComputer)));
    expect(shown, isNot(contains(EquipmentDetailSectionId.transmitter)));
    expect(shown, isNot(contains(EquipmentDetailSectionId.twinSet)));
    expect(shown, isNot(contains(EquipmentDetailSectionId.unitConfigurations)));
    expect(shown, isNot(contains(EquipmentDetailSectionId.sharingHistory)));
    expect(shown, contains(EquipmentDetailSectionId.passport));
    expect(shown, contains(EquipmentDetailSectionId.serviceClocks));
  });

  test('each type-bound card belongs to its type', () {
    expect(
      _applying(_item(EquipmentType.computer)),
      contains(EquipmentDetailSectionId.diveComputer),
    );
    expect(
      _applying(_item(EquipmentType.transmitter)),
      contains(EquipmentDetailSectionId.transmitter),
    );
    expect(
      _applying(_item(EquipmentType.tank)),
      containsAll([
        EquipmentDetailSectionId.twinSet,
        EquipmentDetailSectionId.passport,
      ]),
    );
    expect(
      _applying(_item(EquipmentType.rebreather)),
      containsAll([
        EquipmentDetailSectionId.unitConfigurations,
        EquipmentDetailSectionId.childItems,
      ]),
    );
  });

  test('wishlist gear has no service clocks and, but for a cylinder, '
      'no passport', () {
    final wanted = _applying(_item(EquipmentType.regulator, wanted: true));
    expect(wanted, isNot(contains(EquipmentDetailSectionId.serviceClocks)));
    expect(wanted, isNot(contains(EquipmentDetailSectionId.passport)));
    expect(
      _applying(_item(EquipmentType.tank, wanted: true)),
      contains(EquipmentDetailSectionId.passport),
    );
  });

  test('the sharing history needs two or more profiles', () {
    expect(
      _applying(_item(EquipmentType.regulator), multipleDivers: true),
      contains(EquipmentDetailSectionId.sharingHistory),
    );
  });

  test('an item not yet created shows only the cards of its own values', () {
    expect(_applying(_item(EquipmentType.computer), creating: true), {
      EquipmentDetailSectionId.details,
      EquipmentDetailSectionId.location,
      EquipmentDetailSectionId.serviceClocks,
      EquipmentDetailSectionId.notes,
      EquipmentDetailSectionId.documents,
    });
  });
}
