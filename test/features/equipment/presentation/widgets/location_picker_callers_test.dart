import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_field.dart';
import 'package:submersion/features/equipment/presentation/widgets/location_move_edit_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Neither of these runs the status prompt, so neither may offer a lend: the
/// prompt stays on every lend (issue #3790).
void main() {
  final overrides = [
    settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
    equipmentLocationsProvider.overrideWith(
      (ref) async => const <EquipmentLocation>[],
    ),
    allEquipmentLocationsByIdProvider.overrideWith(
      (ref) async => const <String, EquipmentLocation>{},
    ),
  ];

  testWidgets('the new item form offers no buddy', (tester) async {
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: overrides,
        child: EquipmentLocationField(value: null, onChanged: (_) {}),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('equipment_location_field')));
    await tester.pumpAndSettle();

    expect(find.text('Choose a place'), findsOneWidget);
    expect(find.text('Lend to a buddy'), findsNothing);
  });

  testWidgets('editing a past move offers no buddy', (tester) async {
    final move = EquipmentLocationMove(
      id: 'm',
      equipmentId: 'wet',
      locationId: null,
      movedAt: DateTime(2026),
      createdAt: DateTime(2026),
    );
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: overrides,
        child: Consumer(
          builder: (context, ref, _) => TextButton(
            onPressed: () => showLocationMoveEditDialog(context, ref, move),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('location_move_place')));
    await tester.pumpAndSettle();

    expect(find.text('Choose a place'), findsOneWidget);
    expect(find.text('Lend to a buddy'), findsNothing);
  });
}
