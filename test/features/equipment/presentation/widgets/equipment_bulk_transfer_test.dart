import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_service.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_transfer_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_bulk_transfer.dart';
import 'package:submersion/shared/selection/bulk_action.dart';

import '../../../../helpers/test_app.dart';

class _FakeService extends EquipmentTransferService {
  _FakeService({this.result = const EquipmentTransferResult(itemsMoved: 2)});

  final EquipmentTransferResult? result;
  final calls = <Map<String, Object?>>[];

  @override
  Future<EquipmentTransferPreview> preview({
    required List<String> equipmentIds,
    required String actingDiverId,
    String? toDiverId,
  }) async => EquipmentTransferPreview(
    unitIds: equipmentIds,
    skippedNotOwned: 0,
    computers: const [],
    transmitters: const [],
  );

  @override
  Future<EquipmentTransferResult> transfer({
    required List<String> equipmentIds,
    required String toDiverId,
    required String actingDiverId,
    bool keepAccess = true,
    bool moveRegistry = true,
  }) async {
    calls.add({
      'equipmentIds': equipmentIds,
      'toDiverId': toDiverId,
      'actingDiverId': actingDiverId,
      'keepAccess': keepAccess,
      'moveRegistry': moveRegistry,
    });
    final r = result;
    if (r == null) throw StateError('failed');
    return r;
  }
}

/// "Transfer to..." from the item page and the list (issue #2852).
void main() {
  final t = DateTime(2026);
  final divers = [
    Diver(id: 'bill', name: 'Bill', createdAt: t, updatedAt: t),
    Diver(id: 'anna', name: 'Anna', createdAt: t, updatedAt: t),
    Diver(id: 'tom', name: 'Tom', createdAt: t, updatedAt: t),
  ];

  Future<Future<({BulkActionOutcome outcome, bool keptAccess})>> open(
    WidgetTester tester,
    _FakeService service,
  ) async {
    late Future<({BulkActionOutcome outcome, bool keptAccess})> result;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          equipmentTransferServiceProvider.overrideWithValue(service),
          allDiversProvider.overrideWith((ref) async => divers),
        ],
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => result = transferEquipmentToProfile(
              context,
              ref,
              equipmentIds: const ['a', 'b'],
              activeDiverId: 'bill',
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  Future<void> chooseAndConfirm(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Transfer'));
    await tester.pumpAndSettle();
  }

  testWidgets('transfers to the chosen profile and says so', (tester) async {
    final service = _FakeService();
    final result = await open(tester, service);
    expect(find.text('Bill'), findsNothing);
    await chooseAndConfirm(tester, 'Anna');
    expect(service.calls.single, {
      'equipmentIds': ['a', 'b'],
      'toDiverId': 'anna',
      'actingDiverId': 'bill',
      'keepAccess': true,
      'moveRegistry': true,
    });
    expect(find.text('Transferred 2 items to Anna'), findsOneWidget);
    expect(await result, (
      outcome: BulkActionOutcome.completed,
      keptAccess: true,
    ));
  });

  testWidgets('reports items skipped because you do not own them', (
    tester,
  ) async {
    final service = _FakeService(
      result: const EquipmentTransferResult(itemsMoved: 1, skippedNotOwned: 1),
    );
    await open(tester, service);
    await chooseAndConfirm(tester, 'Anna');
    expect(
      find.text('Transferred 1 item to Anna, skipped 1 you do not own'),
      findsOneWidget,
    );
  });

  testWidgets('a failed transfer says try again and fails the action', (
    tester,
  ) async {
    final service = _FakeService(result: null);
    final result = await open(tester, service);
    await chooseAndConfirm(tester, 'Tom');
    expect(find.textContaining('try again'), findsOneWidget);
    expect((await result).outcome, BulkActionOutcome.failed);
  });

  testWidgets('cancelling transfers nothing', (tester) async {
    final service = _FakeService();
    final result = await open(tester, service);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(service.calls, isEmpty);
    expect((await result).outcome, BulkActionOutcome.cancelled);
  });
}
