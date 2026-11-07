import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_equipment_sets.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/shared/bulk_edit/bulk_membership_editor.dart';

import '../../../../helpers/test_app.dart';

/// Equipment sets in the bulk equipment group (#4284).
void main() {
  group('withSetItems', () {
    test('the first set that switched an item on keeps it', () {
      final first = withSetItems(const {}, 'warm', ['bcd', 'reg']);
      final both = withSetItems(first, 'photo', ['bcd', 'fins']);

      expect(both, {'bcd': 'warm', 'reg': 'warm', 'fins': 'photo'});
    });
  });

  group('withStagedSet', () {
    test('adds a set once', () {
      const warm = (id: 'warm', name: 'Warm');
      final once = withStagedSet(const [], warm);

      expect(once, [warm]);
      expect(withStagedSet(once, warm), [warm]);
    });
  });

  testWidgets('the remove picker is titled for removing and returns the set', (
    tester,
  ) async {
    // A set with no items cannot be tapped in the picker.
    const bcd = EquipmentItem(id: 'bcd', name: 'BCD', type: EquipmentType.bcd);
    final set = EquipmentSet(
      id: 'warm',
      name: 'Warm water',
      description: '',
      equipmentIds: const ['bcd'],
      items: const [bcd],
      createdAt: DateTime(2026, 6, 1),
      updatedAt: DateTime(2026, 6, 1),
    );
    BulkStagedSet? picked;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          equipmentSetsProvider.overrideWith((ref) async => [set]),
          equipmentSetWithItemsProvider.overrideWith((ref, id) async => set),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () async =>
                picked = await pickEquipmentSetToRemove(context),
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Equipment Set'), findsOneWidget);
    await tester.tap(find.text('Warm water'));
    await tester.pumpAndSettle();

    expect(picked, (id: 'warm', name: 'Warm water'));
  });

  group('equipmentAddIds', () {
    test('a set item already on every dive is added again through its set', () {
      // 'reg' is on every dive (no add of its own) and in the set used; a set
      // removed in the same edit may take it off first.
      const delta = MembershipDelta(['lamp'], ['fins']);
      final ids = equipmentAddIds(delta, const {
        'reg': 'warm',
        'lamp': 'warm',
        'fins': 'warm',
      });

      expect(ids, ['lamp', 'reg']);
    });
  });

  group('equipmentAddOps', () {
    test('groups the adds by the set that switched them on', () {
      final ops = equipmentAddOps(
        ['lamp', 'bcd', 'fins', 'reg'],
        const {'bcd': 'warm', 'reg': 'warm', 'fins': 'photo'},
      );

      // Records compare a list field by identity, so the ids are joined.
      expect(
        [for (final op in ops) '${op.viaSetId}: ${op.equipmentIds.join(',')}'],
        ['null: lamp', 'warm: bcd,reg', 'photo: fins'],
      );
      expect(ops.map((op) => op.mode).toSet(), {BulkCollectionMode.add});
    });

    test('no adds give no ops', () {
      expect(equipmentAddOps(const [], const {'bcd': 'warm'}), isEmpty);
    });
  });

  group('BulkEquipmentSetRemovals', () {
    Future<({List<String> unstaged, List<int> picks})> pump(
      WidgetTester tester,
      List<BulkStagedSet> sets,
    ) async {
      final unstaged = <String>[];
      final picks = <int>[];
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          child: BulkEquipmentSetRemovals(
            sets: sets,
            onPick: () => picks.add(1),
            onUnstage: unstaged.add,
          ),
        ),
      );
      return (unstaged: unstaged, picks: picks);
    }

    testWidgets('offers the button, with no list while nothing is staged', (
      tester,
    ) async {
      final calls = await pump(tester, const []);

      expect(find.text('Sets to remove'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('bulk-remove-set')));
      expect(calls.picks, [1]);
    });

    testWidgets('shows each staged set, and unstages one on delete', (
      tester,
    ) async {
      final calls = await pump(tester, const [
        (id: 'warm', name: 'Warm water'),
        (id: 'photo', name: 'Photo'),
      ]);

      expect(find.text('Sets to remove'), findsOneWidget);
      expect(find.text('Warm water'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('bulk-staged-set-photo')),
          matching: find.byIcon(Icons.close),
        ),
      );
      expect(calls.unstaged, ['photo']);
    });
  });
}
