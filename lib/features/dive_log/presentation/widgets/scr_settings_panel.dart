import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';

/// Panel for configuring SCR (Semi-Closed Rebreather) dive settings.
///
/// SCR diving uses a constant or varying gas injection rate. Unlike CCR,
/// ppO₂ is not constant but varies with depth and metabolic rate:
///
/// **SCR Types:**
/// - CMF (Constant Mass Flow): Fixed injection rate, most common type
/// - PASCR (Passive Addition): Gas added based on breathing rate
/// - ESCR (Electronically Controlled): Variable injection with electronics
///
/// **Key formula for CMF SCR:**
/// FO₂_loop = (Q_injection × FO₂_supply - VO₂) / (Q_injection - VO₂)
/// where VO₂ is oxygen consumption rate (typically 1.0-1.5 L/min at rest)
class ScrSettingsPanel extends StatefulWidget {
  /// Type of SCR system.
  final ScrType? scrType;

  /// Gas injection rate in L/min at surface (for CMF).
  final double? injectionRate;

  /// Addition ratio for PASCR (e.g., 1:3 = 0.33).
  final double? additionRatio;

  /// Orifice size for flow control (e.g., "40", "50", "60").
  final String? orificeSize;

  /// Supply gas mix (the injected gas).
  final GasMix? supplyGas;

  /// Assumed O₂ consumption rate (VO₂) in L/min.
  final double? assumedVo2;

  /// Measured minimum loop O₂ percentage.
  final double? loopO2Min;

  /// Measured maximum loop O₂ percentage.
  final double? loopO2Max;

  /// Measured average loop O₂ percentage.
  final double? loopO2Avg;

  /// Scrubber type.
  final String? scrubberType;

  /// Scrubber rated duration in minutes.
  final int? scrubberDurationMinutes;

  /// Scrubber remaining time in minutes.
  final int? scrubberRemainingMinutes;

  /// Callback when settings change.
  final void Function({
    ScrType? scrType,
    double? injectionRate,
    double? additionRatio,
    String? orificeSize,
    GasMix? supplyGas,
    double? assumedVo2,
    double? loopO2Min,
    double? loopO2Max,
    double? loopO2Avg,
    String? scrubberType,
    int? scrubberDurationMinutes,
    int? scrubberRemainingMinutes,
  })
  onChanged;

  const ScrSettingsPanel({
    super.key,
    this.scrType,
    this.injectionRate,
    this.additionRatio,
    this.orificeSize,
    this.supplyGas,
    this.assumedVo2,
    this.loopO2Min,
    this.loopO2Max,
    this.loopO2Avg,
    this.scrubberType,
    this.scrubberDurationMinutes,
    this.scrubberRemainingMinutes,
    required this.onChanged,
  });

  @override
  State<ScrSettingsPanel> createState() => _ScrSettingsPanelState();
}

class _ScrSettingsPanelState extends State<ScrSettingsPanel> {
  late ScrType _selectedType;
  late TextEditingController _injectionRateController;
  late TextEditingController _additionRatioController;
  late TextEditingController _orificeSizeController;
  late TextEditingController _supplyO2Controller;
  late TextEditingController _supplyHeController;
  late TextEditingController _assumedVo2Controller;
  late TextEditingController _loopO2MinController;
  late TextEditingController _loopO2MaxController;
  late TextEditingController _loopO2AvgController;
  late TextEditingController _scrubberTypeController;
  late TextEditingController _scrubberDurationController;
  late TextEditingController _scrubberRemainingController;

  // What each number field last held while readable, so a mistype reports
  // that value instead of null while the field shows its error (#1900).
  late final _injectionRate = LiveNumber(widget.injectionRate);
  late final _additionRatio = LiveNumber(widget.additionRatio);
  late final _supplyO2 = LiveNumber(widget.supplyGas?.o2 ?? 40);
  late final _supplyHe = LiveNumber(widget.supplyGas?.he ?? 0);
  late final _assumedVo2 = LiveNumber(widget.assumedVo2 ?? 1.30);
  late final _loopO2Min = LiveNumber(widget.loopO2Min);
  late final _loopO2Max = LiveNumber(widget.loopO2Max);
  late final _loopO2Avg = LiveNumber(widget.loopO2Avg);
  late final _scrubberDuration = LiveNumber(
    widget.scrubberDurationMinutes?.toDouble(),
    integer: true,
  );
  late final _scrubberRemaining = LiveNumber(
    widget.scrubberRemainingMinutes?.toDouble(),
    integer: true,
  );

