import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/presentation/widgets/pinned_profile/layers/strip_input_memo.dart';

void main() {
  test('the same keys hand back the very same value', () {
    final memo = StripInputMemo();
    final review = Object();
    final first = memo.remember('findings', [review, true], () => <int>[]);
    final second = memo.remember('findings', [review, true], () => <int>[]);
    expect(identical(first, second), isTrue);
  });

  test('a changed key builds again', () {
    final memo = StripInputMemo();
    final first = memo.remember('plan', [Object()], () => <int>[]);
    final second = memo.remember('plan', [Object()], () => <int>[]);
    expect(identical(first, second), isFalse);
  });

  test('keys compare by identity, so an equal copy builds again', () {
    final memo = StripInputMemo();
    var builds = 0;
    memo.remember('sources', [
      [1, 2],
    ], () => builds++);
    memo.remember('sources', [
      [1, 2],
    ], () => builds++);
    expect(builds, 2);
  });

  test('values and plain keys compare by equality', () {
    final memo = StripInputMemo();
    var builds = 0;
    memo.remember('x', ['a', 1, true, null], () => builds++);
    memo.remember('x', ['a', 1, true, null], () => builds++);
    expect(builds, 1);
  });

  test('slots are kept apart', () {
    final memo = StripInputMemo();
    final key = Object();
    final a = memo.remember('a', [key], () => 'a');
    final b = memo.remember('b', [key], () => 'b');
    expect((a, b), ('a', 'b'));
  });
}
