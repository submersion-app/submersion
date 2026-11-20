import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' show DiversCompanion;
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/cylinder_passports/data/repositories/cylinder_passport_repository.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_component.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/gear/trip_gear_tab.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/test_database.dart';
import 'trip_gear_tab_harness.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  testWidgets('Add offers three ways in', (tester) async {
    await pumpTab(tester, gear: const [bcd], editing: true);
    await openAdd(tester);
    expect(find.text('From my equipment'), findsOneWidget);
    expect(find.text('An equipment set'), findsOneWidget);
    expect(find.text('Rental cylinders'), findsOneWidget);
  });

  testWidgets('From my equipment packs a picked item', (tester) async {
    final h = await pumpTab(tester, active: const [bcd], editing: true);
    await openPicker(tester);
    await tickAndAdd(tester, ['Hollis wing']);
    expect(h.heldPacked, ['bcd']);
    expect(h.heldSlots, isEmpty);
    expect(find.text('Hollis wing'), findsOneWidget);
  });

  testWidgets('From my equipment makes a picked cylinder a slot', (
    tester,
  ) async {
    final h = await pumpTab(
      tester,
      states: [slot('Truck 1')],
      active: const [tank],
      editing: true,
    );
    await openPicker(tester);
    await tickAndAdd(tester, ['Faber 12']);
    expect(h.heldPacked, isEmpty);
    // Appended after the board's last slot.
    expect([for (final s in h.heldSlots) s.equipmentId], [null, 'tk']);
  });

  group('From my equipment picks several (#4205)', () {
    testWidgets('ticked gear is packed in one pass and a tank slotted', (
      tester,
    ) async {
      final h = await pumpTab(
        tester,
        active: const [bcd, fins, tank],
        editing: true,
      );
      await openPicker(tester);
      await tickAndAdd(tester, ['Hollis wing', 'Fins', 'Faber 12']);
      // Held by name, as the tab lists them.
      expect(h.heldPacked, ['fins', 'bcd']);
      expect(h.heldSlots.single.equipmentId, 'tk');
      // Add closed the picker.
      expect(find.byType(EquipmentPickerSheet), findsNothing);

      await h.save();
      final (tripId, ids) = h.packs.packed.single;
      expect(tripId, 't1');
      expect(ids, ['fins', 'bcd']);
      expect(h.slots.created.single.single.equipmentId, 'tk');
    });

    testWidgets('Cancel after ticking writes nothing', (tester) async {
      final h = await pumpTab(tester, active: const [bcd, tank], editing: true);
      await openPicker(tester);
      await tester.tap(find.text('Hollis wing').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Faber 12').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(EquipmentPickerSheet), findsNothing);
      expect(h.session!.changedCardIds, isEmpty);
    });

    testWidgets('Add is disabled until something is ticked', (tester) async {
      await pumpTab(tester, active: const [bcd], editing: true);
      await openPicker(tester);
      FilledButton add(String label) => tester.widget<FilledButton>(
        find.descendant(
          of: find.byType(EquipmentPickerSheet),
          matching: find.widgetWithText(FilledButton, label),
        ),
      );
      expect(add('Add').onPressed, isNull);
      await tester.tap(find.text('Hollis wing').last);
      await tester.pumpAndSettle();
      expect(add('Add 1').onPressed, isNotNull);
    });

    testWidgets('an assembly\'s installed part waits behind the switch', (
      tester,
    ) async {
      const first = EquipmentItem(
        id: 'first',
        name: 'DIN First Stage',
        type: EquipmentType.firstStage,
      );
      final at = DateTime(2026, 1, 1);
      final h = await pumpTab(
        tester,
        active: const [reg, first],
        components: ComponentsIndex.fromRows([
          EquipmentComponent(
            id: 'reg>first',
            parentEquipmentId: 'reg',
            componentEquipmentId: 'first',
            createdAt: at,
            updatedAt: at,
          ),
        ]),
        editing: true,
      );
      await openPicker(tester);
      final picker = find.byType(EquipmentPickerSheet);
      expect(
        find.descendant(of: picker, matching: find.text('DIN First Stage')),
        findsNothing,
      );
      expect(find.text('Show components of assemblies'), findsOneWidget);
      await tickAndAdd(tester, ['Regulator']);
      expect(h.heldPacked, ['reg']);
    });

    testWidgets('gear already packed or on the board is not offered', (
      tester,
    ) async {
      await pumpTab(
        tester,
        gear: const [bcd],
        states: [slot('c1', equipmentId: 'tk')],
        active: const [bcd, fins, tank],
        editing: true,
      );
      await openPicker(tester);
      final picker = find.byType(EquipmentPickerSheet);
      expect(
        find.descendant(of: picker, matching: find.text('Hollis wing')),
        findsNothing,
      );
      expect(
        find.descendant(of: picker, matching: find.text('Faber 12')),
        findsNothing,
      );
      // A row per offered item; Fins alone is left to pick.
      final rows = find.descendant(
        of: picker,
        matching: find.byType(CheckboxListTile),
      );
      expect(rows, findsOneWidget);
      expect(
        find.descendant(of: rows, matching: find.text('Fins')),
        findsOneWidget,
      );
    });
  });

  testWidgets('An equipment set packs the members and slots its cylinders', (
    tester,
  ) async {
    final h = await pumpTab(
      tester,
      sets: [
        kit(const [bcd, fins, tank]),
      ],
      editing: true,
    );
    await openAdd(tester);
    await tester.tap(find.text('An equipment set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reef kit'));
    await tester.pumpAndSettle();
    expect(h.heldPacked, ['fins', 'bcd']);
    expect(h.heldSlots.single.equipmentId, 'tk');
    // The slotted cylinder counts alongside the packed items (#2877).
    expect(find.text('Packed 3 items from Reef kit'), findsOneWidget);
  });

  testWidgets('a set of only cylinders counts the slots it adds (#2877)', (
    tester,
  ) async {
    await pumpTab(
      tester,
      sets: [
        kit(const [tank]),
      ],
      editing: true,
    );
    await openAdd(tester);
    await tester.tap(find.text('An equipment set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reef kit'));
    await tester.pumpAndSettle();
    expect(find.text('Packed 1 item from Reef kit'), findsOneWidget);
  });

  testWidgets('a set whose cylinder is already a slot adds nothing', (
    tester,
  ) async {
    final h = await pumpTab(
      tester,
      states: [slot('c1', equipmentId: 'tk')],
      sets: [
        kit(const [tank]),
      ],
      editing: true,
    );
    await openAdd(tester);
    await tester.tap(find.text('An equipment set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reef kit'));
    await tester.pumpAndSettle();
    expect([for (final s in h.heldSlots) s.id], ['c1']);
    expect(h.session!.changedCardIds, isEmpty);
    expect(
      find.text('Everything in Reef kit is already packed'),
      findsOneWidget,
    );
  });

  testWidgets('Rental cylinders opens the rental form alone', (tester) async {
    await pumpTab(tester, editing: true);
    await openAdd(tester);
    await tester.tap(find.text('Rental cylinders'));
    await tester.pumpAndSettle();
    expect(find.text('How many'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is SegmentedButton), findsNothing);
  });

  group('scan a tag (issue #2652)', () {
    const regPid = '8f3a5c1e-1b2c-4d5e-8f90-1234567890ab';
    const tankPid = '22222222-3333-4444-8555-666666666666';
    const regLink = 'https://submersion.app/g#f=1&p=$regPid&t=regulator';

    Future<void> seedTagged(WidgetTester tester) => tester.runAsync(() async {
      final db = DatabaseService.instance.database;
      final t = DateTime.now().millisecondsSinceEpoch;
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: 'd1',
              name: 'd1',
              createdAt: t,
              updatedAt: t,
            ),
          );
      final repo = EquipmentRepository();
      final passports = CylinderPassportRepository();
      // The diver's own gear: the harness's diver is d1.
      await repo.createEquipment(reg.copyWith(diverId: 'd1'));
      await repo.createEquipment(tank.copyWith(diverId: 'd1'));
      await passports.assignPassportId(equipmentId: 'reg', passportId: regPid);
      await passports.assignPassportId(equipmentId: 'tk', passportId: tankPid);
    });

    Future<AppLocalizations> scanFromChooser(WidgetTester tester) async {
      await openAdd(tester);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(TripGearTab)),
      );
      await tester.tap(find.text(l10n.trips_gear_add_scan));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pumpAndSettle();
      return l10n;
    }

    testWidgets('a scanned item is packed', (tester) async {
      await seedTagged(tester);
      final h = await pumpTab(
        tester,
        gear: const [fins],
        scanned: regLink,
        editing: true,
      );
      final l10n = await scanFromChooser(tester);
      expect(h.heldPacked, ['fins', 'reg']);
      expect(
        find.text(l10n.gearPassport_scan_added('Regulator')),
        findsOneWidget,
      );
    });

    testWidgets('a scanned tank becomes a slot on the board', (tester) async {
      await seedTagged(tester);
      final h = await pumpTab(
        tester,
        gear: const [fins],
        scanned: 'https://submersion.app/c#f=1&p=$tankPid',
        editing: true,
      );
      await scanFromChooser(tester);
      expect(h.heldPacked, ['fins']);
      expect(h.heldSlots.single.equipmentId, 'tk');
    });

    testWidgets('an item already packed is not packed again', (tester) async {
      await seedTagged(tester);
      final h = await pumpTab(
        tester,
        gear: const [reg],
        scanned: regLink,
        editing: true,
      );
      final l10n = await scanFromChooser(tester);
      expect(h.session!.changedCardIds, isEmpty);
      expect(
        find.text(l10n.gearPassport_scan_alreadyOnTrip('Regulator')),
        findsOneWidget,
      );
    });
  });
}
