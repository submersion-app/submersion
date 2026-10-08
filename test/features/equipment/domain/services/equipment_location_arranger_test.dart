import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/domain/services/equipment_location_arranger.dart';

void main() {
  EquipmentLocation place(
    String id,
    String name,
    EquipmentLocationKind kind, {
    bool archived = false,
  }) => EquipmentLocation(
    id: id,
    name: name,
    kind: kind,
    isArchived: archived,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
  EquipmentItem item(String id, EquipmentType type) =>
      EquipmentItem(id: id, name: id, type: type);

  final shop = place('shop', 'Shop', EquipmentLocationKind.serviceShop);
  final garage = place('garage', 'Garage', EquipmentLocationKind.storage);
  final attic = place(
    'attic',
    'Attic',
    EquipmentLocationKind.storage,
    archived: true,
  );

  final items = [
    item('reg', EquipmentType.regulator),
    item('bcd', EquipmentType.bcd),
    item('fins', EquipmentType.fins),
    item('mask', EquipmentType.mask),
  ];
  final locationOf = {'reg': shop, 'bcd': garage, 'fins': attic};

  List<EquipmentLocationSection> arrange(
    List<EquipmentItem> items,
    Map<String, EquipmentLocation> locationOf, {
    EquipmentArrangement arrangement = EquipmentArrangement.defaults,
  }) => arrangeEquipmentByLocation(
    items,
    arrangement,
    locationOf: locationOf,
    typeLabel: (t) => t.name,
  );

  test('storage before service shop, names within a kind, no location '
      'last', () {
    final sections = arrange(items, locationOf);
    expect(
      [for (final s in sections) s.location?.id],
      ['attic', 'garage', 'shop', null],
    );
    expect([for (final s in sections) s.itemCount], [1, 1, 1, 1]);
  });

  test('archived place still heads its items', () {
    final sections = arrange(items, locationOf);
    expect(sections.first.location!.isArchived, isTrue);
    expect(sections.first.groups.expand((g) => g.items).single.id, 'fins');
  });

  test('type sub-groups inside a place follow the arrangement', () {
    final two = [
      item('a', EquipmentType.regulator),
      item('b', EquipmentType.bcd),
    ];
    final grouped = arrange(two, {'a': garage, 'b': garage});
    expect(grouped.single.groups.map((g) => g.type), [
      EquipmentType.bcd,
      EquipmentType.regulator,
    ]);
    final flat = arrange(two, {
      'a': garage,
      'b': garage,
    }, arrangement: EquipmentArrangement.defaults.copyWith(groupByType: false));
    expect(flat.single.groups.single.type, isNull);
    expect(flat.single.itemCount, 2);
  });

  test('place names sort as the picker sorts them, accents folded', () {
    // Plain code-unit order puts the accented name after 'Zeta'.
    final ecurie = place('e', '\u00c9curie', EquipmentLocationKind.storage);
    final zeta = place('z', 'Zeta', EquipmentLocationKind.storage);
    final sections = arrange(
      [item('a', EquipmentType.fins), item('b', EquipmentType.mask)],
      {'a': zeta, 'b': ecurie},
    );
    expect([for (final s in sections) s.location?.id], ['e', 'z']);
  });

  test('no items gives no sections', () {
    expect(arrange(const [], locationOf), isEmpty);
  });
}
