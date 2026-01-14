import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../domain/entities/dive.dart';

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

  @override
  void initState() {
    super.initState();
    _selectedType = widget.scrType ?? ScrType.cmf;
    _injectionRateController = TextEditingController(
      text: widget.injectionRate?.toStringAsFixed(1) ?? '',
    );
    _additionRatioController = TextEditingController(
      text: widget.additionRatio?.toStringAsFixed(2) ?? '',
    );
    _orificeSizeController = TextEditingController(
      text: widget.orificeSize ?? '',
    );
    _supplyO2Controller = TextEditingController(
      text: widget.supplyGas?.o2.toString() ?? '40',
    );
    _supplyHeController = TextEditingController(
      text: widget.supplyGas?.he.toString() ?? '0',
    );
    _assumedVo2Controller = TextEditingController(
      text: widget.assumedVo2?.toStringAsFixed(2) ?? '1.30',
    );
    _loopO2MinController = TextEditingController(
      text: widget.loopO2Min?.toStringAsFixed(1) ?? '',
    );
    _loopO2MaxController = TextEditingController(
      text: widget.loopO2Max?.toStringAsFixed(1) ?? '',
    );
    _loopO2AvgController = TextEditingController(
      text: widget.loopO2Avg?.toStringAsFixed(1) ?? '',
    );
    _scrubberTypeController = TextEditingController(
      text: widget.scrubberType ?? '',
    );
    _scrubberDurationController = TextEditingController(
      text: widget.scrubberDurationMinutes?.toString() ?? '',
    );
    _scrubberRemainingController = TextEditingController(
      text: widget.scrubberRemainingMinutes?.toString() ?? '',
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
    final supplyO2 = double.tryParse(_supplyO2Controller.text);
    final supplyHe = double.tryParse(_supplyHeController.text);

    widget.onChanged(
      scrType: _selectedType,
      injectionRate: double.tryParse(_injectionRateController.text),
      additionRatio: double.tryParse(_additionRatioController.text),
      orificeSize: _orificeSizeController.text.isNotEmpty
          ? _orificeSizeController.text
          : null,
      supplyGas: supplyO2 != null
          ? GasMix(o2: supplyO2, he: supplyHe ?? 0)
          : null,
      assumedVo2: double.tryParse(_assumedVo2Controller.text),
      loopO2Min: double.tryParse(_loopO2MinController.text),
      loopO2Max: double.tryParse(_loopO2MaxController.text),
      loopO2Avg: double.tryParse(_loopO2AvgController.text),
      scrubberType: _scrubberTypeController.text.isNotEmpty
          ? _scrubberTypeController.text
          : null,
      scrubberDurationMinutes: int.tryParse(_scrubberDurationController.text),
      scrubberRemainingMinutes: int.tryParse(_scrubberRemainingController.text),
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
                Icon(Icons.sync_alt, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'SCR Settings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // SCR Type selector
            Text('SCR Type', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<ScrType>(
              segments: ScrType.values.map((type) {
                return ButtonSegment<ScrType>(
                  value: type,
                  label: Text(type.shortName),
                  tooltip: type.displayName,
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
            Text('Supply Gas', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _buildSupplyGasTemplates(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _supplyO2Controller,
                    decoration: const InputDecoration(
                      labelText: 'O₂',
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
                    decoration: const InputDecoration(
                      labelText: 'He',
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
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'N₂',
                      suffixText: '%',
                      isDense: true,
                    ),
                    child: Text(_calculateN2()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Loop O₂ measurements (optional)
            Text(
              'Measured Loop O₂ (optional)',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _loopO2MinController,
                    decoration: const InputDecoration(
                      labelText: 'Min',
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
                    decoration: const InputDecoration(
                      labelText: 'Max',
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
                    decoration: const InputDecoration(
                      labelText: 'Avg',
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
            Text('Scrubber', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _scrubberTypeController,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      isDense: true,
                      hintText: 'e.g., Sofnolime',
                    ),
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _scrubberDurationController,
                    decoration: const InputDecoration(
                      labelText: 'Rated',
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
                    decoration: const InputDecoration(
                      labelText: 'Remaining',
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
        Text('CMF Parameters', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _injectionRateController,
                decoration: const InputDecoration(
                  labelText: 'Injection Rate',
                  suffixText: 'L/min',
                  isDense: true,
                  hintText: 'e.g., 8.0',
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
                decoration: const InputDecoration(
                  labelText: 'Assumed VO₂',
                  suffixText: 'L/min',
                  isDense: true,
                  hintText: '1.30',
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
        Text('PASCR Parameters', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _additionRatioController,
                decoration: const InputDecoration(
                  labelText: 'Addition Ratio',
                  isDense: true,
                  hintText: 'e.g., 0.33 (1:3)',
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
                decoration: const InputDecoration(
                  labelText: 'Assumed VO₂',
                  suffixText: 'L/min',
                  isDense: true,
                  hintText: '1.30',
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
        Text('ESCR Parameters', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _orificeSizeController,
                decoration: const InputDecoration(
                  labelText: 'Orifice Size',
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
                decoration: const InputDecoration(
                  labelText: 'Assumed VO₂',
                  suffixText: 'L/min',
                  isDense: true,
                  hintText: '1.30',
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

    final currentO2 = double.tryParse(_supplyO2Controller.text) ?? 40.0;
    final currentHe = double.tryParse(_supplyHeController.text) ?? 0.0;

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
              _supplyO2Controller.text = o2.toString();
              _supplyHeController.text = he.toString();
            });
            _notifyChange();
          },
        );
      }).toList(),
    );
  }

  Widget _buildCalculatedLoopFo2(ThemeData theme) {
    final injectionRate = double.tryParse(_injectionRateController.text);
    final supplyO2 = double.tryParse(_supplyO2Controller.text);
    final vo2 = double.tryParse(_assumedVo2Controller.text) ?? 1.3;

    if (injectionRate == null || supplyO2 == null || injectionRate <= vo2) {
      return const SizedBox.shrink();
    }

    // Calculate steady-state loop FO₂
    // FO₂ = (Qmix × Fmix - VO₂) / (Qmix - VO₂)
    final supplyFraction = supplyO2 / 100.0;
    final loopFo2 =
        (injectionRate * supplyFraction - vo2) / (injectionRate - vo2);
    final loopO2Percent = (loopFo2 * 100).clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calculate,
            size: 16,
            color: theme.colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            'Calculated loop FO₂: ${loopO2Percent.toStringAsFixed(1)}%',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  String _calculateN2() {
    final o2 = double.tryParse(_supplyO2Controller.text) ?? 40.0;
    final he = double.tryParse(_supplyHeController.text) ?? 0.0;
    final n2 = 100.0 - o2 - he;
    return n2.clamp(0.0, 100.0).toStringAsFixed(0);
  }
}
