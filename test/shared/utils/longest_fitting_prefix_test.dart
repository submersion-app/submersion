import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/utils/longest_fitting_prefix.dart';

void main() {
  test('returns the whole value when it fits', () {
    expect(longestFittingPrefix('abc', (v) => true), 'abc');
  });

  test('returns the longest prefix the predicate accepts', () {
    expect(longestFittingPrefix('abcdefgh', (v) => v.length <= 5), 'abcde');
  });

  test('sizes the cut to the encoded length, not the code units', () {
    // Each CJK character encodes to nine URL characters.
    final value = '中' * 1300;
    final kept = longestFittingPrefix(
      value,
      (v) => Uri.encodeQueryComponent(v).length <= 7000,
    );
    expect(kept.length, 7000 ~/ 9);
  });

  test('never ends on half of a surrogate pair', () {
    final value = 'a${'\u{1F420}' * 10}';
    final kept = longestFittingPrefix(value, (v) => v.length <= 6);
    expect(kept, 'a\u{1F420}\u{1F420}');
    final last = kept.codeUnitAt(kept.length - 1);
    expect(last >= 0xD800 && last <= 0xDBFF, isFalse);
  });

  test('keeps at least floor characters even when nothing fits', () {
    expect(longestFittingPrefix('abcdef', (v) => false, floor: 1), 'a');
    expect(longestFittingPrefix('abcdef', (v) => false), '');
  });

  test('a floor inside a surrogate pair keeps the whole pair', () {
    expect(
      longestFittingPrefix('\u{1F420}\u{1F420}', (v) => false, floor: 1),
      '\u{1F420}',
    );
  });
}
