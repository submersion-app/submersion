import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/change_log/data/services/change_log_settle_scheduler.dart';

void main() {
  const quiet = Duration(seconds: 10);

  test('several changes settle once after the quiet period', () {
    fakeAsync((async) {
      final changes = StreamController<void>.broadcast();
      var settles = 0;
      final scheduler = ChangeLogSettleScheduler(
        changes: changes.stream,
        settle: () async => settles++,
      )..start();

      changes.add(null);
      async.elapse(const Duration(seconds: 5));
      changes.add(null);
      async.elapse(const Duration(seconds: 9));
      expect(settles, 0);

      async.elapse(const Duration(seconds: 1));
      expect(settles, 1);

      async.elapse(quiet * 3);
      expect(settles, 1);
      scheduler.stop();
      changes.close();
    });
  });

  test('a change during a settle runs another', () {
    fakeAsync((async) {
      final changes = StreamController<void>.broadcast();
      final release = Completer<void>();
      var settles = 0;
      final scheduler = ChangeLogSettleScheduler(
        changes: changes.stream,
        settle: () {
          settles++;
          return settles == 1 ? release.future : Future<void>.value();
        },
      )..start();

      changes.add(null);
      async.elapse(quiet);
      expect(settles, 1);

      changes.add(null);
      async.elapse(quiet);
      expect(settles, 1, reason: 'one settle at a time');

      release.complete();
      async.flushMicrotasks();
      async.elapse(quiet);
      expect(settles, 2);
      scheduler.stop();
      changes.close();
    });
  });

  test('stop cancels a pending settle', () {
    fakeAsync((async) {
      final changes = StreamController<void>.broadcast();
      var settles = 0;
      final scheduler = ChangeLogSettleScheduler(
        changes: changes.stream,
        settle: () async => settles++,
      )..start();

      changes.add(null);
      async.flushMicrotasks();
      scheduler.stop();
      async.elapse(quiet * 2);

      expect(settles, 0);
      changes.close();
    });
  });
}
