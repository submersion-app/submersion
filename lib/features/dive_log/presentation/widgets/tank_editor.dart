import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/constants/gas_templates.dart';
import '../../../../core/constants/tank_presets.dart';
import '../../../../core/constants/units.dart';
import '../../../../core/utils/unit_formatter.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../domain/entities/dive.dart';

/// Callback when tank data changes
typedef TankChangeCallback = void Function(DiveTank tank);

/// Widget for editing a single tank's configuration
class TankEditor extends ConsumerStatefulWidget {
  final DiveTank tank;
  final int tankNumber;
  final TankChangeCallback onChanged;
  final VoidCallback? onRemove;
  final bool canRemove;

  const TankEditor({
    super.key,
    required this.tank,
    required this.tankNumber,
    required this.onChanged,
    this.onRemove,
    this.canRemove = true,
  });

  @override
  ConsumerState<TankEditor> createState() => _TankEditorState();
}

class _TankEditorState extends ConsumerState<TankEditor> {
  late TextEditingController _volumeController;
  late TextEditingController _workingPressureController;
  late TextEditingController _startPressureController;
  late TextEditingController _endPressureController;
  late TextEditingController _o2Controller;
  late TextEditingController _heController;
  late TankRole _role;
  late TankMaterial? _material;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);
    
    // For tank volume: imperial uses gas capacity (cuft), metric uses water volume (liters)
    String volumeText = '';
    if (widget.tank.volume != null) {
      if (settings.volumeUnit == VolumeUnit.cubicFeet && widget.tank.workingPressure != null) {
        // Calculate cuft from liters and working pressure
        final cuft = (widget.tank.volume! * widget.tank.workingPressure!) / 28.3168;
        volumeText = cuft.toStringAsFixed(1);
      } else {
        volumeText = widget.tank.volume!.toStringAsFixed(1);
      }
    }
    
    _volumeController = TextEditingController(text: volumeText);
    _workingPressureController = TextEditingController(
      text: widget.tank.workingPressure != null
          ? units.convertPressure(widget.tank.workingPressure!.toDouble()).toStringAsFixed(0)
          : '',
    );
    _startPressureController = TextEditingController(
      text: widget.tank.startPressure != null
          ? units.convertPressure(widget.tank.startPressure!.toDouble()).toStringAsFixed(0)
          : '',
    );
    _endPressureController = TextEditingController(
      text: widget.tank.endPressure != null
          ? units.convertPressure(widget.tank.endPressure!.toDouble()).toStringAsFixed(0)
          : '',
    );
    _o2Controller = TextEditingController(
      text: widget.tank.gasMix.o2.toString(),
    );
    _heController = TextEditingController(
      text: widget.tank.gasMix.he.toString(),
    );
    _role = widget.tank.role;
    _material = widget.tank.material;
  }

  @override
  void didUpdateWidget(TankEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tank.id != widget.tank.id) {
      _initializeControllers();
    }
  }

  @override
  void dispose() {
    _volumeController.dispose();
    _workingPressureController.dispose();
    _startPressureController.dispose();
    _endPressureController.dispose();
    _o2Controller.dispose();
    _heController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);
    
    // Convert from user's preferred units back to metric for storage
    final volumeDisplay = double.tryParse(_volumeController.text);
    final workingPressureDisplay = double.tryParse(_workingPressureController.text);
    final startPressureDisplay = double.tryParse(_startPressureController.text);
    final endPressureDisplay = double.tryParse(_endPressureController.text);
    
    // Convert working pressure to bar first (needed for cuft->liters conversion)
    final workingPressureBar = workingPressureDisplay != null
        ? units.pressureToBar(workingPressureDisplay).round()
        : null;
    
    // For tank volume: convert cuft (gas capacity) back to liters (water volume)
    // Formula: liters = (cuft * 28.3168) / working_pressure_bar
    double? volumeLiters;
    if (volumeDisplay != null) {
      if (settings.volumeUnit == VolumeUnit.cubicFeet && workingPressureBar != null && workingPressureBar > 0) {
        volumeLiters = (volumeDisplay * 28.3168) / workingPressureBar;
      } else {
        // Metric: value is already in liters
        volumeLiters = volumeDisplay;
      }
    }
    
    widget.onChanged(DiveTank(
      id: widget.tank.id,
      name: widget.tank.name,
      volume: volumeLiters,
      workingPressure: workingPressureBar,
      startPressure: startPressureDisplay != null
          ? units.pressureToBar(startPressureDisplay).round()
          : null,
      endPressure: endPressureDisplay != null
          ? units.pressureToBar(endPressureDisplay).round()
          : null,
      gasMix: GasMix(
        o2: double.tryParse(_o2Controller.text) ?? 21.0,
        he: double.tryParse(_heController.text) ?? 0.0,
      ),
      role: _role,
      material: _material,
      order: widget.tank.order,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    
    final gasMix = GasMix(
      o2: double.tryParse(_o2Controller.text) ?? 21.0,
      he: double.tryParse(_heController.text) ?? 0.0,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with tank number, gas name, and remove button
            _buildHeader(gasMix),
            const SizedBox(height: 16),

            // Tank preset and role
            _buildPresetAndRoleRow(units),
            const SizedBox(height: 16),

            // Volume, material, working pressure
            _buildTankSpecsRow(units),
            const SizedBox(height: 16),

            // Gas mix with templates
            _buildGasMixSection(),
            const SizedBox(height: 16),

            // Start/end pressure
            _buildPressureRow(units),

            // MOD display if not air
            if (!gasMix.isAir) _buildModInfo(gasMix, units),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(GasMix gasMix) {
    return Row(
      children: [
        CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Text(
            '${widget.tankNumber}',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tank ${widget.tankNumber}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                gasMix.name,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
        if (widget.canRemove && widget.onRemove != null)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: Theme.of(context).colorScheme.error,
            onPressed: widget.onRemove,
            tooltip: 'Remove tank',
          ),
      ],
    );
  }

  Widget _buildPresetAndRoleRow(UnitFormatter units) {
    return Row(
      children: [
        // Tank preset dropdown
        Expanded(
          child: DropdownButtonFormField<TankPreset?>(
            value: null, // Always show "Select Preset" since preset is one-time fill
            decoration: const InputDecoration(
              labelText: 'Tank Preset',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<TankPreset?>(
                value: null,
                child: Text('Select Preset...'),
              ),
              ...TankPresets.all.map(
                (preset) => DropdownMenuItem(
                  value: preset,
                  child: Text(preset.displayName),
                ),
              ),
            ],
            onChanged: (preset) {
              if (preset != null) {
                _applyPreset(preset);
              }
            },
          ),
        ),
        const SizedBox(width: 16),
        // Role dropdown
        Expanded(
          child: DropdownButtonFormField<TankRole>(
            value: _role,
            decoration: const InputDecoration(
              labelText: 'Role',
              isDense: true,
            ),
            items: TankRole.values
                .map(
                  (role) => DropdownMenuItem(
                    value: role,
                    child: Text(role.displayName),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _role = value);
                _notifyChange();
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTankSpecsRow(UnitFormatter units) {
    return Row(
      children: [
        // Volume
        Expanded(
          child: TextFormField(
            controller: _volumeController,
            decoration: InputDecoration(
              labelText: 'Volume',
              suffixText: units.volumeSymbol,
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => _notifyChange(),
          ),
        ),
        const SizedBox(width: 12),
        // Material
        Expanded(
          child: DropdownButtonFormField<TankMaterial?>(
            value: _material,
            decoration: const InputDecoration(
              labelText: 'Material',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<TankMaterial?>(
                value: null,
                child: Text('Not specified'),
              ),
              ...TankMaterial.values.map(
                (mat) => DropdownMenuItem(
                  value: mat,
                  child: Text(mat.displayName),
                ),
              ),
            ],
            onChanged: (value) {
              setState(() => _material = value);
              _notifyChange();
            },
          ),
        ),
        const SizedBox(width: 12),
        // Working pressure
        Expanded(
          child: TextFormField(
            controller: _workingPressureController,
            decoration: InputDecoration(
              labelText: 'Working P',
              suffixText: units.pressureSymbol,
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => _notifyChange(),
          ),
        ),
      ],
    );
  }

  Widget _buildGasMixSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gas Mix',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        // Gas template chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...GasTemplates.recreational.map(_buildGasChip),
            ...GasTemplates.deco.map(_buildGasChip),
            ...GasTemplates.technical.take(2).map(_buildGasChip),
          ],
        ),
        const SizedBox(height: 12),
        // Manual gas entry
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _o2Controller,
                decoration: const InputDecoration(
                  labelText: 'O2',
                  suffixText: '%',
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  setState(() {});
                  _notifyChange();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _heController,
                decoration: const InputDecoration(
                  labelText: 'He',
                  suffixText: '%',
                  isDense: true,
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  setState(() {});
                  _notifyChange();
                },
              ),
            ),
            const SizedBox(width: 16),
            // N2 display (computed)
            Expanded(
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'N2',
                  suffixText: '%',
                  isDense: true,
                ),
                child: Text(
                  GasMix(
                    o2: double.tryParse(_o2Controller.text) ?? 21.0,
                    he: double.tryParse(_heController.text) ?? 0.0,
                  ).n2.toStringAsFixed(0),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGasChip(GasTemplate template) {
    final currentO2 = double.tryParse(_o2Controller.text) ?? 21.0;
    final currentHe = double.tryParse(_heController.text) ?? 0.0;
    final isSelected = currentO2 == template.o2 && currentHe == template.he;

    return FilterChip(
      label: Text(template.displayName),
      selected: isSelected,
      onSelected: (_) => _applyGasTemplate(template),
    );
  }

  Widget _buildPressureRow(UnitFormatter units) {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _startPressureController,
            decoration: InputDecoration(
              labelText: 'Start Pressure',
              suffixText: units.pressureSymbol,
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => _notifyChange(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextFormField(
            controller: _endPressureController,
            decoration: InputDecoration(
              labelText: 'End Pressure',
              suffixText: units.pressureSymbol,
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => _notifyChange(),
          ),
        ),
      ],
    );
  }

  Widget _buildModInfo(GasMix gasMix, UnitFormatter units) {
    final modDepth = units.formatDepth(gasMix.mod(), decimals: 0);
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber,
            size: 16,
            color: Theme.of(context).colorScheme.tertiary,
          ),
          const SizedBox(width: 8),
          Text(
            'MOD: $modDepth (ppO2 1.4)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.tertiary,
                ),
          ),
        ],
      ),
    );
  }

  void _applyPreset(TankPreset preset) {
    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);
    
    setState(() {
      // For volume: use cuft (gas capacity) for imperial, liters (water volume) for metric
      // This is because "tank size" in imperial is rated by gas capacity (e.g., AL80 = 80 cuft),
      // while metric uses physical water volume (e.g., 11.1L)
      if (settings.volumeUnit == VolumeUnit.cubicFeet) {
        _volumeController.text = preset.volumeCuft.toStringAsFixed(1);
      } else {
        _volumeController.text = preset.volumeLiters.toStringAsFixed(1);
      }
      _workingPressureController.text = units.convertPressure(preset.workingPressureBar.toDouble()).toStringAsFixed(0);
      _startPressureController.text = units.convertPressure(preset.workingPressureBar.toDouble()).toStringAsFixed(0);
      _material = preset.material;
    });
    _notifyChange();
  }

  void _applyGasTemplate(GasTemplate template) {
    setState(() {
      _o2Controller.text = template.o2.toString();
      _heController.text = template.he.toString();
    });
    _notifyChange();
  }
}
