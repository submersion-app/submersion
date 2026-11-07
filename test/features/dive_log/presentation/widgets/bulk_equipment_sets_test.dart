import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/bulk_edit_request.dart';
import 'package:submersion/features/dive_log/presentation/widgets/bulk_equipment_sets.dart';

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

  group('equipmentAddOps', () {
    test('groups the adds by the set that switched them on', () {
      final ops = equipmentAddOps(
        ['lamp', 'bcd', 'fins', 'reg'],
        const {'bcd': 'warm', 'reg': 'warm', 'fins': 'photo'},
      );

      expect(
        [for (final op in ops) (op.viaSetId, op.equipmentIds)],
        [
          (null, ['lamp']),
          ('warm', ['bcd', 'reg']),
          ('photo', ['fins']),
        ],
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
