import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/utils/local_day_changes.dart';

void main() {
  group('localDayChanges', () {
    test('emits once when the local day rolls over at midnight', () {
      fakeAsync((async) {
        var events = 0;
        final sub = localDayChanges().listen((_) => events++);

        async.elapse(const Duration(minutes: 59));
        expect(events, 0, reason: 'still Dec 31 at 23:59');

        async.elapse(const Duration(minutes: 2));
        expect(events, 1, reason: 'Jan 1 has begun');

        sub.cancel();
      }, initialTime: DateTime(2026, 12, 31, 23));
    });

    test('stays silent within a day despite its periodic re-checks', () {
      fakeAsync((async) {
        var events = 0;
        final sub = localDayChanges().listen((_) => events++);

        async.elapse(const Duration(hours: 10));
        expect(events, 0);

        sub.cancel();
      }, initialTime: DateTime(2026, 7, 15, 8));
    });

    test('emits once per day over several days', () {
      fakeAsync((async) {
        var events = 0;
        final sub = localDayChanges().listen((_) => events++);

        async.elapse(const Duration(hours: 49));
        expect(events, 2, reason: 'Jul 16 and Jul 17 each began');

        sub.cancel();
      }, initialTime: DateTime(2026, 7, 15, 12));
    });

    test('cancelling leaves no timer behind', () {
      fakeAsync((async) {
        final StreamSubscription<void> sub = localDayChanges().listen((_) {});
        expect(async.pendingTimers, isNotEmpty);

        sub.cancel();
        expect(async.pendingTimers, isEmpty);
      }, initialTime: DateTime(2026, 7, 15, 12));
    });
  });
}