  @override
  void initState() {
    super.initState();
    _selectedType = widget.scrType ?? ScrType.cmf;
    // Every seed goes through formatDecimalForInput so the diver's locale
    // decides the separator, matching what readNumber reads back in
    // _notifyChange. The VO2 default is formatted too: a literal '1.30' would
    // be unreadable in a comma-decimal locale and silently become null (#1091).
    _injectionRateController = TextEditingController(
      text: widget.injectionRate != null
          ? formatDecimalForInput(widget.injectionRate!)
          : '',
    );
    _additionRatioController = TextEditingController(
      text: widget.additionRatio != null
          ? formatDecimalForInput(widget.additionRatio!)
          : '',
    );
    // Orifice size is a free-text spec ("40", "50"), not a parsed quantity.
    _orificeSizeController = TextEditingController(
      text: widget.orificeSize ?? '',
    );
    _supplyO2Controller = TextEditingController(
      text: formatDecimalForInput(widget.supplyGas?.o2 ?? 40),
    );
    _supplyHeController = TextEditingController(
      text: formatDecimalForInput(widget.supplyGas?.he ?? 0),
    );
    _assumedVo2Controller = TextEditingController(
      text: formatDecimalForInput(widget.assumedVo2 ?? 1.30),
    );
    _loopO2MinController = TextEditingController(
      text: widget.loopO2Min != null
          ? formatDecimalForInput(widget.loopO2Min!)
          : '',
    );
    _loopO2MaxController = TextEditingController(
      text: widget.loopO2Max != null
          ? formatDecimalForInput(widget.loopO2Max!)
          : '',
    );
    _loopO2AvgController = TextEditingController(
      text: widget.loopO2Avg != null
          ? formatDecimalForInput(widget.loopO2Avg!)
          : '',
    );
    _scrubberTypeController = TextEditingController(
      text: widget.scrubberType ?? '',
    );
    _scrubberDurationController = TextEditingController(
      text: widget.scrubberDurationMinutes != null
          ? formatDecimalForInput(widget.scrubberDurationMinutes!.toDouble())
          : '',
    );
    _scrubberRemainingController = TextEditingController(
      text: widget.scrubberRemainingMinutes != null
          ? formatDecimalForInput(widget.scrubberRemainingMinutes!.toDouble())
          : '',
    );
  }

