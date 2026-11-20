import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show AppDatabase;
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_fill_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_pairing_repository.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/cylinder_passports/domain/entities/cylinder_fill.dart';
import 'package:submersion/features/cylinder_passports/presentation/providers/cylinder_passport_providers.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_current_fill_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_fill_history_card.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/log_fill_sheet.dart';
import 'package:submersion/features/cylinder_passports/presentation/widgets/passport_service_card.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/entities/service_record.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_card_ids.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_fills_sitting.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_service_sitting.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/record_card_header.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// The cylinder passport's Current fill, Fill history and Service cards in
/// the gear item's sitting (issue #4527, phase 3, plan 7): their changes
/// wait for Save.
void main() {
  late AppDatabase db;
  late EditSession<EquipmentItem> session;
  late CylinderFill stored;
  final at = DateTime(2026, 3, 3, 10);
  const tank = EquipmentItem(
    id: 'a',
    name: 'Left 12',
    type: EquipmentType.tank,
  );

  setUp(() async {
    db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
  });
  tearDown(tearDownTestDatabase);

  Future<AppLocalizations> pump(WidgetTester tester, Widget card) async {
    await tester.runAsync(() async {
      await EquipmentRepository().createEquipment(tank);
      final passport = await CylinderPassportRepository().ensurePassportId('a');
      stored = await CylinderFillRepository().create(
        CylinderFill(
          id: 'f0',
          passportId: passport,
          equipmentId: 'a',
          filledAt: at,
          o2Percent: 32,
          createdAt: at,
          updatedAt: at,
        ),
      );
      session = EditSession(
        (await EquipmentRepository().getEquipmentById('a'))!,
      );
      await gearItemFillsList.currentOrRead(session);
      await gearItemClocksList.currentOrRead(session);
    });
    addTearDown(session.dispose);
    tester.view.physicalSize = const Size(600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          fillsForEquipmentProvider('a').overrideWith((ref) async => [stored]),
          tiedFillsProvider('a').overrideWith((ref) async => const {}),
          tripCopyFillIdsProvider('a').overrideWith((ref) async => const {}),
          serviceClockStatusesProvider(
            'a',
          ).overrideWith((ref) async => const <ServiceClockStatus>[]),
          serviceRecordsForEquipmentProvider(
            'a',
          ).overrideWith((ref) async => const <ServiceRecord>[]),
        ],
        child: SingleChildScrollView(child: card),
      ),
    );
    await tester.pumpAndSettle();
    return AppLocalizations.of(tester.element(find.byType(Card).first));
  }

  testWidgets('the current fill is the sitting\'s newest', (tester) async {
    final l10n = await pump(
      tester,
      Builder(
        builder: (context) => PassportCurrentFillCard(
          equipmentId: 'a',
          passportId: 'pp',
          editing: session,
        ),
      ),
    );
    expect(find.text('EAN32'), findsOneWidget);

    holdLoggedFill(
      session,
      stored.copyWith(o2Percent: 36, filledAt: at.add(const Duration(days: 1))),
    );
    await tester.pumpAndSettle();

    expect(find.text('EAN36'), findsOneWidget);
    expect(find.byType(RecordChangedDot), findsOneWidget);
    expect(find.text(l10n.passport_fill_log), findsOneWidget);
  });

  testWidgets('a fill deleted in the sitting stays stored until Save', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      Builder(
        builder: (context) =>
            PassportFillHistoryCard(equipmentId: 'a', editing: session),
      ),
    );

    await tester.tap(find.byTooltip(l10n.passport_history_delete));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, l10n.passport_history_delete),
    );
    await tester.pumpAndSettle();

    expect(find.text('EAN32'), findsNothing);
    expect(session.changedCardIds, {GearItemCardId.passportFills.name});
    final left = await tester.runAsync(
      () => CylinderFillRepository().getForCylinder(
        passportId: stored.passportId,
        equipmentId: 'a',
      ),
    );
    expect(left, hasLength(1));
  });

  // The sheet a card opens in the sitting holds its fill there: nothing is
  // written until Save.
  Future<void> saveSheet(WidgetTester tester, AppLocalizations l10n) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('logFill_o2')), '36');
    final save = find.descendant(
      of: find.byType(LogFillSheet),
      matching: find.text(l10n.forms_save),
    );
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Future<List<CylinderFill>> storedFills(WidgetTester tester) async =>
      (await tester.runAsync(
        () => CylinderFillRepository().getForCylinder(
          passportId: stored.passportId,
          equipmentId: 'a',
        ),
      ))!;

  testWidgets('Log fill in the sitting holds the new fill until Save', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      Builder(
        builder: (context) => PassportCurrentFillCard(
          equipmentId: 'a',
          passportId: stored.passportId,
          editing: session,
        ),
      ),
    );

    await tester.tap(find.text(l10n.passport_fill_log));
    await saveSheet(tester, l10n);

    expect(gearItemFillsList.current(session), hasLength(2));
    expect(newFillsOf(session).single.o2Percent, 36);
    expect(await storedFills(tester), hasLength(1));
  });

  // The card hands the sheet the sitting's lookup, which the sheet gives
  // the stored pairings: a fill logged on a paired cylinder is a twin fill.
  testWidgets('Log fill in the sitting on a paired cylinder is written on '
      'both at Save', (tester) async {
    final l10n = await pump(
      tester,
      Builder(
        builder: (context) => PassportCurrentFillCard(
          equipmentId: 'a',
          passportId: stored.passportId,
          editing: session,
        ),
      ),
    );
    await tester.runAsync(() async {
      await EquipmentRepository().createEquipment(
        const EquipmentItem(
          id: 'b',
          name: 'Right 12',
          type: EquipmentType.tank,
        ),
      );
      await CylinderPairingRepository().createPairing(
        cylinderAId: 'a',
        cylinderBId: 'b',
        pairedOn: DateTime(2020),
      );
    });

    await tester.tap(find.text(l10n.passport_fill_log));
    await saveSheet(tester, l10n);
    await tester.runAsync(() => db.transaction(session.runHeldWrites));

    final onB = await tester.runAsync(
      () async => CylinderFillRepository().getForCylinder(
        passportId: await CylinderPassportRepository().getPassportId('b'),
        equipmentId: 'b',
      ),
    );
    expect(onB!.single.o2Percent, 36);
  });

  testWidgets('an edit from the fill history is held until Save', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      Builder(
        builder: (context) =>
            PassportFillHistoryCard(equipmentId: 'a', editing: session),
      ),
    );

    await tester.tap(find.byTooltip(l10n.passport_history_edit));
    await saveSheet(tester, l10n);

    expect(gearItemFillsList.current(session)!.single.o2Percent, 36);
    expect(session.changedCardIds, {GearItemCardId.passportFills.name});
    expect((await storedFills(tester)).single.o2Percent, 32);
  });

  testWidgets('Track O2 clean holds the clock in the item\'s clocks', (
    tester,
  ) async {
    final l10n = await pump(
      tester,
      Builder(
        builder: (context) =>
            PassportServiceCard(equipment: tank, editing: session),
      ),
    );

    await tester.tap(find.text(l10n.passport_service_trackO2Clean));
    await tester.pumpAndSettle();

    expect(session.changedCardIds, {GearItemCardId.serviceClocks.name});
    expect(find.text(l10n.passport_service_trackO2Clean), findsNothing);
    expect(find.byType(RecordChangedDot), findsOneWidget);
  });
}
