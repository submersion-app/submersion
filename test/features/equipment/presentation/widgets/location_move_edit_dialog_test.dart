import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/location_move_edit_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  Future<void> openDialog(
    WidgetTester tester,
    EquipmentLocationMove move, {
    void Function(EquipmentLocationMove? edited)? onHold,
  }) async {
    // The dialog edits in an item page's sitting (issue #4527, phase 3).
    final hold = onHold ?? (_) {};
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          allEquipmentLocationsByIdProvider.overrideWith((ref) async => {}),
        ],
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () =>
                showLocationMoveEditDialog(context, ref, move, onHold: hold),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('a move dated in the future (a peer clock ahead) can still '
      'have its date edited', (tester) async {
    final future = DateTime.now().add(const Duration(days: 3));
    await openDialog(
      tester,
      EquipmentLocationMove(
        id: 'm',
        equipmentId: 'reg',
        locationId: null,
        movedAt: future,
        createdAt: future,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('location_move_date')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DatePickerDialog), findsOneWidget);
  });

  testWidgets('the dialog offers the move time for correction', (tester) async {
    final at = DateTime(2026, 9, 3, 18, 0);
    await openDialog(
      tester,
      EquipmentLocationMove(
        id: 'm',
        equipmentId: 'reg',
        locationId: null,
        movedAt: at,
        createdAt: at,
      ),
    );
    await tester.tap(find.byKey(const ValueKey('location_move_time')));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
  });

  EquipmentLocationMove pastMove() => EquipmentLocationMove(
    id: 'm',
    equipmentId: 'reg',
    locationId: null,
    movedAt: DateTime(2026, 9, 3, 18),
    createdAt: DateTime(2026, 9, 3, 18),
  );

  testWidgets('deleting a history entry asks first; Cancel keeps it', (
    tester,
  ) async {
    await openDialog(tester, pastMove());
    await tester.tap(find.byKey(const ValueKey('location_move_delete')));
    await tester.pumpAndSettle();
    expect(
      find.text(
        "Delete this history entry? The item's location is worked out "
        'again from the moves that are left.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    expect(find.text('Edit move'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // An item page's sitting (issue #4527, phase 3): no database here, so a
  // write would fail and say so.
  testWidgets('in a sitting Save hands back the edit and writes nothing', (
    tester,
  ) async {
    final held = <EquipmentLocationMove?>[];
    await openDialog(tester, pastMove(), onHold: held.add);
    await tester.enterText(find.byType(TextField).last, 'Back home');
    await tester.tap(find.byKey(const ValueKey('location_move_save')));
    await tester.pumpAndSettle();

    expect(held.single?.note, 'Back home');
    expect(find.text('Edit move'), findsNothing);
    expect(find.text('Something went wrong. Please try again.'), findsNothing);
  });

  testWidgets('in a sitting Delete still asks, then hands back null', (
    tester,
  ) async {
    final held = <EquipmentLocationMove?>[];
    await openDialog(tester, pastMove(), onHold: held.add);
    await tester.tap(find.byKey(const ValueKey('location_move_delete')));
    await tester.pumpAndSettle();
    expect(find.text('Cancel'), findsWidgets);
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();

    expect(held, [null]);
    expect(find.text('Edit move'), findsNothing);
  });
}
