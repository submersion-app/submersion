import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/presentation/formatters/condition_band_label.dart';

void main() {
  test('open-below, closed and open-above bands', () {
    expect(conditionBandLabel(lower: null, upper: 10), '<10');
    expect(conditionBandLabel(lower: 10, upper: 20), '10-20');
    expect(conditionBandLabel(lower: 30, upper: null), '30+');
  });

  test("keeps a fractional edge and drops a whole one's decimals", () {
    expect(conditionBandLabel(lower: 0.5, upper: 1), '0.5-1');
    expect(conditionBandLabel(lower: 29.5, upper: 30.1), '29.5-30.1');
  });
}
