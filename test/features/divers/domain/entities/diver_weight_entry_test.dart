import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/divers/domain/entities/diver_weight_entry.dart';

void main() {
  final at = DateTime(2026, 6, 1);
  final entry = DiverWeightEntry(
    id: 'w1',
    diverId: 'd1',
    measuredAt: at,
    weightKg: 80,
    heightCm: 180,
    bodyFatPercent: 22,
    createdAt: at,
    updatedAt: at,
  );

  // Body fat is optional and a diver can take it back off an entry
  // (issue #4525), so copyWith tells "leave it" from "clear it".
  test('copyWith keeps the body fat when it is not named', () {
    expect(entry.copyWith(weightKg: 81).bodyFatPercent, 22);
  });

  test('copyWith clears the body fat when given null', () {
    expect(entry.copyWith(bodyFatPercent: null).bodyFatPercent, isNull);
  });

  test('copyWith sets a new body fat, whole numbers included', () {
    expect(entry.copyWith(bodyFatPercent: 18.5).bodyFatPercent, 18.5);
    expect(entry.copyWith(bodyFatPercent: 21).bodyFatPercent, 21.0);
  });
}
