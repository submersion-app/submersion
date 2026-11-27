import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/opening_hours/opening_hours.dart';
import 'package:submersion/core/opening_hours/opening_status.dart';

/// A run of consecutive weekdays (in the locale's week order) with the same
/// hours, shown as one row: "Mon to Fri 09:00 to 17:00" (issue #5073).
class DayGroup {
  /// Weekdays, 1 Monday to 7 Sunday, in the order shown.
  final List<int> weekdays;
  final DayHours hours;

  const DayGroup(this.weekdays, this.hours);
}

/// [schedule]'s week as rows, consecutive equal days joined; [weekOrder] is
/// the locale's week, its first day first.
List<DayGroup> groupDays(
  OpeningSchedule schedule, {
  required List<int> weekOrder,
}) {
  final groups = <DayGroup>[];
  for (final day in weekOrder) {
    final hours = schedule.dayHours(day);
    if (groups.isNotEmpty && groups.last.hours == hours) {
      final last = groups.removeLast();
      groups.add(DayGroup([...last.weekdays, day], hours));
    } else {
      groups.add(DayGroup([day], hours));
    }
  }
  return groups;
}

/// [hours]' schedules with the one that applies [today] first, the rest in
/// the order the diver listed them.
List<OpeningSchedule> schedulesInDisplayOrder(
  OpeningHours hours,
  DateTime today,
) {
  final current = scheduleOn(hours, today);
  if (current == null) return hours.schedules;
  return [current, ...hours.schedules.where((s) => !identical(s, current))];
}

/// A weekday's name in the app's locale: 1 is Monday, 7 is Sunday.
String weekdayName(BuildContext context, int weekday, {bool short = false}) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  // 1 January 2024 was a Monday.
  final date = DateTime(2024, 1, weekday);
  return (short ? DateFormat.E(locale) : DateFormat.EEEE(locale)).format(date);
}

/// The weekdays in the locale's order, its first day of the week first.
List<int> localeWeekdays(BuildContext context) {
  // MaterialLocalizations counts from Sunday = 0.
  final first = MaterialLocalizations.of(context).firstDayOfWeekIndex;
  final start = first == 0 ? DateTime.sunday : first;
  return [for (var i = 0; i < 7; i++) (start - 1 + i) % 7 + 1];
}
