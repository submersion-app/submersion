// The helper that keeps fire-and-forget work out of the zone handler.
//
// Every one of these tests would fail if logFailure stopped attaching a
// listener: an unlistened future's error reaches the zone, and package:test
// reports that as a failure against whichever test is running.

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/log_failure.dart';

Future<void> _settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class _Owner {}

void main() {
  test('a failing future does not reach the zone handler', () async {
    logFailure(Future<void>.error(StateError('boom')), _Owner, 'do the thing');
    await _settle();
    // Reaching here at all is the assertion.
  });

  test('a failure that arrives late still does not reach the zone', () async {
    // The real shape: work started during a test that outlives it.
    logFailure(
      Future<void>.delayed(
        const Duration(milliseconds: 5),
        () => throw StateError('late boom'),
      ),
      _Owner,
      'do the slow thing',
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
  });

  test('a succeeding future is left alone', () async {
    var ran = false;
    logFailure(Future<void>(() => ran = true), _Owner, 'do the thing');
    await _settle();
    expect(ran, isTrue);
  });

  test(
    'the caller can still await the same future and see the error',
    () async {
      // A Dart future carries several listeners, so attaching one here does not
      // consume the error. Anything that also awaits it still has to handle it.
      final work = Future<void>.error(StateError('boom'));
      logFailure(work, _Owner, 'do the thing');
      await expectLater(work, throwsA(isA<StateError>()));
    },
  );
}
