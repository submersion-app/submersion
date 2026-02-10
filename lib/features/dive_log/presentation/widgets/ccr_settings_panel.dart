import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Panel for configuring CCR (Closed Circuit Rebreather) dive settings.
///
/// CCR diving uses a constant ppO₂ setpoint, controlled by the rebreather.
/// Divers typically use multiple setpoints during a dive:
/// - Low setpoint (~0.7 bar) for descent/ascent to reduce O₂ toxicity risk
/// - High setpoint (~1.2-1.3 bar) for the working/bottom phase
/// - Deco setpoint (~1.3-1.6 bar) for decompression stops
class CcrSettingsPanel extends StatefulWidget {
  /// Low setpoint for descent/ascent (bar).
  final double? setpointLow;

  /// High (working) setpoint for bottom phase (bar).
  final double? setpointHigh;

  /// Deco setpoint for decompression (bar).
  final double? setpointDeco;

  /// Diluent gas mix.
  final GasMix? diluentGas;

  /// Scrubber type (e.g., "Sofnolime", "ExtendAir").
  final String? scrubberType;

  /// Scrubber rated duration in minutes.
  final int? scrubberDurationMinutes;

  /// Scrubber remaining time in minutes.
  final int? scrubberRemainingMinutes;

  /// Loop volume in liters.
  final double? loopVolume;

  /// Callback when settings change.
  final void Function({
    double? setpointLow,
    double? setpointHigh,
    double? setpointDeco,
    GasMix? diluentGas,
    String? scrubberType,
    int? scrubberDurationMinutes,
    int? scrubberRemainingMinutes,
    double? loopVolume,
  })
  onChanged;

  const CcrSettingsPanel({
    super.key,
    this.setpointLow,
    this.setpointHigh,
    this.setpointDeco,
    this.diluentGas,
    this.scrubberType,
    this.scrubberDurationMinutes,
    this.scrubberRemainingMinutes,
    this.loopVolume,
    required this.onChanged,
  });

  @override
  State<CcrSettingsPanel> createState() => _CcrSettingsPanelState();
}

class _CcrSettingsPanelState extends State<CcrSettingsPanel> {
  late TextEditingController _setpointLowController;
  late TextEditingController _setpointHighController;
  late TextEditingController _setpointDecoController;
  late TextEditingController _diluentO2Controller;
  late TextEditingController _diluentHeController;
  late TextEditingController _scrubberTypeController;
  late TextEditingController _scrubberDurationController;
  late TextEditingController _scrubberRemainingController;
  late TextEditingController _loopVolumeController;

  @override
  void initState() {
    super.initState();
    _setpointLowController = TextEditingController(
      text: widget.setpointLow?.toStringAsFixed(2) ?? '0.70',
    );
    _setpointHighController = TextEditingController(
      text: widget.setpointHigh?.toStringAsFixed(2) ?? '1.30',
    );
    _setpointDecoController = TextEditingController(
      text: widget.setpointDeco?.toStringAsFixed(2) ?? '',
    );
    _diluentO2Controller = TextEditingController(
      text: widget.diluentGas?.o2.toString() ?? '21',
    );
    _diluentHeController = TextEditingController(
      text: widget.diluentGas?.he.toString() ?? '0',
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
    _loopVolumeController = TextEditingController(
      text: widget.loopVolume?.toStringAsFixed(1) ?? '',
    );
  }

  @override
  void dispose() {
    _setpointLowController.dispose();
    _setpointHighController.dispose();
    _setpointDecoController.dispose();
    _diluentO2Controller.dispose();
    _diluentHeController.dispose();
    _scrubberTypeController.dispose();
    _scrubberDurationController.dispose();
    _scrubberRemainingController.dispose();
    _loopVolumeController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    final diluentO2 = double.tryParse(_diluentO2Controller.text);
    final diluentHe = double.tryParse(_diluentHeController.text);

    widget.onChanged(
      setpointLow: double.tryParse(_setpointLowController.text),
      setpointHigh: double.tryParse(_setpointHighController.text),
      setpointDeco: double.tryParse(_setpointDecoController.text),
      diluentGas: diluentO2 != null
          ? GasMix(o2: diluentO2, he: diluentHe ?? 0)
          : null,
      scrubberType: _scrubberTypeController.text.isNotEmpty
          ? _scrubberTypeController.text
          : null,
      scrubberDurationMinutes: int.tryParse(_scrubberDurationController.text),
      scrubberRemainingMinutes: int.tryParse(_scrubberRemainingController.text),
      loopVolume: double.tryParse(_loopVolumeController.text),
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
                  child: Icon(Icons.loop, color: theme.colorScheme.primary),
                ),
                const SizedBox(width: 8),
                Text(
                  'CCR Settings',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Setpoints section
            Text('Setpoints (bar)', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _setpointLowController,
                    decoration: const InputDecoration(
                      labelText: 'Low (Desc/Asc)',
                      suffixText: 'bar',
                      isDense: true,
                      hintText: '0.70',
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
                    controller: _setpointHighController,
                    decoration: const InputDecoration(
                      labelText: 'High (Bottom)',
                      suffixText: 'bar',
                      isDense: true,
                      hintText: '1.30',
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
                    controller: _setpointDecoController,
                    decoration: const InputDecoration(
                      labelText: 'Deco',
                      suffixText: 'bar',
                      isDense: true,
                      hintText: '1.60',
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

            // Diluent gas section
            Text('Diluent Gas', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            _buildDiluentTemplates(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _diluentO2Controller,
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
                    controller: _diluentHeController,
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
                  child: Semantics(
                    label: 'Nitrogen: ${_calculateN2()} percent',
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'N₂',
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
            const SizedBox(height: 16),

            // Loop volume
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _loopVolumeController,
                    decoration: const InputDecoration(
                      labelText: 'Loop Volume',
                      suffixText: 'L',
                      isDense: true,
                      hintText: 'e.g., 6.0',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => _notifyChange(),
                  ),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiluentTemplates() {
    // Common diluent gas presets
    final templates = [
      ('Air', 21.0, 0.0),
      ('Tx 21/35', 21.0, 35.0),
      ('Tx 18/45', 18.0, 45.0),
      ('Tx 15/55', 15.0, 55.0),
      ('Tx 12/60', 12.0, 60.0),
      ('Tx 10/70', 10.0, 70.0),
    ];

    final currentO2 = double.tryParse(_diluentO2Controller.text) ?? 21.0;
    final currentHe = double.tryParse(_diluentHeController.text) ?? 0.0;

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
              _diluentO2Controller.text = o2.toString();
              _diluentHeController.text = he.toString();
            });
            _notifyChange();
          },
        );
      }).toList(),
    );
  }

  String _calculateN2() {
    final o2 = double.tryParse(_diluentO2Controller.text) ?? 21.0;
    final he = double.tryParse(_diluentHeController.text) ?? 0.0;
    final n2 = 100.0 - o2 - he;
    return n2.clamp(0.0, 100.0).toStringAsFixed(0);
  }
}
