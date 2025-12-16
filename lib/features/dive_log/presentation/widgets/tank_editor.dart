import 'package:flutter/material.dart';

import '../../../../core/constants/enums.dart';
import '../../../../core/constants/gas_templates.dart';
import '../../../../core/constants/tank_presets.dart';
import '../../domain/entities/dive.dart';

/// Callback when tank data changes
typedef TankChangeCallback = void Function(DiveTank tank);

/// Widget for editing a single tank's configuration
class TankEditor extends StatefulWidget {
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
  State<TankEditor> createState() => _TankEditorState();
}

class _TankEditorState extends State<TankEditor> {
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
    _volumeController = TextEditingController(
      text: widget.tank.volume?.toString() ?? '',
    );
    _workingPressureController = TextEditingController(
      text: widget.tank.workingPressure?.toString() ?? '',
    );
    _startPressureController = TextEditingController(
      text: widget.tank.startPressure?.toString() ?? '',
    );
    _endPressureController = TextEditingController(
      text: widget.tank.endPressure?.toString() ?? '',
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
    widget.onChanged(DiveTank(
      id: widget.tank.id,
      name: widget.tank.name,
      volume: double.tryParse(_volumeController.text),
      workingPressure: int.tryParse(_workingPressureController.text),
      startPressure: int.tryParse(_startPressureController.text),
      endPressure: int.tryParse(_endPressureController.text),
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
            _buildPresetAndRoleRow(),
            const SizedBox(height: 16),

            // Volume, material, working pressure
            _buildTankSpecsRow(),
            const SizedBox(height: 16),

            // Gas mix with templates
            _buildGasMixSection(),
            const SizedBox(height: 16),

            // Start/end pressure
            _buildPressureRow(),

            // MOD display if not air
            if (!gasMix.isAir) _buildModInfo(gasMix),
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

  Widget _buildPresetAndRoleRow() {
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

  Widget _buildTankSpecsRow() {
    return Row(
      children: [
        // Volume
        Expanded(
          child: TextFormField(
            controller: _volumeController,
            decoration: const InputDecoration(
              labelText: 'Volume',
              suffixText: 'L',
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
            decoration: const InputDecoration(
              labelText: 'Working P',
              suffixText: 'bar',
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

  Widget _buildPressureRow() {
    return Row(
      children: [
        Expanded(
          child: TextFormField(
            controller: _startPressureController,
            decoration: const InputDecoration(
              labelText: 'Start Pressure',
              suffixText: 'bar',
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
            decoration: const InputDecoration(
              labelText: 'End Pressure',
              suffixText: 'bar',
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            onChanged: (_) => _notifyChange(),
          ),
        ),
      ],
    );
  }

  Widget _buildModInfo(GasMix gasMix) {
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
            'MOD: ${gasMix.mod().toStringAsFixed(0)}m (ppO2 1.4)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.tertiary,
                ),
          ),
        ],
      ),
    );
  }

  void _applyPreset(TankPreset preset) {
    setState(() {
      _volumeController.text = preset.volumeLiters.toString();
      _workingPressureController.text = preset.workingPressureBar.toString();
      _startPressureController.text = preset.workingPressureBar.toString();
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
