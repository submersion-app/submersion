import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_detail/editing/dive_header_fields.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';
import 'package:submersion/shared/widgets/forms/form_row.dart';

/// An entry or exit row of the header editor (issue #4527): tapping it
/// picks a date, then a time.
///
/// Times are wall clock stamped UTC, as every dive time is. The minute on
/// show stands for the instant behind it ([pickedInstant]), so picking it
/// again keeps the stored seconds, and an estimate confirmed at its own
/// minute is stored exactly. A date picked and the time then cancelled
/// keeps the old time of day on the new date.
class DiveTimeRow extends ConsumerWidget {
  const DiveTimeRow({
    super.key,
    required this.label,
    required this.value,
    required this.onPicked,
    this.hint,
    this.stored,
    this.onClear,
    required this.firstDate,
    required this.lastDate,
  });

  final String label;
  final DateTime? value;

  /// The estimated exit, shown muted when there is no value. Never stored
  /// unless the diver picks it.
  final DateTime? hint;

  /// The value stored before the sitting: a time moved and moved back to
  /// its minute is given its stored seconds again ([pickedInstant]).
  final DateTime? stored;
  final ValueChanged<DateTime> onPicked;
  final VoidCallback? onClear;
  final DateTime firstDate;
  final DateTime lastDate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final units = ref.watch(unitFormatterProvider);
    final value = this.value;
    final hint = this.hint;
    return FormRow.picker(
      label: label,
      value: value == null ? null : units.formatDateTimeBullet(value),
      placeholder: hint == null
          ? context.l10n.diveLog_edit_row_notSet
          : units.formatDateTimeBullet(hint),
      onTap: () => _pick(context, units),
      onClear: value == null ? null : onClear,
    );
  }

  Future<void> _pick(BuildContext context, UnitFormatter units) async {
    final current = value ?? hint;
    final date = await showAppDatePicker(
      context: context,
      initialDate: _within(current ?? DateTime.now()),
      firstDate: firstDate,
      lastDate: lastDate,
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: current == null
          ? TimeOfDay.now()
          : TimeOfDay(hour: current.hour, minute: current.minute),
    );
    if (time == null) {
      // The time of day stays, seconds and all, on the new date. An
      // estimate is not the diver's: a cancel stores nothing for it.
      final current = value;
      if (current != null) {
        onPicked(
          DateTime.utc(
            date.year,
            date.month,
            date.day,
            current.hour,
            current.minute,
            current.second,
            current.millisecond,
          ),
        );
      }
      return;
    }
    final picked = DateTime.utc(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    onPicked(pickedInstant(picked, current, stored: stored));
  }

  /// [at]'s day, kept inside the row's range so the picker can open on it.
  DateTime _within(DateTime at) {
    final day = DateTime(at.year, at.month, at.day);
    if (day.isBefore(firstDate)) return firstDate;
    if (day.isAfter(lastDate)) return lastDate;
    return day;
  }
}
