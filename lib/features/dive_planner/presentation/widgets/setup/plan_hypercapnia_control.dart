import 'package:flutter/material.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_choice_wrap.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The three states a plan's hypercapnia-bailout override can be in (issue
/// #3743), matching [PlanPpO2BandsControl]'s shape: follow the diver's
/// Settings default, explicitly off regardless of that default, or a custom
/// AMV/duration for this plan.
enum _HypercapniaChoice { default_, off, custom }

/// Default/Off/Custom control for a plan's hypercapnia-bailout phase
/// override (issue #3743): an elevated RMV for a configurable duration at
/// the start of an OC bailout. "Default" always shows the diver's Settings
/// values as read-only text - it never hides them - and "Off" is a
/// plan-level choice distinct from the Settings toggle itself being off.
class PlanHypercapniaControl extends StatelessWidget {
  const PlanHypercapniaControl({
    super.key,
    required this.amv,
    required this.minutes,
    required this.explicitlyOff,
    required this.defaultAmv,
    required this.defaultMinutes,
    required this.enabledInSettings,
    required this.units,
    required this.onAmvChanged,
    required this.onMinutesChanged,
    required this.onOff,
    required this.onDefault,
  });

  /// This plan's own overrides; null = follow the Settings default (unless
  /// [explicitlyOff]).
  final double? amv;
  final int? minutes;

  /// True = this plan's OC bailout never uses a hypercapnia phase,
  /// regardless of [enabledInSettings] or [amv]/[minutes].
  final bool explicitlyOff;

  final double defaultAmv;
  final int defaultMinutes;

  /// Whether the diver's Settings have the hypercapnia phase on at all -
  /// decides what "Default" resolves to and displays.
  final bool enabledInSettings;

  /// Formats the displayed AMV in the diver's unit settings; [amv],
  /// [defaultAmv] and the values this control reports back are always
  /// L/min.
  final UnitFormatter units;

  final ValueChanged<double> onAmvChanged;
  final ValueChanged<int> onMinutesChanged;

  /// Sets or clears [explicitlyOff] for this plan.
  final ValueChanged<bool> onOff;

  /// Clears both overrides and [explicitlyOff] at once, back to following
  /// the diver's Settings.
  final VoidCallback onDefault;

  bool get _isCustom => amv != null || minutes != null;

  _HypercapniaChoice get _choice {
    if (explicitlyOff) return _HypercapniaChoice.off;
    if (_isCustom) return _HypercapniaChoice.custom;
    return _HypercapniaChoice.default_;
  }

  void _select(_HypercapniaChoice choice) {
    switch (choice) {
      case _HypercapniaChoice.default_:
        onDefault();
      case _HypercapniaChoice.off:
        onOff(true);
      case _HypercapniaChoice.custom:
        onOff(false);
        onAmvChanged(amv ?? defaultAmv);
        onMinutesChanged(minutes ?? defaultMinutes);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final choice = _choice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settings_decompression_hypercapniaTitle,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 6),
        PlanChoiceWrap<_HypercapniaChoice>(
          options: [
            (_HypercapniaChoice.default_, l10n.divePlanner_label_default),
            (_HypercapniaChoice.off, l10n.divePlanner_label_off),
            (_HypercapniaChoice.custom, l10n.divePlanner_label_airBreaksCustom),
          ],
          selected: choice,
          onChanged: _select,
        ),
        if (choice == _HypercapniaChoice.default_) ...[
          const SizedBox(height: 8),
          if (enabledInSettings)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.divePlanner_gasOptions_hypercapniaAmv}: '
                  '${units.formatRmv(defaultAmv)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                Text(
                  '${l10n.divePlanner_gasOptions_hypercapniaMinutes}: '
                  '$defaultMinutes ${l10n.divePlanner_label_minutesUnit}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
              ],
            )
          else
            Text(
              l10n.divePlanner_label_off,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
        ],
        if (choice == _HypercapniaChoice.custom) ...[
          const SizedBox(height: 8),
          PlanNumberField(
            label: l10n.divePlanner_gasOptions_hypercapniaAmv,
            value: amv != null ? units.convertRmv(amv!) : null,
            hintValue: units.convertRmv(defaultAmv),
            suffixText: units.rmvSymbol,
            decimals: units.rmvDecimals,
            allowEmpty: false,
            onChanged: (value) => onAmvChanged(
              value != null ? units.volumeToLiters(value) : defaultAmv,
            ),
          ),
          PlanNumberField(
            label: l10n.divePlanner_gasOptions_hypercapniaMinutes,
            value: minutes?.toDouble(),
            hintValue: defaultMinutes.toDouble(),
            suffixText: l10n.divePlanner_label_minutesUnit,
            isInteger: true,
            // A Custom phase of 0 minutes would read as on but size the
            // bailout as if it were off.
            min: 1,
            allowEmpty: false,
            onChanged: (value) =>
                onMinutesChanged((value ?? defaultMinutes.toDouble()).round()),
          ),
        ],
      ],
    );
  }
}
