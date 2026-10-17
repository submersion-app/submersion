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
  // Generated from the notifier's own bounds so the offered options can never
  // drift from what setPpO2Limits will accept (0.1-bar grid).
  static final List<double> _workingOptions = _tenths(
    SettingsNotifier.ppO2WorkingMin,
    SettingsNotifier.ppO2Ceiling,
  );
  static final List<double> _maxOptions = _tenths(
    SettingsNotifier.ppO2MaxMin,
    SettingsNotifier.ppO2Ceiling,
  );

  static List<double> _tenths(double min, double max) {
    final lo = (min * 10).round();
    final hi = (max * 10).round();
    return [for (var i = lo; i <= hi; i++) i / 10.0];
  }

  late double _working;
  late double _max;

  /// Snap a stored value (which may carry float noise or sit off the grid
  /// after a clamp) to the nearest offered option.
  static double _snap(double value, List<double> options) =>
      options.reduce((a, b) => (a - value).abs() <= (b - value).abs() ? a : b);

  @override
  void initState() {
    super.initState();
    _working = _snap(widget.initialWorking, _workingOptions);
    _max = _snap(widget.initialMax, _maxOptions);
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
              options: _workingOptions,
              onChanged: (v) => setState(() {
                _working = v;
                if (_max < _working) _max = _snap(_working, _maxOptions);
              }),
            ),
            const SizedBox(height: 12),
            _buildRow(
              context,
              label: context.l10n.settings_decompression_ppO2Dialog_max,
              hint: context.l10n.settings_decompression_ppO2Dialog_maxHint,
              value: _max,
              options: _maxOptions,
              onChanged: (v) => setState(() {
                _max = v;
                if (_working > _max) _working = v;
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
    required List<double> options,
    required ValueChanged<double> onChanged,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
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
        DropdownButton<double>(
          value: value,
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
          items: [
            for (final o in options)
              DropdownMenuItem(
                value: o,
                child: Text('${formatRoundedForInput(o, 1)} bar'),
              ),
          ],
        ),
      ],
    );
  }
}
