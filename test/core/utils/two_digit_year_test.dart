import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/two_digit_year.dart';

void main() {
  final now = DateTime.utc(2026, 10, 1);

  test('a year that would be in the future falls back a century', () {
    expect(expandTwoDigitYear(91, now: now), 1991);
    expect(expandTwoDigitYear(27, now: now), 1927);
  });

  test('a year up to and including this one stays in this century', () {
    expect(expandTwoDigitYear(26, now: now), 2026);
    expect(expandTwoDigitYear(7, now: now), 2007);
    expect(expandTwoDigitYear(0, now: now), 2000);
  });

  test('the pivot moves with today', () {
    expect(expandTwoDigitYear(99, now: DateTime.utc(2099)), 2099);
    expect(expandTwoDigitYear(0, now: DateTime.utc(2099)), 2000);
  });
}
