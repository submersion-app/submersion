import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/domain/services/components_index.dart';
import 'package:submersion/features/equipment/domain/services/equipment_location_arranger.dart';
import 'package:submersion/features/equipment/domain/services/equipment_part_tree.dart';
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

  group('assembly view (#5071)', () {
    EquipmentItem item(String id, EquipmentType type, {String? host}) =>
        EquipmentItem(id: id, name: id, type: type, parentEquipmentId: host);
    EquipmentComponent edge(String parent, String part, int order) =>
        EquipmentComponent(
          id: '$parent-$part',
          parentEquipmentId: parent,
          componentEquipmentId: part,
          sortOrder: order,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
    EquipmentPartTree tree(
      List<EquipmentItem> items,
      List<EquipmentComponent> edges,
    ) => EquipmentPartTree.build(
      components: ComponentsIndex.fromRows(edges),
      items: items,
    );

    /// Rows with depth: two spaces per level, `A id+` / `A id-` for an open
    /// or folded assembly row.
    List<String> nested(EquipmentRowLayout layout) => [
      for (final row in layout.rows)
        switch (row) {
          EquipmentLocationHeadingRow(:final foldKey) => 'L $foldKey',
          EquipmentTypeHeadingRow(:final foldKey) => 'T $foldKey',
          EquipmentItemRow(:final item, :final depth, :final foldKey) =>
            foldKey == null
                ? 'I ${'  ' * depth}${item.id}'
                : 'A ${'  ' * depth}${item.id}'
                      '${row.isExpanded ? '+' : '-'}',
        },
    ];

    final sf2 = item('sf2', EquipmentType.rebreather);
    final head = item('head', EquipmentType.other);
    final cell1 = item('cell1', EquipmentType.o2Cell, host: 'sf2');
    final cell2 = item('cell2', EquipmentType.o2Cell, host: 'sf2');
    final sf2Items = [sf2, head, cell1, cell2];
    final sf2Tree = tree(sf2Items, [edge('sf2', 'head', 0)]);
    final sf2Groups = [
      EquipmentGroup(type: EquipmentType.o2Cell, items: [cell1, cell2]),
      EquipmentGroup(type: EquipmentType.other, items: [head]),
      EquipmentGroup(type: EquipmentType.rebreather, items: [sf2]),
    ];

    test('no parts graph leaves layout unchanged', () {
      for (final parts in [null, EquipmentPartTree.empty]) {
        final plain = layoutEquipmentRows(
          groups: typed,
          sections: sections,
          collapsed: const {},
        );
        final layout = layoutEquipmentRows(
          groups: typed,
          sections: sections,
          collapsed: const {},
          parts: parts,
        );
        expect(_kinds(layout), _kinds(plain));
        expect(layout.navStops.keys, plain.navStops.keys);
        expect(layout.foldKeysByItem, plain.foldKeysByItem);
        expect(layout.outerKeys, plain.outerKeys);
        expect(layout.assemblyIds, isEmpty);
        expect(layout.itemIdByNavKey, {
          for (final id in ['bcd1', 'reg1', 'bcd2']) id: id,
        });
      }
    });

    test('parts move under their assembly and leave their type', () {
      final layout = layoutEquipmentRows(
        groups: sf2Groups,
        collapsed: const {},
        parts: sf2Tree,
      );
      expect(nested(layout), [
        'T type:rebreather',
        'A sf2+',
        'I   head',
        'I   cell1',
        'I   cell2',
      ]);
      expect(layout.outerKeys, ['type:rebreather']);
    });

    test('heading counts top-level rows only', () {
      final layout = layoutEquipmentRows(
        groups: sf2Groups,
        collapsed: const {},
        parts: sf2Tree,
      );
      final heading = layout.rows.whereType<EquipmentTypeHeadingRow>().single;
      expect(heading.items, [sf2]);
    });

    test('folded assembly hides its parts', () {
      final layout = layoutEquipmentRows(
        groups: sf2Groups,
        collapsed: const {'asm:sf2'},
        parts: sf2Tree,
      );
      expect(nested(layout), ['T type:rebreather', 'A sf2-']);
      expect(layout.foldKeysByItem['cell1'], ['type:rebreather', 'asm:sf2']);
      final row = layout.rows.whereType<EquipmentItemRow>().single;
      expect(row.partCount, 3);
    });

    test('nested assembly folds inside its parent', () {
      final set = item('cellSet', EquipmentType.other);
      final c1 = item('c1', EquipmentType.o2Cell, host: 'cellSet');
      final parts = tree([sf2, set, c1], [edge('sf2', 'cellSet', 0)]);
      final groups = [
        EquipmentGroup(type: EquipmentType.o2Cell, items: [c1]),
        EquipmentGroup(type: EquipmentType.other, items: [set]),
        EquipmentGroup(type: EquipmentType.rebreather, items: [sf2]),
      ];
      final folded = layoutEquipmentRows(
        groups: groups,
        collapsed: const {'asm:cellSet'},
        parts: parts,
      );
      expect(nested(folded), ['T type:rebreather', 'A sf2+', 'A   cellSet-']);
      expect(folded.foldKeysByItem['c1'], [
        'type:rebreather',
        'asm:sf2',
        'asm:cellSet',
      ]);

      final allFolded = layoutEquipmentRows(
        groups: groups,
        collapsed: const {'asm:sf2', 'asm:cellSet'},
        parts: parts,
      );
      expect(allFolded.assemblyIds, {'sf2', 'cellSet'});
    });

    test('orphaned part stays top level', () {
      final layout = layoutEquipmentRows(
        groups: [
          EquipmentGroup(type: EquipmentType.o2Cell, items: [cell1]),
        ],
        collapsed: const {},
        parts: sf2Tree,
      );
      expect(nested(layout), ['T type:o2Cell', 'I cell1']);
      final row = layout.rows.whereType<EquipmentItemRow>().single;
      expect(row.parentId, isNull);
      expect(row.depth, 0);
    });

    test('shared part gets a second nav key', () {
      final regA = item('regA', EquipmentType.regulator);
      final regB = item('regB', EquipmentType.regulator);
      final ss = item('s', EquipmentType.secondStage);
      final parts = tree(
        [regA, regB, ss],
        [edge('regA', 's', 0), edge('regB', 's', 0)],
      );
      final layout = layoutEquipmentRows(
        groups: [
          EquipmentGroup(type: EquipmentType.regulator, items: [regA, regB]),
          EquipmentGroup(type: EquipmentType.secondStage, items: [ss]),
        ],
        collapsed: const {},
        parts: parts,
      );
      expect(nested(layout), [
        'T type:regulator',
        'A regA+',
        'I   s',
        'A regB+',
        'I   s',
      ]);
      final rows = layout.rows.whereType<EquipmentItemRow>().toList();
      expect(rows[1].navKey, 's');
      expect(rows[3].navKey, isNot('s'));
      expect(layout.itemIdByNavKey[rows[3].navKey], 's');
      expect(layout.foldKeysByItem['s'], ['type:regulator', 'asm:regA']);
      expect(rows[3].parentId, 'regB');
    });

    test('loop members still show', () {
      final a = item('a', EquipmentType.other);
      final b = item('b', EquipmentType.other);
      final parts = tree([a, b], [edge('a', 'b', 0), edge('b', 'a', 0)]);
      final layout = layoutEquipmentRows(
        groups: [
          EquipmentGroup(type: EquipmentType.other, items: [a, b]),
        ],
        collapsed: const {},
        parts: parts,
      );
      final ids = layout.rows
          .whereType<EquipmentItemRow>()
          .map((r) => r.item.id)
          .toSet();
      expect(ids, {'a', 'b'});
    });

    test('place sections nest within a place only', () {
      final layout = layoutEquipmentRows(
        groups: const [],
        sections: [
          EquipmentLocationSection(
            location: _place('G'),
            groups: [
              EquipmentGroup(type: EquipmentType.o2Cell, items: [cell1]),
              EquipmentGroup(type: EquipmentType.rebreather, items: [sf2]),
            ],
          ),
          EquipmentLocationSection(
            location: _place('F'),
            groups: [
              EquipmentGroup(type: EquipmentType.o2Cell, items: [cell2]),
            ],
          ),
        ],
        collapsed: const {},
        parts: sf2Tree,
      );
      expect(nested(layout), [
        'L loc:G',
        'T loc:G/type:rebreather',
        'A sf2+',
        'I   cell1',
        'L loc:F',
        'T loc:F/type:o2Cell',
        'I cell2',
      ]);
    });

    test('keyboard stops', () {
      final layout = layoutEquipmentRows(
        groups: sf2Groups,
        collapsed: const {},
        parts: sf2Tree,
      );
      expect(layout.navStops.keys, [
        equipmentGroupNavKey('type:rebreather'),
        'sf2',
        'head',
        'cell1',
        'cell2',
      ]);
      expect(layout.assemblyFoldByNavKey, {'sf2': 'asm:sf2'});
      expect(layout.parentNavKeyOf['cell1'], 'sf2');
      expect(
        layout.navStops.headerFor('cell1'),
        equipmentGroupNavKey('type:rebreather'),
      );
    });

    test('a folded place still records the assembly path', () {
      final layout = layoutEquipmentRows(
        groups: const [],
        sections: [
          EquipmentLocationSection(
            location: _place('G'),
            groups: [
              EquipmentGroup(type: EquipmentType.o2Cell, items: [cell1]),
              EquipmentGroup(type: EquipmentType.rebreather, items: [sf2]),
            ],
          ),
        ],
        collapsed: const {'loc:G', 'asm:sf2'},
        parts: sf2Tree,
      );
      expect(nested(layout), ['L loc:G']);
      expect(layout.foldKeysByItem['cell1'], [
        'loc:G',
        'loc:G/type:rebreather',
        'asm:sf2',
      ]);
      expect(layout.assemblyIds, {'sf2'});
    });
  });
}
