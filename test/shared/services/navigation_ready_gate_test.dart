import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/shared/services/navigation_ready_gate.dart';

/// A handler that finishes every item by adding it to [into].
Future<bool> Function(String item) finishInto(List<String> into) =>
    (item) async {
      into.add(item);
      return true;
    };

void main() {
  group('NavigationReadyGate', () {
    test('hands an item over at once when its owner is ready', () async {
      final gate = NavigationReadyGate<String>();
      final handled = <String>[];
      gate.attach(finishInto(handled)).setReady(true);

      await gate.run('file');

      expect(handled, ['file']);
    });

    test('holds an item until its owner is ready (#2690)', () async {
      final gate = NavigationReadyGate<String>();
      final handled = <String>[];
      final owner = gate.attach(finishInto(handled));

      final done = gate.run('file');
      await pumpEventQueue();
      expect(handled, isEmpty);

      owner.setReady(true);
      await done;
      expect(handled, ['file']);
    });

    test('holds an item while no owner is attached', () async {
      final gate = NavigationReadyGate<String>();
      final handled = <String>[];

      final done = gate.run('file');
      await pumpEventQueue();
      expect(handled, isEmpty);

      gate.attach(finishInto(handled)).setReady(true);
      await done;
      expect(handled, ['file']);
    });

    test('a not-ready update keeps the item held', () async {
      final gate = NavigationReadyGate<String>();
      final handled = <String>[];
      final owner = gate.attach(finishInto(handled));

      unawaited(gate.run('file'));
      owner.setReady(false);
      await pumpEventQueue();

      expect(handled, isEmpty);
    });

    test('an item held for one owner goes to the owner that replaces it, '
        'not the one released', () async {
      final gate = NavigationReadyGate<String>();
      final first = <String>[];
      final second = <String>[];
      final old = gate.attach(finishInto(first));

      final done = gate.run('file');
      // A soft restart: the new app root attaches before the old one is
      // disposed, so the old release and readiness must not touch it.
      final replacement = gate.attach(finishInto(second));
      old
        ..setReady(true)
        ..release();
      await pumpEventQueue();
      expect(first, isEmpty);
      expect(second, isEmpty);

      replacement.setReady(true);
      await done;
      expect(first, isEmpty);
      expect(second, ['file']);
    });

    test('releasing the current owner holds later items again', () async {
      final gate = NavigationReadyGate<String>();
      final handled = <String>[];
      gate.attach(finishInto(handled))
        ..setReady(true)
        ..release();

      unawaited(gate.run('file'));
      await pumpEventQueue();

      expect(handled, isEmpty);
    });

    test('the caller learns when a held item has been handled', () async {
      final gate = NavigationReadyGate<String>();
      var handled = false;
      final owner = gate.attach((item) async {
        handled = true;
        return true;
      });

      final done = gate.run('file');
      owner.setReady(true);
      await done;

      expect(handled, isTrue);
    });

    test(
      'the caller gets the error of a held item once it is handled',
      () async {
        final gate = NavigationReadyGate<String>();
        final owner = gate.attach((item) async => throw StateError('unread'));

        final done = gate.run('file');
        owner.setReady(true);

        await expectLater(done, throwsStateError);
      },
    );

    test('a failed item does not stop the ones behind it', () async {
      final gate = NavigationReadyGate<String>();
      final handled = <String>[];
      final owner = gate.attach((item) async {
        if (item == 'bad') throw StateError('unread');
        handled.add(item);
        return true;
      });

      final first = gate.run('bad');
      final second = gate.run('good');
      owner.setReady(true);

      await expectLater(first, throwsStateError);
      await second;
      expect(handled, ['good']);
    });

    test('held items are handled one at a time, in arrival order', () async {
      final gate = NavigationReadyGate<String>();
      final events = <String>[];
      final firstMayFinish = Completer<void>();
      final owner = gate.attach((item) async {
        events.add('$item started');
        if (item == 'first') await firstMayFinish.future;
        events.add('$item finished');
        return true;
      });

      final first = gate.run('first');
      final second = gate.run('second');
      owner.setReady(true);
      await pumpEventQueue();
      expect(events, ['first started']);

      firstMayFinish.complete();
      await Future.wait([first, second]);
      expect(events, [
        'first started',
        'first finished',
        'second started',
        'second finished',
      ]);
    });

    test('an item arriving while ready waits behind one still being '
        'handled', () async {
      final gate = NavigationReadyGate<String>();
      final events = <String>[];
      final firstMayFinish = Completer<void>();
      gate
          .attach((item) async {
            events.add('$item started');
            if (item == 'first') await firstMayFinish.future;
            return true;
          })
          .setReady(true);

      final first = gate.run('first');
      final second = gate.run('second');
      await pumpEventQueue();
      expect(events, ['first started']);

      firstMayFinish.complete();
      await Future.wait([first, second]);
      expect(events, ['first started', 'second started']);
    });

    test('going unready mid-queue holds the rest until ready again', () async {
      final gate = NavigationReadyGate<String>();
      final handled = <String>[];
      late final NavigationReadyGateOwner owner;
      owner = gate.attach((item) async {
        handled.add(item);
        owner.setReady(false);
        return true;
      });

      final first = gate.run('first');
      final second = gate.run('second');
      owner.setReady(true);
      await first;
      await pumpEventQueue();
      expect(handled, ['first']);

      owner.setReady(true);
      await second;
      expect(handled, ['first', 'second']);
    });

    test('an item its owner hands back unfinished waits for the next '
        'owner', () async {
      final gate = NavigationReadyGate<String>();
      final second = <String>[];
      // The root went away while it was opening the share (a soft restart
      // mid-parse), so it could not finish it.
      gate.attach((item) async => false).setReady(true);

      final done = gate.run('file');
      await pumpEventQueue();
      expect(second, isEmpty);

      gate.attach(finishInto(second)).setReady(true);
      await done;
      expect(second, ['file']);
    });

    test('an item handed back after a ready owner replaced the one handling '
        'it goes straight to the new owner', () async {
      final gate = NavigationReadyGate<String>();
      final second = <String>[];
      final restartMidway = Completer<void>();
      gate
          .attach((item) async {
            // The replacement attaches and is ready while this one works.
            gate.attach(finishInto(second)).setReady(true);
            await restartMidway.future;
            return false;
          })
          .setReady(true);

      final done = gate.run('file');
      await pumpEventQueue();
      restartMidway.complete();
      await done;

      expect(second, ['file']);
    });

    test('an item handed back by the current owner is kept ahead of later '
        'ones, for its next readiness', () async {
      final gate = NavigationReadyGate<String>();
      final handled = <String>[];
      var canFinish = false;
      final owner = gate.attach((item) async {
        if (!canFinish) return false;
        handled.add(item);
        return true;
      })..setReady(true);

      final first = gate.run('first');
      final second = gate.run('second');
      await pumpEventQueue();
      expect(handled, isEmpty);

      canFinish = true;
      owner.setReady(true);
      await Future.wait([first, second]);
      expect(handled, ['first', 'second']);
    });
  });
}
