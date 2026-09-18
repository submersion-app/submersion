import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_row_label.dart';

final _strings = EquipmentRowLabelStrings(
  identifier: (v) => 'ID $v',
  serial: (v) => 'S/N $v',
  purchased: (v) => 'Bought $v',
  formatDate: (d) => '${d.year}-${d.month}-${d.day}',
);

EquipmentItem _pouch(
  String id, {
  String name = 'Pouches',
  String? identifier,
  String? serial,
  String? size,
  DateTime? purchased,
}) => EquipmentItem(
  id: id,
  name: name,
  type: EquipmentType.other,
  brand: 'Palantic',
  model: 'Drop-Bottom',
  serialNumber: serial,
  purchaseDate: purchased,
  attributes: [
    if (identifier != null)
      EquipmentAttribute.curated(
        equipmentId: id,
        key: EquipmentAttrKeys.identifier,
        valueText: identifier,
      ),
    if (size != null)
      EquipmentAttribute.curated(
        equipmentId: id,
        key: EquipmentAttrKeys.size,
        valueText: size,
      ),
  ],
);

void main() {
  test('subtitle is brand and model, then the identifier', () {
    final labels = buildEquipmentRowLabels([
      _pouch('a', identifier: 'P2'),
    ], _strings);
    expect(labels['a']!.title, 'Pouches');
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom · ID P2');
  });

  test('no subtitle when the name is all there is', () {
    const bare = EquipmentItem(id: 'm', name: 'Mask', type: EquipmentType.mask);
    expect(buildEquipmentRowLabels([bare], _strings)['m']!.subtitle, isNull);
  });

  test('a blank identifier is not shown', () {
    final labels = buildEquipmentRowLabels([
      _pouch('a', identifier: '  '),
    ], _strings);
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom');
  });

  test('rows that do not collide get no tie-break detail', () {
    final labels = buildEquipmentRowLabels([
      _pouch('a', identifier: 'P1', serial: 'X1'),
      _pouch('b', identifier: 'P2', serial: 'X2'),
    ], _strings);
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom · ID P1');
    expect(labels['b']!.subtitle, 'Palantic Drop-Bottom · ID P2');
  });

  test('colliding rows append the serial number first', () {
    // Fed in descending serial order: a builder that only looked at the
    // first row, or that relied on input order, would still fail here.
    final labels = buildEquipmentRowLabels([
      _pouch('b', serial: 'X2', size: 'L'),
      _pouch('a', serial: 'X1', size: 'M'),
    ], _strings);
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom · S/N X1');
    expect(labels['b']!.subtitle, 'Palantic Drop-Bottom · S/N X2');
  });

  test('size breaks the tie when the serial numbers do not differ', () {
    final labels = buildEquipmentRowLabels([
      _pouch('b', size: 'L'),
      _pouch('a', size: 'M'),
    ], _strings);
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom · M');
    expect(labels['b']!.subtitle, 'Palantic Drop-Bottom · L');
  });

  test('purchase date is the last tie-break, in the given date format', () {
    final labels = buildEquipmentRowLabels([
      _pouch('b', purchased: DateTime(2025, 6, 1)),
      _pouch('a', purchased: DateTime(2024, 3, 9)),
    ], _strings);
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom · Bought 2024-3-9');
    expect(labels['b']!.subtitle, 'Palantic Drop-Bottom · Bought 2025-6-1');
  });

  test('a row with no value for the deciding field stays as it was', () {
    final labels = buildEquipmentRowLabels([
      _pouch('a', serial: 'X1'),
      _pouch('b'),
    ], _strings);
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom · S/N X1');
    expect(labels['b']!.subtitle, 'Palantic Drop-Bottom');
  });

  test('rows a tie-break leaves colliding move on to the next one', () {
    // Four rows collide. Serial separates two of them; the two with no
    // serial still read the same, and only the purchase date can split them.
    final labels = buildEquipmentRowLabels([
      _pouch('d', purchased: DateTime(2025, 6, 1)),
      _pouch('b', serial: 'X2'),
      _pouch('c', purchased: DateTime(2024, 3, 9)),
      _pouch('a', serial: 'X1'),
    ], _strings);
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom · S/N X1');
    expect(labels['b']!.subtitle, 'Palantic Drop-Bottom · S/N X2');
    expect(labels['c']!.subtitle, 'Palantic Drop-Bottom · Bought 2024-3-9');
    expect(labels['d']!.subtitle, 'Palantic Drop-Bottom · Bought 2025-6-1');
  });

  test('a shared serial number falls through to the size', () {
    final labels = buildEquipmentRowLabels([
      _pouch('b', serial: 'X1', size: 'L'),
      _pouch('a', serial: 'X1', size: 'M'),
      _pouch('c'),
    ], _strings);
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom · S/N X1 · M');
    expect(labels['b']!.subtitle, 'Palantic Drop-Bottom · S/N X1 · L');
    expect(labels['c']!.subtitle, 'Palantic Drop-Bottom');
  });

  test('truly identical rows stay identical: no invented counter', () {
    final labels = buildEquipmentRowLabels([
      _pouch('a'),
      _pouch('b'),
    ], _strings);
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom');
    expect(labels['b']!.subtitle, 'Palantic Drop-Bottom');
  });

  test('a different name is not a collision', () {
    final labels = buildEquipmentRowLabels([
      _pouch('a', name: 'Pouches Bill', serial: 'X1'),
      _pouch('b', name: 'Pouches Laurie', serial: 'X2'),
    ], _strings);
    expect(labels['a']!.subtitle, 'Palantic Drop-Bottom');
    expect(labels['b']!.subtitle, 'Palantic Drop-Bottom');
  });

  test('the input list is not mutated', () {
    final rows = List<EquipmentItem>.unmodifiable([
      _pouch('a', serial: 'X1'),
      _pouch('b', serial: 'X2'),
    ]);
    expect(() => buildEquipmentRowLabels(rows, _strings), returnsNormally);
  });
}
