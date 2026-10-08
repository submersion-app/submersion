import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
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

  Future<void> pump(WidgetTester tester, List<EquipmentLocationMove> moves) =>
      tester.pumpWidget(
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
          child: const SingleChildScrollView(
            child: EquipmentLocationCard(equipment: reg),
          ),
        ),
      );

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

  testWidgets('a move that fails says so instead of throwing', (tester) async {
    // No database behind this test: recording the move throws.
    await pump(tester, const []);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('equipment_location_move')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move_equipment_to')));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Joe's Scuba"));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('move_equipment_confirm')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
  });
}
