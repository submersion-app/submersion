import 'package:flutter/material.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Gradient Factor preset configurations
enum GfPreset {
  high(50, 75, 'High', 'Most conservative, longer deco stops'),
  medium(50, 85, 'Medium', 'Balanced approach'),
  low(50, 95, 'Low', 'Least conservative, shorter deco'),
  custom(0, 0, 'Custom', 'Set your own values');

  final int gfLow;
  final int gfHigh;
  final String name;
  final String description;

  const GfPreset(this.gfLow, this.gfHigh, this.name, this.description);

  bool matches(int low, int high) {
    if (this == GfPreset.custom) return false;
    return gfLow == low && gfHigh == high;
  }

  static GfPreset fromValues(int low, int high) {
    for (final preset in GfPreset.values) {
      if (preset != GfPreset.custom && preset.matches(low, high)) {
        return preset;
      }
    }
    return GfPreset.custom;
  }
}

class GradientFactorDialog extends StatefulWidget {
  final int initialGfLow;
  final int initialGfHigh;
  final void Function(int low, int high) onSave;

  const GradientFactorDialog({
    super.key,
    required this.initialGfLow,
    required this.initialGfHigh,
    required this.onSave,
  });

  @override
  State<GradientFactorDialog> createState() => _GradientFactorDialogState();
}

class _GradientFactorDialogState extends State<GradientFactorDialog> {
  late int _gfLow;
  late int _gfHigh;
  late GfPreset _selectedPreset;

  @override
  void initState() {
    super.initState();
    _gfLow = widget.initialGfLow;
    _gfHigh = widget.initialGfHigh;
    _selectedPreset = GfPreset.fromValues(_gfLow, _gfHigh);
  }

  void _selectPreset(GfPreset preset) {
    setState(() {
      _selectedPreset = preset;
      if (preset != GfPreset.custom) {
        _gfLow = preset.gfLow;
        _gfHigh = preset.gfHigh;
      }
    });
  }

  void _updateGfLow(int value) {
    setState(() {
      _gfLow = value;
      if (_gfHigh < _gfLow) _gfHigh = _gfLow;
      _selectedPreset = GfPreset.fromValues(_gfLow, _gfHigh);
    });
  }

  void _updateGfHigh(int value) {
    setState(() {
      _gfHigh = value;
      if (_gfLow > _gfHigh) _gfLow = _gfHigh;
      _selectedPreset = GfPreset.fromValues(_gfLow, _gfHigh);
    });
  }

  String _getPresetName(BuildContext context, GfPreset preset) {
    switch (preset) {
      case GfPreset.high:
        return context.l10n.settings_gfPreset_high_name;
      case GfPreset.medium:
        return context.l10n.settings_gfPreset_medium_name;
      case GfPreset.low:
        return context.l10n.settings_gfPreset_low_name;
      case GfPreset.custom:
        return context.l10n.settings_gfPreset_custom_name;
    }
  }

  String _getPresetDescription(BuildContext context, GfPreset preset) {
    switch (preset) {
      case GfPreset.high:
        return context.l10n.settings_gfPreset_high_description;
      case GfPreset.medium:
        return context.l10n.settings_gfPreset_medium_description;
      case GfPreset.low:
        return context.l10n.settings_gfPreset_low_description;
      case GfPreset.custom:
        return context.l10n.settings_gfPreset_custom_description;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      title: Text(context.l10n.settings_decompression_dialog_title),
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
                      context.l10n.settings_decompression_dialog_info,
                      style: textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.settings_decompression_dialog_presets,
              style: textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            ...GfPreset.values.where((p) => p != GfPreset.custom).map((preset) {
              final isSelected = _selectedPreset == preset;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Semantics(
                  button: true,
                  label: context.l10n.settings_decompression_preset_selectLabel(
                    _getPresetName(context, preset),
                  ),
                  child: InkWell(
                    onTap: () => _selectPreset(preset),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: isSelected
                            ? Border.all(color: colorScheme.primary, width: 2)
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getPresetName(context, preset),
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  _getPresetDescription(context, preset),
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? colorScheme.primary
                                  : colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${preset.gfLow}/${preset.gfHigh}',
                              style: textTheme.labelMedium?.copyWith(
                                color: isSelected
                                    ? colorScheme.onPrimary
                                    : colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  context.l10n.settings_decompression_dialog_customValues,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'GF $_gfLow/$_gfHigh',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    context.l10n.settings_decompression_dialog_gfLow,
                    style: textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _gfLow.toDouble(),
                    min: 15,
                    max: 100,
                    divisions: 85,
                    label: '$_gfLow',
                    onChanged: (value) => _updateGfLow(value.round()),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '$_gfLow',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                SizedBox(
                  width: 60,
                  child: Text(
                    context.l10n.settings_decompression_dialog_gfHigh,
                    style: textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _gfHigh.toDouble(),
                    min: 15,
                    max: 100,
                    divisions: 85,
                    label: '$_gfHigh',
                    onChanged: (value) => _updateGfHigh(value.round()),
                  ),
                ),
                SizedBox(
                  width: 36,
                  child: Text(
                    '$_gfHigh',
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.settings_decompression_dialog_conservatismHint,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
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
            widget.onSave(_gfLow, _gfHigh);
            Navigator.of(context).pop();
          },
          child: Text(context.l10n.settings_decompression_dialog_save),
        ),
      ],
    );
  }
}
