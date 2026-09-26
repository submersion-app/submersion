import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
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
///
/// The injection rate and VO₂ are stored in L/min but shown and entered in
/// the diver's volume unit per minute (#1935).
class ScrSettingsPanel extends ConsumerStatefulWidget {
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
  ConsumerState<ScrSettingsPanel> createState() => _ScrSettingsPanelState();
}

/// Typical CMF injection rate, in L/min, shown as the field's placeholder.
const double _hintInjectionRateLpm = 8.0;

/// VO₂ assumed when the dive has none recorded, in L/min.
const double _defaultVo2Lpm = 1.30;

/// The text a flow field was seeded with, and the L/min value it stands for.
///
/// While the field still holds [text] the panel reports [litersPerMin] as is,
/// so a save that never touched the field cannot drift it through the
/// rounding of a cuft/min seed (8.0 L/min seeds as 0.28, which reads back as
/// 7.93). Both halves are frozen at seeding time: the parent passes each
/// reported value back in, so comparing against the widget's current value
/// would restore whatever was last typed.
typedef _FlowSeed = ({String text, double? litersPerMin});

class _ScrSettingsPanelState extends ConsumerState<ScrSettingsPanel> {
  /// The unit the flow fields currently hold. Replaced, with the fields
  /// re-seeded, when the diver's volume unit changes while the panel is open
  /// (including when the stored settings finish loading after it was built).
  late UnitFormatter _units;

  late _FlowSeed _injectionRateSeed;
  late _FlowSeed _assumedVo2Seed;

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

