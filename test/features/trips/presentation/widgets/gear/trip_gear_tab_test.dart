import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/domain/services/trip_cylinder_state_fold.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_scrubber_margin_details.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_service_alert_list.dart';

import '../../../../../helpers/test_database.dart';
import 'trip_gear_tab_harness.dart';

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });
  tearDown(tearDownTestDatabase);

  testWidgets('an upcoming trip with nothing explains Add', (tester) async {
    await pumpTab(tester, editing: true);
    expect(
      find.text(
        "Nothing packed yet. Add the gear you'll bring and the cylinders "
        "you'll dive from.",
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('trip-gear-add')), findsOneWidget);
  });

  testWidgets('a past trip with nothing says so and offers no Add', (
    tester,
  ) async {
    await pumpTab(tester, onTrip: trip(past: true));
    expect(find.text('Nothing was packed for this trip.'), findsOneWidget);
    expect(find.byKey(const Key('trip-gear-add')), findsNothing);
  });

  testWidgets('packed gear and cylinders sit in two sections', (tester) async {
    await pumpTab(
      tester,
      gear: const [bcd, fins],
      states: [slot('Truck 1'), slot('Truck 2')],
    );
    expect(find.text('Packed'), findsOneWidget);
    expect(find.text('Cylinders'), findsOneWidget);
    expect(find.text('Hollis wing'), findsOneWidget);
    expect(find.text('Truck 2'), findsOneWidget);
  });

  testWidgets('an owned cylinder is listed once', (tester) async {
    await pumpTab(
      tester,
      gear: const [tank, bcd],
      states: [slot('Faber 12', equipmentId: 'tk')],
    );
    expect(find.text('Faber 12'), findsOneWidget);
    expect(find.textContaining('My equipment'), findsOneWidget);
  });

  testWidgets('a packed tank with no slot is listed under Cylinders (#2873)', (
    tester,
  ) async {
    await pumpTab(
      tester,
      gear: const [bcd, tank],
      states: [slot('Truck 1')],
      editing: true,
    );
    expect(find.text('Packed'), findsOneWidget);
    final cylinders = tester.getTopLeft(find.text('Cylinders')).dy;
    expect(tester.getTopLeft(find.text('Faber 12')).dy, greaterThan(cylinders));
    expect(find.textContaining('Not on the board'), findsOneWidget);
    expect(find.byKey(const Key('trip-gear-putOnBoard-tk')), findsOneWidget);
  });

  testWidgets('an ended trip lists a slotless tank with no board prompt', (
    tester,
  ) async {
    await pumpTab(
      tester,
      onTrip: trip(past: true),
      gear: const [tank],
      editing: true,
    );
    expect(find.text('Cylinders'), findsOneWidget);
    expect(find.text('Faber 12'), findsOneWidget);
    expect(find.byKey(const Key('trip-gear-putOnBoard-tk')), findsNothing);
    expect(find.textContaining('Not on the board'), findsNothing);
    // A tank with no specs reads its type, as a packed row does.
    expect(
      find.descendant(
        of: find.byKey(const Key('trip-gear-tank-tk')),
        matching: find.text('Tank'),
      ),
      findsOneWidget,
    );
    // It can still be unpacked.
    expect(find.byKey(const Key('trip-gear-menu-tk')), findsOneWidget);
  });

  testWidgets('a trip under way still offers Put on board', (tester) async {
    await pumpTab(
      tester,
      onTrip: trip(started: true),
      gear: const [tank],
      editing: true,
    );
    expect(find.byKey(const Key('trip-gear-putOnBoard-tk')), findsOneWidget);
    expect(find.textContaining('Not on the board'), findsOneWidget);
  });

  testWidgets('a slotless tank alone is a cylinder, not packed gear', (
    tester,
  ) async {
    await pumpTab(tester, gear: const [tank]);
    expect(find.text('Packed'), findsNothing);
    expect(find.text('Cylinders'), findsOneWidget);
    expect(find.text('Faber 12'), findsOneWidget);
  });

  testWidgets('Put on board appends the tank to the board and unpacks it, '
      'writing both at Save', (tester) async {
    final h = await pumpTab(
      tester,
      gear: const [tank],
      states: [slot('Truck 1')],
      editing: true,
    );
    await tester.tap(find.byKey(const Key('trip-gear-putOnBoard-tk')));
    await tester.pumpAndSettle();
    // Held after the board's last slot, and no longer packed.
    expect([for (final s in h.heldSlots) s.label], ['Truck 1', 'Faber 12']);
    final added = h.heldSlots.last;
    expect(added.equipmentId, 'tk');
    expect(added.tripId, 't1');
    expect(h.heldPacked, isEmpty);
    expect(find.byKey(const Key('trip-gear-putOnBoard-tk')), findsNothing);
    // Nothing is written before Save.
    expect(h.slots.created, isEmpty);
    expect(h.packs.unpacked, isEmpty);

    await h.save();
    expect(h.slots.created.single.single.equipmentId, 'tk');
    expect(h.packs.unpacked, [('t1', 'tk')]);
  });

  testWidgets('a slotless tank shows its size as a slot does', (tester) async {
    const al80 = EquipmentItem(
      id: 'al80',
      name: 'AL80',
      type: EquipmentType.tank,
      attributes: [
        EquipmentAttribute(
          id: 'a1',
          equipmentId: 'al80',
          key: EquipmentAttrKeys.volumeL,
          valueNum: 11.1,
        ),
        EquipmentAttribute(
          id: 'a2',
          equipmentId: 'al80',
          key: EquipmentAttrKeys.workingPressureBar,
          valueNum: 207,
        ),
      ],
    );
    await pumpTab(
      tester,
      gear: const [al80],
      settings: const AppSettings(
        volumeUnit: VolumeUnit.cubicFeet,
        pressureUnit: PressureUnit.psi,
      ),
    );
    final specs = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('trip-gear-tank-al80')),
        matching: find.textContaining('psi'),
      ),
    );
    // Rated gas in imperial, about 78 cuft, then the working pressure.
    expect(specs.data, matches(RegExp(r'^~?7[0-9] cuft · 3,?00[0-9] psi$')));
  });

  testWidgets('a slotless tank shows its service clock', (tester) async {
    await pumpTab(tester, gear: const [tank], alerts: [dueClock('tk')]);
    expect(find.byKey(const Key('trip-gear-alert-tk')), findsOneWidget);
    await tester.tap(find.byKey(const Key('trip-gear-alert-tk')));
    await tester.pumpAndSettle();
    expect(find.byType(TripServiceAlertList), findsOneWidget);
  });

  testWidgets('a slotless tank can still be unpacked', (tester) async {
    final h = await pumpTab(tester, gear: const [tank], editing: true);
    await tester.tap(find.byKey(const Key('trip-gear-menu-tk')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unpack'));
    await tester.pumpAndSettle();
    expect(h.heldPacked, isEmpty);
    expect(h.heldSlots, isEmpty);
    expect(find.text('Faber 12'), findsNothing);
  });

  testWidgets('before departure an owned slot names its item', (tester) async {
    // The slot carries the tank's mark, so the item's name is what tells
    // the diver which of their cylinders it is.
    await pumpTab(
      tester,
      states: [slot('A1', equipmentId: 'tk')],
      active: const [tank],
    );
    expect(find.text('A1'), findsOneWidget);
    expect(find.textContaining('Faber 12'), findsOneWidget);
    expect(find.textContaining('My equipment'), findsNothing);
  });

  testWidgets('a service clock reads on its item', (tester) async {
    await pumpTab(tester, gear: const [reg], alerts: [dueClock('reg')]);
    expect(find.textContaining('Annual service'), findsOneWidget);
  });

  testWidgets('an overdue clock reads overdue on its item', (tester) async {
    await pumpTab(
      tester,
      gear: const [reg],
      alerts: [dueClock('reg', overdue: true)],
    );
    expect(find.textContaining('overdue'), findsOneWidget);
  });

  testWidgets('a scrubber margin reads on its rebreather', (tester) async {
    await pumpTab(tester, gear: const [ccr], margins: [margin()]);
    expect(find.text('120 min scrubber margin'), findsOneWidget);
  });

  testWidgets('before departure a slot shows its specs and origin', (
    tester,
  ) async {
    await pumpTab(tester, states: [slot('Truck 1', full: true)]);
    expect(find.text('Truck 1'), findsOneWidget);
    expect(find.textContaining('207 bar'), findsOneWidget);
    expect(find.textContaining('Rental'), findsOneWidget);
    expect(find.text('Open board'), findsNothing);
  });

  testWidgets('from the first day a slot shows its state and the board '
      'opens from the header', (tester) async {
    await pumpTab(
      tester,
      onTrip: trip(started: true),
      states: [slot('Truck 1', full: true)],
    );
    expect(find.text('#140 · EAN32 · 207 bar'), findsOneWidget);
    expect(find.text('Open board'), findsOneWidget);
  });

  testWidgets('under way an unfilled slot says so instead of dashes (#2957)', (
    tester,
  ) async {
    await pumpTab(
      tester,
      onTrip: trip(started: true),
      states: [slot('Truck 1')],
    );
    expect(find.text('Truck 1 · Not filled yet'), findsOneWidget);
    expect(find.textContaining('--'), findsNothing);
  });

  testWidgets('tapping a slot opens the board', (tester) async {
    final h = await pumpTab(tester, states: [slot('Truck 1')]);
    await tester.tap(find.text('Truck 1'));
    await tester.pumpAndSettle();
    expect(h.pushed, ['/trips/t1/cylinders']);
  });

  testWidgets('tapping a packed item opens it', (tester) async {
    final h = await pumpTab(tester, gear: const [bcd]);
    await tester.tap(find.text('Hollis wing'));
    await tester.pumpAndSettle();
    expect(h.pushed, ['/equipment/bcd']);
  });

  testWidgets('Unpack removes the item, and Save unpacks it', (tester) async {
    final h = await pumpTab(tester, gear: const [bcd, fins], editing: true);
    await tester.tap(find.byKey(const Key('trip-gear-menu-bcd')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unpack'));
    await tester.pumpAndSettle();
    expect(h.heldPacked, ['fins']);
    expect(find.text('Hollis wing'), findsNothing);
    expect(h.packs.unpacked, isEmpty);

    await h.save();
    expect(h.packs.unpacked, [('t1', 'bcd')]);
  });

  testWidgets('locked, the tab offers no Add, unpack or put on board, and '
      'Open board still opens the board', (tester) async {
    final h = await pumpTab(
      tester,
      onTrip: trip(started: true),
      gear: const [bcd, tank],
      states: [slot('Truck 1')],
    );
    expect(find.text('Hollis wing'), findsOneWidget);
    expect(find.text('Faber 12'), findsOneWidget);
    expect(find.byKey(const Key('trip-gear-add')), findsNothing);
    expect(find.byKey(const Key('trip-gear-menu-bcd')), findsNothing);
    expect(find.byKey(const Key('trip-gear-menu-tk')), findsNothing);
    expect(find.byKey(const Key('trip-gear-putOnBoard-tk')), findsNothing);
    await tester.tap(find.text('Open board'));
    await tester.pumpAndSettle();
    expect(h.pushed, ['/trips/t1/cylinders']);
  });

  testWidgets('locked, an upcoming trip with nothing offers no Add', (
    tester,
  ) async {
    await pumpTab(tester);
    expect(
      find.text(
        "Nothing packed yet. Add the gear you'll bring and the cylinders "
        "you'll dive from.",
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('trip-gear-add')), findsNothing);
  });

  testWidgets('tapping a service line opens that item\'s clocks', (
    tester,
  ) async {
    final h = await pumpTab(
      tester,
      gear: const [reg],
      alerts: [dueClock('reg'), dueClock('reg', overdue: true)],
    );
    await tester.tap(find.byKey(const Key('trip-gear-alert-reg')));
    await tester.pumpAndSettle();
    expect(find.byType(TripServiceAlertList), findsOneWidget);
    expect(
      tester
          .widget<TripServiceAlertList>(find.byType(TripServiceAlertList))
          .alerts,
      hasLength(2),
    );
    expect(h.pushed, isEmpty);
  });

  testWidgets('the alert sheet names its item once, not on every row (#2882)', (
    tester,
  ) async {
    await pumpTab(
      tester,
      gear: const [reg],
      alerts: [dueClock('reg'), dueClock('reg', overdue: true)],
    );
    await tester.tap(find.byKey(const Key('trip-gear-alert-reg')));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(
      find.descendant(of: sheet, matching: find.text('Regulator')),
      findsOneWidget,
    );
    // dueClock names each alert's item by its id; no row may repeat it.
    expect(
      find.descendant(of: sheet, matching: find.text('reg')),
      findsNothing,
    );
    final rows = find.descendant(of: sheet, matching: find.byType(ListTile));
    expect(rows, findsNWidgets(2));
    for (final row in tester.widgetList<ListTile>(rows)) {
      expect(row.subtitle, isNull);
    }
  });

  testWidgets('tapping a scrubber line opens the breakdown', (tester) async {
    await pumpTab(tester, gear: const [ccr], margins: [margin()]);
    await tester.tap(find.byKey(const Key('trip-gear-alert-ccr')));
    await tester.pumpAndSettle();
    expect(find.byType(TripScrubberMarginDetails), findsOneWidget);
    expect(find.text('Scrubber margin'), findsOneWidget);
  });

  testWidgets('an item with no trip alert has no alert line to tap', (
    tester,
  ) async {
    await pumpTab(tester, gear: const [fins]);
    expect(find.byKey(const Key('trip-gear-alert-fins')), findsNothing);
  });

  testWidgets('before departure an imperial diver sees rated capacity', (
    tester,
  ) async {
    final al80 = foldCylinderState(
      cylinder: TripCylinder(
        id: 'c1',
        tripId: 't1',
        label: 'Truck 1',
        volume: 11.1,
        workingPressure: 207,
        createdAt: t0,
        updatedAt: t0,
      ),
      events: const [],
      uses: const [],
    );
    await pumpTab(
      tester,
      states: [al80],
      settings: const AppSettings(
        volumeUnit: VolumeUnit.cubicFeet,
        pressureUnit: PressureUnit.psi,
      ),
    );
    final subtitle = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const Key('trip-gear-slot-c1')),
        matching: find.textContaining('Rental'),
      ),
    );
    // About 78 cuft of gas, never the 0.4 cuft of water the tank holds.
    expect(subtitle.data, matches(RegExp(r'^~?7[0-9] cuft')));
  });

  testWidgets('a failed load says so instead of spinning', (tester) async {
    await pumpTab(tester, gearError: StateError('database is locked'));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('database is locked'), findsNothing);
  });

  testWidgets('an owned cylinder\'s service clock reads on its slot and '
      'opens the detail', (tester) async {
    await pumpTab(
      tester,
      states: [slot('Faber 12', equipmentId: 'tk')],
      alerts: [dueClock('tk')],
    );
    expect(find.byKey(const Key('trip-gear-alert-tk')), findsOneWidget);
    await tester.tap(find.byKey(const Key('trip-gear-alert-tk')));
    await tester.pumpAndSettle();
    expect(find.byType(TripServiceAlertList), findsOneWidget);
  });

  testWidgets('an ended trip shows no service or scrubber lines (#2485)', (
    tester,
  ) async {
    await pumpTab(
      tester,
      onTrip: trip(past: true),
      gear: const [reg, ccr],
      states: [slot('Faber 12', equipmentId: 'tk')],
      alerts: [dueClock('reg', overdue: true), dueClock('tk')],
      margins: [margin()],
    );
    expect(find.textContaining('overdue'), findsNothing);
    expect(find.textContaining('scrubber margin'), findsNothing);
    expect(find.byKey(const Key('trip-gear-alert-reg')), findsNothing);
    expect(find.byKey(const Key('trip-gear-alert-ccr')), findsNothing);
    expect(find.byKey(const Key('trip-gear-alert-tk')), findsNothing);
  });

  testWidgets('only a trip under way reads the fill forecast', (tester) async {
    final upcomingReads = <String>[];
    await pumpTab(
      tester,
      states: [slot('Faber 12')],
      forecastReads: upcomingReads,
    );
    expect(upcomingReads, isEmpty);

    final endedReads = <String>[];
    await pumpTab(
      tester,
      onTrip: trip(past: true),
      states: [slot('Faber 12')],
      forecastReads: endedReads,
    );
    expect(endedReads, isEmpty);

    final underWayReads = <String>[];
    await pumpTab(
      tester,
      onTrip: trip(started: true),
      states: [slot('Faber 12')],
      forecastReads: underWayReads,
    );
    expect(underWayReads, isNotEmpty);
  });
}
