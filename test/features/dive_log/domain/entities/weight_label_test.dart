import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/weight_label.dart';

void main() {
  test('trims surrounding whitespace', () {
    expect(normalizeWeightLabel('  Top pocket \n'), 'Top pocket');
  });

  test('whitespace only is no name', () {
    expect(normalizeWeightLabel('   '), '');
  });

  test('keeps a name at the limit and cuts one past it', () {
    final atLimit = 'a' * weightLabelMaxLength;
    expect(normalizeWeightLabel(atLimit), atLimit);
    expect(normalizeWeightLabel('${atLimit}b'), atLimit);
  });

  test('never splits a character at the limit', () {
    // A flag is two code points (four UTF-16 units) but one character.
    final flag = String.fromCharCodes([0x1F1F3, 0x1F1F1]);
    final kept = '${'a' * (weightLabelMaxLength - 1)}$flag';
    expect(normalizeWeightLabel('${kept}zz'), kept);
  });
}
