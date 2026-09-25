import 'package:flutter/material.dart';

import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Edits the diver's CCR ppO2 limits (issue #2342): setpoint low, setpoint
/// high and the ppO2 a diluent may reach on a flush.
///
/// Sliders in 0.01 bar steps rather than the OC dialog's dropdowns: the range
/// 0.19-1.6 bar would be a list of 142 entries.
class CcrPpO2LimitDialog extends StatefulWidget {
  const CcrPpO2LimitDialog({
    super.key,
    required this.initialSetpointLow,
    required this.initialSetpointHigh,
    required this.initialDiluentModPpO2,
    required this.onSave,
  });

  final double initialSetpointLow;
  final double initialSetpointHigh;
  final double initialDiluentModPpO2;
  final void Function(double low, double high, double diluentMod) onSave;

  @override
  State<CcrPpO2LimitDialog> createState() => _CcrPpO2LimitDialogState();
}

class _CcrPpO2LimitDialogState extends State<CcrPpO2LimitDialog> {
  static const double _min = SettingsNotifier.ccrPpO2Min;
  static const double _max = SettingsNotifier.ccrPpO2Max;
  static final int _divisions = ((_max - _min) * 100).round();

  late double _low;
  late double _high;
  late double _diluentMod;

  /// A stored value snapped onto the slider's 0.01 grid and range.
  static double _snap(double value) =>
      ((value.clamp(_min, _max) * 100).round() / 100).toDouble();

  @override
  void initState() {
    super.initState();
    _low = _snap(widget.initialSetpointLow);
    _high = _snap(widget.initialSetpointHigh);
    if (_high < _low) _high = _low;
    _diluentMod = _snap(widget.initialDiluentModPpO2);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(l10n.settings_decompression_ccrPpO2LimitsTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.settings_decompression_ccrDialog_info,
                      style: textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _CcrSliderRow(
              label: l10n.settings_decompression_ccrDialog_setpointLow,
              hint: l10n.settings_decompression_ccrDialog_setpointLowHint,
              value: _low,
              divisions: _divisions,
              onChanged: (v) => setState(() {
                _low = _snap(v);
                if (_high < _low) _high = _low;
              }),
            ),
            const SizedBox(height: 12),
            _CcrSliderRow(
              label: l10n.settings_decompression_ccrDialog_setpointHigh,
              hint: l10n.settings_decompression_ccrDialog_setpointHighHint,
              value: _high,
              divisions: _divisions,
              onChanged: (v) => setState(() {
                _high = _snap(v);
                if (_low > _high) _low = _high;
              }),
            ),
            const SizedBox(height: 12),
            _CcrSliderRow(
              label: l10n.settings_decompression_ccrDialog_diluentMod,
              hint: l10n.settings_decompression_ccrDialog_diluentModHint,
              value: _diluentMod,
              divisions: _divisions,
              onChanged: (v) => setState(() => _diluentMod = _snap(v)),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.settings_decompression_dialog_cancel),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_low, _high, _diluentMod);
            Navigator.of(context).pop();
          },
          child: Text(l10n.settings_decompression_dialog_save),
        ),
      ],
    );
  }
}

class _CcrSliderRow extends StatelessWidget {
  const _CcrSliderRow({
    required this.label,
    required this.hint,
    required this.value,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final String hint;
  final double value;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final shown = '${formatFixedForDisplay(value, 2)} bar';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    hint,
                    style: textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              shown,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Semantics(
          label: label,
          child: Slider(
            value: value,
            min: SettingsNotifier.ccrPpO2Min,
            max: SettingsNotifier.ccrPpO2Max,
            divisions: divisions,
            onChanged: onChanged,
            semanticFormatterCallback: (v) =>
                '${formatFixedForDisplay(v, 2)} bar',
          ),
        ),
      ],
    );
  }
}