  @override
  void initState() {
    super.initState();
    _units = UnitFormatter(ref.read(settingsProvider));
    _selectedType = widget.scrType ?? ScrType.cmf;
    // Every seed goes through formatDecimalForInput so the diver's locale
    // decides the separator, matching what parseUserDecimal reads back in
    // _notifyChange. The VO2 default is formatted too: a literal '1.30' would
    // be unreadable in a comma-decimal locale and silently become null (#1091).
    _injectionRateSeed = _seedInjectionRate(widget.injectionRate);
    _injectionRateController = TextEditingController(
      text: _injectionRateSeed.text,
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
    _assumedVo2Seed = _seedAssumedVo2(widget.assumedVo2 ?? _defaultVo2Lpm);
    _assumedVo2Controller = TextEditingController(text: _assumedVo2Seed.text);
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

  /// Decimals for VO₂ in the diver's unit. VO₂ is roughly a sixth of a CMF
  /// rate, so it takes one digit more than the RMV precision: 1.30 L/min is
  /// 0.046 cuft/min, which two decimals would flatten to 0.05.
  int get _vo2Decimals => _units.rmvDecimals + 1;

  /// A stored L/min flow rendered for its field in the diver's volume unit.
  /// Litres keep their full stored precision, as before; cubic feet round to
  /// [decimals] so the conversion's long tail does not leak into the field.
  String _seedFlow(double litersPerMin, int decimals) =>
      _units.settings.volumeUnit == VolumeUnit.liters
      ? formatDecimalForInput(litersPerMin)
      : formatRoundedForInput(_units.convertRmv(litersPerMin), decimals);

  /// Placeholder for a flow field: [litersPerMin] in the diver's unit and
  /// locale, at [decimals].
  String _flowHint(double litersPerMin, int decimals) =>
      formatFixedForDisplay(_units.convertRmv(litersPerMin), decimals);

  _FlowSeed _seedFlowField(double? litersPerMin, int decimals) => (
    text: litersPerMin != null ? _seedFlow(litersPerMin, decimals) : '',
    litersPerMin: litersPerMin,
  );

  _FlowSeed _seedInjectionRate(double? litersPerMin) =>
      _seedFlowField(litersPerMin, _units.rmvDecimals);

  _FlowSeed _seedAssumedVo2(double? litersPerMin) =>
      _seedFlowField(litersPerMin, _vo2Decimals);

  /// A flow field read back as L/min, or the seeded value while the field
  /// still holds its seed text.
  double? _readFlowLpm(TextEditingController controller, _FlowSeed seed) {
    if (controller.text == seed.text) return seed.litersPerMin;
    final display = parseUserDecimal(controller.text);
    return display != null ? _units.volumeToLiters(display) : null;
  }

  double? get _injectionRateLpm =>
      _readFlowLpm(_injectionRateController, _injectionRateSeed);

  double? get _assumedVo2Lpm =>
      _readFlowLpm(_assumedVo2Controller, _assumedVo2Seed);

  /// Re-renders both flow fields in [units]. Each field is read as L/min in
  /// the old unit first, so what the diver typed carries over; the stored
  /// values are unchanged, so nothing needs reporting.
  void _changeUnits(UnitFormatter units) {
    final injectionRate = _injectionRateLpm;
    final assumedVo2 = _assumedVo2Lpm;
    setState(() {
      _units = units;
      _injectionRateSeed = _seedInjectionRate(injectionRate);
      _assumedVo2Seed = _seedAssumedVo2(assumedVo2);
      _injectionRateController.text = _injectionRateSeed.text;
      _assumedVo2Controller.text = _assumedVo2Seed.text;
    });
  }

  void _notifyChange() {
    final supplyO2 = parseUserDecimal(_supplyO2Controller.text);
    final supplyHe = parseUserDecimal(_supplyHeController.text);

    widget.onChanged(
      scrType: _selectedType,
      injectionRate: _injectionRateLpm,
      additionRatio: parseUserDecimal(_additionRatioController.text),
      orificeSize: _orificeSizeController.text.isNotEmpty
          ? _orificeSizeController.text
          : null,
      supplyGas: supplyO2 != null
          ? GasMix(o2: supplyO2, he: supplyHe ?? 0)
          : null,
      assumedVo2: _assumedVo2Lpm,
      loopO2Min: parseUserDecimal(_loopO2MinController.text),
      loopO2Max: parseUserDecimal(_loopO2MaxController.text),
      loopO2Avg: parseUserDecimal(_loopO2AvgController.text),
      scrubberType: _scrubberTypeController.text.isNotEmpty
          ? _scrubberTypeController.text
          : null,
      scrubberDurationMinutes: parseUserInt(_scrubberDurationController.text),
      scrubberRemainingMinutes: parseUserInt(_scrubberRemainingController.text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ref.listen<VolumeUnit>(
      settingsProvider.select((settings) => settings.volumeUnit),
      (_, next) {
        if (next != _units.settings.volumeUnit) {
          _changeUnits(UnitFormatter(ref.read(settingsProvider)));
        }
      },
    );

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
                  child: TextFormField(
                    controller: _supplyO2Controller,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_ccr_label_o2,
                      suffixText: '%',
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _notifyChange();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _supplyHeController,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_ccr_label_he,
                      suffixText: '%',
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
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
                  child: TextFormField(
                    controller: _loopO2MinController,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_scr_label_min,
                      suffixText: '%',
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _loopO2MaxController,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_scr_label_max,
                      suffixText: '%',
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _loopO2AvgController,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_scr_label_avg,
                      suffixText: '%',
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
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
                  child: TextFormField(
                    controller: _scrubberDurationController,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_ccr_label_rated,
                      suffixText: 'min',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _scrubberRemainingController,
                    decoration: InputDecoration(
                      labelText: context.l10n.diveLog_ccr_label_remaining,
                      suffixText: 'min',
                      isDense: true,
                    ),
                    keyboardType: TextInputType.number,
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
              child: TextFormField(
                controller: _injectionRateController,
                decoration: InputDecoration(
                  labelText: context.l10n.diveLog_scr_label_injectionRate,
                  suffixText: _units.rmvSymbol,
                  isDense: true,
                  hintText: _flowHint(
                    _hintInjectionRateLpm,
                    _units.rmvDecimals,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => _notifyChange(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _assumedVo2Controller,
                decoration: InputDecoration(
                  labelText: context.l10n.diveLog_scr_label_assumedVo2,
                  suffixText: _units.rmvSymbol,
                  isDense: true,
                  hintText: _flowHint(_defaultVo2Lpm, _vo2Decimals),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
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
              child: TextFormField(
                controller: _additionRatioController,
                decoration: InputDecoration(
                  labelText: context.l10n.diveLog_scr_label_additionRatio,
                  isDense: true,
                  hintText: context.l10n.diveLog_scr_hint_additionRatio,
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: (_) => _notifyChange(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _assumedVo2Controller,
                decoration: InputDecoration(
                  labelText: context.l10n.diveLog_scr_label_assumedVo2,
                  suffixText: _units.rmvSymbol,
                  isDense: true,
                  hintText: _flowHint(_defaultVo2Lpm, _vo2Decimals),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
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
              child: TextFormField(
                controller: _assumedVo2Controller,
                decoration: InputDecoration(
                  labelText: context.l10n.diveLog_scr_label_assumedVo2,
                  suffixText: _units.rmvSymbol,
                  isDense: true,
                  hintText: _flowHint(_defaultVo2Lpm, _vo2Decimals),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
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

    final currentO2 = parseUserDecimal(_supplyO2Controller.text) ?? 40.0;
    final currentHe = parseUserDecimal(_supplyHeController.text) ?? 0.0;

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
    // Both flows in L/min, so the fallback VO₂ shares their unit.
    final injectionRate = _injectionRateLpm;
    final supplyO2 = parseUserDecimal(_supplyO2Controller.text);
    final vo2 = _assumedVo2Lpm ?? _defaultVo2Lpm;

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
    final o2 = parseUserDecimal(_supplyO2Controller.text) ?? 40.0;
    final he = parseUserDecimal(_supplyHeController.text) ?? 0.0;
    final n2 = 100.0 - o2 - he;
    return n2.clamp(0.0, 100.0).toStringAsFixed(0);
  }
}
