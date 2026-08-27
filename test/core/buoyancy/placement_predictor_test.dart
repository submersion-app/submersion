import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/placement_predictor.dart';
import 'package:submersion/core/buoyancy/weight_observation.dart';

void main() {
  WeightObservation obs({
    required int index,
    Map<String, double> placement = const {},
    List<String> equipmentIds = const [],
  }) => WeightObservation(
    diveId: 'd$index',
    diveDateTime: DateTime(2026, 1, 1).add(Duration(days: index)),
    carriedKg: placement.values.fold(0.0, (a, b) => a + b),
    placement: placement,
    equipmentIds: equipmentIds,
  );

  test('returns null when no observation has placement data', () {
    expect(
      PlacementPredictor.predict(
        totalKg: 6.0,
        observations: [obs(index: 0)],
        incrementKg: 0.5,
      ),
      isNull,
    );
  });

  test('splits by average fractions with largest-remainder rounding, '
      'summing exactly to the rounded total', () {
    final placement = PlacementPredictor.predict(
      totalKg: 6.6,
      observations: [
        obs(index: 0, placement: {'integrated': 4.0, 'trimWeights': 2.0}),
        obs(index: 1, placement: {'integrated': 8.0, 'trimWeights': 4.0}),
      ],
      incrementKg: 0.5,
    );
    // Fractions 2/3 and 1/3 of 6.6 -> 4.4 + 2.2; 13 half-kg units total;
    // largest remainder gives integrated the extra unit.
    expect(placement, {'integrated': 4.5, 'trimWeights': 2.0});
    expect(placement!.values.fold(0.0, (a, b) => a + b), closeTo(6.5, 1e-9));
  });

  test('prefers observations sharing the exposure item, falls back to all', () {
    final observations = [
      obs(index: 0, placement: {'belt': 6.0}, equipmentIds: ['other-suit']),
      obs(index: 1, placement: {'integrated': 6.0}, equipmentIds: ['my-suit']),
    ];
    final matched = PlacementPredictor.predict(
      totalKg: 6.0,
      observations: observations,
      exposureItemId: 'my-suit',
      incrementKg: 0.5,
    );
    expect(matched, {'integrated': 6.0});

    final fallback = PlacementPredictor.predict(
      totalKg: 6.0,
      observations: observations,
      exposureItemId: 'never-dived-suit',
      incrementKg: 0.5,
    );
    expect(fallback, isNotNull);
  });

  test('uses only the most recent observations up to the cap', () {
    final observations = [
      // 10 recent dives all integrated.
      for (var i = 10; i < 20; i++)
        obs(index: i, placement: {'integrated': 6.0}),
      // Older belt-diving history beyond the cap.
      for (var i = 0; i < 10; i++) obs(index: i, placement: {'belt': 6.0}),
    ];
    final placement = PlacementPredictor.predict(
      totalKg: 6.0,
      observations: observations,
      incrementKg: 0.5,
    );
    expect(placement, {'integrated': 6.0});
  });

  test('imperial increment rounds to whole pounds', () {
    const lb = 0.45359237;
    final placement = PlacementPredictor.predict(
      totalKg: 6.0,
      observations: [
        obs(index: 0, placement: {'integrated': 3.0, 'belt': 3.0}),
      ],
      incrementKg: lb,
    );
    final total = placement!.values.fold(0.0, (a, b) => a + b);
    // 6.0 kg is 13.2 lb -> 13 units.
    expect(total / lb, closeTo(13, 1e-9));
    for (final value in placement.values) {
      expect((value / lb) - (value / lb).round(), closeTo(0, 1e-9));
    }
  });

  test('zero total returns null', () {
    expect(
      PlacementPredictor.predict(
        totalKg: 0,
        observations: [
          obs(index: 0, placement: {'integrated': 6.0}),
        ],
        incrementKg: 0.5,
      ),
      isNull,
    );
  });
}
