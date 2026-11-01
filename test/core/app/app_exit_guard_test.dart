import 'dart:async';
import 'dart:ui' show AppExitResponse;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/app/app_exit_guard.dart';

/// Unsaved work stops a quit, and the platform still always gets an answer.
void main() {
  late List<String> calls;
  late AppExitGuard guard;

  Future<AppExitResponse> close() async {
    calls.add('close');
    return AppExitResponse.exit;
  }

  setUp(() {
    calls = [];
    guard = AppExitGuard(retryExit: () async => calls.add('retry'));
  });

  test('with nothing held the databases close and the app exits', () async {
    expect(await guard.answer(close), AppExitResponse.exit);
    expect(calls, ['close']);
  });

  test('a blocker with no unsaved work does not stand in the way', () async {
    guard.hold(
      AppExitBlocker(
        hasUnsavedWork: () => false,
        confirmLeaving: () async => fail('nothing to ask about'),
      ),
    );

    expect(await guard.answer(close), AppExitResponse.exit);
    expect(calls, ['close']);
  });

  test('unsaved work cancels at once, before the diver has answered', () async {
    final answer = Completer<bool>();
    guard.hold(
      AppExitBlocker(
        hasUnsavedWork: () => true,
        confirmLeaving: () => answer.future,
      ),
    );

    expect(await guard.answer(close), AppExitResponse.cancel);
    expect(calls, isEmpty);

    answer.complete(false);
    await pumpEventQueue();
    expect(calls, isEmpty);
  });

  test('giving the work up asks the platform to exit again', () async {
    var unsaved = true;
    guard.hold(
      AppExitBlocker(
        hasUnsavedWork: () => unsaved,
        confirmLeaving: () async {
          unsaved = false;
          return true;
        },
      ),
    );

    expect(await guard.answer(close), AppExitResponse.cancel);
    await pumpEventQueue();

    expect(calls, ['retry']);
    expect(await guard.answer(close), AppExitResponse.exit);
  });

  test('a repeated quit does not stack a second prompt', () async {
    final answer = Completer<bool>();
    var asked = 0;
    guard.hold(
      AppExitBlocker(
        hasUnsavedWork: () => true,
        confirmLeaving: () {
          asked++;
          return answer.future;
        },
      ),
    );

    await guard.answer(close);
    expect(await guard.answer(close), AppExitResponse.cancel);
    expect(asked, 1);

    answer.complete(false);
    await pumpEventQueue();
    await guard.answer(close);
    expect(asked, 2);
  });

  test(
    'a check that throws still answers, and lets the quit through',
    () async {
      guard.hold(
        AppExitBlocker(
          hasUnsavedWork: () => throw StateError('page gone'),
          confirmLeaving: () async => false,
        ),
      );

      expect(await guard.answer(close), AppExitResponse.exit);
    },
  );

  test('a prompt that throws leaves the app up', () async {
    guard.hold(
      AppExitBlocker(
        hasUnsavedWork: () => true,
        confirmLeaving: () async => throw StateError('no navigator'),
      ),
    );

    expect(await guard.answer(close), AppExitResponse.cancel);
    await pumpEventQueue();

    expect(calls, isEmpty);
  });

  test('a released blocker no longer stands in the way', () async {
    final blocker = AppExitBlocker(
      hasUnsavedWork: () => true,
      confirmLeaving: () async => false,
    );
    guard.hold(blocker);
    guard.release(blocker);

    expect(await guard.answer(close), AppExitResponse.exit);
  });

  group('the close button', () {
    late List<bool> prevented;

    setUp(() {
      prevented = [];
      guard = AppExitGuard(
        retryExit: () async => calls.add('retry'),
        preventWindowClose: (prevent) async => prevented.add(prevent),
      );
    });

    AppExitBlocker blocker({required bool unsaved, bool leave = false}) =>
        AppExitBlocker(
          hasUnsavedWork: () => unsaved,
          confirmLeaving: () async {
            calls.add('ask');
            return leave;
          },
        );

    test('the window is held from the first blocker to the last', () {
      final first = blocker(unsaved: false);
      final second = blocker(unsaved: false);

      guard.hold(first);
      guard.hold(second);
      guard.release(first);
      expect(prevented, [true]);

      guard.release(second);
      expect(prevented, [true, false]);
    });

    test('a close with unsaved work asks, and stays when told to', () async {
      guard.hold(blocker(unsaved: true));

      await guard.closeWindowRequested();

      expect(calls, ['ask']);
    });

    test('a close given up on exits through the platform', () async {
      guard.hold(blocker(unsaved: true, leave: true));

      await guard.closeWindowRequested();

      expect(calls, ['ask', 'retry']);
    });

    test('a close with nothing to lose still quits', () async {
      guard.hold(blocker(unsaved: false));

      await guard.closeWindowRequested();

      expect(calls, ['retry']);
    });

    test('with nothing held the window closes by itself', () async {
      await guard.closeWindowRequested();

      expect(calls, isEmpty);
    });

    test('a plugin failure does not reach the page', () async {
      final failing = AppExitGuard(
        preventWindowClose: (_) async => throw StateError('no window'),
      );

      failing.hold(blocker(unsaved: false));
      await pumpEventQueue();
    });
  });
}
