import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_computer/presentation/pages/device_list_page.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';

import '../../../../helpers/bulk_delete_contract.dart';
import '../../../../helpers/selection_contract.dart';
import '../../../../helpers/test_app.dart';

DiveComputer _makeComputer({required String id, required String name}) {
  return DiveComputer(
    id: id,
    name: name,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );
}

/// Mutable source for the contract test's filter step, so the visible list
/// can be narrowed mid-test the way a real refresh would.
final _visibleComputersProvider = StateProvider<List<DiveComputer>>(
  (ref) => const [],
);

void main() {
  group('DeviceListPage selection contract', () {
    testWidgets('satisfies the shared selection contract', (tester) async {
      final all = <DiveComputer>[
        _makeComputer(id: 'c1', name: 'Aaa Perdix'),
        _makeComputer(id: 'c2', name: 'Bbb Teric'),
        _makeComputer(id: 'c3', name: 'Ccc Descent'),
      ];

      final overrides = <dynamic>[
        _visibleComputersProvider.overrideWith((ref) => all),
        allDiveComputersProvider.overrideWith(
          (ref) async => ref.watch(_visibleComputersProvider),
        ),
      ];

      await verifySelectionContract(
        tester,
        build: () => testApp(
          overrides: overrides,
          locale: const Locale('en'),
          child: const DeviceListPage(),
        ),
        selectButton: find.byKey(const ValueKey('enter_selection')),
        rowRoot: find.byType(Card).first,
        // The card renders computer.displayName, not name, so target the
        // row widget rather than a text string.
        firstRow: find.byType(Card).first,
        applyFilter: (tester) async {
          final container = ProviderScope.containerOf(
            tester.element(find.byType(DeviceListPage)),
          );
          container.read(_visibleComputersProvider.notifier).state = [
            all.first,
          ];
        },
        visibleAfterFilter: 1,
      );
    });

    testWidgets('deletes every checked computer and reports the count', (
      tester,
    ) async {
      final notifier = _CapturingComputerNotifier();
      final widget = testApp(
        locale: const Locale('en'),
        overrides: [
          allDiveComputersProvider.overrideWith(
            (ref) async => [
              _makeComputer(id: 'c1', name: 'Aaa Perdix'),
              _makeComputer(id: 'c2', name: 'Bbb Teric'),
            ],
          ),
          diveComputerNotifierProvider.overrideWith((ref) => notifier),
        ],
        child: const DeviceListPage(),
      );

      await verifyBulkDelete(
        tester,
        build: () => widget,
        selectButton: find.byKey(const ValueKey('enter_selection')),
        expectedDeletedCount: 2,
      );

      expect(notifier.deleted, ['c1', 'c2']);
      expect(find.text('2 deleted'), findsOneWidget);
    });

    testWidgets('the Select button is visible without any hidden gesture', (
      tester,
    ) async {
      await tester.pumpWidget(
        testApp(
          overrides: [
            allDiveComputersProvider.overrideWith(
              (ref) async => [_makeComputer(id: 'c1', name: 'Perdix')],
            ),
          ],
          locale: const Locale('en'),
          child: const DeviceListPage(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('enter_selection')), findsOneWidget);
    });
  });
}

/// Records the ids bulk delete reached the notifier with.
class _CapturingComputerNotifier
    extends StateNotifier<AsyncValue<List<DiveComputer>>>
    implements DiveComputerNotifier {
  _CapturingComputerNotifier() : super(const AsyncValue.data([]));

  final deleted = <String>[];

  @override
  Future<void> delete(String id) async => deleted.add(id);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
