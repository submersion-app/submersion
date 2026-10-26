import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/pages/device_list_page.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_computer_merge_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/device_item_providers.dart';

import '../../../../helpers/computer_items_override.dart';
import '../../../../helpers/test_app.dart';

DiveComputer _makeComputer({
  required String id,
  required String name,
  int diveCount = 0,
}) {
  return DiveComputer(
    id: id,
    name: name,
    serialNumber: '3101949313',
    diveCount: diveCount,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

class _FakeMergeRepository implements DiveComputerMergeRepository {
  @override
  Future<int> countAffectedDives({
    required String survivorId,
    required List<String> duplicateIds,
  }) async => 2;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _CapturingNotifier extends StateNotifier<AsyncValue<List<DiveComputer>>>
    implements DiveComputerNotifier {
  _CapturingNotifier() : super(const AsyncValue.data([]));

  String? survivorId;
  List<String>? duplicateIds;

  @override
  Future<DiveComputerMergeResult> merge({
    required String survivorId,
    required List<String> duplicateIds,
  }) async {
    this.survivorId = survivorId;
    this.duplicateIds = duplicateIds;
    return DiveComputerMergeResult(
      survivorId: survivorId,
      mergedComputerIds: duplicateIds,
      movedDiveCount: 2,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  late _CapturingNotifier notifier;

  setUp(() {
    notifier = _CapturingNotifier();
  });

  Future<void> pumpList(WidgetTester tester, List<DiveComputer> computers) {
    return tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          computerItemsFromComputers,
          allDiveComputersProvider.overrideWith((ref) async => computers),
          diveComputerNotifierProvider.overrideWith((ref) => notifier),
          diveComputerMergeRepositoryProvider.overrideWithValue(
            _FakeMergeRepository(),
          ),
        ],
        child: const DeviceListPage(),
      ),
    );
  }

  group('DeviceListPage merge action', () {
    testWidgets('is disabled until two computers are checked', (tester) async {
      await pumpList(tester, [
        _makeComputer(id: 'c1', name: 'Petrel 3'),
        _makeComputer(id: 'c2', name: 'ssss'),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();

      final mergeButton = find.byKey(const ValueKey('selection_action_merge'));
      expect(mergeButton, findsOneWidget);
      expect(tester.widget<IconButton>(mergeButton).onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('selection_select_all')));
      await tester.pumpAndSettle();

      expect(tester.widget<IconButton>(mergeButton).onPressed, isNotNull);
    });

    testWidgets('opens the merge sheet for the checked computers and reports', (
      tester,
    ) async {
      await pumpList(tester, [
        _makeComputer(id: 'c1', name: 'Petrel 3', diveCount: 21),
        _makeComputer(id: 'c2', name: 'ssss', diveCount: 2),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_select_all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_action_merge')));
      await tester.pumpAndSettle();

      expect(find.text('Merge Dive Computers'), findsOneWidget);
      expect(find.byKey(const ValueKey('merge_keep_c1')), findsOneWidget);
      expect(find.byKey(const ValueKey('merge_keep_c2')), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('merge_confirm')));
      await tester.pumpAndSettle();

      expect(notifier.survivorId, 'c1');
      expect(notifier.duplicateIds, ['c2']);
      expect(find.text('1 record merged into Petrel 3'), findsOneWidget);
      // Selection mode is left behind once the merge completes.
      expect(find.byKey(const ValueKey('enter_selection')), findsOneWidget);
    });

    testWidgets('merges every registration behind the checked items '
        '(review)', (tester) async {
      final a1 = _makeComputer(id: 'c1', name: 'Petrel 3', diveCount: 21);
      final a2 = _makeComputer(id: 'c2', name: 'Petrel 3 (old)');
      final b1 = _makeComputer(id: 'c3', name: 'ssss');
      await tester.pumpWidget(
        testApp(
          locale: const Locale('en'),
          overrides: [
            computerItemsProvider.overrideWith(
              (ref) async => [
                (
                  item: const EquipmentItem(
                    id: 'gear-a',
                    name: 'Petrel 3',
                    type: EquipmentType.computer,
                  ),
                  computers: [a1, a2],
                ),
                (
                  item: const EquipmentItem(
                    id: 'gear-b',
                    name: 'ssss',
                    type: EquipmentType.computer,
                  ),
                  computers: [b1],
                ),
              ],
            ),
            allDiveComputersProvider.overrideWith((ref) async => [a1, a2, b1]),
            diveComputerNotifierProvider.overrideWith((ref) => notifier),
            diveComputerMergeRepositoryProvider.overrideWithValue(
              _FakeMergeRepository(),
            ),
          ],
          child: const DeviceListPage(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_select_all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_action_merge')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('merge_confirm')));
      await tester.pumpAndSettle();

      expect(
        {notifier.survivorId, ...?notifier.duplicateIds},
        {'c1', 'c2', 'c3'},
      );
    });

    testWidgets('dismissing the sheet keeps the selection', (tester) async {
      await pumpList(tester, [
        _makeComputer(id: 'c1', name: 'Petrel 3'),
        _makeComputer(id: 'c2', name: 'ssss'),
      ]);
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('enter_selection')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_select_all')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('selection_action_merge')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(notifier.survivorId, isNull);
      expect(
        find.byKey(const ValueKey('selection_action_merge')),
        findsOneWidget,
      );
    });
  });
}
