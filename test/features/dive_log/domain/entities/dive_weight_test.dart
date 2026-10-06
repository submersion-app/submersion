import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';

void main() {
  const weight = DiveWeight(
    id: 'w1',
    diveId: 'd1',
    weightType: WeightType.trimWeights,
    amountKg: 2,
  );

  test('a weight is unnamed by default', () {
    expect(weight.label, '');
  });

  test('copyWith sets and clears the name', () {
    final named = weight.copyWith(label: 'Top pocket');
    expect(named.label, 'Top pocket');
    expect(named.copyWith(label: '').label, '');
    expect(named.copyWith(amountKg: 3).label, 'Top pocket');
  });

  test('the name takes part in equality', () {
    expect(weight.copyWith(label: 'Top pocket'), isNot(weight));
  });
}
