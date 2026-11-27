import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/opening_hours/opening_hours.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

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

/// The default range for a day just set to hours: 08:00 to 12:00.
const TimeRange _firstRange = TimeRange(480, 720);

/// One weekday of a schedule in the hours editor (issue #5073): closed, open
/// 24 hours, or open for one or more ranges, with a copy to other days.
///
/// Keys are `hours_day_<schedule>_<weekday>_<part>`.
class OpeningDayRow extends ConsumerWidget {
  const OpeningDayRow({
    super.key,
    required this.scheduleIndex,
    required this.weekday,
    required this.hours,
    required this.invalid,
    required this.onChanged,
    required this.onCopy,
  });

  final int scheduleIndex;
  final int weekday;
  final DayHours hours;

  /// Whether the day's ranges cannot be saved.
  final bool invalid;
  final ValueChanged<DayHours> onChanged;

  /// Copies this day's hours to the given weekdays.
  final ValueChanged<Set<int>> onCopy;

  String get _key => 'hours_day_${scheduleIndex}_$weekday';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);

    Widget kindChip(DayHoursKind kind, String label, String part) => ChoiceChip(
      key: ValueKey('${_key}_$part'),
      label: Text(label),
      selected: hours.kind == kind,
      onSelected: (_) => onChanged(switch (kind) {
        DayHoursKind.closed => const DayHours.closed(),
        DayHoursKind.open24h => const DayHours.open24h(),
        DayHoursKind.ranges =>
          hours.kind == DayHoursKind.ranges
              ? hours
              : DayHours.ranges(const [_firstRange]),
      }),
    );

    String time(int minutes) =>
        units.formatMinutesOfDay(minutes % minutesPerDay);

    Future<void> pick(int index, {required bool opens}) async {
      final range = hours.ranges[index];
      final current = opens ? range.opensAt : range.closesAt % minutesPerDay;
      final picked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      );
      if (picked == null) return;
      var minutes = picked.hour * 60 + picked.minute;
      // A close picked at 00:00 is midnight at the end of the day.
      if (!opens && minutes == 0) minutes = minutesPerDay;
      final ranges = [...hours.ranges];
      ranges[index] = opens
          ? range.copyWith(opensAt: minutes)
          : range.copyWith(closesAt: minutes);
      onChanged(DayHours.ranges(ranges));
    }

    final last = hours.ranges.isEmpty ? null : hours.ranges.last;
    final nextOpen = last == null ? 0 : last.closesAt + 60;
    final canAdd = nextOpen < minutesPerDay;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  weekdayName(context, weekday),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: invalid ? theme.colorScheme.error : null,
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('${_key}_copy'),
                icon: const Icon(Icons.copy_all_outlined, size: 20),
                tooltip: l10n.diveSites_hours_copyDay,
                onPressed: () async {
                  final days = await showDialog<Set<int>>(
                    context: context,
                    builder: (_) => _CopyDaysDialog(from: weekday),
                  );
                  if (days != null && days.isNotEmpty) onCopy(days);
                },
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              kindChip(
                DayHoursKind.closed,
                l10n.diveSites_hours_closed,
                'closed',
              ),
              kindChip(
                DayHoursKind.open24h,
                l10n.diveSites_hours_open24h,
                '24h',
              ),
              kindChip(
                DayHoursKind.ranges,
                l10n.diveSites_hours_kindHours,
                'hours',
              ),
            ],
          ),
          for (var i = 0; i < hours.ranges.length; i++)
            Row(
              children: [
                TextButton(
                  key: ValueKey('${_key}_opens_$i'),
                  onPressed: () => pick(i, opens: true),
                  child: Text(time(hours.ranges[i].opensAt)),
                ),
                const Text('–'),
                TextButton(
                  key: ValueKey('${_key}_closes_$i'),
                  onPressed: () => pick(i, opens: false),
                  child: Text(time(hours.ranges[i].closesAt)),
                ),
                IconButton(
                  key: ValueKey('${_key}_remove_range_$i'),
                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                  tooltip: l10n.diveSites_hours_removeRange,
                  onPressed: () => onChanged(
                    DayHours.ranges([...hours.ranges]..removeAt(i)),
                  ),
                ),
              ],
            ),
          if (hours.kind == DayHoursKind.ranges && canAdd)
            TextButton.icon(
              key: ValueKey('${_key}_add_range'),
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.diveSites_hours_addRange),
              onPressed: () => onChanged(
                DayHours.ranges([...hours.ranges, _rangeAfter(nextOpen)]),
              ),
            ),
        ],
      ),
    );
  }
}

/// A new range opening at [opensAt]: two hours long, never past midnight.
TimeRange _rangeAfter(int opensAt) =>
    TimeRange(opensAt, math.min(opensAt + 120, minutesPerDay));

/// Picks the weekdays to copy one day's hours to.
class _CopyDaysDialog extends StatefulWidget {
  const _CopyDaysDialog({required this.from});

  final int from;

  @override
  State<_CopyDaysDialog> createState() => _CopyDaysDialogState();
}

class _CopyDaysDialogState extends State<_CopyDaysDialog> {
  final Set<int> _picked = {};

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final others = localeWeekdays(
      context,
    ).where((d) => d != widget.from).toList();
    final all = _picked.length == others.length;
    return AlertDialog(
      title: Text(
        l10n.diveSites_hours_copyTitle(weekdayName(context, widget.from)),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CheckboxListTile(
            key: const ValueKey('hours_copy_all'),
            title: Text(l10n.diveSites_hours_selectAll),
            value: all,
            onChanged: (on) => setState(() {
              _picked
                ..clear()
                ..addAll(on == true ? others : const []);
            }),
          ),
          for (final day in others)
            CheckboxListTile(
              key: ValueKey('hours_copy_day_$day'),
              title: Text(weekdayName(context, day)),
              value: _picked.contains(day),
              onChanged: (on) => setState(
                () => on == true ? _picked.add(day) : _picked.remove(day),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('hours_copy_confirm'),
          onPressed: () => Navigator.of(context).pop({..._picked}),
          child: Text(l10n.diveSites_hours_copy),
        ),
      ],
    );
  }
}
