import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/minutes_seconds_field.dart';

/// The moments a switch row's cylinder started being breathed, as one-tap
/// fills for its time (issue #4089). Only ever shown with at least one time.
class GasSwitchTimeChips extends StatelessWidget {
  const GasSwitchTimeChips({
    super.key,
    required this.times,
    required this.onSelected,
  });

  /// Seconds from the start of the dive, in the order to show them.
  final List<int> times;

  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          l10n.diveLog_edit_gasSwitches_startedDropping,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        for (final seconds in times)
          ActionChip(
            label: Text(formatMinutesSeconds(seconds)),
            tooltip: l10n.diveLog_edit_gasSwitches_useTime(
              formatMinutesSeconds(seconds),
            ),
            visualDensity: VisualDensity.compact,
            onPressed: () => onSelected(seconds),
          ),
      ],
    );
  }
}
