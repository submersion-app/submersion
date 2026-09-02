import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// A Monday, used only to derive locale-aware weekday labels via
/// [DateFormat]; the specific date is irrelevant, only its weekday is.
final DateTime _referenceMonday = DateTime(2024, 1, 1);

/// Locale-aware abbreviated weekday label (e.g. "Mon", "lun.") for [weekday]
/// in [DateTime.weekday] numbering (1 = Monday, 7 = Sunday).
String weekdayAbbreviation(BuildContext context, int weekday) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.E(
    locale,
  ).format(_referenceMonday.add(Duration(days: weekday - 1)));
}

/// Weekday chip selector for the dive list's Advanced Filter.
///
/// Chips are ordered to match the diver's locale-specific week start
/// (Monday- or Sunday-first), derived from
/// [MaterialLocalizations.firstDayOfWeekIndex] the same way the platform
/// date picker orders its calendar grid.
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
    final materialLocalizations = MaterialLocalizations.of(context);
    // firstDayOfWeekIndex: 0 = Sunday .. 6 = Saturday. Converted to
    // DateTime.weekday numbering (1 = Monday .. 7 = Sunday) so the chip order
    // follows the diver's locale-specific week start.
    final firstWeekday = materialLocalizations.firstDayOfWeekIndex == 0
        ? 7
        : materialLocalizations.firstDayOfWeekIndex;
    final orderedWeekdays = List.generate(
      7,
      (i) => ((firstWeekday - 1 + i) % 7) + 1,
    );

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
