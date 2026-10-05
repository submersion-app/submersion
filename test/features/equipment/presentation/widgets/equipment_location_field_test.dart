import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_location.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_location_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_location_field.dart';

import '../../../../helpers/test_app.dart';

void main() {
  testWidgets('picking a place reports it; No location clears it', (
    tester,
  ) async {
    final garage = EquipmentLocation(
      id: 'g',
      name: 'Garage',
      kind: EquipmentLocationKind.storage,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
    EquipmentLocation? value;
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          equipmentLocationsProvider.overrideWith((ref) async => [garage]),
        ],
        child: StatefulBuilder(
          builder: (context, setState) => EquipmentLocationField(
            value: value,
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ),
    );
    expect(find.text('Not set'), findsOneWidget);
    await tester.tap(find.byType(EquipmentLocationField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Garage'));
    await tester.pumpAndSettle();
    expect(value?.id, 'g');
    expect(find.text('Garage'), findsOneWidget);

    await tester.tap(find.byType(EquipmentLocationField));
    await tester.pumpAndSettle();
    await tester.tap(find.text('No location'));
    await tester.pumpAndSettle();
    expect(value, isNull);
    expect(find.text('Not set'), findsOneWidget);
  });
}
