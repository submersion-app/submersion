import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import 'trip_detail_page_unlock_harness.dart';

/// A trip's packed gear and board are held in its sitting behind the phase
/// 3 switch (issue #4527): unpacking and putting a tank on board wait for
/// Save.
void main() {
  final l = AppLocalizationsEn();

  const fins = EquipmentItem(
    id: 'fins',
    name: 'Fins',
    type: EquipmentType.fins,
  );
  const tank = EquipmentItem(
    id: 'tank',
    name: 'Steel 12',
    type: EquipmentType.tank,
  );

  Future<void> unlock(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pumpAndSettle();
  }

  Future<void> showGear(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(Tab, l.trips_detail_tab_gear));
    await tester.pumpAndSettle();
  }

  Future<void> unpackFins(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('trip-gear-menu-fins')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.trips_gear_remove).last);
    await tester.pumpAndSettle();
  }

  Future<void> putTankOnBoard(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('trip-gear-putOnBoard-tank')));
    await tester.pumpAndSettle();
  }

  testWidgets('locked, the Gear tab offers no Add, unpack or put on board', (
    tester,
  ) async {
    final harness = await pumpTripPage(tester, packed: [fins, tank]);
    await showGear(tester);

    expect(find.byKey(const Key('trip-gear-add')), findsNothing);
    expect(find.byKey(const Key('trip-gear-menu-fins')), findsNothing);
    expect(find.byKey(const Key('trip-gear-putOnBoard-tank')), findsNothing);
    expect(harness.gearWrites, isEmpty);
  });

  testWidgets('in a sitting, unpack and put on board write nothing until '
      'Save, then one entry of Packed gear and Cylinders', (tester) async {
    final harness = await pumpTripPage(tester, packed: [fins, tank]);
    await unlock(tester);
    await showGear(tester);

    await putTankOnBoard(tester);
    await unpackFins(tester);

    expect(find.text('Fins'), findsNothing);
    expect(find.byKey(const Key('trip-gear-tank-tank')), findsNothing);
    expect(find.text('Steel 12'), findsOneWidget);
    expect(harness.gearWrites, isEmpty);

    await tester.tap(find.text(l.forms_save));
    await tester.pumpAndSettle();

    expect(harness.save.calls.single.cards, {'packedGear', 'cylinders'});
    expect(
      harness.gearWrites,
      containsAll(['createCylinders Steel 12', 'unpack tank', 'unpack fins']),
    );
  });

  testWidgets('Cancel after unpacking writes nothing and shows the gear as '
      'stored', (tester) async {
    final harness = await pumpTripPage(tester, packed: [fins, tank]);
    await unlock(tester);
    await showGear(tester);
    await unpackFins(tester);

    await tester.tap(find.text(l.common_action_cancel).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(l.forms_discard_discard));
    await tester.pumpAndSettle();

    expect(harness.gearWrites, isEmpty);
    expect(harness.save.calls, isEmpty);
    expect(find.text('Fins'), findsWidgets);
  });

  testWidgets("in a sitting, Add waits for the trip's checklists, so a set's "
      'lead item has a checklist to go on', (tester) async {
    await pumpTripPage(tester, packed: [fins, tank]);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MaterialApp)),
    );
    final gate = Completer<void>();
    (container.read(tripChecklistsRepositoryProvider) as FakeTripChecklists)
            .gate =
        gate;
    await tester.tap(find.byIcon(Icons.lock_outline));
    await tester.pump();
    await tester.tap(find.widgetWithText(Tab, l.trips_detail_tab_gear));
    // The spinner shown meanwhile never settles: step a few frames.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byKey(const Key('trip-gear-add')), findsNothing);

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('trip-gear-add')), findsOneWidget);
  });
}
