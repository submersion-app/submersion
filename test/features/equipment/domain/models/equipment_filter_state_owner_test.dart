import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';

void main() {
  final items = [
    const EquipmentItem(
      id: 'a',
      diverId: 'owner',
      name: 'a',
      type: EquipmentType.bcd,
    ),
    const EquipmentItem(
      id: 'b',
      diverId: 'wife',
      name: 'b',
      type: EquipmentType.bcd,
    ),
  ];

  List<String> ids(EquipmentOwnerFilter f) => [
    for (final i in EquipmentFilterState(
      owner: f,
    ).apply(items, const {}, activeDiverId: 'owner'))
      i.id,
  ];

  test('owner axis', () {
    expect(ids(EquipmentOwnerFilter.all), ['a', 'b']);
    expect(ids(EquipmentOwnerFilter.mine), ['a']);
    expect(ids(EquipmentOwnerFilter.sharedWithMe), ['b']);
  });

  test(
    'a non-default owner counts as an active filter and survives copyWith',
    () {
      const f = EquipmentFilterState(owner: EquipmentOwnerFilter.mine);
      expect(f.hasActiveFilters, isTrue);
      expect(f.copyWith(clearType: true).owner, EquipmentOwnerFilter.mine);
      expect(f, const EquipmentFilterState(owner: EquipmentOwnerFilter.mine));
      expect(f == const EquipmentFilterState(), isFalse);
    },
  );
}
