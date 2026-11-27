import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/passport_usage.dart';
import 'package:submersion/features/cylinder_passports/presentation/pages/passport_page.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/data/services/gear_item_edit_save_service.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_check_ins_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_fills_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_header_editor.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_passport_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_service_sitting.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_frame.dart';
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';
import '../../../equipment/presentation/pages/equipment_detail_page_unlock_harness.dart';

/// The cylinder passport is a satellite page of its gear item behind the
/// phase 3 switch (issue #4527, plan 7): opened alone it has its own lock
/// and Save on the item; joined, it hands its changes to the item's
/// sitting with Done.
void main() {
  final l = AppLocalizationsEn();
  const tank = EquipmentItem(
    id: 'c1',
    name: 'Left 12',
    type: EquipmentType.tank,
  );
  late CylinderFill stored;

  setUp(() async {
    await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
  });
  tearDown(tearDownTestDatabase);

  Future<List<CylinderFill>> fillsInDb(WidgetTester tester) async =>
      (await tester.runAsync(
        () => CylinderFillRepository().getForCylinder(
          passportId: stored.passportId,
          equipmentId: 'c1',
        ),
      ))!;

  /// Pumps the passport over the test database: the cylinder, its passport
  /// id and one fill stored. The item's save is the fake the item page's
  /// tests use, running the held writes.
  Future<FakeGearItemSave?> pump(
    WidgetTester tester, {
    RecordEditController<EquipmentItem>? joined,
    List<PassportUsageDive> usage = const [],
  }) async {
    await tester.runAsync(() async {
      await EquipmentRepository().createEquipment(tank);
      final passport = await CylinderPassportRepository().ensurePassportId(
        'c1',
      );
      stored = await CylinderFillRepository().create(
        CylinderFill(
          id: 'f0',
          passportId: passport,
          equipmentId: 'c1',
          filledAt: DateTime(2026, 3, 3),
          o2Percent: 32,
          createdAt: DateTime(2026, 3, 3),
          updatedAt: DateTime(2026, 3, 3),
        ),
      );
    });
    tester.view.physicalSize = const Size(600, 2800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final item = StateProvider<EquipmentItem?>((ref) => tank);
    FakeGearItemSave? save;
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
          equipmentItemProvider(
            'c1',
          ).overrideWith((ref) async => ref.watch(item)),
          passportIdProvider(
            'c1',
          ).overrideWith((ref) async => stored.passportId),
          passportUsageProvider(
            stored.passportId,
          ).overrideWith((ref) async => usage),
          fillsForEquipmentProvider('c1').overrideWith((ref) async => [stored]),
          tiedFillsProvider('c1').overrideWith((ref) async => const {}),
          tripCopyFillIdsProvider('c1').overrideWith((ref) async => const {}),
          serviceClockStatusesProvider(
            'c1',
          ).overrideWith((ref) async => const <ServiceClockStatus>[]),
          serviceRecordsForEquipmentProvider(
            'c1',
          ).overrideWith((ref) async => const <ServiceRecord>[]),
          serviceRecordNotifierProvider(
            'c1',
          ).overrideWith((ref) => CountingServiceRecords()),
          gearItemEditSaveServiceProvider.overrideWith(
            (ref) => save = FakeGearItemSave(ref.watch(item.notifier)),
          ),
        ],
        child: PassportPage(equipmentId: 'c1', joined: joined),
      ),
    );
    await tester.pumpAndSettle();
    ProviderScope.containerOf(
      tester.element(find.byType(PassportPage)),
    ).read(gearItemEditSaveServiceProvider);
    return save;
  }

  Future<void> openFills(WidgetTester tester) async {
    final pencil = find.byTooltip(
      l.recordEdit_editCardTooltip(l.passport_history_title),
    );
    await tester.ensureVisible(pencil.first);
    await tester.tap(pencil.first);
    await tester.pumpAndSettle();
  }

  Future<void> deleteTheFill(WidgetTester tester) async {
    await tester.ensureVisible(find.byTooltip(l.passport_history_delete));
    await tester.tap(find.byTooltip(l.passport_history_delete));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, l.passport_history_delete),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('opened alone it opens locked, and offers no change', (
    tester,
  ) async {
    final save = await pump(tester);

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
    expect(find.text(l.passport_fill_log), findsNothing);
    expect(find.byTooltip(l.passport_history_delete), findsNothing);
    expect(find.text(l.passport_tag_linkExisting), findsNothing);
    expect(find.byKey(const Key('passport-trip-assign')), findsNothing);
    expect(save!.calls, isEmpty);
  });

  testWidgets('alone: Unlock, delete a fill, Save is one save on the item, '
      'labelled with the fills card', (tester) async {
    final save = await pump(tester);
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    await openFills(tester);

    await deleteTheFill(tester);
    expect(await fillsInDb(tester), hasLength(1));
    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {});

    expect(save!.calls.single.cards, {GearItemCardId.passportFills.name});
    expect(await fillsInDb(tester), isEmpty);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('unlocked, a cylinder never dived labels only its spec as '
      'calculated', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();

    // The empty Usage card draws nothing, so it has no label to float.
    expect(find.text(l.recordEdit_calculated), findsOneWidget);
  });

  EditSession<EquipmentItem> sessionOf(WidgetTester tester) =>
      RecordEditScope.maybeOf<EquipmentItem>(
        tester.element(find.byType(RecordCardFrame<EquipmentItem>).first),
      )!.session!;

  testWidgets('alone, its sitting reads only what its cards hold', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();

    final session = sessionOf(tester);
    expect(gearItemFillsList.loaded(session), isNotNull);
    expect(gearItemClocksList.loaded(session), isNotNull);
    expect(gearItemTagsList.loaded(session), isNull);
    expect(gearItemCheckInsList.loaded(session), isNull);
  });

  testWidgets('a tag linked in the sitting leaves the Usage card on the '
      'stored passport', (tester) async {
    await pump(
      tester,
      usage: [
        PassportUsageDive(diveId: 'd1', dateTime: DateTime.utc(2026, 9, 1)),
      ],
    );
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    expect(find.text(l.passport_usage_ownTitle(1)), findsOneWidget);

    holdPassportTag(
      sessionOf(tester),
      '11111111-2222-4333-8444-555555555555',
      stored: stored.passportId,
      repository: CylinderPassportRepository(),
    );
    await tester.pumpAndSettle();

    expect(find.text(l.passport_usage_ownTitle(1)), findsOneWidget);
  });

  testWidgets('alone: a change, then Cancel asks and writes nothing', (
    tester,
  ) async {
    final save = await pump(tester);
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
    await openFills(tester);
    await deleteTheFill(tester);

    await tester.tap(find.text(l.common_action_cancel));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pumpAndSettle();

    expect(save!.calls, isEmpty);
    expect(await fillsInDb(tester), hasLength(1));
  });
}
