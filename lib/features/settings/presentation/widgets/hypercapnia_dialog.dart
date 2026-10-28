import 'package:flutter/material.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Picks the hypercapnia-bailout phase (issue #3743): an elevated RMV for a
/// configurable duration at the start of an OC bailout during a CCR/SCR
/// dive, layered over the existing stressed-SAC fallback. Dive Planner
/// only, same shape as [PpO2DecoBandsDialog].
class HypercapniaDialog extends StatefulWidget {
  final bool initialEnabled;
  final double initialFactor;
  final int initialMinutes;
  final void Function(bool enabled, double factor, int minutes) onSave;

  const HypercapniaDialog({
    super.key,
    required this.initialEnabled,
    required this.initialFactor,
    required this.initialMinutes,
    required this.onSave,
  });

  @override
  State<HypercapniaDialog> createState() => _HypercapniaDialogState();
}

class _HypercapniaDialogState extends State<HypercapniaDialog> {
  // The notifier's own bounds, so the dialog never offers a value
  // setPlannerHypercapniaConfig would clamp away.
  static const double _factorMin = SettingsNotifier.plannerHypercapniaFactorMin;
  static const double _factorMax = SettingsNotifier.plannerHypercapniaFactorMax;
  static const double _factorStep =
      SettingsNotifier.plannerHypercapniaFactorStep;
  static final int _factorDivisions = ((_factorMax - _factorMin) / _factorStep)
      .round();

  static const int _minutesMin = SettingsNotifier.plannerHypercapniaMinutesMin;
  static const int _minutesMax = SettingsNotifier.plannerHypercapniaMinutesMax;
  static const int _minutesDivisions = _minutesMax - _minutesMin;

  late bool _enabled;
  late double _factor;
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _enabled = widget.initialEnabled;
    _factor = widget.initialFactor.clamp(_factorMin, _factorMax);
    _minutes = widget.initialMinutes.clamp(_minutesMin, _minutesMax);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = _enabled
        ? null
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return AlertDialog(
      title: Text(l10n.settings_decompression_hypercapniaDialog_title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.settings_decompression_hypercapniaDialog_enabledToggle,
              ),
              value: _enabled,
              onChanged: (value) => setState(() => _enabled = value),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.settings_decompression_hypercapniaDialog_factorLabel,
                          style: TextStyle(color: color),
                        ),
                      ),
                      Text(
                        '${formatRoundedForInput(_factor, 1)}×',
                        style: TextStyle(color: color),
                      ),
                    ],
                  ),
                  Slider(
                    value: _factor,
                    min: _factorMin,
                    max: _factorMax,
                    divisions: _factorDivisions,
                    label: '${formatRoundedForInput(_factor, 1)}×',
                    onChanged: _enabled
                        ? (v) => setState(() => _factor = v)
                        : null,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.settings_decompression_hypercapniaDialog_minutesLabel,
                          style: TextStyle(color: color),
                        ),
                      ),
                      Text(
                        '$_minutes ${l10n.divePlanner_label_minutesUnit}',
                        style: TextStyle(color: color),
                      ),
                    ],
                  ),
                  Slider(
                    value: _minutes.toDouble(),
                    min: _minutesMin.toDouble(),
                    max: _minutesMax.toDouble(),
                    divisions: _minutesDivisions,
                    label: '$_minutes ${l10n.divePlanner_label_minutesUnit}',
                    onChanged: _enabled
                        ? (v) => setState(() => _minutes = v.round())
                        : null,
                  ),
                ],
              ),
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
            widget.onSave(_enabled, _factor, _minutes);
            Navigator.of(context).pop();
          },
          child: Text(l10n.settings_decompression_dialog_save),
        ),
      ],
    );
  }
}
