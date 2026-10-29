import 'package:flutter/material.dart';

import 'package:submersion/core/deco/deco_ppo2_limits.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_choice_wrap.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The three states a plan's ppO2-band (or explicit-depth) override can be
/// in, matching [PlanAirBreaksControl]'s shape: follow the diver's Settings
/// default, explicitly off regardless of that default, or a custom value for
/// this plan.
enum _PpO2BandsChoice { default_, off, custom }

/// Default/Off/Custom control for a plan's per-O2-band deco ppO2 overrides
/// (issue #3580), styled like the Setup accordion's air-breaks control.
/// Unlike the plain two-way Default/Custom switch this replaced, "Default"
/// here always shows the diver's Settings values as read-only text - it
/// never hides them - and "Off" is a plan-level choice distinct from the
/// Settings band toggle itself being off.
class PlanPpO2BandsControl extends StatelessWidget {
  const PlanPpO2BandsControl({
    super.key,
    required this.band1,
    required this.band2,
    required this.band3,
    required this.explicitlyOff,
    required this.defaultBand1,
    required this.defaultBand2,
    required this.defaultBand3,
    required this.bandsEnabledInSettings,
    required this.onBand1Changed,
    required this.onBand2Changed,
    required this.onBand3Changed,
    required this.onOff,
    required this.onDefault,
  });

  /// This plan's own band overrides; null = follow the Settings default
  /// (unless [explicitlyOff]).
  final double? band1;
  final double? band2;
  final double? band3;

  /// True = this plan never uses band mode, regardless of
  /// [bandsEnabledInSettings] or any of [band1]/[band2]/[band3].
  final bool explicitlyOff;

  final double defaultBand1;
  final double defaultBand2;
  final double defaultBand3;

  /// Whether the diver's Settings have band mode on at all - decides what
  /// "Default" resolves to and displays.
  final bool bandsEnabledInSettings;

  final ValueChanged<double> onBand1Changed;
  final ValueChanged<double> onBand2Changed;
  final ValueChanged<double> onBand3Changed;

  /// Sets or clears [explicitlyOff] for this plan.
  final ValueChanged<bool> onOff;

  /// Clears all three band overrides and [explicitlyOff] at once, back to
  /// following the diver's Settings.
  final VoidCallback onDefault;

  bool get _isCustom => hasCustomDecoBands(band1, band2, band3);

  _PpO2BandsChoice get _choice {
    if (explicitlyOff) return _PpO2BandsChoice.off;
    if (_isCustom) return _PpO2BandsChoice.custom;
    return _PpO2BandsChoice.default_;
  }

  void _select(_PpO2BandsChoice choice) {
    switch (choice) {
      case _PpO2BandsChoice.default_:
        onDefault();
      case _PpO2BandsChoice.off:
        onOff(true);
      case _PpO2BandsChoice.custom:
        onOff(false);
        onBand1Changed(band1 ?? defaultBand1);
        onBand2Changed(band2 ?? defaultBand2);
        onBand3Changed(band3 ?? defaultBand3);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settings_decompression_ppO2BandsTitle,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 6),
        PlanChoiceWrap<_PpO2BandsChoice>(
          options: [
            (_PpO2BandsChoice.default_, l10n.divePlanner_label_default),
            (_PpO2BandsChoice.off, l10n.divePlanner_label_off),
            (_PpO2BandsChoice.custom, l10n.divePlanner_label_airBreaksCustom),
          ],
          selected: _choice,
          onChanged: _select,
        ),
        if (_choice == _PpO2BandsChoice.default_) ...[
          const SizedBox(height: 8),
          if (bandsEnabledInSettings)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${l10n.divePlanner_gasOptions_ppO2DecoBand1}: '
                  '${formatRoundedForInput(defaultBand1, 2)} bar',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                Text(
                  '${l10n.divePlanner_gasOptions_ppO2DecoBand2}: '
                  '${formatRoundedForInput(defaultBand2, 2)} bar',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.hintColor,
                  ),
                ),
                Text(
                  '${l10n.divePlanner_gasOptions_ppO2DecoBand3}: '
                  '${formatRoundedForInput(defaultBand3, 2)} bar',
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
        if (_choice == _PpO2BandsChoice.custom) ...[
          const SizedBox(height: 12),
          PlanPpO2Slider(
            label: l10n.divePlanner_gasOptions_ppO2DecoBand1,
            value: band1 ?? defaultBand1,
            onChanged: onBand1Changed,
          ),
          PlanPpO2Slider(
            label: l10n.divePlanner_gasOptions_ppO2DecoBand2,
            value: band2 ?? defaultBand2,
            onChanged: onBand2Changed,
          ),
          PlanPpO2Slider(
            label: l10n.divePlanner_gasOptions_ppO2DecoBand3,
            value: band3 ?? defaultBand3,
            onChanged: onBand3Changed,
          ),
        ],
      ],
    );
  }
}

/// Default/Off/Custom control for a plan's explicit MOD for 100% O2 override
/// (issue #3580), same shape as [PlanPpO2BandsControl].
class PlanMaxO2DepthControl extends StatelessWidget {
  const PlanMaxO2DepthControl({
    super.key,
    required this.maxO2DepthMeters,
    required this.explicitlyOff,
    required this.defaultMaxO2DepthMeters,
    required this.enabledInSettings,
    required this.units,
    required this.onChanged,
    required this.onOff,
    required this.onDefault,
  });

