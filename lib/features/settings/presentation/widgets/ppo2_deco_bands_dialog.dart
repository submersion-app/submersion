import 'package:flutter/material.dart';
import 'package:submersion/core/deco/max_operating_depth.dart';
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

  /// The diver's flat deco ppO2 ([AppSettings.ppO2MaxDeco]). A layer that is
  /// off and still at its column default starts from this instead, so
  /// turning it on keeps today's ceiling rather than jumping back to 1.6.
  final double initialFlatPpO2;
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
    required this.initialFlatPpO2,
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

  /// Whether a layer's sliders still show values seeded from the flat
  /// limit rather than ones the diver stored or moved. A seeded layer that
  /// is still off when the dialog is saved keeps its stored values, so
  /// saving for the other layer never pins it to today's flat limit.
  late bool _bandsSeeded;
  late bool _depthSeeded;

  @override
  void initState() {
    super.initState();
    const defaults = AppSettings();
    // Untouched = off and still at the column defaults: the diver never set
    // these, so they start from the flat limit in force. Once edited (or
    // on), the stored values are kept as they are.
    final bandsUntouched =
        !widget.initialBandsEnabled &&
        widget.initialBand1 == defaults.ppO2DecoBand1 &&
        widget.initialBand2 == defaults.ppO2DecoBand2 &&
        widget.initialBand3 == defaults.ppO2DecoBand3;
    final depthUntouched =
        !widget.initialMaxO2DepthEnabled &&
        widget.initialMaxO2DepthMeters == defaults.maxO2DepthMeters;
    _bandsSeeded = bandsUntouched;
    _depthSeeded = depthUntouched;
    // Seeds round DOWN onto the grid, so a seeded limit is never more
    // permissive than the flat one it comes from.
    final seededBand = SettingsNotifier.ppO2DecoBandFloorOnGrid(
      widget.initialFlatPpO2,
    );
    _bandsEnabled = widget.initialBandsEnabled;
    _band1 = bandsUntouched
        ? seededBand
        : SettingsNotifier.ppO2DecoBandOnGrid(widget.initialBand1);
    _band2 = bandsUntouched
        ? seededBand
        : SettingsNotifier.ppO2DecoBandOnGrid(widget.initialBand2);
    _band3 = bandsUntouched
        ? seededBand
        : SettingsNotifier.ppO2DecoBandOnGrid(widget.initialBand3);
    _maxO2DepthEnabled = widget.initialMaxO2DepthEnabled;
    _maxO2DepthMeters = depthUntouched
        ? SettingsNotifier.maxO2DepthFloorOnGrid(
            maxOperatingDepthMeters(1.0, maxPpO2: widget.initialFlatPpO2),
          )
        : SettingsNotifier.maxO2DepthOnGrid(widget.initialMaxO2DepthMeters);
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
              onChanged: (v) => setState(() {
                _band1 = v;
                _bandsSeeded = false;
              }),
            ),
            _ppO2Slider(
              label: l10n.settings_decompression_ppO2BandsDialog_band2,
              value: _band2,
              enabled: _bandsEnabled,
              onChanged: (v) => setState(() {
                _band2 = v;
                _bandsSeeded = false;
              }),
            ),
            _ppO2Slider(
              label: l10n.settings_decompression_ppO2BandsDialog_band3,
              value: _band3,
              enabled: _bandsEnabled,
              onChanged: (v) => setState(() {
                _band3 = v;
                _bandsSeeded = false;
              }),
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
              onChanged: (v) => setState(() {
                _maxO2DepthMeters = v;
                _depthSeeded = false;
              }),
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
            final keepBands = _bandsSeeded && !_bandsEnabled;
            final keepDepth = _depthSeeded && !_maxO2DepthEnabled;
            widget.onSave(
              _bandsEnabled,
              keepBands ? widget.initialBand1 : _band1,
              keepBands ? widget.initialBand2 : _band2,
              keepBands ? widget.initialBand3 : _band3,
              _maxO2DepthEnabled,
              keepDepth ? widget.initialMaxO2DepthMeters : _maxO2DepthMeters,
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
