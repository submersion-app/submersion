import 'package:flutter/material.dart' show TimeOfDay;

import 'package:submersion/core/util/wall_clock_utc.dart';

/// When the reminder for a draft out of the water at [exitWallClock] fires
/// (issue #637): three days later, at [reminderTime], on the diver's own
/// clock. The exit is wall-clock UTC, as the dive stores it.
DateTime draftReminderAt({
  required DateTime exitWallClock,
  required TimeOfDay reminderTime,
}) {
  final exit = fromWallClockUtc(exitWallClock);
  return DateTime(
    exit.year,
    exit.month,
    exit.day + 3,
    reminderTime.hour,
    reminderTime.minute,
  );
}
