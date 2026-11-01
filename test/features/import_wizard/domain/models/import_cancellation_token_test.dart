import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/import_wizard/domain/models/import_cancellation_token.dart';

void main() {
  group('ImportCancellationToken', () {
    test('is not cancelled initially', () {
      final token = ImportCancellationToken();
      expect(token.isCancelled, isFalse);
    });

    test('becomes cancelled after cancel()', () {
      final token = ImportCancellationToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    test('cancel() is idempotent', () {
      final token = ImportCancellationToken();
      token.cancel();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });

    group('untilCancelled', () {
      test('gives the result of work that finishes first', () async {
        final token = ImportCancellationToken();

        expect(await token.untilCancelled(Future.value(42)), 42);
      });

      test('gives null without waiting for work that never ends', () async {
        final token = ImportCancellationToken();
        final result = token.untilCancelled(Completer<int>().future);

        token.cancel();

        expect(await result, isNull);
      });

      test('gives null once cancelled, even if the work is done', () async {
        final token = ImportCancellationToken()..cancel();

        expect(await token.untilCancelled(Future.value(42)), isNull);
      });

      test('gives null when a cancel lands in the tick work ends', () async {
        // The work wins the race here, but the caller has not seen its result
        // yet, and the cancel is the last thing the diver asked for.
        final token = ImportCancellationToken();
        final work = Completer<int>();
        final result = token.untilCancelled(work.future);

        work.complete(42);
        token.cancel();

        expect(await result, isNull);
      });

      test('passes on an error from work that fails first', () async {
        final token = ImportCancellationToken();

        await expectLater(
          token.untilCancelled(Future<int>.error(StateError('bad file'))),
          throwsStateError,
        );
      });

      test('gives null when a cancel lands in the tick work fails', () async {
        // As with a result, the cancel is the last thing the diver asked for,
        // so a failure nobody is waiting for is not reported as one.
        final token = ImportCancellationToken();
        final work = Completer<int>();
        final result = token.untilCancelled(work.future);

        work.completeError(StateError('bad file'));
        token.cancel();

        expect(await result, isNull);
      });

      test('keeps the stack trace of work that fails first', () async {
        final token = ImportCancellationToken();
        final trace = StackTrace.fromString('from the parser');

        try {
          await token.untilCancelled(
            Future<int>.error(StateError('bad'), trace),
          );
          fail('the failure should have come through');
        } on StateError catch (_, stackTrace) {
          expect(stackTrace.toString(), contains('from the parser'));
        }
      });

      test('leaves no unhandled error when abandoned work fails', () async {
        final token = ImportCancellationToken();
        final work = Completer<int>();
        final result = token.untilCancelled(work.future);

        token.cancel();
        expect(await result, isNull);

        // An unhandled error here would fail this test through its zone.
        work.completeError(StateError('failed after the diver left'));
        await pumpEventQueue();
      });
    });
  });
}
