@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/platform/cross_tab_lock.dart';

/// Two bodies under the same lock name never overlap, however they are
/// started: the second enters only after the first has left.
void main() {
  test('two bodies under one lock run one after the other', () async {
    final events = <String>[];
    Future<String> body(String tag) =>
        withCrossTabLock('submersion-test', () async {
          events.add('enter $tag');
          await Future<void>.delayed(const Duration(milliseconds: 150));
          events.add('exit $tag');
          return tag;
        });
    final results = await Future.wait([body('a'), body('b')]);
    expect(results, ['a', 'b']);
    expect(events, ['enter a', 'exit a', 'enter b', 'exit b']);
  });

  test('the body\'s value and error come back through the lock', () async {
    expect(await withCrossTabLock('submersion-test', () async => 7), 7);
    expect(
      () => withCrossTabLock('submersion-test', () async {
        throw StateError('x');
      }),
      throwsStateError,
    );
  });
}
