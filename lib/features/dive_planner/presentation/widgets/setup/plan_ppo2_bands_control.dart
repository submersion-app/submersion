import 'package:flutter/material.dart';

import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/dive_planner/presentation/widgets/setup/plan_choice_wrap.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Default/Custom control for a plan's per-O2-band deco ppO2 overrides
/// (issue #3580), styled like the Setup accordion's air-breaks control: a
/// chip picks between following the diver's Settings bands and a custom
/// set for this plan alone; Custom reveals a slider per band, seeded from
/// whichever bands are already custom, the Settings default for the rest.
class PlanPpO2BandsControl extends StatelessWidget {
  const PlanPpO2BandsControl({
    super.key,
    required this.band1,
    required this.band2,
    required this.band3,
    required this.defaultBand1,
    required this.defaultBand2,
    required this.defaultBand3,
    required this.onBand1Changed,
    required this.onBand2Changed,
    required this.onBand3Changed,
    required this.onDefault,
  });

  /// This plan's own band overrides; null = follow the Settings default.
  final double? band1;
  final double? band2;
  final double? band3;

  final double defaultBand1;
  final double defaultBand2;
  final double defaultBand3;

  final ValueChanged<double> onBand1Changed;
  final ValueChanged<double> onBand2Changed;
  final ValueChanged<double> onBand3Changed;

  /// Clears all three band overrides at once, back to Default.
  final VoidCallback onDefault;

  bool get _isCustom => band1 != null || band2 != null || band3 != null;

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
        PlanChoiceWrap<bool>(
          options: [
            (false, l10n.divePlanner_label_default),
            (true, l10n.divePlanner_label_airBreaksCustom),
          ],
          selected: _isCustom,
          onChanged: (custom) {
            if (!custom) {
              onDefault();
            } else {
              onBand1Changed(band1 ?? defaultBand1);
              onBand2Changed(band2 ?? defaultBand2);
              onBand3Changed(band3 ?? defaultBand3);
            }
          },
        ),
        if (_isCustom) ...[
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

/// Default/Custom control for a plan's explicit MOD for 100% O2 override
/// (issue #3580), same Default/Custom shape as [PlanPpO2BandsControl].
class PlanMaxO2DepthControl extends StatelessWidget {
  const PlanMaxO2DepthControl({
    super.key,
    required this.maxO2DepthMeters,
    required this.defaultMaxO2DepthMeters,
    required this.onChanged,
    required this.onDefault,
  });

  final double? maxO2DepthMeters;
  final double defaultMaxO2DepthMeters;
  final ValueChanged<double> onChanged;
  final VoidCallback onDefault;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final isCustom = maxO2DepthMeters != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.settings_decompression_ppO2BandsDialog_maxO2DepthLabel,
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 6),
        PlanChoiceWrap<bool>(
          options: [
            (false, l10n.divePlanner_label_default),
            (true, l10n.divePlanner_label_airBreaksCustom),
          ],
          selected: isCustom,
          onChanged: (custom) {
            if (!custom) {
              onDefault();
            } else {
              onChanged(maxO2DepthMeters ?? defaultMaxO2DepthMeters);
            }
          },
        ),
        if (isCustom) ...[
          const SizedBox(height: 12),
          PlanPpO2DepthSlider(
            label: l10n.divePlanner_gasOptions_maxO2DepthMeters,
            value: maxO2DepthMeters ?? defaultMaxO2DepthMeters,
            onChanged: onChanged,
          ),
        ],
      ],
    );
  }
}

/// A single ppO2 slider row (1.2-1.6 bar, 0.05 bar steps), shared label +
/// value styling with the Settings dialog's own band sliders.
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

  static const double _min = 1.2;
  static const double _max = 1.6;
  static const int _divisions = 8; // 0.05 bar steps

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
            onChanged: onChanged,
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
    required this.onChanged,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  static const double _min = 3.0;
  static const double _max = 9.0;
  static const int _divisions = 12; // 0.5 m steps

  @override
  Widget build(BuildContext context) {
    final valueText = '${formatRoundedForInput(value, 1)} m';
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
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
