import 'package:flutter/material.dart';
import 'package:submersion/core/utils/number_input.dart';
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
    required this.onSave,
  });

  @override
  State<PpO2DecoBandsDialog> createState() => _PpO2DecoBandsDialogState();
}

class _PpO2DecoBandsDialogState extends State<PpO2DecoBandsDialog> {
  // Same 0.1 bar grid as PpO2LimitDialog's deco ceiling.
  static final List<double> _ppO2Options = _steps(
    SettingsNotifier.ppO2MaxMin,
    SettingsNotifier.ppO2Ceiling,
    0.1,
  );
  static final List<double> _depthOptions = _steps(
    SettingsNotifier.maxO2DepthMin,
    SettingsNotifier.maxO2DepthMax,
    0.5,
  );

  static List<double> _steps(double min, double max, double step) {
    final lo = (min / step).round();
    final hi = (max / step).round();
    return [for (var i = lo; i <= hi; i++) i * step];
  }

  static double _snap(double value, List<double> options) =>
      options.reduce((a, b) => (a - value).abs() <= (b - value).abs() ? a : b);

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
    _band1 = _snap(widget.initialBand1, _ppO2Options);
    _band2 = _snap(widget.initialBand2, _ppO2Options);
    _band3 = _snap(widget.initialBand3, _ppO2Options);
    _maxO2DepthEnabled = widget.initialMaxO2DepthEnabled;
    _maxO2DepthMeters = _snap(widget.initialMaxO2DepthMeters, _depthOptions);
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
            _ppO2Row(
              label: l10n.settings_decompression_ppO2BandsDialog_band1,
              value: _band1,
              enabled: _bandsEnabled,
              onChanged: (v) => setState(() => _band1 = v),
            ),
            _ppO2Row(
              label: l10n.settings_decompression_ppO2BandsDialog_band2,
              value: _band2,
              enabled: _bandsEnabled,
              onChanged: (v) => setState(() => _band2 = v),
            ),
            _ppO2Row(
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
            _depthRow(
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

  Widget _ppO2Row({
    required String label,
    required double value,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) => _row(
    label: label,
    enabled: enabled,
    child: DropdownButton<double>(
      value: value,
      onChanged: enabled
          ? (v) {
              if (v != null) onChanged(v);
            }
          : null,
      items: [
        for (final o in _ppO2Options)
          DropdownMenuItem(
            value: o,
            child: Text('${formatRoundedForInput(o, 1)} bar'),
          ),
      ],
    ),
  );

  Widget _depthRow({
    required String label,
    required double value,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) => _row(
    label: label,
    enabled: enabled,
    child: DropdownButton<double>(
      value: value,
      onChanged: enabled
          ? (v) {
              if (v != null) onChanged(v);
            }
          : null,
      items: [
        for (final o in _depthOptions)
          DropdownMenuItem(
            value: o,
            child: Text('${formatRoundedForInput(o, 1)} m'),
          ),
      ],
    ),
  );

  Widget _row({
    required String label,
    required bool enabled,
    required Widget child,
  }) {
    final color = enabled
        ? null
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(color: color)),
          ),
          const SizedBox(width: 12),
          child,
        ],
      ),
    );
  }
}
