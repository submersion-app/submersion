import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/first_day_of_week.dart';
import 'package:submersion/core/presentation/localizations/week_start_material_localizations.dart';

/// Locale-aware abbreviated weekday label (e.g. "Mon", "lun.") for [weekday]
/// in [DateTime.weekday] numbering (1 = Monday, 7 = Sunday).
String weekdayAbbreviation(BuildContext context, int weekday) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.E(locale).format(dateOnWeekday(weekday));
}

/// Weekday chip selector for the dive list's Advanced Filter.
///
/// Chips start on the diver's first day of the week, read from
/// [MaterialLocalizations.firstDayOfWeekIndex] the same way the platform
/// date picker orders its calendar grid (issue #4232).
class WeekdayFilterSelector extends StatelessWidget {
  final List<int> selectedWeekdays;
  final ValueChanged<List<int>> onChanged;

  const WeekdayFilterSelector({
    super.key,
    required this.selectedWeekdays,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final orderedWeekdays = weekdaysFrom(firstWeekdayOf(context));

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: orderedWeekdays.map((weekday) {
        final isSelected = selectedWeekdays.contains(weekday);
        return FilterChip(
          label: Text(weekdayAbbreviation(context, weekday)),
          selected: isSelected,
          onSelected: (selected) {
            final updated = List<int>.from(selectedWeekdays);
            if (selected) {
              updated.add(weekday);
            } else {
              updated.remove(weekday);
            }
            onChanged(updated);
          },
        );
      }).toList(),
    );
  }
}
