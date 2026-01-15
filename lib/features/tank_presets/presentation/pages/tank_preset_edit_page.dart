import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';

class TankPresetEditPage extends ConsumerStatefulWidget {
  final String? presetId;

  const TankPresetEditPage({super.key, this.presetId});

  bool get isEditing => presetId != null;

  @override
  ConsumerState<TankPresetEditPage> createState() => _TankPresetEditPageState();
}

class _TankPresetEditPageState extends ConsumerState<TankPresetEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  late TextEditingController _displayNameController;
  late TextEditingController _volumeController;
  late TextEditingController _workingPressureController;
  late TextEditingController _descriptionController;
  TankMaterial _material = TankMaterial.aluminum;

  bool _isLoading = false;
  TankPresetEntity? _existingPreset;

  @override
  void initState() {
    super.initState();
    _displayNameController = TextEditingController();
    _volumeController = TextEditingController();
    _workingPressureController = TextEditingController();
    _descriptionController = TextEditingController();

    if (widget.isEditing) {
      _loadPreset();
    }
  }

  Future<void> _loadPreset() async {
    setState(() => _isLoading = true);

    try {
      final repository = ref.read(tankPresetRepositoryProvider);
      final preset = await repository.getPresetById(widget.presetId!);

      if (preset != null && mounted) {
        final settings = ref.read(settingsProvider);
        final units = UnitFormatter(settings);

        setState(() {
          _existingPreset = preset;
          _displayNameController.text = preset.displayName;
          _descriptionController.text = preset.description;
          _material = preset.material;

          // Convert volume to user's preferred units
          if (settings.volumeUnit == VolumeUnit.cubicFeet) {
            _volumeController.text = preset.volumeCuft.toStringAsFixed(1);
          } else {
            _volumeController.text = preset.volumeLiters.toStringAsFixed(1);
          }

          // Convert pressure to user's preferred units
          _workingPressureController.text = units
              .convertPressure(preset.workingPressureBar.toDouble())
              .toStringAsFixed(0);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading preset: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _volumeController.dispose();
    _workingPressureController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Tank Preset' : 'New Tank Preset'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _savePreset,
            child: const Text('Save'),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Display Name
                  TextFormField(
                    controller: _displayNameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      hintText: 'e.g., My AL80',
                      helperText: 'A friendly name for this tank preset',
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Volume and Pressure Row
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _volumeController,
                          decoration: InputDecoration(
                            labelText: 'Volume',
                            suffixText: units.volumeSymbol,
                            helperText:
                                settings.volumeUnit == VolumeUnit.cubicFeet
                                ? 'Gas capacity (cuft)'
                                : 'Water volume (L)',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            final parsed = double.tryParse(value);
                            if (parsed == null || parsed <= 0) {
                              return 'Enter a valid volume';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _workingPressureController,
                          decoration: InputDecoration(
                            labelText: 'Working Pressure',
                            suffixText: units.pressureSymbol,
                            helperText: 'Rated pressure',
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            final parsed = int.tryParse(value);
                            if (parsed == null || parsed <= 0) {
                              return 'Enter a valid pressure';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Material Dropdown
                  DropdownButtonFormField<TankMaterial>(
                    key: ValueKey(_material),
                    initialValue: _material,
                    decoration: const InputDecoration(labelText: 'Material'),
                    items: TankMaterial.values.map((material) {
                      return DropdownMenuItem(
                        value: material,
                        child: Text(material.displayName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _material = value);
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description (optional)',
                      hintText: 'e.g., My rental tank from dive shop',
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 32),

                  // Info Card showing calculated values
                  _buildInfoCard(settings, units),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(AppSettings settings, UnitFormatter units) {
    final volumeDisplay = double.tryParse(_volumeController.text);
    final pressureDisplay = double.tryParse(_workingPressureController.text);

    if (volumeDisplay == null || pressureDisplay == null) {
      return const SizedBox.shrink();
    }

    // Calculate the values for display
    final pressureBar = units.pressureToBar(pressureDisplay).round();
    double volumeLiters;
    double volumeCuft;

    if (settings.volumeUnit == VolumeUnit.cubicFeet) {
      volumeCuft = volumeDisplay;
      volumeLiters = (volumeDisplay * 28.3168) / pressureBar;
    } else {
      volumeLiters = volumeDisplay;
      volumeCuft = (volumeDisplay * pressureBar) / 28.3168;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tank Specifications',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              '• Water volume: ${volumeLiters.toStringAsFixed(1)} L',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              '• Gas capacity: ${volumeCuft.toStringAsFixed(0)} cuft',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              '• Working pressure: $pressureBar bar',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _savePreset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final settings = ref.read(settingsProvider);
      final units = UnitFormatter(settings);
      final notifier = ref.read(tankPresetListNotifierProvider.notifier);

      // Parse form values
      final displayName = _displayNameController.text.trim();
      final volumeDisplay = double.parse(_volumeController.text);
      final pressureDisplay = double.parse(_workingPressureController.text);
      final description = _descriptionController.text.trim();

      // Convert to storage units (metric)
      final workingPressureBar = units.pressureToBar(pressureDisplay).round();

      double volumeLiters;
      if (settings.volumeUnit == VolumeUnit.cubicFeet) {
        // Convert cuft to liters: liters = (cuft * 28.3168) / pressure_bar
        volumeLiters = (volumeDisplay * 28.3168) / workingPressureBar;
      } else {
        volumeLiters = volumeDisplay;
      }

      if (widget.isEditing && _existingPreset != null) {
        // Update existing preset
        final updated = _existingPreset!.copyWith(
          name: TankPresetEntity.generateSlug(displayName),
          displayName: displayName,
          volumeLiters: volumeLiters,
          workingPressureBar: workingPressureBar,
          material: _material,
          description: description,
          updatedAt: DateTime.now(),
        );
        await notifier.updatePreset(updated);
      } else {
        // Create new preset
        final preset = TankPresetEntity.create(
          id: _uuid.v4(),
          name: TankPresetEntity.generateSlug(displayName),
          displayName: displayName,
          volumeLiters: volumeLiters,
          workingPressureBar: workingPressureBar,
          material: _material,
          description: description,
        );
        await notifier.addPreset(preset);
      }

      if (mounted) {
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.isEditing
                  ? 'Updated "$displayName"'
                  : 'Created "$displayName"',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving preset: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
