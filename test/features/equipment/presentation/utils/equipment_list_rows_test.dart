import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/domain/services/equipment_location_arranger.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_list_rows.dart';

EquipmentItem _item(String id, EquipmentType type) =>
    EquipmentItem(id: id, name: id, type: type);

EquipmentLocation _place(String id) => EquipmentLocation(
  id: id,
  name: id,
  kind: EquipmentLocationKind.storage,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

List<String> _kinds(EquipmentRowLayout layout) => [
  for (final row in layout.rows)
    switch (row) {
      EquipmentLocationHeadingRow(:final foldKey) => 'L $foldKey',
      EquipmentTypeHeadingRow(:final foldKey) => 'T $foldKey',
      EquipmentItemRow(:final item) => 'I ${item.id}',
    },
];

/// The Equipment list's rows with folds applied (issue #4184).
void main() {
  final bcd1 = _item('bcd1', EquipmentType.bcd);
  final bcd2 = _item('bcd2', EquipmentType.bcd);
  final reg1 = _item('reg1', EquipmentType.regulator);
  final typed = [
    EquipmentGroup(type: EquipmentType.bcd, items: [bcd1, bcd2]),
    EquipmentGroup(type: EquipmentType.regulator, items: [reg1]),
  ];
  final sections = [
    EquipmentLocationSection(
      location: _place('g'),
      groups: [
        EquipmentGroup(type: EquipmentType.bcd, items: [bcd1]),
        EquipmentGroup(type: EquipmentType.regulator, items: [reg1]),
      ],
    ),
    EquipmentLocationSection(
      location: null,
      groups: [
        EquipmentGroup(type: EquipmentType.bcd, items: [bcd2]),
      ],
    ),
  ];

  test('ungrouped list has no headers', () {
    final layout = layoutEquipmentRows(
      groups: [
        EquipmentGroup(type: null, items: [bcd1, reg1]),
      ],
      collapsed: const {},
    );
    expect(_kinds(layout), ['I bcd1', 'I reg1']);
    expect(layout.outerKeys, isEmpty);
    expect(layout.navStops.keys, ['bcd1', 'reg1']);
  });

  test('type groups only', () {
    final layout = layoutEquipmentRows(groups: typed, collapsed: const {});
    expect(_kinds(layout), [
      'T type:bcd',
      'I bcd1',
      'I bcd2',
      'T type:regulator',
      'I reg1',
    ]);
    expect(layout.outerKeys, ['type:bcd', 'type:regulator']);
  });

  test('by location nests types', () {
    final layout = layoutEquipmentRows(
      groups: typed,
      sections: sections,
      collapsed: const {},
    );
    expect(_kinds(layout), [
      'L loc:g',
      'T loc:g/type:bcd',
      'I bcd1',
      'T loc:g/type:regulator',
      'I reg1',
      'L loc:none',
      'T loc:none/type:bcd',
      'I bcd2',
    ]);
    expect(layout.outerKeys, ['loc:g', 'loc:none']);
    final first = layout.rows.first as EquipmentLocationHeadingRow;
    expect(first.isFirst, isTrue);
    expect((layout.rows[5] as EquipmentLocationHeadingRow).isFirst, isFalse);
    expect((layout.rows[1] as EquipmentTypeHeadingRow).parentKey, 'loc:g');
  });

  test('folded location hides its types and items, keeps its type counts', () {
    final layout = layoutEquipmentRows(
      groups: typed,
      sections: sections,
      collapsed: const {'loc:g'},
    );
    expect(_kinds(layout), [
      'L loc:g',
      'L loc:none',
      'T loc:none/type:bcd',
      'I bcd2',
    ]);
    final garage = layout.rows.first as EquipmentLocationHeadingRow;
    expect(garage.isExpanded, isFalse);
    expect(garage.typeCounts, [
      (EquipmentType.bcd, 1),
      (EquipmentType.regulator, 1),
    ]);
    expect(garage.items.map((e) => e.id), ['bcd1', 'reg1']);
  });

  test('folded type under an open location', () {
    final layout = layoutEquipmentRows(
      groups: typed,
      sections: sections,
      collapsed: const {'loc:g/type:bcd'},
    );
    expect(_kinds(layout).take(4), [
      'L loc:g',
      'T loc:g/type:bcd',
      'T loc:g/type:regulator',
      'I reg1',
    ]);
    expect((layout.rows[1] as EquipmentTypeHeadingRow).isExpanded, isFalse);
  });

  test('stale key folds nothing', () {
    final stale = layoutEquipmentRows(
      groups: typed,
      sections: sections,
      collapsed: const {'loc:deleted'},
    );
    final open = layoutEquipmentRows(
      groups: typed,
      sections: sections,
      collapsed: const {},
    );
    expect(_kinds(stale), _kinds(open));
  });

  test('foldKeysByItem lists outer then inner, folded or not', () {
    final layout = layoutEquipmentRows(
      groups: typed,
      sections: sections,
      collapsed: const {'loc:g'},
    );
    expect(layout.foldKeysByItem['bcd1'], ['loc:g', 'loc:g/type:bcd']);
    expect(layout.foldKeysByItem['bcd2'], ['loc:none', 'loc:none/type:bcd']);
  });

  test('nav stops skip folded rows and know each row header', () {
    final layout = layoutEquipmentRows(
      groups: typed,
      collapsed: const {'type:bcd'},
    );
    final bcdHeader = equipmentGroupNavKey('type:bcd');
    final regHeader = equipmentGroupNavKey('type:regulator');
    expect(layout.navStops.keys, [bcdHeader, regHeader, 'reg1']);
    expect(layout.navStops.groupOfHeader(bcdHeader), 'type:bcd');
    expect(layout.navStops.headerFor('reg1'), regHeader);
  });

  test('a nested type header knows its parent for Left', () {
    final layout = layoutEquipmentRows(
      groups: typed,
      sections: sections,
      collapsed: const {},
    );
    expect(
      layout.navStops.parentHeaderOf(equipmentGroupNavKey('loc:g/type:bcd')),
      equipmentGroupNavKey('loc:g'),
    );
    expect(
      layout.navStops.headerFor('bcd1'),
      equipmentGroupNavKey('loc:g/type:bcd'),
    );
  });

  test('ungrouped items inside a place fold into the place', () {
    final layout = layoutEquipmentRows(
      groups: const [],
      sections: [
        EquipmentLocationSection(
          location: _place('g'),
          groups: [
            EquipmentGroup(type: null, items: [bcd1]),
          ],
        ),
      ],
      collapsed: const {},
    );
    expect(_kinds(layout), ['L loc:g', 'I bcd1']);
    expect(layout.navStops.headerFor('bcd1'), equipmentGroupNavKey('loc:g'));
    expect(layout.foldKeysByItem['bcd1'], ['loc:g']);
  });
}
