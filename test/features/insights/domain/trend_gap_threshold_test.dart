import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/trend_gap_threshold.dart';

void main() {
  test('each choice carries its month count', () {
    expect(TrendGapThreshold.off.months, 0);
    expect(TrendGapThreshold.months6.months, 6);
    expect(TrendGapThreshold.year1.months, 12);
    expect(TrendGapThreshold.years2.months, 24);
  });

  test('the default is one year', () {
    expect(TrendGapThreshold.defaultValue, TrendGapThreshold.year1);
  });

  test('fromMonths reads every stored choice back', () {
    for (final t in TrendGapThreshold.values) {
      expect(TrendGapThreshold.fromMonths(t.months), t);
    }
  });

  test('an unknown or missing count reads as the default', () {
    expect(TrendGapThreshold.fromMonths(7), TrendGapThreshold.year1);
    expect(TrendGapThreshold.fromMonths(-1), TrendGapThreshold.year1);
    expect(TrendGapThreshold.fromMonths(null), TrendGapThreshold.year1);
  });
}
