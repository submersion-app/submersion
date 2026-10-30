import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_choice_wrap.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Where the final decompression stop is held: the diver's Settings default,
/// or an override of 3, 4, 5 or 6 m, offered as whole metres because that is
/// how divers name it (a "6 m last stop"), shown in the diver's depth unit.
/// The schedule follows the 3 m grid down to 6 m and then holds the chosen
/// depth, so 4 and 5 m are real choices, not rounded to the grid.
///
/// Unlike the Setup accordion's number fields, this is a fixed-choice
/// control, so "follow Settings" is its own segment rather than an empty
/// box (issue #3552): picking "Default" clears the plan's override, picking
/// a depth sets one.
class PlanLastStopSelector extends StatelessWidget {
  const PlanLastStopSelector({
    super.key,
    required this.value,
    required this.defaultValueMeters,
    required this.units,
    required this.onChanged,
  });

  static const List<double> choicesMeters = [3, 4, 5, 6];

  /// The plan's own override in meters; null = follows [defaultValueMeters].
  final double? value;

  /// The diver's Settings default, shown on the "Default" segment.
  final double defaultValueMeters;

  final UnitFormatter units;

  /// Receives the new override in meters, or null when "Default" is chosen.
  final ValueChanged<double?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Snap an override that is not one of the choices (an imported plan) to
    // the nearest so the control always shows a selection.
    final double? selected = value == null
        ? null
        : choicesMeters.reduce(
            (a, b) => (a - value!).abs() <= (b - value!).abs() ? a : b,
          );
    // Stacked, not a label-plus-control row: the "Default (X m)" segment
    // added for issue #3552 makes the control too wide to share a row with
    // the label at the Setup accordion's usual widths (confirmed: 694 px
    // overflow at 272 px when it was still inline).
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.plannerCanvas_rates_lastStop,
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 6),
          // A Wrap of chips, not a SegmentedButton (issue #3552 follow-up):
          // 5 choices never reliably fit one row at the Setup accordion's
          // narrow widths - a SegmentedButton either wraps labels mid-word,
          // or (given unconstrained width to avoid that) pushes later
          // choices out of view with nothing to show they exist. A Wrap
          // breaks onto a second line on its own instead, so the Default
          // chip can safely show the resolved value too.
          PlanChoiceWrap<double?>(
            options: [
              (
                null,
                context.l10n.divePlanner_label_defaultWithValue(
                  units.formatDepth(defaultValueMeters, decimals: 0),
                ),
              ),
              for (final meters in choicesMeters)
                (meters, units.formatDepth(meters, decimals: 0)),
            ],
            selected: selected,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
