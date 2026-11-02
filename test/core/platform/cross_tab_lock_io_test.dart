import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/cross_tab_lock.dart';

void main() {
  test('runs the body once and returns its value', () async {
    var calls = 0;
    final value = await withCrossTabLock('submersion-sync', () async {
      calls++;
      return 42;
    });
    expect(value, 42);
    expect(calls, 1);
  });

  test('an error from the body propagates', () {
    expect(
      () => withCrossTabLock('submersion-sync', () async {
        throw StateError('x');
      }),
      throwsStateError,
    );
  });
}
