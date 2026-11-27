import 'package:flutter/material.dart';

import 'package:submersion/core/utils/switch_depth_format.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_choice_wrap.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_number_field.dart';
import 'package:submersion/l10n/l10n_extension.dart';

enum _SwitchDepthChoice { default_, off, custom }

/// Default/Off/Custom control for a plan's CCR setpoint switch depth (issue
/// #3793). "Default" follows the diver's Settings depth, "Off" never switches
/// by depth (the low setpoint throughout) regardless of Settings, and
/// "Custom" gives the plan its own depth, any value from 0.
///
/// All depths this control receives and reports are meters; it shows them in
/// the diver's depth unit.
class CcrSwitchDepthControl extends StatelessWidget {
  const CcrSwitchDepthControl({
    super.key,
    required this.title,
    required this.depth,
    required this.switchOff,
    required this.defaultDepth,
    required this.units,
    required this.onDefault,
    required this.onOff,
    required this.onCustom,
  });

  final String title;

  /// This plan's own switch depth in meters; null = follow Settings. Kept
  /// while [switchOff] is on, so turning Off back to Custom restores it.
  final double? depth;

  /// True = this plan never switches by depth.
  final bool switchOff;

  /// The diver's Settings switch depth in meters.
  final double defaultDepth;

  final UnitFormatter units;

  /// Clears the plan's depth and [switchOff], back to following Settings.
  final VoidCallback onDefault;

  /// Sets [switchOff] for this plan, keeping the stored depth.
  final VoidCallback onOff;

  /// Clears [switchOff] and writes a plan depth in meters.
  final ValueChanged<double> onCustom;

  _SwitchDepthChoice get _choice {
    if (switchOff) return _SwitchDepthChoice.off;
    if (depth != null) return _SwitchDepthChoice.custom;
    return _SwitchDepthChoice.default_;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final choice = _choice;
    final hintStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.hintColor,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 6),
        PlanChoiceWrap<_SwitchDepthChoice>(
          options: [
            (_SwitchDepthChoice.default_, l10n.divePlanner_label_default),
            (_SwitchDepthChoice.off, l10n.divePlanner_label_off),
            (_SwitchDepthChoice.custom, l10n.divePlanner_label_airBreaksCustom),
          ],
          selected: choice,
          onChanged: (picked) {
            if (picked == choice) return;
            switch (picked) {
              case _SwitchDepthChoice.default_:
                onDefault();
              case _SwitchDepthChoice.off:
                onOff();
              case _SwitchDepthChoice.custom:
                onCustom(depth ?? defaultDepth);
            }
          },
        ),
        const SizedBox(height: 8),
        switch (choice) {
          _SwitchDepthChoice.default_ => Text(
            formatSwitchDepth(units, defaultDepth),
            style: hintStyle,
          ),
          _SwitchDepthChoice.off => Text(
            l10n.plannerCanvas_ccr_switchDepthOffNote,
            style: hintStyle,
          ),
          _SwitchDepthChoice.custom => PlanNumberField(
            label: l10n.divePlanner_label_airBreaksCustom,
            semanticsLabel: title,
            value: units.convertDepth(depth ?? defaultDepth),
            hintValue: units.convertDepth(defaultDepth),
            suffixText: units.depthSymbol,
            decimals: 1,
            // Any depth from 0 (high setpoint from the surface) up to the
            // same 100 m the Settings field takes.
            min: 0,
            max: units.convertDepth(100),
            allowEmpty: false,
            onChanged: (v) {
              if (v != null) onCustom(units.depthToMeters(v));
            },
          ),
        },
      ],
    );
  }
}
