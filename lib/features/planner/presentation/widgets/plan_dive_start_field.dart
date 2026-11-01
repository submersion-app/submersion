import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/planner/presentation/providers/plan_series_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';

/// When the selected dive starts (issue #3565), optional.
///
/// A start and the surface interval before the dive set each other: give a
/// later dive a start and its interval is measured from the dive before it;
/// change the interval and the start moves (see `PlanSeriesDive.fixedStart`).
/// A later dive can only be timed once there is a start before it to measure
/// from, so the field is greyed out until the first dive has one or follows a
/// logged dive. Times are clock digits stamped UTC, like the dive log's.
class PlanDiveStartField extends ConsumerWidget {
  const PlanDiveStartField({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final index = ref.watch(
      planSeriesNotifierProvider.select((s) => s.selectedIndex),
    );
    final fixed = ref.watch(
      planSeriesNotifierProvider.select((s) => s.selected.fixedStart),
    );
    final start = ref.watch(
      divePlanNotifierProvider.select((s) => s.startDateTime),
    );
    // A later dive has a start only when the dive before it has an end.
    final enabled = index == 0 || start != null;
    // A first dive's start is always its own; a later one's only when fixed.
    final clearable = start != null && (index == 0 || fixed);

    final field = InkWell(
      key: const Key('diveStartField'),
      onTap: enabled ? () => _pick(context, ref, start) : null,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        isEmpty: false,
        decoration: InputDecoration(
          isDense: true,
          enabled: enabled,
          border: const OutlineInputBorder(),
          labelText: l10n.plannerSeries_start,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          prefixIcon: const Icon(Icons.schedule),
          suffixIcon: clearable
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  tooltip: l10n.plannerSeries_start_clear,
                  onPressed: () => ref
                      .read(planSeriesNotifierProvider.notifier)
                      .setSelectedStart(null),
                )
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                start == null
                    ? l10n.plannerSeries_start_notSet
                    : units.formatDateTime(start, l10n: l10n),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (index > 0 && fixed)
              Tooltip(
                message: l10n.plannerSeries_start_fixed,
                child: const Icon(Icons.push_pin_outlined, size: 18),
              ),
          ],
        ),
      ),
    );
    if (enabled) return field;
    return Tooltip(message: l10n.plannerSeries_start_needsFirst, child: field);
  }

  Future<void> _pick(
    BuildContext context,
    WidgetRef ref,
    DateTime? current,
  ) async {
    final start = await pickPlanStart(context, current: current);
    if (start == null || !context.mounted) return;
    ref.read(planSeriesNotifierProvider.notifier).setSelectedStart(start);
  }
}

/// Asks for a date and time, returned as clock digits stamped UTC like the dive
/// log's times; null when the diver backs out of either.
Future<DateTime?> pickPlanStart(
  BuildContext context, {
  DateTime? current,
}) async {
  // Shown as the clock digits it holds, so read them as a local time.
  final shown = current == null
      ? DateTime.now()
      : DateTime(
          current.year,
          current.month,
          current.day,
          current.hour,
          current.minute,
        );
  final date = await showAppDatePicker(
    context: context,
    initialDate: shown,
    firstDate: DateTime(1950),
    lastDate: DateTime(shown.year + 10),
  );
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(shown),
  );
  if (time == null) return null;
  return DateTime.utc(date.year, date.month, date.day, time.hour, time.minute);
}
