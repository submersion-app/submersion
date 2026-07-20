import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/weight_observation.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_history_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/weight_planner/presentation/providers/weight_planner_providers.dart';

void main() {
  const suit = EquipmentItem(
    id: 'suit1',
    name: 'Wetsuit',
    type: EquipmentType.wetsuit,
  );

  Dive diveWith({required List<EquipmentItem> equipment, bool tank = true}) =>
      Dive(
        id: 'x',
        dateTime: DateTime(2024, 1, 1),
        equipment: equipment,
        tanks: tank
            ? [
                const DiveTank(
                  id: 't1',
                  volume: 11,
                  workingPressure: 207,
                  material: TankMaterial.aluminum,
                  presetName: 'al80',
                ),
              ]
            : const [],
      );

  WeightObservation obs(String id, {bool sharesSuit = true}) =>
      WeightObservation(
        diveId: id,
        diveDateTime: DateTime(2024, 1, int.parse(id.substring(1))),
        carriedKg: 6.0,
        equipmentIds: sharesSuit ? const ['suit1'] : const ['other'],
        waterType: WaterType.salt,
      );

  ProviderContainer container({
    required List<WeightObservation> observations,
    required Map<String, Dive?> divesById,
    Dive? currentDive,
  }) {
    return ProviderContainer(
      overrides: [
        weightObservationsProvider.overrideWith((ref) async => observations),
        weightCalibrationProvider.overrideWith(
          (ref) async => WeightPredictionEngine.fit(
            observations: const [],
            gearById: (_) => null,
            bodyWeightKg: 75,
          ),
        ),
        latestDiverWeightProvider.overrideWith((ref) async => null),
        // The provider now reads the fully-hydrated diveProvider (equipment +
        // typed weights) and the isPrimary-filtered diveProfileProvider, not
        // the lean analysisDiveProvider. See buoyancyTwinProvider for the same
        // hydration pairing.
        diveProvider('cur').overrideWith(
          (ref) async => currentDive ?? diveWith(equipment: [suit]),
        ),
        for (final entry in divesById.entries) ...[
          diveProvider(entry.key).overrideWith((ref) async => entry.value),
          diveProfileProvider(
            entry.key,
          ).overrideWith((ref) async => const <DiveProfilePoint>[]),
          tankPressuresProvider(
            entry.key,
          ).overrideWith((ref) async => <String, List<TankPressurePoint>>{}),
        ],
      ],
    );
  }

  test(
    'includes only same-suit dives, excludes current, oldest first',
    () async {
      final c = container(
        observations: [
          obs('d1'),
          obs('d2'),
          obs('d3'),
          obs('d4', sharesSuit: false),
        ],
        divesById: {
          'd1': diveWith(equipment: [suit]),
          'd2': diveWith(equipment: [suit]),
          'd3': diveWith(equipment: [suit]),
          'd4': diveWith(equipment: [suit]),
        },
      );
      addTearDown(c.dispose);

      final entries = await c.read(buoyancyHistoryProvider('cur').future);
      expect(entries.map((e) => e.diveId), ['d1', 'd2', 'd3']);
    },
  );

  test('skips a matching dive that has no tanks and no suit', () async {
    final c = container(
      observations: [obs('d1'), obs('d2')],
      divesById: {
        'd1': diveWith(equipment: [suit]),
        // d2 loads with no suit and no tank -> assemble returns null.
        'd2': diveWith(equipment: const [], tank: false),
      },
    );
    addTearDown(c.dispose);

    final entries = await c.read(buoyancyHistoryProvider('cur').future);
    expect(entries.map((e) => e.diveId), ['d1']);
  });

  test('returns empty when the current dive has no exposure suit', () async {
    // Same-suit observations exist, but the current dive is suitless, so the
    // filter must self-suppress rather than degrade to matching every dive.
    final c = container(
      observations: [obs('d1'), obs('d2'), obs('d3')],
      divesById: {
        'd1': diveWith(equipment: [suit]),
        'd2': diveWith(equipment: [suit]),
        'd3': diveWith(equipment: [suit]),
      },
      currentDive: diveWith(equipment: const []),
    );
    addTearDown(c.dispose);

    final entries = await c.read(buoyancyHistoryProvider('cur').future);
    expect(entries, isEmpty);
  });
}
