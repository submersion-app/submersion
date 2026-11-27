import 'package:flutter/material.dart';

import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_choice_wrap.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/l10n/l10n_extension.dart';

enum _SetpointChoice { default_, custom }

/// Default/Custom control for one CCR setpoint of a plan (issue #3793),
/// shaped like [PlanHypercapniaControl]: "Default" follows the diver's
/// Settings and shows that value as read-only text, "Custom" gives the plan
/// its own setpoint, starting from the Settings value.
class CcrSetpointControl extends StatelessWidget {
  const CcrSetpointControl({
    super.key,
    required this.title,
    required this.value,
    required this.defaultValue,
    required this.onDefault,
    required this.onCustom,
  });

  final String title;

  /// This plan's own setpoint in bar; null = follow the Settings default.
  final double? value;

  /// The diver's Settings setpoint in bar.
  final double defaultValue;

  /// Clears the plan's setpoint, back to following Settings.
  final VoidCallback onDefault;

  /// Writes a plan setpoint in bar.
  final ValueChanged<double> onCustom;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final choice = value == null
        ? _SetpointChoice.default_
        : _SetpointChoice.custom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 6),
        PlanChoiceWrap<_SetpointChoice>(
          options: [
            (_SetpointChoice.default_, l10n.divePlanner_label_default),
            (_SetpointChoice.custom, l10n.divePlanner_label_airBreaksCustom),
          ],
          selected: choice,
          onChanged: (picked) {
            if (picked == choice) return;
            switch (picked) {
              case _SetpointChoice.default_:
                onDefault();
              case _SetpointChoice.custom:
                onCustom(defaultValue);
            }
          },
        ),
        const SizedBox(height: 8),
        if (choice == _SetpointChoice.default_)
          Text(
            '${formatFixedForDisplay(defaultValue, 1)} bar',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          )
        else
          PlanNumberField(
            label: l10n.divePlanner_label_airBreaksCustom,
            semanticsLabel: title,
            value: value,
            hintValue: defaultValue,
            suffixText: 'bar',
            decimals: 1,
            // A setpoint of exactly 0 bar is meaningless; typing it clamps up
            // to this practical minimum when focus leaves the box.
            min: 0.1,
            // Custom always holds a value: an emptied box returns to the
            // plan's value on blur instead of silently becoming Default.
            allowEmpty: false,
            onChanged: (v) {
              if (v != null) onCustom(v);
            },
          ),
      ],
    );
  }
}
