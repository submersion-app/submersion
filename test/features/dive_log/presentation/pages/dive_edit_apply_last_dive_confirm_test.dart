import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_weight.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_edit_page.dart';

/// Issue #2075: "Apply last dive" replaces the form's weights and tanks, so
/// it asks first whenever the form holds any, however empty they look.
void main() {
  const blankWeight = DiveWeight(
    id: 'w',
    diveId: 'd',
    weightType: WeightType.trimWeights,
    amountKg: 0,
    notes: 'left pocket',
  );
  const tank = DiveTank(id: 't');

  test('an empty form replaces without asking', () {
    expect(
      applyLastDiveNeedsConfirm(weights: const [], tanks: const []),
      isFalse,
    );
  });

  test('a weight row with no amount yet still asks', () {
    expect(
      applyLastDiveNeedsConfirm(weights: const [blankWeight], tanks: const []),
      isTrue,
    );
  });

  test('a tank alone asks', () {
    expect(
      applyLastDiveNeedsConfirm(weights: const [], tanks: const [tank]),
      isTrue,
    );
  });
}
