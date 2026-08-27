import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/app/app_exit.dart';

/// The platform's only reply path on macOS, so its whole contract is that it
/// always answers, whatever the databases do.
void main() {
  test('closes both databases in order and replies exit', () async {
    final calls = <String>[];
    final response = await closeDatabasesForExit(
      closeMain: () async => calls.add('main'),
      closeCache: () async => calls.add('cache'),
    );

    expect(calls, ['main', 'cache']);
    expect(response, AppExitResponse.exit);
  });

  test('still replies exit when the main database close throws', () async {
    final errors = <Object>[];
    final calls = <String>[];

    final response = await closeDatabasesForExit(
      closeMain: () async => throw StateError('boom'),
      closeCache: () async => calls.add('cache'),
      onError: (error, _) => errors.add(error),
    );

    expect(response, AppExitResponse.exit);
    expect(errors.single, isA<StateError>());
    expect(calls, [
      'cache',
    ], reason: 'a failed main close must not strand the cache database');
  });

  test('still replies exit when the cache close throws', () async {
    final errors = <Object>[];

    final response = await closeDatabasesForExit(
      closeMain: () async {},
      closeCache: () async => throw StateError('boom'),
      onError: (error, _) => errors.add(error),
    );

    expect(response, AppExitResponse.exit);
    expect(errors.single, isA<StateError>());
  });

  test('still replies exit when a close never completes', () {
    fakeAsync((async) {
      AppExitResponse? response;
      final errors = <Object>[];

      closeDatabasesForExit(
        closeMain: () => Completer<void>().future,
        closeCache: () async {},
        budget: const Duration(seconds: 8),
        onError: (error, _) => errors.add(error),
      ).then((r) => response = r);

      async.elapse(const Duration(seconds: 7));
      async.flushMicrotasks();
      expect(response, isNull);

      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(response, AppExitResponse.exit);
      expect(errors.single, isA<TimeoutException>());
    });
  });

  test('the two closes share one budget rather than getting one each', () {
    fakeAsync((async) {
      AppExitResponse? response;

      closeDatabasesForExit(
        closeMain: () => Future<void>.delayed(const Duration(seconds: 6)),
        closeCache: () => Completer<void>().future,
        budget: const Duration(seconds: 8),
      ).then((r) => response = r);

      async.elapse(const Duration(seconds: 9));
      async.flushMicrotasks();

      expect(
        response,
        AppExitResponse.exit,
        reason: 'a per-close budget would make the worst case 2 x budget',
      );
    });
  });

  test('an exhausted budget still attempts the cache close', () {
    fakeAsync((async) {
      var cacheAttempted = false;

      closeDatabasesForExit(
        closeMain: () => Completer<void>().future,
        closeCache: () async => cacheAttempted = true,
        budget: const Duration(seconds: 8),
      );

      async.elapse(const Duration(seconds: 9));
      async.flushMicrotasks();

      expect(
        cacheAttempted,
        isTrue,
        reason: 'a zero remainder must not silently skip the second close',
      );
    });
  });
}
