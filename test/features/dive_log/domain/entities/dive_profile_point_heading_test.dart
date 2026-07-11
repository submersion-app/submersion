import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

void main() {
  test('DiveProfilePoint carries heading through copyWith and equality', () {
    const point = DiveProfilePoint(timestamp: 60, depth: 18.5, heading: 275.0);
    expect(point.heading, 275.0);

    final copied = point.copyWith(depth: 20.0);
    expect(copied.heading, 275.0, reason: 'copyWith must preserve heading');

    final reheaded = point.copyWith(heading: 90.0);
    expect(reheaded.heading, 90.0);

    // props must include heading so Equatable sees the difference.
    expect(point == reheaded, isFalse);
  });
}
