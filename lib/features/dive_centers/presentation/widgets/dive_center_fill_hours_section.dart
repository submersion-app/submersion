import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Why a pair of fill hours cannot be saved.
enum FillHoursProblem { missingOne, closesBeforeOpens }

/// Pure. Both times or neither, and the station closes after it opens: one
/// daily window, so no overnight hours (ruling R5).
FillHoursProblem? fillHoursProblem(int? opensAt, int? closesAt) {
  if (opensAt == null && closesAt == null) return null;
  if (opensAt == null || closesAt == null) return FillHoursProblem.missingOne;
  return closesAt > opensAt ? null : FillHoursProblem.closesBeforeOpens;
}

/// The dive center's fill hours: an opening and a closing time, each picked
/// with the time picker and shown in the diver's time format, a clear
/// button, and [errorText] under them when the pair cannot be saved.
class DiveCenterFillHoursSection extends StatelessWidget {
  const DiveCenterFillHoursSection({
    super.key,
    required this.opensAt,
    required this.closesAt,
    required this.units,
    required this.onChanged,
    this.errorText,
  });

  final int? opensAt;
  final int? closesAt;
  final UnitFormatter units;
  final void Function(int? opensAt, int? closesAt) onChanged;
  final String? errorText;

  static const _defaultOpens = 8 * 60;
  static const _defaultCloses = 17 * 60;

  Future<int?> _pick(BuildContext context, int? current, int fallback) async {
    final m = current ?? fallback;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60, minute: m % 60),
    );
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }

  Widget _row(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    required int? value,
    required VoidCallback onTap,
  }) => ListTile(
    key: key,
    leading: Icon(icon),
    title: Text(label),
    subtitle: Text(
      value == null
          ? context.l10n.diveCenters_fillHours_notSet
          : units.formatMinutesOfDay(value),
    ),
    trailing: const Icon(Icons.edit),
    contentPadding: EdgeInsets.zero,
    onTap: onTap,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.diveCenters_section_fillHours,
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (opensAt != null || closesAt != null)
              IconButton(
                key: const Key('fill-hours-clear'),
                tooltip: l10n.diveCenters_fillHours_clear,
                icon: const Icon(Icons.clear),
                onPressed: () => onChanged(null, null),
              ),
          ],
        ),
        Text(
          l10n.diveCenters_fillHours_caption,
          style: theme.textTheme.bodySmall,
        ),
        _row(
          context,
          key: const Key('fill-hours-opens'),
          icon: Icons.lock_open_outlined,
          label: l10n.diveCenters_fillHours_opens,
          value: opensAt,
          onTap: () async {
            final m = await _pick(context, opensAt, _defaultOpens);
            if (m != null) onChanged(m, closesAt);
          },
        ),
        _row(
          context,
          key: const Key('fill-hours-closes'),
          icon: Icons.lock_outline,
          label: l10n.diveCenters_fillHours_closes,
          value: closesAt,
          onTap: () async {
            final m = await _pick(context, closesAt, _defaultCloses);
            if (m != null) onChanged(opensAt, m);
          },
        ),
        if (errorText != null)
          Text(
            errorText!,
            key: const Key('fill-hours-error'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
      ],
    );
  }
}
