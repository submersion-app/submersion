import 'package:flutter/material.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Picks the two optional, finer-grained deco ppO2 layers (issue #3580):
/// per-O2-band limits instead of the single "Deco" ppO2, and an explicit
/// MOD for 100% O2 instead of computing it through the ppO2 formula. Dive
/// Planner only.
class PpO2DecoBandsDialog extends StatefulWidget {
  final bool initialBandsEnabled;
  final double initialBand1;
  final double initialBand2;
  final double initialBand3;
  final bool initialMaxO2DepthEnabled;
  final double initialMaxO2DepthMeters;
  final UnitFormatter units;
  final void Function(
    bool bandsEnabled,
    double band1,
    double band2,
    double band3,
    bool maxO2DepthEnabled,
    double maxO2DepthMeters,
  )
  onSave;

  const PpO2DecoBandsDialog({
    super.key,
    required this.initialBandsEnabled,
    required this.initialBand1,
    required this.initialBand2,
    required this.initialBand3,
    required this.initialMaxO2DepthEnabled,
    required this.initialMaxO2DepthMeters,
    required this.units,
    required this.onSave,
  });

  @override
  State<PpO2DecoBandsDialog> createState() => _PpO2DecoBandsDialogState();
}

class _PpO2DecoBandsDialogState extends State<PpO2DecoBandsDialog> {
  static const double _ppO2Min = SettingsNotifier.ppO2WorkingMin;
  static const double _ppO2Max = SettingsNotifier.ppO2Ceiling;
  static const double _ppO2Step = SettingsNotifier.ppO2DecoBandStep;
  static final int _ppO2Divisions = ((_ppO2Max - _ppO2Min) / _ppO2Step).round();

  static const double _depthMin = SettingsNotifier.maxO2DepthMin;
  static const double _depthMax = SettingsNotifier.maxO2DepthMax;
  static const double _depthStep = SettingsNotifier.maxO2DepthStep;
  static final int _depthDivisions = ((_depthMax - _depthMin) / _depthStep)
      .round();

  late bool _bandsEnabled;
  late double _band1;
  late double _band2;
  late double _band3;
  late bool _maxO2DepthEnabled;
  late double _maxO2DepthMeters;

  @override
  void initState() {
    super.initState();
    _bandsEnabled = widget.initialBandsEnabled;
    _band1 = SettingsNotifier.ppO2DecoBandOnGrid(widget.initialBand1);
    _band2 = SettingsNotifier.ppO2DecoBandOnGrid(widget.initialBand2);
    _band3 = SettingsNotifier.ppO2DecoBandOnGrid(widget.initialBand3);
    _maxO2DepthEnabled = widget.initialMaxO2DepthEnabled;
    _maxO2DepthMeters = SettingsNotifier.maxO2DepthOnGrid(
      widget.initialMaxO2DepthMeters,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AlertDialog(
      title: Text(l10n.settings_decompression_ppO2BandsDialog_title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.settings_decompression_ppO2BandsDialog_bandsToggle,
              ),
              value: _bandsEnabled,
              onChanged: (value) => setState(() => _bandsEnabled = value),
            ),
            _ppO2Slider(
              label: l10n.settings_decompression_ppO2BandsDialog_band1,
              value: _band1,
              enabled: _bandsEnabled,
              onChanged: (v) => setState(() => _band1 = v),
            ),
            _ppO2Slider(
              label: l10n.settings_decompression_ppO2BandsDialog_band2,
              value: _band2,
              enabled: _bandsEnabled,
              onChanged: (v) => setState(() => _band2 = v),
            ),
            _ppO2Slider(
              label: l10n.settings_decompression_ppO2BandsDialog_band3,
              value: _band3,
              enabled: _bandsEnabled,
              onChanged: (v) => setState(() => _band3 = v),
            ),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                l10n.settings_decompression_ppO2BandsDialog_maxO2DepthToggle,
              ),
              value: _maxO2DepthEnabled,
              onChanged: (value) => setState(() => _maxO2DepthEnabled = value),
            ),
            _depthSlider(
              label:
                  l10n.settings_decompression_ppO2BandsDialog_maxO2DepthLabel,
              value: _maxO2DepthMeters,
              enabled: _maxO2DepthEnabled,
              onChanged: (v) => setState(() => _maxO2DepthMeters = v),
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
            widget.onSave(
              _bandsEnabled,
              _band1,
              _band2,
              _band3,
              _maxO2DepthEnabled,
              _maxO2DepthMeters,
            );
            Navigator.of(context).pop();
          },
          child: Text(l10n.settings_decompression_dialog_save),
        ),
      ],
    );
  }

  Widget _ppO2Slider({
    required String label,
    required double value,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) => _slider(
    label: label,
    valueText: '${formatRoundedForInput(value, 2)} bar',
    value: value,
    min: _ppO2Min,
    max: _ppO2Max,
    divisions: _ppO2Divisions,
    enabled: enabled,
    onChanged: onChanged,
  );

  Widget _depthSlider({
    required String label,
    required double value,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) => _slider(
    label: label,
    // The slider's own grid (min/max/step) stays in meters - it mirrors the
    // physical MOD-for-100%-O2 range divers think in - only the displayed
    // text respects the diver's unit setting (issue #3580 follow-up).
    valueText: widget.units.formatDepth(value, decimals: 1),
    value: value,
    min: _depthMin,
    max: _depthMax,
    divisions: _depthDivisions,
    enabled: enabled,
    onChanged: onChanged,
  );

  Widget _slider({
    required String label,
    required String valueText,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) {
    final color = enabled
        ? null
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: TextStyle(color: color)),
              ),
              Text(valueText, style: TextStyle(color: color)),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: valueText,
            onChanged: enabled ? onChanged : null,
          ),
        ],
      ),
    );
  }
}
