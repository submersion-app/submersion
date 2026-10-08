import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_picker_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/move_equipment_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

void main() {
  final garage = EquipmentLocation(
    id: 'g',
    name: 'Garage',
    kind: EquipmentLocationKind.storage,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  testWidgets('Move stays disabled until a place is chosen, then returns '
      'the draft', (tester) async {
    MoveDraft? draft;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
          equipmentLocationsProvider.overrideWith((ref) async => [garage]),
        ],
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () async => draft = await showMoveEquipmentSheet(
              context,
              ref,
              itemCount: 2,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Move 2 items'), findsOneWidget);
    expect(find.text('Choose a place'), findsOneWidget);
    final confirm = find.byKey(const ValueKey('move_equipment_confirm'));
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

    await tester.tap(find.byKey(const ValueKey('move_equipment_to')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Garage'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('move_equipment_note')),
      'annual',
    );
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect((draft!.pick as PlacePick).location.id, 'g');
    expect(draft!.note, 'annual');
    // Today keeps the time of day, so it lands after any earlier move today.
    expect(DateTime.now().difference(draft!.movedAt).inMinutes, lessThan(1));
  });
}
