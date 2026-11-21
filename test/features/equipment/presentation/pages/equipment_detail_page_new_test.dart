import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_new_sitting.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_clone_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/pages/equipment_detail_page.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/twin_set_card.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';
import 'package:submersion/features/query/presentation/providers/query_id_set_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_bar.dart';

import '../../../../helpers/test_database.dart';
import 'equipment_detail_page_unlock_harness.dart';

/// A query runner whose queries all fail.
class _FailingRunner extends QueryIdSetRunner {
  _FailingRunner() : super(DatabaseService.instance.database);

  @override
  Future<Set<String>> ids(
    CompiledQuery compiled, {
    QueryScope? scope,
    QueryCte? cte,
  }) => Future.error(StateError('query failed'));
}

/// A new gear item and a clone open on the item page, already unlocked
/// (issue #4527, phase 3, plan 11).
void main() {
  final l = AppLocalizationsEn();

  setUp(() async {
    final db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('d1'),
            name: Value('D'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  Finder nameField() => find.byKey(const ValueKey('gear-edit-name'));

  Future<void> typeName(WidgetTester tester, String name) async {
    await tester.enterText(nameField(), name);
    await tester.pumpAndSettle();
  }

  Future<void> tapSave(WidgetTester tester) async {
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
  }

  testWidgets('a new item opens unlocked with header, Details and Location', (
    tester,
  ) async {
    await pumpNewGearItemPage(tester);

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text(l.equipment_edit_appBar_newTitle), findsOneWidget);
    expect(nameField(), findsOneWidget);
    expect(
      find.byKey(const ValueKey('equipment-detail-overflow')),
      findsNothing,
    );
  });

  testWidgets('what needs a stored item is left out', (tester) async {
    await pumpNewGearItemPage(
      tester,
      request: const NewGearItemRequest(type: EquipmentType.tank),
    );

    expect(find.byType(TwinSetCard), findsNothing);
    // Details counts no dives or trips for an item not yet stored.
    expect(find.text(l.equipment_detail_divesLabel), findsNothing);
    expect(find.text(l.equipment_detail_tripsLabel), findsNothing);
    // Nor works out the stored item's header clock from the app's rollup.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(EquipmentDetailPage)),
    );
    expect(container.exists(equipmentRollupClockProvider), isFalse);
  });

  testWidgets('Save waits for the first entry, then pops the id', (
    tester,
  ) async {
    final harness = await pumpNewGearItemPage(tester);

    await tapSave(tester);
    expect(harness.save.creates, isEmpty);

    await typeName(tester, 'Backup reg');
    await tapSave(tester);
    final created = harness.save.creates.single.item;
    expect(created.name, 'Backup reg');
    expect(created.diverId, 'd1');
    expect(created.purchaseCurrency, 'EUR');
    expect(harness.popped, created.id);
  });

  testWidgets('a type from the device list is a change: Save at once', (
    tester,
  ) async {
    final harness = await pumpNewGearItemPage(
      tester,
      request: const NewGearItemRequest(
        type: EquipmentType.transmitter,
        serial: '0042',
      ),
    );

    await typeName(tester, 'AI tx');
    await tapSave(tester);

    final created = harness.save.creates.single.item;
    expect(created.type, EquipmentType.transmitter);
    expect(created.serialNumber, '0042');
  });

  testWidgets('in the pane, Save hands the id to the pane', (tester) async {
    final harness = await pumpNewGearItemPage(tester, embedded: true);
    await typeName(tester, 'Backup reg');

    await tester.tap(find.text(l.forms_save));
    await tester.pump(const Duration(milliseconds: 500));

    expect(harness.createdIds, [harness.save.creates.single.item.id]);
  });

  testWidgets('an entry asks before leaving, and nothing is written', (
    tester,
  ) async {
    final harness = await pumpNewGearItemPage(tester);
    await typeName(tester, 'Backup reg');

    await tester.tap(find.text(l.forms_cancel));
    await tester.pumpAndSettle();
    expect(find.text(l.forms_discard_title), findsOneWidget);
    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pumpAndSettle();

    expect(harness.poppedAtAll, isTrue);
    expect(harness.save.creates, isEmpty);
    expect(harness.save.calls, isEmpty);
  });

  testWidgets('a Save that fails keeps everything', (tester) async {
    final harness = await pumpNewGearItemPage(tester);
    await typeName(tester, 'Backup reg');
    harness.save.fail = true;

    await tapSave(tester);
    expect(find.text(l.recordEdit_saveFailed), findsOneWidget);
    expect(find.byType(RecordEditBar), findsOneWidget);

    harness.save.fail = false;
    await tapSave(tester);
    expect(harness.save.creates, hasLength(2));
    expect(
      harness.save.creates.last.item.id,
      harness.save.creates.first.item.id,
    );
  });

  testWidgets('a clone opens titled Clone, prefilled, and its Save replaces '
      'the page with the clone', (tester) async {
    await tester.runAsync(
      () => EquipmentRepository().createEquipment(
        const EquipmentItem(
          id: 'src',
          diverId: 'd1',
          name: 'Steel 12',
          type: EquipmentType.tank,
        ),
      ),
    );
    final harness = await pumpNewGearItemPage(
      tester,
      request: const NewGearItemRequest(cloneFromId: 'src'),
    );

    expect(find.text(l.equipment_edit_appBar_cloneTitle), findsOneWidget);
    expect(find.text(l.equipment_clone_nameCopy('Steel 12')), findsOneWidget);
    await tapSave(tester);

    final created = harness.save.creates.single.item;
    expect(created.type, EquipmentType.tank);
    expect(find.text('ITEM ${created.id}'), findsOneWidget);
    // In the place of the new item's page: Back returns to the launcher.
    expect(harness.poppedAtAll, isFalse);
  });

  testWidgets('a clone whose source is gone opens as not found', (
    tester,
  ) async {
    await pumpNewGearItemPage(
      tester,
      request: const NewGearItemRequest(cloneFromId: 'gone'),
    );

    expect(find.text(l.equipment_detail_notFoundMessage), findsOneWidget);
    expect(find.byType(RecordEditBar), findsNothing);
  });

  // The list may hide what was just made (a Wanted item under the default
  // view); a new item's Save asks it, as a pane's Save does. A check that
  // fails says the item was saved.
  testWidgets("a new item's Save asks whether the list will show it", (
    tester,
  ) async {
    final harness = await pumpNewGearItemPage(
      tester,
      extraOverrides: [
        queryIdSetRunnerProvider.overrideWithValue(_FailingRunner()),
      ],
    );
    await typeName(tester, 'Backup reg');

    await tester.tap(find.text(l.forms_save));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    expect(harness.save.creates, hasLength(1));
    expect(find.text(l.equipment_edit_snackbar_updated), findsOneWidget);
  });

  // The source is read once, as the clone opens: the clone is the diver's
  // from then on, and its source going away or failing to read again does
  // not close it or undo what was typed.
  testWidgets('a clone keeps its form when the source goes away mid-edit', (
    tester,
  ) async {
    await tester.runAsync(
      () => EquipmentRepository().createEquipment(
        const EquipmentItem(
          id: 'src',
          diverId: 'd1',
          name: 'Steel 12',
          type: EquipmentType.tank,
        ),
      ),
    );
    final harness = await pumpNewGearItemPage(
      tester,
      request: const NewGearItemRequest(cloneFromId: 'src'),
    );
    await typeName(tester, 'Steel 12 spare');

    await tester.runAsync(() => EquipmentRepository().deleteEquipment('src'));
    final container = ProviderScope.containerOf(
      tester.element(find.byType(RecordEditBar)),
    );
    container
      ..invalidate(equipmentItemProvider('src'))
      ..invalidate(cloneSourceProvider('src'));
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();

    expect(find.byType(RecordEditBar), findsOneWidget);
    expect(find.text('Steel 12 spare'), findsOneWidget);
    expect(harness.poppedAtAll, isFalse);
  });
}
