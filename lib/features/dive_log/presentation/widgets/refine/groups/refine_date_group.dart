import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/weekday_filter_selector.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// The Refine panel's Date group (#2773): range presets, start and end
/// pickers, and weekdays (which AND with the range).
class RefineDateGroup extends ConsumerWidget {
  const RefineDateGroup({
    super.key,
    required this.draft,
    required this.onChanged,
  });

  final DiveFilterState draft;
  final ValueChanged<DiveFilterState> onChanged;

  /// The DiveFilterState fields this group edits (read by the axis guard).
  static const fields = {'startDate', 'endDate', 'weekdays'};

  static int activeCount(DiveFilterState f) => [
    f.startDate != null || f.endDate != null,
    f.weekdays.isNotEmpty,
  ].where((active) => active).length;

  static String title(AppLocalizations l10n) =>
      l10n.diveLog_search_section_dateRange;

  void _setRange(DateTime? start, DateTime? end) => onChanged(
    draft.copyWith(
      startDate: start,
      clearStartDate: start == null,
      endDate: end,
      clearEndDate: end == null,
    ),
  );

  Future<void> _pick(BuildContext context, {required bool isStart}) async {
    final initial = isStart ? draft.startDate : draft.endDate;
    final picked = await showAppDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    if (isStart) {
      _setRange(picked, draft.endDate);
    } else {
      _setRange(draft.startDate, picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = UnitFormatter(ref.watch(settingsProvider));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    DateTime yearsBack(int n) => DateTime(now.year - n, now.month, now.day);
    final presets = <(String, DateTime?, DateTime?)>[
      (l10n.diveLog_filter_presetAllTime, null, null),
      (l10n.diveLog_filter_presetThisYear, DateTime(now.year, 1, 1), today),
      (l10n.diveLog_filter_presetLast12Months, yearsBack(1), today),
      (
        l10n.diveLog_filter_presetLastYear,
        DateTime(now.year - 1, 1, 1),
        DateTime(now.year - 1, 12, 31),
      ),
      (l10n.diveLog_filter_presetLast5Years, yearsBack(5), today),
      (l10n.diveLog_filter_presetLast10Years, yearsBack(10), today),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          children: [
            for (final (label, start, end) in presets)
              ActionChip(
                label: Text(label, style: const TextStyle(fontSize: 12)),
                onPressed: () => _setRange(start, end),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(context, isStart: true),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  draft.startDate != null
                      ? units.formatDate(draft.startDate)
                      : l10n.diveLog_filter_startDate,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(l10n.diveLog_filter_dateSeparator),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _pick(context, isStart: false),
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(
                  draft.endDate != null
                      ? units.formatDate(draft.endDate)
                      : l10n.diveLog_filter_endDate,
                ),
              ),
            ),
          ],
        ),
        if (draft.startDate != null || draft.endDate != null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => _setRange(null, null),
              child: Text(l10n.diveLog_filter_clearDates),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          l10n.diveLog_filter_sectionWeekdays,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        WeekdayFilterSelector(
          selectedWeekdays: draft.weekdays,
          onChanged: (days) => onChanged(draft.copyWith(weekdays: days)),
        ),
        if (draft.weekdays.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => onChanged(draft.copyWith(clearWeekdays: true)),
              child: Text(l10n.diveLog_filter_clearWeekdays),
            ),
          ),
      ],
    );
  }
}
