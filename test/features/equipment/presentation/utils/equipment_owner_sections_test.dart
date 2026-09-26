import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_owner_sections.dart';

EquipmentItem item(String id, String? owner) =>
    EquipmentItem(id: id, diverId: owner, name: id, type: EquipmentType.bcd);

void main() {
  const names = {'wife': 'Zoe', 'son': 'Adam', 'owner': 'Bill'};
  String nameOf(String id) => names[id]!;

  test('own items first, then one section per owner by name', () {
    final sections = sectionsByOwner(
      [
        item('a', 'wife'),
        item('b', 'owner'),
        item('c', 'son'),
        item('d', 'wife'),
        item('e', 'owner'),
      ],
      activeDiverId: 'owner',
      ownerName: nameOf,
    );
    expect(sections.map((s) => s.ownerId), [null, 'son', 'wife']);
    expect(sections.first.items.map((i) => i.id), ['b', 'e']);
    expect(sections.last.items.map((i) => i.id), ['a', 'd']);
  });

  test('an ownerless item counts as the active diver own', () {
    final sections = sectionsByOwner(
      [item('a', null)],
      activeDiverId: 'owner',
      ownerName: nameOf,
    );
    expect(sections.single.ownerId, isNull);
  });

  test('no active diver puts everything in one section', () {
    final sections = sectionsByOwner(
      [item('a', 'wife'), item('b', 'son')],
      activeDiverId: null,
      ownerName: nameOf,
    );
    expect(sections, hasLength(1));
  });

  test('showsOwnerChip only for another owner with two or more profiles', () {
    expect(
      showsOwnerChip(item('a', 'wife'), 'owner', multipleDivers: true),
      isTrue,
    );
    expect(
      showsOwnerChip(item('a', 'owner'), 'owner', multipleDivers: true),
      isFalse,
    );
    expect(
      showsOwnerChip(item('a', 'wife'), 'owner', multipleDivers: false),
      isFalse,
    );
    expect(
      showsOwnerChip(item('a', null), 'owner', multipleDivers: true),
      isFalse,
    );
  });
}
