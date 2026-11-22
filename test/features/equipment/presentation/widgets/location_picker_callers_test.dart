import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location_move.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/location_move_edit_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

/// Editing a past move runs no status prompt, so it may not offer a lend:
/// the prompt stays on every lend (issue #3790). A new item's first place
/// is a move on its Location card, which does run it.
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
            onPressed: () =>
                showLocationMoveEditDialog(context, ref, move, onHold: (_) {}),
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
