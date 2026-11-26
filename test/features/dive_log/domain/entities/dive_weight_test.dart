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

  test('a weight is carried on both sides by default', () {
    expect(weight.side, isNull);
  });

  test('copyWith sets and clears the side', () {
    final left = weight.copyWith(side: WeightSide.left);
    expect(left.side, WeightSide.left);
    expect(left.copyWith(amountKg: 3).side, WeightSide.left);
    expect(left.copyWith(clearSide: true).side, isNull);
  });

  test('the side takes part in equality', () {
    expect(weight.copyWith(side: WeightSide.right), isNot(weight));
  });
}
