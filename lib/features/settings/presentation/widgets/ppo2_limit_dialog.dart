import 'package:flutter/material.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Picks the two ppO2 ceilings (working and maximum) that drive MOD, gas
/// planning and the oxygen toxicity warnings. Kept to the values a dive
/// computer actually offers, and holds max >= working.
class PpO2LimitDialog extends StatefulWidget {
  final double initialWorking;
  final double initialMax;
  final void Function(double working, double max) onSave;

  const PpO2LimitDialog({
    super.key,
    required this.initialWorking,
    required this.initialMax,
    required this.onSave,
  });

  @override
  State<PpO2LimitDialog> createState() => _PpO2LimitDialogState();
}

class _PpO2LimitDialogState extends State<PpO2LimitDialog> {
  // Same 0.1 bar grid the picker always offered, now as a slider instead
  // of a dropdown.
  static const double _step = 0.1;
  static const double _workingMin = SettingsNotifier.ppO2WorkingMin;
  static const double _maxMin = SettingsNotifier.ppO2MaxMin;
  static const double _ceiling = SettingsNotifier.ppO2Ceiling;
  static final int _workingDivisions = ((_ceiling - _workingMin) / _step)
      .round();
  static final int _maxDivisions = ((_ceiling - _maxMin) / _step).round();

  /// [value] clamped to [min]..[_ceiling] and snapped to the [_step] grid,
  /// so a stored value (float noise, or off-grid after a clamp) lands
  /// exactly on a slider division.
  static double _onGrid(double value, double min) =>
      SettingsNotifier.onStepGrid(value.clamp(min, _ceiling), _step);

  late double _working;
  late double _max;

  @override
  void initState() {
    super.initState();
    _working = _onGrid(widget.initialWorking, _workingMin);
    _max = _onGrid(widget.initialMax, _maxMin);
    if (_max < _working) _max = _working;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(context.l10n.settings_decompression_ppO2Dialog_title),
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
                      context.l10n.settings_decompression_ppO2Dialog_info,
                      style: textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildRow(
              context,
              label: context.l10n.settings_decompression_ppO2Dialog_working,
              hint: context.l10n.settings_decompression_ppO2Dialog_workingHint,
              value: _working,
              min: _workingMin,
              divisions: _workingDivisions,
              // The slider interpolates its divisions, so snap what it
              // reports onto the exact grid before it is saved.
              onChanged: (v) => setState(() {
                _working = _onGrid(v, _workingMin);
                if (_max < _working) _max = _onGrid(_working, _maxMin);
              }),
            ),
            const SizedBox(height: 12),
            _buildRow(
              context,
              label: context.l10n.settings_decompression_ppO2Dialog_max,
              hint: context.l10n.settings_decompression_ppO2Dialog_maxHint,
              value: _max,
              min: _maxMin,
              divisions: _maxDivisions,
              onChanged: (v) => setState(() {
                _max = _onGrid(v, _maxMin);
                if (_working > _max) _working = _max;
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.settings_decompression_dialog_cancel),
        ),
        FilledButton(
          onPressed: () {
            widget.onSave(_working, _max);
            Navigator.of(context).pop();
          },
          child: Text(context.l10n.settings_decompression_dialog_save),
        ),
      ],
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required String label,
    required String hint,
    required double value,
    required double min,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    final textTheme = Theme.of(context).textTheme;
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
            Text('${formatRoundedForInput(value, 1)} bar'),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: _ceiling,
          divisions: divisions,
          label: '${formatRoundedForInput(value, 1)} bar',
          onChanged: onChanged,
        ),
      ],
    );
  }
}
