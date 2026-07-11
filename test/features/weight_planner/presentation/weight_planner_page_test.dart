import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/weight_observation.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/features/divers/domain/entities/diver_weight_entry.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/weight_planner/presentation/pages/weight_planner_page.dart';
import 'package:submersion/features/weight_planner/presentation/providers/weight_planner_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';

void main() {
  const suitItem = EquipmentItem(
    id: 'suit',
    name: '5mm Suit',
    type: EquipmentType.wetsuit,
  );
  const bcdItem = EquipmentItem(
    id: 'bcd',
    name: 'Wing',
    type: EquipmentType.bcd,
  );

  final entry = DiverWeightEntry(
    id: 'w1',
    diverId: 'diver-1',
    measuredAt: DateTime(2026, 6, 1),
    weightKg: 80,
    createdAt: DateTime(2026, 6, 1),
    updatedAt: DateTime(2026, 6, 1),
  );

  final observations = [
    for (var i = 0; i < 12; i++)
      WeightObservation(
        diveId: 'd$i',
        diveDateTime: DateTime(2026, 6, 1).subtract(Duration(days: i)),
        waterType: WaterType.salt,
        carriedKg: 8.0,
        equipmentIds: const ['suit'],
        tanks: const [
          ObservedTank(
            presetName: 'al80',
            volumeL: 11.1,
            workingPressureBar: 207,
            material: TankMaterial.aluminum,
          ),
        ],
        feedback: 'correct',
      ),
  ];

  Future<void> pumpPage(WidgetTester tester) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...base,
          weightObservationsProvider.overrideWith((ref) async => observations),
          allEquipmentProvider.overrideWith(
            (ref) async => const [suitItem, bcdItem],
          ),
          latestDiverWeightProvider.overrideWith((ref) async => entry),
          tankPresetsProvider.overrideWith(
            (ref) async => [TankPresetEntity.fromBuiltIn(TankPresets.al80)],
          ),
        ],
        child: const WeightPlannerPage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  String? predictedText(WidgetTester tester) {
    final finder = find.byType(WeightPlannerPage);
    expect(finder, findsOneWidget);
    // The big total is the only displaySmall text on the page.
    for (final widget in tester.widgetList<Text>(find.byType(Text))) {
      if (widget.style?.fontWeight == FontWeight.bold &&
          (widget.data?.contains('kg') ?? false)) {
        return widget.data;
      }
    }
    return null;
  }

  testWidgets('renders a prediction with confidence line', (tester) async {
    await pumpPage(tester);
    expect(predictedText(tester), isNotNull);
    expect(find.textContaining('Based on 12 logged dives'), findsOneWidget);
  });

  testWidgets('adding gear through the picker changes the prediction', (
    tester,
  ) async {
    await pumpPage(tester);
    final before = predictedText(tester);

    await tester.tap(find.text('Add gear'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5mm Suit').last);
    await tester.pumpAndSettle();

    expect(find.byType(InputChip), findsOneWidget);
    final after = predictedText(tester);
    expect(after, isNot(before));

    // Let the 4-second delta chip timer elapse.
    await tester.pump(const Duration(seconds: 5));
  });
}
