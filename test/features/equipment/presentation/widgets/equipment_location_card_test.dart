import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/data/services/equipment_move_flow.dart';
import 'package:submersion/features/equipment/presentation/editing/gear_item_location_sitting.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  const reg = EquipmentItem(
    id: 'reg',
    name: 'Reg',
    type: EquipmentType.regulator,
  );
  EquipmentLocation place(String id, String name, {bool archived = false}) =>
      EquipmentLocation(
        id: id,
        name: name,
        kind: EquipmentLocationKind.serviceShop,
        isArchived: archived,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );
  EquipmentLocationMove move(
    String id,
    String? loc,
    int day, {
    String note = '',
  }) => EquipmentLocationMove(
    id: id,
    equipmentId: 'reg',
    locationId: loc,
    movedAt: DateTime(2026, 9, day),
    note: note,
    createdAt: DateTime(2026, 9, day),
  );

  Future<void> pump(
    WidgetTester tester,
    List<EquipmentLocationMove> moves, {
    Widget card = const EquipmentLocationCard(equipment: reg),
  }) => tester.pumpWidget(
    testApp(
      locale: const Locale('en'),
      overrides: [
        settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        equipmentLocationMovesProvider(
          'reg',
        ).overrideWith((ref) async => moves),
        equipmentLocationsProvider.overrideWith(
          (ref) async => [place('shop', "Joe's Scuba")],
        ),
        allEquipmentLocationsByIdProvider.overrideWith(
          (ref) async => {
            'shop': place('shop', "Joe's Scuba"),
            'old': place('old', 'Old locker', archived: true),
          },
        ),
      ],
      child: SingleChildScrollView(child: card),
    ),
  );

  // Where the item page edits in place (issue #4527, phase 3).
  group('on a page that edits in place', () {
    testWidgets('locked, it offers no Move and its moves open nothing', (
      tester,
    ) async {
      await pump(tester, [
        move('b', 'shop', 3),
      ], card: const EquipmentLocationCard(equipment: reg));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('equipment_location_move')),
        findsNothing,
      );
      await tester.tap(find.byKey(const ValueKey('equipment_location_move_b')));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('a closed card shows the held move as the current place, and '
        'offers nothing', (tester) async {
      final session = EditSession(reg);
      addTearDown(session.dispose);
      holdGearItemMove(
        session,
        HeldGearItemMove(
          pick: PlacePick(place('shop', "Joe's Scuba")),
          plan: EquipmentMovePlan(
            items: const {'reg': EquipmentStatus.active},
            movedAt: DateTime(2026, 9, 9),
            note: 'Annual service',
          ),
        ),
      );
      await pump(tester, [
        move('a', 'old', 1),
      ], card: EquipmentLocationCard(equipment: reg, shown: session));
      await tester.pumpAndSettle();

      final current = find.byKey(const ValueKey('equipment_location_current'));
      expect(
        find.descendant(of: current, matching: find.text("Joe's Scuba")),
        findsOneWidget,
      );
      expect(find.textContaining('Annual service'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('equipment_location_move')),
        findsNothing,
      );
    });

    testWidgets('open, past moves open nothing until the sitting has read '
        'them', (tester) async {
      final session = EditSession(reg);
      addTearDown(session.dispose);
      await pump(tester, [
        move('b', 'shop', 3),
      ], card: EquipmentLocationCard(equipment: reg, editing: session));
      // A progress bar waiting for a read never settles.
      await tester.pump();
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('equipment_location_move_b')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('open, a past move edited is held in the sitting', (
      tester,
    ) async {
      final session = EditSession(reg);
      addTearDown(session.dispose);
      final moves = [move('b', 'shop', 3), move('a', 'old', 1)];
      // No database here: the list starts empty and is given the moves.
      gearItemMovesList
        ..loadNone(session)
        ..set(session, moves);
      await pump(
        tester,
        moves,
        card: EquipmentLocationCard(equipment: reg, editing: session),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('equipment_location_move_a')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('location_move_delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      expect(gearItemMovesList.current(session)!.map((m) => m.id), ['b']);
      expect(session.changedCardIds, {'location'});
      expect(
        find.byKey(const ValueKey('equipment_location_move_a')),
        findsNothing,
      );
    });
  });

  testWidgets('no moves reads No location set', (tester) async {
    await pump(tester, const []);
    await tester.pumpAndSettle();
    expect(find.text('No location set'), findsOneWidget);
    expect(find.text('Show all'), findsNothing);
  });

  testWidgets('shows the current place, its note and the history, archived '
      'places included', (tester) async {
    await pump(tester, [
      move('b', 'shop', 3, note: 'annual'),
      move('a', 'old', 1),
    ]);
    await tester.pumpAndSettle();
    expect(find.text("Joe's Scuba"), findsNWidgets(2));
    expect(find.textContaining('annual'), findsWidgets);
    expect(find.text('Old locker'), findsOneWidget);
  });

  testWidgets('a cleared latest move reads No location set', (tester) async {
    await pump(tester, [move('b', null, 3), move('a', 'shop', 1)]);
    await tester.pumpAndSettle();
    expect(find.text('No location set'), findsOneWidget);
    expect(find.text('Location cleared'), findsOneWidget);
  });

  testWidgets('more than three moves collapse behind Show all', (tester) async {
    await pump(tester, [
      for (var day = 9; day >= 1; day -= 2) move('m$day', 'shop', day),
    ]);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('equipment_location_move_m1')),
      findsNothing,
    );
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('equipment_location_move_m1')),
      findsOneWidget,
    );
  });
}
