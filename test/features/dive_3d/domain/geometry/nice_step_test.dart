import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/domain/geometry/nice_step.dart';

void main() {
  test('niceStep rounds up to 1/2/5 x 10^n', () {
    expect(niceStep(2.5), 5);
    expect(niceStep(4.5), 5);
    expect(niceStep(37.5), 50);
    expect(niceStep(543.75), 1000);
    expect(niceStep(7.5), 10);
    expect(niceStep(0.2975), closeTo(0.5, 1e-12));
    expect(niceStep(0.5), closeTo(0.5, 1e-12));
    expect(niceStep(0), 0);
    expect(niceStep(-3), 0);
  });

  test('formatTickValue drops decimals for whole steps only', () {
    expect(formatTickValue(20, 5), '20');
    expect(formatTickValue(1.5, 0.5), '1.5');
    expect(formatTickValue(-20, 10), '-20');
  });
}
