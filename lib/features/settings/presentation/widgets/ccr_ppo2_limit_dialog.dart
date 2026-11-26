import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/switch_depth_format.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/settings/presentation/widgets/ccr_switch_depth_row.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The "ppO2 limits CCR" entry of the decompression settings: the current
/// setpoints and Dil MOD, opening [CcrPpO2LimitDialog] to edit them.
class CcrPpO2LimitTile extends ConsumerWidget {
  const CcrPpO2LimitTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(
      settingsProvider.select(
        (s) => (
          ccrSetpointLow: s.ccrSetpointLow,
          ccrSetpointHigh: s.ccrSetpointHigh,
          ccrDiluentModPpO2: s.ccrDiluentModPpO2,
          ccrSetpointSwitchDepth: s.ccrSetpointSwitchDepth,
        ),
      ),
    );
    final units = ref.watch(unitFormatterProvider);

    return ListTile(
      leading: const Icon(Icons.loop),
      title: Text(l10n.settings_decompression_ccrPpO2LimitsTitle),
      subtitle: Text(
        l10n.settings_decompression_ccrPpO2LimitsSubtitleWithSwitch(
          formatFixedForDisplay(settings.ccrSetpointLow, 1),
          formatFixedForDisplay(settings.ccrSetpointHigh, 1),
          formatFixedForDisplay(settings.ccrDiluentModPpO2, 1),
          formatSwitchDepth(units, settings.ccrSetpointSwitchDepth),
        ),
      ),
      trailing: const Icon(Icons.edit),
      onTap: () => showDialog<void>(
        context: context,
        builder: (_) => CcrPpO2LimitDialog(
          initialSetpointLow: settings.ccrSetpointLow,
          initialSetpointHigh: settings.ccrSetpointHigh,
          initialDiluentModPpO2: settings.ccrDiluentModPpO2,
          initialSetpointSwitchDepth: settings.ccrSetpointSwitchDepth,
          units: units,
          onSave: (low, high, diluentMod, switchDepth) => ref
              .read(settingsProvider.notifier)
              .setCcrPpO2Limits(
                setpointLow: low,
                setpointHigh: high,
                diluentModPpO2: diluentMod,
                setpointSwitchDepth: switchDepth,
              ),
        ),
      ),
    );
  }
}

/// Edits the diver's CCR ppO2 limits (issue #2342): setpoint low, setpoint
/// high and the ppO2 a diluent may reach on a flush.
///
/// Sliders in 0.1 bar steps across 0.5-1.6 bar, the grid the notifier
/// stores.
class CcrPpO2LimitDialog extends StatefulWidget {
  const CcrPpO2LimitDialog({
    super.key,
    required this.initialSetpointLow,
    required this.initialSetpointHigh,
    required this.initialDiluentModPpO2,
    required this.initialSetpointSwitchDepth,
    required this.units,
    required this.onSave,
  });

  final double initialSetpointLow;
  final double initialSetpointHigh;
  final double initialDiluentModPpO2;

  /// Stored switch depth in meters; the row shows it in [units].
  final double initialSetpointSwitchDepth;
  final UnitFormatter units;

  /// Receives the setpoints and Dil MOD in bar and the switch depth in
  /// meters.
  final void Function(
    double low,
    double high,
    double diluentMod,
    double switchDepth,
  )
  onSave;

  @override
  State<CcrPpO2LimitDialog> createState() => _CcrPpO2LimitDialogState();
}

class _CcrPpO2LimitDialogState extends State<CcrPpO2LimitDialog> {
  static const double _min = SettingsNotifier.ccrPpO2Min;
  static const double _max = SettingsNotifier.ccrPpO2Max;
  static final int _divisions = ((_max - _min) * 10).round();

  late double _low;
  late double _high;
  late double _diluentMod;
  late double _switchDepth;

  /// A stored value snapped onto the slider's 0.1 grid and range.
  static double _snap(double value) => SettingsNotifier.ccrPpO2OnGrid(value);

  @override
  void initState() {
    super.initState();
    _low = _snap(widget.initialSetpointLow);
    _high = _snap(widget.initialSetpointHigh);
    if (_high < _low) _high = _low;
    _diluentMod = _snap(widget.initialDiluentModPpO2);
    _switchDepth = SettingsNotifier.ccrSwitchDepthOnGrid(
      widget.initialSetpointSwitchDepth,
    );
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
            const SizedBox(height: 12),
            CcrSwitchDepthRow(
              label: l10n.settings_decompression_ccrDialog_switchDepth,
              hint: l10n.settings_decompression_ccrDialog_switchDepthHint,
              meters: _switchDepth,
              units: widget.units,
              onChanged: (v) => setState(() => _switchDepth = v),
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
            widget.onSave(_low, _high, _diluentMod, _switchDepth);
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
    final shown = '${formatFixedForDisplay(value, 1)} bar';

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
                '${formatFixedForDisplay(v, 1)} bar',
          ),
        ),
      ],
    );
  }
}