  /// This plan's own override; null = follow the Settings default (unless
  /// [explicitlyOff]).
  final double? maxO2DepthMeters;

  /// True = this plan never uses an explicit MOD for 100% O2, regardless of
  /// [enabledInSettings] or [maxO2DepthMeters].
  final bool explicitlyOff;

  final double defaultMaxO2DepthMeters;

  /// Whether the diver's Settings have the explicit-depth toggle on at all -
  /// decides what "Default" resolves to and displays.
  final bool enabledInSettings;

  /// Formats the displayed depth in the diver's unit settings; the slider's
  /// own grid stays in meters (issue #3580 follow-up).
  final UnitFormatter units;

  final ValueChanged<double> onChanged;

  /// Sets or clears [explicitlyOff] for this plan.
  final ValueChanged<bool> onOff;

  /// Clears the override and [explicitlyOff] at once, back to following the
  /// diver's Settings.
  final VoidCallback onDefault;

  _PpO2BandsChoice get _choice {
    if (explicitlyOff) return _PpO2BandsChoice.off;
    if (maxO2DepthMeters != null) return _PpO2BandsChoice.custom;
    return _PpO2BandsChoice.default_;
  }

  void _select(_PpO2BandsChoice choice) {
    switch (choice) {
      case _PpO2BandsChoice.default_:
        onDefault();
      case _PpO2BandsChoice.off:
        onOff(true);
      case _PpO2BandsChoice.custom:
        onOff(false);
        onChanged(maxO2DepthMeters ?? defaultMaxO2DepthMeters);
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
          l10n.settings_decompression_ppO2BandsDialog_maxO2DepthLabel,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 6),
        PlanChoiceWrap<_PpO2BandsChoice>(
          options: [
            (_PpO2BandsChoice.default_, l10n.divePlanner_label_default),
            (_PpO2BandsChoice.off, l10n.divePlanner_label_off),
            (_PpO2BandsChoice.custom, l10n.divePlanner_label_airBreaksCustom),
          ],
          selected: choice,
          onChanged: _select,
        ),
        if (choice == _PpO2BandsChoice.default_) ...[
          const SizedBox(height: 8),
          Text(
            enabledInSettings
                ? units.formatDepth(defaultMaxO2DepthMeters, decimals: 1)
                : l10n.divePlanner_label_off,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
        ],
        if (choice == _PpO2BandsChoice.custom) ...[
          const SizedBox(height: 12),
          PlanPpO2DepthSlider(
            label: l10n.divePlanner_gasOptions_maxO2DepthMeters,
            value: maxO2DepthMeters ?? defaultMaxO2DepthMeters,
            units: units,
            onChanged: onChanged,
          ),
        ],
      ],
    );
  }
}

/// A single ppO2 slider row (1.2-1.6 bar), shared label + value styling
/// with the Settings dialog's own band sliders. The step size is
/// [SettingsNotifier.ppO2DecoBandStep], not a separate copy, so a plan's
/// own band override can never land off the grid the Settings sliders
/// snap to (issue #3580 spec: 0.1 bar steps).
class PlanPpO2Slider extends StatelessWidget {
  const PlanPpO2Slider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  static const double _min = SettingsNotifier.ppO2WorkingMin;
  static const double _max = SettingsNotifier.ppO2Ceiling;
  static final int _divisions =
      ((_max - _min) / SettingsNotifier.ppO2DecoBandStep).round();

  @override
  Widget build(BuildContext context) {
    final valueText = '${formatRoundedForInput(value, 2)} bar';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(valueText),
            ],
          ),
          Slider(
            value: value.clamp(_min, _max),
            min: _min,
            max: _max,
            divisions: _divisions,
            label: valueText,
            // The slider interpolates its divisions; report the exact grid
            // point so a plan override never carries float noise.
            onChanged: (v) => onChanged(SettingsNotifier.ppO2DecoBandOnGrid(v)),
          ),
        ],
      ),
    );
  }
}

/// A single depth slider row (3-9 m, 0.5 m steps), for the explicit MOD
/// override.
class PlanPpO2DepthSlider extends StatelessWidget {
  const PlanPpO2DepthSlider({
    super.key,
    required this.label,
    required this.value,
    required this.units,
    required this.onChanged,
  });

  final String label;
  final double value;

  /// Formats the displayed depth in the diver's unit settings; the slider's
  /// own grid stays in meters.
  final UnitFormatter units;

  final ValueChanged<double> onChanged;

  static const double _min = 3.0;
  static const double _max = 9.0;
  static const int _divisions = 12; // 0.5 m steps

  @override
  Widget build(BuildContext context) {
    final valueText = units.formatDepth(value, decimals: 1);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label)),
              Text(valueText),
            ],
          ),
          Slider(
            value: value.clamp(_min, _max),
            min: _min,
            max: _max,
            divisions: _divisions,
            label: valueText,
            onChanged: (v) => onChanged(SettingsNotifier.maxO2DepthOnGrid(v)),
          ),
        ],
      ),
    );
  }
}
