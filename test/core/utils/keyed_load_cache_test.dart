import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/utils/keyed_load_cache.dart';

/// The page's second sqlite3.wasm (issue #4121) loads once per asset URI and
/// is kept, but a load that failed is not.
void main() {
  test('a value loads once for its key and is kept', () async {
    var loads = 0;
    final cache = KeyedLoadCache<String, int>((key) async => ++loads);

    expect(await cache.get('a'), 1);
    expect(await cache.get('a'), 1);
    expect(loads, 1);
  });

  test('a new key loads again', () async {
    var loads = 0;
    final cache = KeyedLoadCache<String, int>((key) async => ++loads);

    await cache.get('a');
    expect(await cache.get('b'), 2);
  });

  test('a failed load is not kept, and its error keeps its own stack '
      'trace', () async {
    final failure = StateError('no wasm');
    final trace = StackTrace.current;
    var loads = 0;
    final cache = KeyedLoadCache<String, int>((key) {
      loads++;
      return loads == 1 ? Future.error(failure, trace) : Future.value(loads);
    });

    Object? error;
    StackTrace? stackTrace;
    try {
      await cache.get('a');
    } catch (e, st) {
      error = e;
      stackTrace = st;
    }
    expect(error, same(failure));
    expect(stackTrace, same(trace));
    expect(await cache.get('a'), 2, reason: 'the next use tries again');
  });

  test('an older key failing late does not drop the newer key\'s '
      'value', () async {
    final older = Completer<int>();
    var loads = 0;
    final cache = KeyedLoadCache<String, int>((key) {
      loads++;
      return key == 'old' ? older.future : Future.value(loads);
    });

    final first = cache.get('old');
    expect(await cache.get('new'), 2);
    older.completeError(StateError('late'));
    await expectLater(first, throwsStateError);

    expect(await cache.get('new'), 2);
    expect(loads, 2);
  });
}
