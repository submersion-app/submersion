import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/services/navigation_ready_gate.dart';

void main() {
  group('NavigationReadyGate', () {
    test('runs work at once when the app can already show a page', () async {
      final gate = NavigationReadyGate()..setReady(true);
      final ran = <String>[];

      await gate.run(() async => ran.add('file'));

      expect(ran, ['file']);
    });

    test('holds work until ready, then runs it (#2690)', () async {
      final gate = NavigationReadyGate();
      final ran = <String>[];

      final done = gate.run(() async => ran.add('file'));
      await pumpEventQueue();
      expect(ran, isEmpty);

      gate.setReady(true);
      await done;
      expect(ran, ['file']);
    });

    test('a not-ready update keeps the work held', () async {
      final gate = NavigationReadyGate();
      final ran = <String>[];

      unawaited(gate.run(() async => ran.add('file')));
      gate.setReady(false);
      await pumpEventQueue();

      expect(ran, isEmpty);
    });

    test('the caller gets the result of held work once it runs', () async {
      final gate = NavigationReadyGate();

      final result = gate.run(() async => 42);
      gate.setReady(true);

      expect(await result, 42);
    });

    test('the caller gets the error of held work once it runs', () async {
      final gate = NavigationReadyGate();

      final result = gate.run<void>(() async => throw StateError('unread'));
      gate.setReady(true);

      await expectLater(result, throwsStateError);
    });

    test('a failed item does not stop the ones behind it', () async {
      final gate = NavigationReadyGate();
      final ran = <String>[];

      final first = gate.run<void>(() async => throw StateError('unread'));
      final second = gate.run(() async => ran.add('second'));
      gate.setReady(true);

      await expectLater(first, throwsStateError);
      await second;
      expect(ran, ['second']);
    });

    test('held work runs one item at a time, in arrival order', () async {
      final gate = NavigationReadyGate();
      final events = <String>[];
      final firstMayFinish = Completer<void>();

      final first = gate.run(() async {
        events.add('first started');
        await firstMayFinish.future;
        events.add('first finished');
      });
      final second = gate.run(() async => events.add('second started'));

      gate.setReady(true);
      await pumpEventQueue();
      expect(events, ['first started']);

      firstMayFinish.complete();
      await Future.wait([first, second]);
      expect(events, ['first started', 'first finished', 'second started']);
    });

    test('work arriving while ready waits behind work still running', () async {
      final gate = NavigationReadyGate()..setReady(true);
      final events = <String>[];
      final firstMayFinish = Completer<void>();

      final first = gate.run(() async {
        events.add('first started');
        await firstMayFinish.future;
        events.add('first finished');
      });
      final second = gate.run(() async => events.add('second started'));
      await pumpEventQueue();
      expect(events, ['first started']);

      firstMayFinish.complete();
      await Future.wait([first, second]);
      expect(events, ['first started', 'first finished', 'second started']);
    });

    test('going unready mid-queue holds the rest until ready again', () async {
      final gate = NavigationReadyGate();
      final ran = <String>[];

      final first = gate.run(() async {
        ran.add('first');
        gate.setReady(false);
      });
      final second = gate.run(() async => ran.add('second'));

      gate.setReady(true);
      await first;
      await pumpEventQueue();
      expect(ran, ['first']);

      gate.setReady(true);
      await second;
      expect(ran, ['first', 'second']);
    });
  });
}
