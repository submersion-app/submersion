import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/opening_hours/opening_hours.dart';
import 'package:submersion/features/dive_sites/presentation/editing/opening_day_row.dart';
import 'package:submersion/features/dive_sites/presentation/opening_hours_summary.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A season a schedule starts with when made seasonal: 1 April to
/// 31 October, the northern summer most inland sites keep.
const YearlyDateRange defaultSeason = YearlyDateRange(
  start: MonthDay(4, 1),
  end: MonthDay(10, 31),
);

/// A day of the year as the locale writes it, without a year ("Apr 1").
String monthDayLabel(BuildContext context, MonthDay day) => DateFormat.MMMd(
  Localizations.localeOf(context).toLanguageTag(),
).format(DateTime(2000, day.month, day.day));

/// One schedule in the hours editor (issue #5073): its name, an optional
/// yearly season and its seven days. Keys are `hours_schedule_<index>_*`.
class OpeningScheduleEditor extends StatefulWidget {
  const OpeningScheduleEditor({
    super.key,
    required this.index,
    required this.schedule,
    required this.invalidDays,
    required this.onChanged,
    required this.onDelete,
  });

  final int index;
  final OpeningSchedule schedule;

  /// Weekdays of this schedule that cannot be saved.
  final Set<int> invalidDays;
  final ValueChanged<OpeningSchedule> onChanged;
  final VoidCallback onDelete;

  @override
  State<OpeningScheduleEditor> createState() => _OpeningScheduleEditorState();
}

class _OpeningScheduleEditorState extends State<OpeningScheduleEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.schedule.name ?? '',
  );

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _key => 'hours_schedule_${widget.index}';

  void _setDay(int weekday, DayHours hours) => widget.onChanged(
    widget.schedule.copyWith(days: {...widget.schedule.days, weekday: hours}),
  );

  Future<void> _pickSeasonEnd({required bool start}) async {
    final season = widget.schedule.season ?? defaultSeason;
    final picked = await showDialog<MonthDay>(
      context: context,
      builder: (_) =>
          _MonthDayDialog(initial: start ? season.start : season.end),
    );
    if (picked == null) return;
    widget.onChanged(
      widget.schedule.copyWith(
        season: start
            ? season.copyWith(start: picked)
            : season.copyWith(end: picked),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final schedule = widget.schedule;
    final season = schedule.season;
    return Card.outlined(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    key: ValueKey('${_key}_name'),
                    controller: _name,
                    decoration: InputDecoration(
                      labelText: l10n.diveSites_hours_scheduleName,
                      hintText: l10n.diveSites_hours_scheduleName_hint,
                      isDense: true,
                    ),
                    onChanged: (text) => widget.onChanged(
                      text.trim().isEmpty
                          ? schedule.copyWith(clearName: true)
                          : schedule.copyWith(name: text),
                    ),
                  ),
                ),
                IconButton(
                  key: ValueKey('${_key}_delete'),
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.diveSites_hours_deleteSchedule,
                  onPressed: widget.onDelete,
                ),
              ],
            ),
            SwitchListTile(
              key: ValueKey('${_key}_seasonal'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.diveSites_hours_seasonal),
              value: season != null,
              onChanged: (on) => widget.onChanged(
                on
                    ? schedule.copyWith(season: defaultSeason)
                    : schedule.copyWith(clearSeason: true),
              ),
            ),
            if (season != null)
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l10n.diveSites_hours_seasonFrom),
                  OutlinedButton(
                    key: ValueKey('${_key}_season_start'),
                    onPressed: () => _pickSeasonEnd(start: true),
                    child: Text(monthDayLabel(context, season.start)),
                  ),
                  Text(l10n.diveSites_hours_seasonTo),
                  OutlinedButton(
                    key: ValueKey('${_key}_season_end'),
                    onPressed: () => _pickSeasonEnd(start: false),
                    child: Text(monthDayLabel(context, season.end)),
                  ),
                ],
              ),
            for (final weekday in localeWeekdays(context))
              OpeningDayRow(
                key: ValueKey('${_key}_day_$weekday'),
                scheduleIndex: widget.index,
                weekday: weekday,
                hours: schedule.dayHours(weekday),
                invalid: widget.invalidDays.contains(weekday),
                onChanged: (hours) => _setDay(weekday, hours),
                onCopy: (days) => widget.onChanged(
                  schedule.copyWith(
                    days: {
                      ...schedule.days,
                      for (final d in days) d: schedule.dayHours(weekday),
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Picks a day of the year: a month, then a day valid in a leap year.
class _MonthDayDialog extends StatefulWidget {
  const _MonthDayDialog({required this.initial});

  final MonthDay initial;

  @override
  State<_MonthDayDialog> createState() => _MonthDayDialogState();
}

class _MonthDayDialogState extends State<_MonthDayDialog> {
  late int _month = widget.initial.month;
  late int _day = widget.initial.day;

  int get _daysInMonth => DateTime(2000, _month + 1, 0).day;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final material = MaterialLocalizations.of(context);
    return AlertDialog(
      content: Row(
        children: [
          Expanded(
            child: DropdownButton<int>(
              key: const ValueKey('hours_season_month'),
              isExpanded: true,
              value: _month,
              items: [
                for (var m = 1; m <= 12; m++)
                  DropdownMenuItem(
                    value: m,
                    child: Text(
                      DateFormat.MMMM(locale).format(DateTime(2000, m)),
                    ),
                  ),
              ],
              onChanged: (m) => setState(() {
                _month = m!;
                if (_day > _daysInMonth) _day = _daysInMonth;
              }),
            ),
          ),
          const SizedBox(width: 12),
          DropdownButton<int>(
            key: const ValueKey('hours_season_day'),
            value: _day,
            items: [
              for (var d = 1; d <= _daysInMonth; d++)
                DropdownMenuItem(value: d, child: Text('$d')),
            ],
            onChanged: (d) => setState(() => _day = d!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('hours_season_confirm'),
          onPressed: () => Navigator.of(context).pop(MonthDay(_month, _day)),
          child: Text(material.okButtonLabel),
        ),
      ],
    );
  }
}
