import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/weight_observation.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/tank_presets.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/data/repositories/diver_weight_entry_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver_weight_entry.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/weight_planner/presentation/pages/weight_planner_page.dart';
import 'package:submersion/features/weight_planner/presentation/providers/weight_planner_providers.dart';

import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_app.dart';
import '../../../helpers/test_database.dart';

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

  Future<void> pumpPage(
    WidgetTester tester, {
    List<dynamic> extraOverrides = const [],
    DiverWeightEntry? latestWeight,
  }) async {
    final base = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...base,
          weightObservationsProvider.overrideWith((ref) async => observations),
          allEquipmentProvider.overrideWith(
            (ref) async => const [suitItem, bcdItem],
          ),
          latestDiverWeightProvider.overrideWith(
            (ref) async => latestWeight ?? entry,
          ),
          tankPresetsProvider.overrideWith(
            (ref) async => [
              TankPresetEntity.fromBuiltIn(TankPresets.al80),
              TankPresetEntity.fromBuiltIn(TankPresets.steel12),
            ],
          ),
          ...extraOverrides,
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

  testWidgets('water switch and tank add/remove/change update the '
      'prediction', (tester) async {
    await pumpPage(tester);
    final salt = predictedText(tester);

    await tester.tap(find.text('Fresh Water'));
    await tester.pumpAndSettle();
    expect(predictedText(tester), isNot(salt));
    await tester.pump(const Duration(seconds: 5));

    // Add a second tank, swap it to steel, then remove it.
    await tester.tap(find.text('Add tank'));
    await tester.pumpAndSettle();
    expect(
      find.byType(DropdownButtonFormField<TankPresetEntity>),
      findsNWidgets(2),
    );

    await tester.tap(
      find.byType(DropdownButtonFormField<TankPresetEntity>).last,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Steel 12L').last);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));

    await tester.tap(find.byIcon(Icons.delete_outline).last);
    await tester.pumpAndSettle();
    expect(
      find.byType(DropdownButtonFormField<TankPresetEntity>),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('use set adds all set items as chips', (tester) async {
    final set = EquipmentSet(
      id: 'set-1',
      name: 'Tropical rig',
      description: '',
      equipmentIds: const ['suit', 'bcd'],
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    await pumpPage(
      tester,
      extraOverrides: [
        equipmentSetsProvider.overrideWith((ref) async => [set]),
        equipmentSetWithItemsProvider('set-1').overrideWith(
          (ref) async => set.copyWith(items: const [suitItem, bcdItem]),
        ),
      ],
    );

    await tester.tap(find.text('Use set'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tropical rig'));
    await tester.pumpAndSettle();

    expect(find.byType(InputChip), findsNWidgets(2));
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('save-to-profile writes a new weight entry', (tester) async {
    await setUpTestDatabase();
    addTearDown(tearDownTestDatabase);
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('diver-1', 'Eric', 1000, 1000)",
    );

    await pumpPage(
      tester,
      latestWeight: null,
      extraOverrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => 'diver-1'),
      ],
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Body Weight (optional)'),
      '85',
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save weight to profile'));
    await tester.pumpAndSettle();

    final entries = await DiverWeightEntryRepository().getEntriesForDiver(
      'diver-1',
    );
    expect(entries.single.weightKg, 85.0);
  });

  testWidgets('through-the-dive panel renders swing and ditchable rows', (
    tester,
  ) async {
    await pumpPage(tester);
    // The default rig seeds a tank, so the panel is present.
    await tester.scrollUntilVisible(
      find.text('Through the dive'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Buoyancy swing'), findsOneWidget);
    expect(find.text('Min ditchable weight'), findsOneWidget);
  });

  testWidgets('adjusting max depth keeps the panel live', (tester) async {
    await pumpPage(tester);
    await tester.scrollUntilVisible(
      find.text('Through the dive'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('Max Depth'), findsOneWidget);
    final slider = find.byType(Slider).first;
    await tester.drag(slider, const Offset(80, 0));
    await tester.pumpAndSettle();
    // Panel still renders its summary after the depth change.
    expect(find.text('Buoyancy swing'), findsOneWidget);
  });

  group('squareDiveProfile', () {
    void expectStrictlyIncreasing(List<TwinProfileSample> profile) {
      for (var i = 1; i < profile.length; i++) {
        expect(
          profile[i].timestamp,
          greaterThan(profile[i - 1].timestamp),
          reason: 'sample $i duplicates or reverses the previous timestamp',
        );
      }
    }

    test('has strictly increasing timestamps at the 5 m slider minimum', () {
      // At 5 m the ascent-to-5 m leg is zero-length; the transition sample
      // must be skipped so it does not duplicate the bottom-end timestamp.
      expectStrictlyIncreasing(
        squareDiveProfile(maxDepthM: 5, bottomMinutes: 45),
      );
    });

    test('has strictly increasing timestamps for a typical dive', () {
      final profile = squareDiveProfile(maxDepthM: 30, bottomMinutes: 20);
      expectStrictlyIncreasing(profile);
      final deepest = profile
          .map((s) => s.depthM)
          .reduce((a, b) => a > b ? a : b);
      expect(deepest, 30);
    });
  });
}