  @override
  void dispose() {
    _injectionRateController.dispose();
    _additionRatioController.dispose();
    _orificeSizeController.dispose();
    _supplyO2Controller.dispose();
    _supplyHeController.dispose();
    _assumedVo2Controller.dispose();
    _loopO2MinController.dispose();
    _loopO2MaxController.dispose();
    _loopO2AvgController.dispose();
    _scrubberTypeController.dispose();
    _scrubberDurationController.dispose();
    _scrubberRemainingController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    // Blank keeps its meaning from before: an empty field is "not set", an
    // empty supply O2 drops the supply gas, and an empty He is 0 %.
    final supplyO2 = _supplyO2.resolve(_supplyO2Controller.text);
    final supplyHe = _supplyHe.resolve(_supplyHeController.text, blank: 0);

    widget.onChanged(
      scrType: _selectedType,
      injectionRate: _injectionRate.resolve(_injectionRateController.text),
      additionRatio: _additionRatio.resolve(_additionRatioController.text),
      orificeSize: _orificeSizeController.text.isNotEmpty
          ? _orificeSizeController.text
          : null,
      supplyGas: supplyO2 != null
          ? GasMix(o2: supplyO2, he: supplyHe ?? 0)
          : null,
      assumedVo2: _assumedVo2.resolve(_assumedVo2Controller.text),
      loopO2Min: _loopO2Min.resolve(_loopO2MinController.text),
      loopO2Max: _loopO2Max.resolve(_loopO2MaxController.text),
      loopO2Avg: _loopO2Avg.resolve(_loopO2AvgController.text),
      scrubberType: _scrubberTypeController.text.isNotEmpty
          ? _scrubberTypeController.text
          : null,
      scrubberDurationMinutes: _scrubberDuration
          .resolve(_scrubberDurationController.text)
          ?.toInt(),
      scrubberRemainingMinutes: _scrubberRemaining
          .resolve(_scrubberRemainingController.text)
          ?.toInt(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(Icons.sync_alt, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.diveLog_scr_title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // SCR Type selector
            Text(
              context.l10n.diveLog_scr_sectionScrType,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            SegmentedButton<ScrType>(
              segments: ScrType.values.map((type) {
                return ButtonSegment<ScrType>(
                  value: type,
                  label: Text(type.localizedShortName(context.l10n)),
                  tooltip: type.localizedName(context.l10n),
                );
              }).toList(),
              selected: {_selectedType},
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) {
                  setState(() => _selectedType = selection.first);
                  _notifyChange();
                }
              },
              showSelectedIcon: false,
            ),
            const SizedBox(height: 16),

            // Type-specific settings
            if (_selectedType == ScrType.cmf) _buildCmfSettings(theme),
            if (_selectedType == ScrType.pascr) _buildPascrSettings(theme),
            if (_selectedType == ScrType.escr) _buildEscrSettings(theme),

            const SizedBox(height: 16),

            // Supply gas section (common to all types)
            Text(
              context.l10n.diveLog_scr_sectionSupplyGas,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _buildSupplyGasTemplates(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: NumberField(
                    controller: _supplyO2Controller,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_ccr_label_o2,
                      suffixText: '%',
                      isDense: true,
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _notifyChange();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NumberField(
                    controller: _supplyHeController,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_ccr_label_he,
                      suffixText: '%',
                      isDense: true,
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _notifyChange();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Semantics(
                    label: 'Nitrogen: ${_calculateN2()} percent',
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: context.l10n.diveLog_ccr_label_n2,
                        suffixText: '%',
                        isDense: true,
                      ),
                      child: Text(_calculateN2()),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Loop O₂ measurements (optional)
            Text(
              context.l10n.diveLog_scr_sectionMeasuredLoopO2,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: NumberField(
                    controller: _loopO2MinController,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_scr_label_min,
                      suffixText: '%',
                      isDense: true,
                    ),
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NumberField(
                    controller: _loopO2MaxController,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_scr_label_max,
                      suffixText: '%',
                      isDense: true,
                    ),
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NumberField(
                    controller: _loopO2AvgController,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_scr_label_avg,
                      suffixText: '%',
                      isDense: true,
                    ),
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Scrubber section
            Text(
              context.l10n.diveLog_ccr_sectionScrubber,
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _scrubberTypeController,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_ccr_label_type,
                      isDense: true,
                      hintText: context.l10n.diveLog_ccr_hint_type,
                    ),
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NumberField(
                    controller: _scrubberDurationController,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_ccr_label_rated,
                      suffixText: 'min',
                      isDense: true,
                    ),
                    integer: true,
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NumberField(
                    controller: _scrubberRemainingController,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_ccr_label_remaining,
                      suffixText: 'min',
                      isDense: true,
                    ),
                    integer: true,
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCmfSettings(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveLog_scr_sectionCmf,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: NumberField(
                controller: _injectionRateController,
                decoration: InputDecoration(
                  labelText: context.l10n.diveLog_scr_label_injectionRate,
                  suffixText: 'L/min',
                  isDense: true,
                  hintText: 'e.g., 8.0',
                ),
                onChanged: (_) => _notifyChange(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NumberField(
                controller: _assumedVo2Controller,
                decoration: InputDecoration(
                  labelText: context.l10n.diveLog_scr_label_assumedVo2,
                  suffixText: 'L/min',
                  isDense: true,
                  hintText: '1.30',
                ),
                onChanged: (_) => _notifyChange(),
              ),
            ),
          ],
        ),
        if (_injectionRateController.text.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildCalculatedLoopFo2(theme),
          ),
      ],
    );
  }

  Widget _buildPascrSettings(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveLog_scr_sectionPascr,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: NumberField(
                controller: _additionRatioController,
                decoration: InputDecoration(
                  labelText: context.l10n.diveLog_scr_label_additionRatio,
                  isDense: true,
                  hintText: context.l10n.diveLog_scr_hint_additionRatio,
                ),
                onChanged: (_) => _notifyChange(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NumberField(
                controller: _assumedVo2Controller,
                decoration: InputDecoration(
                  labelText: context.l10n.diveLog_scr_label_assumedVo2,
                  suffixText: 'L/min',
                  isDense: true,
                  hintText: '1.30',
                ),
                onChanged: (_) => _notifyChange(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEscrSettings(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.diveLog_scr_sectionEscr,
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _orificeSizeController,
                decoration: InputDecoration(
                  labelText: context.l10n.diveLog_scr_label_orificeSize,
                  isDense: true,
                  hintText: 'e.g., 50',
                ),
                onChanged: (_) => _notifyChange(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: NumberField(
                controller: _assumedVo2Controller,
                decoration: InputDecoration(
                  labelText: context.l10n.diveLog_scr_label_assumedVo2,
                  suffixText: 'L/min',
                  isDense: true,
                  hintText: '1.30',
                ),
                onChanged: (_) => _notifyChange(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSupplyGasTemplates() {
    // Common SCR supply gas presets (enriched nitrox)
    final templates = [
      ('EAN40', 40.0, 0.0),
      ('EAN50', 50.0, 0.0),
      ('EAN60', 60.0, 0.0),
      ('EAN80', 80.0, 0.0),
      ('O₂', 100.0, 0.0),
    ];

    // The chips follow the mix the panel reports; an unreadable field shows
    // its own error.
    final currentO2 = _supplyO2.resolve(_supplyO2Controller.text) ?? 40.0;
    final currentHe = _supplyHe.resolve(_supplyHeController.text) ?? 0.0;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: templates.map((template) {
        final (name, o2, he) = template;
        final isSelected = currentO2 == o2 && currentHe == he;

        return FilterChip(
          label: Text(name),
          selected: isSelected,
          onSelected: (_) {
            setState(() {
              _supplyO2Controller.text = formatDecimalForInput(o2);
              _supplyHeController.text = formatDecimalForInput(he);
            });
            _notifyChange();
          },
        );
      }).toList(),
    );
  }

  Widget _buildCalculatedLoopFo2(ThemeData theme) {
    final injectionRate = _injectionRate.resolve(_injectionRateController.text);
    final supplyO2 = _supplyO2.resolve(_supplyO2Controller.text);
    final vo2 = _assumedVo2.resolve(_assumedVo2Controller.text) ?? 1.3;

    if (injectionRate == null || supplyO2 == null || injectionRate <= vo2) {
      return const SizedBox.shrink();
    }

    // Calculate steady-state loop FO₂
    // FO₂ = (Qmix × Fmix - VO₂) / (Qmix - VO₂)
    final supplyFraction = supplyO2 / 100.0;
    final loopFo2 =
        (injectionRate * supplyFraction - vo2) / (injectionRate - vo2);
    final loopO2Percent = (loopFo2 * 100).clamp(0, 100);

    return Semantics(
      label:
          'Calculated loop fraction of oxygen: ${loopO2Percent.toStringAsFixed(1)} percent',
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.tertiaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.calculate,
                size: 16,
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              context.l10n.diveLog_scr_calculatedLoopFo2(
                loopO2Percent.toStringAsFixed(1),
              ),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _calculateN2() {
    final o2 = _supplyO2.resolve(_supplyO2Controller.text) ?? 40.0;
    final he = _supplyHe.resolve(_supplyHeController.text) ?? 0.0;
    final n2 = 100.0 - o2 - he;
    return n2.clamp(0.0, 100.0).toStringAsFixed(0);
  }
}
