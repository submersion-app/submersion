import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where the final decompression stop is held: 3, 4, 5 or 6 m, offered as
/// whole metres because that is how divers name it (a "6 m last stop"),
/// shown in the diver's depth unit. The schedule follows the 3 m grid down to
/// 6 m and then holds the chosen depth, so 4 and 5 m are real choices, not
/// rounded to the grid.
class PlanLastStopSelector extends StatelessWidget {
  const PlanLastStopSelector({
    super.key,
    required this.value,
    required this.units,
    required this.onChanged,
  });

  static const List<double> choicesMeters = [3, 4, 5, 6];

  final double value;
  final UnitFormatter units;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Snap a stored value that is not one of the choices (an imported plan)
    // to the nearest so the control always shows a selection.
    final selected = choicesMeters.reduce(
      (a, b) => (a - value).abs() <= (b - value).abs() ? a : b,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.plannerCanvas_rates_lastStop,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          SegmentedButton<double>(
            showSelectedIcon: false,
            style: const ButtonStyle(
              visualDensity: VisualDensity.compact,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            segments: [
              for (final meters in choicesMeters)
                ButtonSegment<double>(
                  value: meters,
                  label: Text(units.formatDepth(meters, decimals: 0)),
                ),
            ],
            selected: {selected},
            onSelectionChanged: (set) => onChanged(set.first),
          ),
        ],
      ),
    );
  }
}
