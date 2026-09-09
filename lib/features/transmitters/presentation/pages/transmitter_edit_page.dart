import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/constants/tank_preset_display.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Full-screen editor for one registry entry. Picking a gear cylinder or a
/// preset copies its specs into the fields (snapshot rule); the fields stay
/// editable afterward.
class TransmitterEditPage extends ConsumerStatefulWidget {
  final String? transmitterId;
  final String? initialSerial;

  const TransmitterEditPage({
    super.key,
    this.transmitterId,
    this.initialSerial,
  });

  bool get isEditing => transmitterId != null;

  @override
  ConsumerState<TransmitterEditPage> createState() =>
      _TransmitterEditPageState();
}

class _TransmitterEditPageState extends ConsumerState<TransmitterEditPage> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  final _labelController = TextEditingController();
  final _serialController = TextEditingController();
  final _channelController = TextEditingController();
  final _volumeController = TextEditingController();
  final _workingPressureController = TextEditingController();

  TankRole _role = TankRole.backGas;
  TankMaterial? _material;
  String? _computerId;
  String? _presetName;
  String? _equipmentId;
  String? _equipmentName;
  Transmitter? _existing;
  bool _loading = false;
  String? _keyError;
  String? _duplicateError;

  @override
  void initState() {
    super.initState();
    _serialController.text = widget.initialSerial ?? '';
    if (widget.isEditing) _load();
  }

  @override
  void dispose() {
    _labelController.dispose();
    _serialController.dispose();
    _channelController.dispose();
    _volumeController.dispose();
    _workingPressureController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entry = await ref
        .read(transmitterRepositoryProvider)
        .getById(widget.transmitterId!);
    if (!mounted) return;
    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);
    setState(() {
      _existing = entry;
      _loading = false;
      if (entry == null) return;
      _labelController.text = entry.label;
      _serialController.text = entry.transmitterSerial ?? '';
      _computerId = entry.diveComputerId;
      _channelController.text = entry.channelIndex == null
          ? ''
          : '${entry.channelIndex! + 1}';
      _role = entry.role;
      _material = entry.material;
      _presetName = entry.presetName;
      _equipmentId = entry.equipmentId;
      _fillSpecFields(units, settings, entry.volumeL, entry.workingPressureBar);
    });
    if (entry?.equipmentId != null) {
      final gear = await ref.read(
        equipmentItemProvider(entry!.equipmentId!).future,
      );
      if (mounted) setState(() => _equipmentName = gear?.name);
    }
  }

  /// Show liters or cubic feet (gas capacity at working pressure), and bar or
  /// psi, per the diver's units. The same conversion the tank editor uses.
  void _fillSpecFields(
    UnitFormatter units,
    AppSettings settings,
    double? volumeL,
    double? workingPressureBar,
  ) {
    if (volumeL != null) {
      final cuft = workingPressureBar != null
          ? volumeL * workingPressureBar / 28.3168
          : null;
      _volumeController.text =
          settings.volumeUnit == VolumeUnit.cubicFeet && cuft != null
          ? formatRoundedForInput(cuft, 1)
          : formatRoundedForInput(volumeL, 1);
    } else {
      _volumeController.text = '';
    }
    _workingPressureController.text = workingPressureBar != null
        ? formatRoundedForInput(units.convertPressure(workingPressureBar), 0)
        : '';
  }

  void _applyPreset(TankPresetEntity preset) {
    final settings = ref.read(settingsProvider);
    setState(() {
      _presetName = preset.name;
      _material = preset.material;
      _fillSpecFields(
        UnitFormatter(settings),
        settings,
        preset.volumeLiters,
        preset.workingPressureBar,
      );
    });
  }

  void _applyGear(EquipmentItem item) {
    final settings = ref.read(settingsProvider);
    setState(() {
      _equipmentId = item.id;
      _equipmentName = item.name;
      if (item.tankMaterial != null) _material = item.tankMaterial;
      if (item.volumeL != null || item.workingPressureBar != null) {
        _fillSpecFields(
          UnitFormatter(settings),
          settings,
          item.volumeL,
          item.workingPressureBar,
        );
      }
    });
  }

  Future<void> _pickGear() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => EquipmentPickerSheet(
          scrollController: scrollController,
          selectedEquipmentIds: {?_equipmentId},
          typeFilter: EquipmentType.tank,
          onEquipmentSelected: (item) {
            _applyGear(item);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    setState(() {
      _keyError = null;
      _duplicateError = null;
    });
    final serialText = _serialController.text.trim();
    final channel = parseUserInt(_channelController.text);
    final hasChannel = _computerId != null && channel != null && channel >= 1;
    if (serialText.isEmpty && !hasChannel) {
      setState(() => _keyError = l10n.transmitters_validation_key);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);
    final pressureDisplay = parseUserDecimal(_workingPressureController.text);
    final workingPressureBar = pressureDisplay == null
        ? null
        : units.pressureToBar(pressureDisplay);
    final volumeDisplay = parseUserDecimal(_volumeController.text);
    double? volumeL;
    if (volumeDisplay != null) {
      volumeL =
          settings.volumeUnit == VolumeUnit.cubicFeet &&
              workingPressureBar != null &&
              workingPressureBar > 0
          ? (volumeDisplay * 28.3168) / workingPressureBar
          : volumeDisplay;
    }

    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    final now = DateTime.now();
    final entry = Transmitter(
      id: _existing?.id ?? _uuid.v4(),
      diverId: _existing?.diverId ?? diverId,
      transmitterSerial: serialText.isEmpty ? null : serialText,
      diveComputerId: hasChannel ? _computerId : null,
      channelIndex: hasChannel ? channel - 1 : null,
      label: _labelController.text.trim(),
      role: _role,
      volumeL: volumeL,
      workingPressureBar: workingPressureBar,
      material: _material,
      presetName: _presetName,
      equipmentId: _equipmentId,
      createdAt: _existing?.createdAt ?? now,
      updatedAt: now,
    );

    final repo = ref.read(transmitterRepositoryProvider);
    try {
      if (_existing != null) {
        await repo.update(entry);
      } else {
        await repo.create(entry);
      }
    } on TransmitterConflictException catch (e) {
      setState(
        () => _duplicateError = l10n.transmitters_validation_duplicate(
          e.existing.label,
        ),
      );
      return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${l10n.common_label_error}: $e')));
      return;
    }
    if (!mounted) return;
    // A serial assigned straight after a download is the moment the diver
    // most wants the dives just imported fixed too, so offer the retroactive
    // apply once here (spec section 5). Edits never apply automatically.
    final offerApply = _existing == null && widget.initialSerial != null;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.transmitters_saved),
        action: !offerApply
            ? null
            : SnackBarAction(
                label: l10n.transmitters_action_apply,
                onPressed: () async {
                  final result = await repo.applyToExistingDives(entry);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.transmitters_apply_done(
                          result.tanksUpdated,
                          result.divesUpdated,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  String? _positive(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final value = parseUserDecimal(text);
    if (value == null || value <= 0) {
      return context.l10n.transmitters_validation_positive;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final presets = ref.watch(tankPresetsProvider);
    final computers = ref.watch(allDiveComputersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? l10n.transmitters_edit_title
              : l10n.transmitters_new_title,
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          tooltip: l10n.common_action_close,
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: Text(l10n.common_action_save),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  TextFormField(
                    key: const Key('transmitter_label'),
                    controller: _labelController,
                    decoration: InputDecoration(
                      labelText: l10n.transmitters_field_label,
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const Key('transmitter_serial'),
                    controller: _serialController,
                    decoration: InputDecoration(
                      labelText: l10n.transmitters_field_serial,
                      errorText: _duplicateError ?? _keyError,
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: computers.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (e, st) =>
                              Text('${l10n.common_label_error}: $e'),
                          data: (list) => DropdownButtonFormField<String?>(
                            key: const Key('transmitter_computer'),
                            initialValue: _computerId,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: l10n.transmitters_field_computer,
                              isDense: true,
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(l10n.transmitters_gear_none),
                              ),
                              ...list.map(
                                (c) => DropdownMenuItem<String?>(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                              ),
                            ],
                            onChanged: (id) => setState(() => _computerId = id),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          key: const Key('transmitter_channel'),
                          controller: _channelController,
                          decoration: InputDecoration(
                            labelText: l10n.transmitters_field_channel,
                            isDense: true,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TankRole>(
                    key: const Key('transmitter_role'),
                    initialValue: _role,
                    decoration: InputDecoration(
                      labelText: l10n.transmitters_field_role,
                    ),
                    items: [
                      for (final role in TankRole.values)
                        DropdownMenuItem(
                          value: role,
                          child: Text(role.localizedName(l10n)),
                        ),
                    ],
                    onChanged: (role) => setState(() => _role = role ?? _role),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    key: const Key('transmitter_gear'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.transmitters_field_gear),
                    subtitle: Text(
                      _equipmentName ?? l10n.transmitters_gear_none,
                    ),
                    trailing: _equipmentId == null
                        ? const Icon(Icons.chevron_right)
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() {
                              _equipmentId = null;
                              _equipmentName = null;
                            }),
                          ),
                    onTap: _pickGear,
                  ),
                  const SizedBox(height: 8),
                  presets.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, st) => Text('${l10n.common_label_error}: $e'),
                    data: (list) {
                      final matching = _presetName == null
                          ? null
                          : list
                                .where((p) => p.name == _presetName)
                                .firstOrNull;
                      return DropdownButtonFormField<TankPresetEntity?>(
                        key: ValueKey(matching?.id ?? 'no-preset'),
                        initialValue: matching,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: l10n.diveLog_tank_label_tankPreset,
                          isDense: true,
                        ),
                        items: [
                          DropdownMenuItem<TankPresetEntity?>(
                            value: null,
                            child: Text(l10n.diveLog_tank_selectPreset),
                          ),
                          ...list.map(
                            (p) => DropdownMenuItem<TankPresetEntity?>(
                              value: p,
                              child: Text(
                                p.isBuiltIn
                                    ? builtInTankPresetName(l10n, p.name) ??
                                          p.displayName
                                    : p.displayName,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (p) {
                          if (p != null) {
                            _applyPreset(p);
                          } else {
                            setState(() => _presetName = null);
                          }
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          key: const Key('transmitter_volume'),
                          controller: _volumeController,
                          decoration: InputDecoration(
                            labelText: l10n.diveLog_tank_label_volume,
                            suffixText:
                                settings.volumeUnit == VolumeUnit.cubicFeet
                                ? units.volumeSymbol
                                : 'L',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: _positive,
                          onChanged: (_) => setState(() => _presetName = null),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          key: const Key('transmitter_working_pressure'),
                          controller: _workingPressureController,
                          decoration: InputDecoration(
                            labelText: l10n.diveLog_tank_label_workingPressure,
                            suffixText: units.pressureSymbol,
                          ),
                          keyboardType: TextInputType.number,
                          validator: _positive,
                          onChanged: (_) => setState(() => _presetName = null),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TankMaterial?>(
                    key: const Key('transmitter_material'),
                    initialValue: _material,
                    decoration: InputDecoration(
                      labelText: l10n.transmitters_field_material,
                    ),
                    items: [
                      DropdownMenuItem<TankMaterial?>(
                        value: null,
                        child: Text(l10n.transmitters_gear_none),
                      ),
                      for (final m in TankMaterial.values)
                        DropdownMenuItem<TankMaterial?>(
                          value: m,
                          child: Text(m.localizedName(l10n)),
                        ),
                    ],
                    onChanged: (m) => setState(() => _material = m),
                  ),
                ],
              ),
            ),
    );
  }
}
