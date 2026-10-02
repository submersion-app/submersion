import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_log/presentation/widgets/searchable_filter_dropdown.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/refine/groups/refine_gas_equipment_group.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/models/equipment_attr_condition.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';

import 'group_test_host.dart';

void main() {
  const hoseHp = EquipmentAttrCondition(
    key: 'hose_type',
    choices: {'hp'},
    types: {EquipmentType.hose},
  );
  const hoseItem = EquipmentItem(
    id: 'h',
    name: 'Gauge hose',
    type: EquipmentType.hose,
  );
  final now = DateTime(2026, 6, 1);
  final computers = [
    // No serial (#1064): firmware that never reports one must still be
    // offered, since attribution rides the computer id.
    DiveComputer(id: 'c1', name: 'Perdix', createdAt: now, updatedAt: now),
    DiveComputer(
      id: 'c2',
      name: 'Teric',
      serialNumber: 'SN9',
      createdAt: now,
      updatedAt: now,
    ),
  ];
  final diveTypes = [
    DiveTypeEntity(id: 'wreck', name: 'Wreck', createdAt: now, updatedAt: now),
  ];

  Future<GroupHarness> pump(
    WidgetTester tester, {
    DiveFilterState initial = const DiveFilterState(),
    List<EquipmentItem> gear = const [],
  }) => pumpGroup(
    tester,
    (d, on) => RefineGasEquipmentGroup(draft: d, onChanged: on),
    initial: initial,
    overrides: [
      diveTypesProvider.overrideWith((ref) async => diveTypes),
      allDiveComputersProvider.overrideWith((ref) async => computers),
      allEquipmentProvider.overrideWith((ref) async => gear),
    ],
  );

  testWidgets('gas chips: Air, Trimix, All', (tester) async {
    final h = await pump(tester);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Air (21%)'));
    await tester.pump();
    expect((h.draft.minO2Percent, h.draft.maxO2Percent), (20.0, 22.0));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Trimix (<21% O₂)'));
    await tester.pump();
    expect((h.draft.minO2Percent, h.draft.maxO2Percent), (null, 21.0));
    await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
    await tester.pump();
    expect((h.draft.minO2Percent, h.draft.maxO2Percent), (null, null));
  });

  testWidgets('suit thickness writes beside a gear condition', (tester) async {
    final h = await pump(
      tester,
      initial: const DiveFilterState(equipmentAttrConditions: [hoseHp]),
      gear: [hoseItem],
    );
    await tester.enterText(
      find.byKey(const ValueKey('refine-suit-min')),
      '2.5',
    );
    await tester.pump();
    expect(h.draft.equipmentAttrConditions, [
      EquipmentAttrCondition.suitThickness(min: 2.5),
      hoseHp,
    ]);
  });

  testWidgets('suit thickness hydrates and a typo keeps the bound', (
    tester,
  ) async {
    final h = await pump(
      tester,
      initial: DiveFilterState(
        equipmentAttrConditions: [
          EquipmentAttrCondition.suitThickness(min: 5, max: 7),
        ],
      ),
    );
    final min = find.byKey(const ValueKey('refine-suit-min'));
    expect(
      tester
          .widget<TextField>(
            find.descendant(of: min, matching: find.byType(TextField)),
          )
          .controller!
          .text,
      '5',
    );
    await tester.enterText(min, '5..');
    await tester.pump();
    expect(h.draft.equipmentAttrConditions, [
      EquipmentAttrCondition.suitThickness(min: 5, max: 7),
    ]);
  });

  testWidgets('switching the gear category clears its chips', (tester) async {
    final h = await pump(
      tester,
      initial: const DiveFilterState(equipmentAttrConditions: [hoseHp]),
      gear: [
        hoseItem,
        const EquipmentItem(
          id: 'g',
          name: 'Gloves',
          type: EquipmentType.gloves,
        ),
      ],
    );
    await tester.tap(find.byKey(const ValueKey('diveFilter_gearCategory')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gloves').last);
    await tester.pumpAndSettle();
    expect(h.draft.equipmentAttrConditions, isEmpty);
  });

  testWidgets('equipment chips toggle; a duplicated id deselects fully', (
    tester,
  ) async {
    final h = await pump(
      tester,
      initial: const DiveFilterState(equipmentIds: ['h', 'h']),
      gear: [hoseItem],
    );
    await tester.tap(find.widgetWithText(FilterChip, 'Gauge hose'));
    await tester.pump();
    expect(h.draft.equipmentIds, isEmpty);
    await tester.tap(find.widgetWithText(FilterChip, 'Gauge hose'));
    await tester.pump();
    expect(h.draft.equipmentIds, ['h']);
  });

  // Review Focus 3 (the sheet's #1064 rules).
  test('a deleted computer resolves to all computers on apply', () {
    const d = DiveFilterState(computerId: 'gone');
    expect(
      RefineGasEquipmentGroup.resolveOnApply(
        d,
        AsyncValue.data(computers),
      ).computerId,
      isNull,
    );
    expect(
      RefineGasEquipmentGroup.resolveOnApply(
        const DiveFilterState(computerId: 'c1'),
        AsyncValue.data(computers),
      ).computerId,
      'c1',
    );
    expect(
      RefineGasEquipmentGroup.resolveOnApply(
        d,
        const AsyncValue<List<DiveComputer>>.loading(),
      ).computerId,
      'gone',
    );
  });

  test('declares its fields', () {
    expect(RefineGasEquipmentGroup.fields, {
      'diveTypeId',
      'minO2Percent',
      'maxO2Percent',
      'equipmentIds',
      'equipmentAttrConditions',
      'computerId',
    });
  });

  // #1091 (ported from the Filter sheet): suit thickness keeps decimals, and
  // a comma means what the diver's locale says it means.
  testWidgets('suit thickness keeps decimals and reads a decimal comma', (
    tester,
  ) async {
    final h = await pump(
      tester,
      initial: DiveFilterState(
        equipmentAttrConditions: [
          EquipmentAttrCondition.suitThickness(min: 2.5),
        ],
      ),
    );
    expect(find.widgetWithText(TextField, '2.5'), findsOneWidget);
    final previousLocale = Intl.defaultLocale;
    addTearDown(() => Intl.defaultLocale = previousLocale);
    Intl.defaultLocale = 'fr';
    await tester.enterText(
      find.byKey(const ValueKey('refine-suit-max')),
      '7,5',
    );
    await tester.pump();
    expect(h.draft.equipmentAttrConditions, [
      EquipmentAttrCondition.suitThickness(min: 2.5, max: 7.5),
    ]);
  });

  testWidgets('a comma is thousands under a dot-decimal locale', (
    tester,
  ) async {
    final previousLocale = Intl.defaultLocale;
    addTearDown(() => Intl.defaultLocale = previousLocale);
    Intl.defaultLocale = 'en_US';
    final h = await pump(tester);
    await tester.enterText(
      find.byKey(const ValueKey('refine-suit-max')),
      '1,250',
    );
    await tester.pump();
    expect(h.draft.equipmentAttrConditions.single.max, 1250);
  });

  Finder fieldShowing(String label) =>
      find.ancestor(of: find.text(label), matching: find.byType(TextField));

  Future<void> pick(WidgetTester tester, String all, String hit) async {
    await tester.tap(fieldShowing(all));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byKey(searchableFilterOptionsKey),
        matching: find.text(hit),
      ),
    );
    await tester.pumpAndSettle();
  }

  // #1064: every computer is offered, serial or not.
  testWidgets('a computer with no serial is offered and picks', (tester) async {
    final h = await pump(tester);
    await pick(tester, 'All computers', 'Perdix');
    expect(h.draft.computerId, 'c1');
  });

  testWidgets('a dive type pick writes its id', (tester) async {
    final h = await pump(tester);
    await pick(tester, 'All types', 'Wreck');
    expect(h.draft.diveTypeId, 'wreck');
  });
}
