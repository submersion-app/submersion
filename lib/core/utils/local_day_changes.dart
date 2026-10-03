import 'dart:async';

import 'package:clock/clock.dart';

/// Emits each time the device's local calendar day changes.
///
/// For providers that read "today" or "this year" from the clock once per
/// build: their change-tick streams only fire on data writes, so an app left
/// open across midnight (or across New Year) keeps showing the previous day's
/// answer until something else rebuilds them. Feed this to
/// `ref.invalidateSelfWhen` alongside the data ticks.
///
/// A single timer aimed at midnight is not enough on its own: Dart timers run
/// on a monotonic clock that can stop while a phone sleeps, so a long timer
/// fires late after a wake. The wait is therefore capped at [maxWait], and
/// every wake compares the current date with the last one seen, so a missed
/// midnight is caught at most [maxWait] after the device resumes. Each event
/// is one date change, however many days passed while asleep.
///
/// The timer runs only while the stream has a listener.
Stream<void> localDayChanges({Duration maxWait = const Duration(hours: 1)}) {
  late final StreamController<void> controller;
  Timer? timer;
  // Set when listening starts; no timer runs before that.
  late DateTime day;

  void arm() {
    final now = clock.now();
    // One second past midnight so a timer that fires a hair early still
    // finds the new date rather than re-arming for a near-zero wait.
    final nextMidnight = DateTime(
      now.year,
      now.month,
      now.day + 1,
    ).add(const Duration(seconds: 1));
    final untilMidnight = nextMidnight.difference(now);
    timer = Timer(untilMidnight < maxWait ? untilMidnight : maxWait, () {
      final today = _dateOf(clock.now());
      if (today != day) {
        day = today;
        controller.add(null);
      }
      arm();
    });
  }

  controller = StreamController<void>(
    onListen: () {
      day = _dateOf(clock.now());
      arm();
    },
    onCancel: () {
      timer?.cancel();
      timer = null;
    },
  );
  return controller.stream;
}

DateTime _dateOf(DateTime moment) =>
    DateTime(moment.year, moment.month, moment.day);
