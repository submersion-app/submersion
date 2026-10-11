import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/domain/visibility/visibility_scale.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/trips/domain/services/day_conditions.dart';

Dive _dive(
  String id, {
  double? waterTemp,
  double? visMeters,
  Visibility? vis,
  CurrentStrength? current,
}) => Dive(
  id: id,
  dateTime: DateTime(2026, 3, 8, 9),
  waterTemp: waterTemp,
  visibilityMeters: visMeters,
  visibility: vis,
  currentStrength: current,
);

void main() {
  test('no dives or no logged conditions is empty', () {
    expect(DayConditions.fromDives(const []).isEmpty, isTrue);
    expect(DayConditions.fromDives([_dive('a')]).isEmpty, isTrue);
  });

  test('water temperature is the range of the dives that logged one', () {
    final c = DayConditions.fromDives([
      _dive('a', waterTemp: 28),
      _dive('b'),
      _dive('c', waterTemp: 26),
    ]);
    expect(c.minWaterTemp, 26);
    expect(c.maxWaterTemp, 28);
    expect(c.isEmpty, isFalse);
  });

  test('measured visibility is a range and ignores legacy buckets', () {
    final c = DayConditions.fromDives([
      _dive('a', visMeters: 20),
      _dive('b', visMeters: 12),
      _dive('c', vis: Visibility.poor),
    ]);
    expect(c.minVisibilityMeters, 12);
    expect(c.maxVisibilityMeters, 20);
    expect(c.legacyVisibility, isNull);
  });

  test('legacy visibility shows only when every bucketed dive agrees', () {
    expect(
      DayConditions.fromDives([
        _dive('a', vis: Visibility.good),
        _dive('b', vis: Visibility.good),
        _dive('c', vis: Visibility.unknown),
      ]).legacyVisibility,
      VisibilityBand.good,
    );
    expect(
      DayConditions.fromDives([
        _dive('a', vis: Visibility.good),
        _dive('b', vis: Visibility.poor),
      ]).legacyVisibility,
      isNull,
    );
    expect(
      DayConditions.fromDives([_dive('a', vis: Visibility.unknown)]).isEmpty,
      isTrue,
    );
  });

  test('current is the weakest to strongest logged', () {
    final c = DayConditions.fromDives([
      _dive('a', current: CurrentStrength.moderate),
      _dive('b', current: CurrentStrength.light),
      _dive('c', current: CurrentStrength.strong),
    ]);
    expect(c.minCurrent, CurrentStrength.light);
    expect(c.maxCurrent, CurrentStrength.strong);
  });
}
