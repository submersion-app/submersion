import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/equipment_transfer_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_transfer_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_transfer_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

class _FakeService extends EquipmentTransferService {
  _FakeService(this.byTarget);
  final Map<String?, EquipmentTransferPreview> byTarget;

  @override
  Future<EquipmentTransferPreview> preview({
    required List<String> equipmentIds,
    required String actingDiverId,
    String? toDiverId,
  }) async => byTarget[toDiverId] ?? byTarget[null]!;
}

class _FakeRepository extends EquipmentRepository {
  _FakeRepository(this.items);
  final List<EquipmentItem> items;

  @override
  Future<List<EquipmentItem>> getEquipmentByIds(List<String> ids) async => [
    for (final i in items)
      if (ids.contains(i.id)) i,
  ];
}

/// The transfer dialog (issue #2852).
void main() {
  final profiles = [
    Diver(
      id: 'anna',
      name: 'Anna',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    Diver(
      id: 'tom',
      name: 'Tom',
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
  ];

  const plain = EquipmentTransferPreview(
    unitIds: ['light'],
    skippedNotOwned: 0,
    computers: [],
    transmitters: [],
  );

  Future<Future<EquipmentTransferRequest?>> open(
    WidgetTester tester,
    Map<String?, EquipmentTransferPreview> previews, {
    List<String> picked = const ['light'],
    List<EquipmentItem> items = const [],
  }) async {
    late Future<EquipmentTransferRequest?> result;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          equipmentTransferServiceProvider.overrideWithValue(
            _FakeService(previews),
          ),
          equipmentRepositoryProvider.overrideWithValue(_FakeRepository(items)),
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showEquipmentTransferDialog(
              context,
              equipmentIds: picked,
              activeDiverId: 'bill',
              profiles: profiles,
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

  Finder transferButton() => find.widgetWithText(FilledButton, 'Transfer');

  testWidgets('Transfer is disabled until a profile is chosen', (tester) async {
    await open(tester, {null: plain});
    expect(tester.widget<FilledButton>(transferButton()).onPressed, isNull);
  });

  testWidgets('returns the choice with keep access on by default', (
    tester,
  ) async {
    final result = await open(tester, {null: plain});
    await tester.tap(find.text('Tom'));
    await tester.pumpAndSettle();
    await tester.tap(transferButton());
    await tester.pumpAndSettle();
    expect(await result, (
      toDiverId: 'tom',
      keepAccess: true,
      moveRegistry: true,
    ));
  });

  testWidgets('keep access can be turned off', (tester) async {
    final result = await open(tester, {null: plain});
    await tester.tap(find.text('Anna'));
    await tester.tap(find.text('Keep access for me'));
    await tester.pumpAndSettle();
    await tester.tap(transferButton());
    await tester.pumpAndSettle();
    expect((await result)!.keepAccess, isFalse);
  });

  testWidgets('cancel returns null', (tester) async {
    final result = await open(tester, {null: plain});
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isNull);
  });

  testWidgets('the registry switch shows only with linked rows', (
    tester,
  ) async {
    await open(tester, {null: plain});
    expect(
      find.text('Also move linked dive computers and transmitters'),
      findsNothing,
    );
  });

  testWidgets('a clashing transmitter is explained for the chosen profile', (
    tester,
  ) async {
    const withTx = EquipmentTransferPreview(
      unitIds: ['tank'],
      skippedNotOwned: 0,
      computers: [],
      transmitters: [TransferRegistryRow(id: 'tx1', label: 'Back gas')],
    );
    const clash = EquipmentTransferPreview(
      unitIds: ['tank'],
      skippedNotOwned: 0,
      computers: [],
      transmitters: [
        TransferRegistryRow(id: 'tx1', label: 'Back gas', clashes: true),
      ],
    );
    await open(tester, {null: withTx, 'anna': clash}, picked: const ['tank']);
    expect(
      find.text('Also move linked dive computers and transmitters'),
      findsOneWidget,
    );
    expect(find.textContaining('stays with you'), findsNothing);
    await tester.tap(find.text('Anna'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Back gas stays with you: Anna'),
      findsOneWidget,
    );
  });

  testWidgets('the rest of the unit is listed under Also moves', (
    tester,
  ) async {
    const unit = EquipmentTransferPreview(
      unitIds: ['ccr', 'cell'],
      skippedNotOwned: 0,
      computers: [],
      transmitters: [],
    );
    await open(
      tester,
      {null: unit},
      picked: const ['cell'],
      items: const [
        EquipmentItem(
          id: 'ccr',
          diverId: 'bill',
          name: 'JJ rebreather',
          type: EquipmentType.rebreather,
        ),
      ],
    );
    expect(find.text('Also moves:'), findsOneWidget);
    expect(find.text('JJ rebreather'), findsOneWidget);
  });
}
