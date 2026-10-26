import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/constants/tank_preset_display.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/services/transmitter_serial.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/domain/services/tank_preset_visibility.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/transmitters/data/repositories/transmitter_repository.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/features/transmitters/presentation/widgets/transmitter_key_remove_dialog.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';
import 'package:submersion/shared/widgets/forms/number_field.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Sets up a Transmitter item (issue #3676): one of its keys (a serial, or
/// a computer and channel) plus the role and cylinder, which belong to the
/// physical transmitter and are saved onto every key behind the item. The
/// item's name is the keys' label; it is edited on the Equipment page.
/// Picking a gear cylinder or a preset copies its specs into the fields
/// (snapshot rule); the fields stay editable afterward.
class TransmitterEditPage extends ConsumerStatefulWidget {
  /// The Transmitter item being set up.
  final String equipmentId;

  /// The key being edited; null adds a key to the item.
  final String? transmitterId;

  const TransmitterEditPage({
    super.key,
    required this.equipmentId,
    this.transmitterId,
  });

  bool get isEditing => transmitterId != null;

  @override
  ConsumerState<TransmitterEditPage> createState() =>
      _TransmitterEditPageState();
}

class _TransmitterEditPageState extends ConsumerState<TransmitterEditPage> {
  static final _log = LoggerService.forClass(TransmitterEditPage);

  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();

  final _serialController = TextEditingController();
  final _channelController = TextEditingController();
  final _volumeController = TextEditingController();
  final _workingPressureController = TextEditingController();

  TankRole _role = TankRole.backGas;
  bool _roleTouched = false;

  /// Bumped only when the page sets [_role] itself (a suggestion from the
  /// picked cylinder's history), so the Role dropdown, which reads its
  /// value once, remounts then and not on the diver's own picks.
  int _roleFieldGeneration = 0;
  bool _missingSizeHint = false;
  TankMaterial? _material;
  String? _computerId;
  String? _presetName;
  String? _equipmentId;
  String? _equipmentName;

  /// The item's name, the label every key carries, and its serial, which a
  /// key with no serial of its own starts from.
  String _itemName = '';
  String? _itemSerial;
  Transmitter? _existing;
  bool _loading = false;
  String? _keyError;
  String? _duplicateError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _serialController.dispose();
    _channelController.dispose();
    _volumeController.dispose();
    _workingPressureController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final repo = ref.read(transmitterRepositoryProvider);
    final item = await ref.read(
      equipmentItemProvider(widget.equipmentId).future,
    );
    final keys = await repo.getForEquipment(widget.equipmentId);
    final editing = widget.transmitterId == null
        ? null
        : await repo.getById(widget.transmitterId!);
    if (!mounted) return;
    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);
    // A new key starts from the setup the item's keys already share.
    final setup = editing ?? keys.firstOrNull;
    setState(() {
      _existing = editing;
      _loading = false;
      _itemName = item?.name ?? '';
      _itemSerial = normalizeTransmitterSerial(item?.serialNumber);
      if (editing != null) {
        _serialController.text = editing.transmitterSerial ?? '';
        _computerId = editing.diveComputerId;
        _channelController.text = editing.channelIndex == null
            ? ''
            : '${editing.channelIndex! + 1}';
      } else if (keys.isEmpty) {
        _serialController.text = _itemSerial ?? '';
      }
      if (setup != null) {
        _role = setup.role;
        _roleTouched = setup.isConfigured;
        _material = setup.material;
        _presetName = setup.presetName;
        _equipmentId = setup.equipmentId;
        _fillSpecFields(
          units,
          settings,
          setup.volumeL,
          setup.workingPressureBar,
        );
      }
    });
    final cylinderId = setup?.equipmentId;
    if (cylinderId != null) {
      final gear = await ref.read(equipmentItemProvider(cylinderId).future);
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
      _missingSizeHint = false;
      _fillSpecFields(
        UnitFormatter(settings),
        settings,
        preset.volumeLiters,
        preset.workingPressureBar,
      );
    });
  }

  Future<void> _applyGear(EquipmentItem item) async {
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
      // A cylinder with no size of its own leaves an already-filled field
      // (an existing entry's saved spec, or one set from a preset) alone,
      // so the hint reflects what the fields will actually show, not just
      // whether this particular pick carried a size.
      _missingSizeHint =
          _volumeController.text.isEmpty &&
          _workingPressureController.text.isEmpty;
    });
    if (_roleTouched) return;
    final TankRole role;
    try {
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      role = await ref
          .read(transmitterRepositoryProvider)
          .lastRoleForEquipment(item.id, diverId: diverId);
    } catch (e, stackTrace) {
      // The suggestion is a convenience: a failed lookup leaves Role as it
      // is rather than blocking the pick.
      _log.warning(
        'Could not suggest a role from the cylinder history',
        error: e,
        stackTrace: stackTrace,
      );
      return;
    }
    // The diver may have chosen a Role, or picked another cylinder, while
    // the lookup ran; a late answer must not overwrite either.
    if (!mounted || _roleTouched || _equipmentId != item.id) return;
    setState(() {
      _role = role;
      _roleFieldGeneration++;
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
            // Close first: the role suggestion runs a query, and the sheet
            // should not wait on it.
            Navigator.of(context).pop();
            unawaited(_applyGear(item));
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
    // Field errors first: an unreadable channel is a typo to fix, not a
    // missing key, and used to save as no channel at all (#1900).
    if (!_formKey.currentState!.validate()) return;
    final serialText = _serialController.text.trim();
    final channel = _validatedNumber(_channelController)?.toInt();
    final hasChannel = _computerId != null && channel != null && channel >= 1;
    if (serialText.isEmpty && !hasChannel) {
      setState(() => _keyError = l10n.transmitters_validation_key);
      return;
    }

    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);
    final pressureDisplay = _validatedNumber(_workingPressureController);
    final workingPressureBar = pressureDisplay == null
        ? null
        : units.pressureToBar(pressureDisplay);
    final volumeDisplay = _validatedNumber(_volumeController);
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
      label: _itemName,
      role: _role,
      volumeL: volumeL,
      workingPressureBar: workingPressureBar,
      material: _material,
      presetName: _presetName,
      equipmentId: _equipmentId,
      transmitterEquipmentId: widget.equipmentId,
      isConfigured: true,
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
      // Role and cylinder are the transmitter's, so every other key behind
      // the item takes them too, and each is marked configured.
      await repo.saveSetup(
        widget.equipmentId,
        role: _role,
        cylinderId: _equipmentId,
        volumeL: volumeL,
        workingPressureBar: workingPressureBar,
        material: _material,
        presetName: _presetName,
        exceptKeyId: entry.id,
      );
      // The dropout findings read serials through the transmitter link and
      // are stored, read without the engine, so the item refreshes now.
      scheduleConditionFindingsRefresh({widget.equipmentId});
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
    // Outside the save's try: the entry is already written. An item with no
    // serial of its own takes the key's, as an item created from a serial
    // does (issue #3676); one it already has is never overwritten.
    final keySerial = normalizeTransmitterSerial(serialText);
    if (keySerial != null && _itemSerial == null) {
      await _fillItemSerial(keySerial);
    }
    if (!mounted) return;
    // The first setup after a download is the moment the diver most wants
    // the dives already imported fixed too, so offer the retroactive apply
    // once here (spec section 5). Edits never apply automatically.
    final offerApply = _existing == null || !_existing!.isConfigured;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.transmitters_saved),
        action: !offerApply
            ? null
            : SnackBarAction(
                label: l10n.transmitters_action_apply,
                onPressed: () async {
                  // The setup went onto every key of the item, so every
                  // key's dives are filled, not just this one's.
                  var tanks = 0;
                  var dives = 0;
                  try {
                    for (final key in await repo.getForEquipment(
                      widget.equipmentId,
                    )) {
                      final result = await repo.applyToExistingDives(key);
                      tanks += result.tanksUpdated;
                      dives += result.divesUpdated;
                    }
                  } catch (e) {
                    // The page is gone, so the messenger is the only place
                    // left to say the apply did not happen.
                    messenger.showSnackBar(
                      SnackBar(content: Text('${l10n.common_label_error}: $e')),
                    );
                    return;
                  }
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(l10n.transmitters_apply_done(tanks, dives)),
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

  /// Writes [serial] onto the item, which has none. Through the list
  /// notifier, as the equipment editor saves, so the lists refresh. A
  /// failure is reported and swallowed: the key is already saved.
  Future<void> _fillItemSerial(String serial) async {
    try {
      final gear = await ref.read(
        equipmentItemProvider(widget.equipmentId).future,
      );
      if (gear == null) return;
      await ref
          .read(equipmentListNotifierProvider.notifier)
          .updateEquipment(gear.copyWith(serialNumber: serial));
    } catch (e, stackTrace) {
      _log.warning(
        'Could not copy the serial onto the transmitter item',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// A field's number once the form has validated. Blank is "not set";
  /// unreadable text cannot reach here.
  static double? _validatedNumber(TextEditingController controller) =>
      switch (readNumber(controller.text)) {
        NumberValue(:final value) => value,
        NumberBlank() => null,
        NumberInvalid() => null, // unreachable: validate() ran first
      };

  String? _positive(String? text) => numberValidator(
    context,
    check: (value) =>
        value <= 0 ? context.l10n.transmitters_validation_positive : null,
  )(text);

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
          AppBarTextAction(
            label: l10n.common_action_save,
            onPressed: _loading ? null : _save,
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
                          inputFormatters: numberInputFormatters(),
                          validator: numberValidator(context, integer: true),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<TankRole>(
                    key: ValueKey('transmitter_role-$_roleFieldGeneration'),
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
                    onChanged: (role) => setState(() {
                      _role = role ?? _role;
                      _roleTouched = true;
                    }),
                  ),
                  const SizedBox(height: 16),
                  _FieldNote(l10n.transmitters_field_gear_subtitle),
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
                              _missingSizeHint = false;
                            }),
                          ),
                    onTap: _pickGear,
                  ),
                  const SizedBox(height: 8),
                  presets.when(
                    skipLoadingOnReload: true,
                    loading: () => const LinearProgressIndicator(),
                    error: (e, st) => Text('${l10n.common_label_error}: $e'),
                    data: (visibleList) {
                      // A preset the diver has since hidden stays selectable
                      // while it is this transmitter's value (issue #2305).
                      final list = withKeptTankPresets(visibleList, [
                        _presetName,
                      ]);
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
                          onChanged: (_) => setState(() {
                            _presetName = null;
                            _missingSizeHint = false;
                          }),
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
                          onChanged: (_) => setState(() {
                            _presetName = null;
                            _missingSizeHint = false;
                          }),
                        ),
                      ),
                    ],
                  ),
                  if (_missingSizeHint)
                    _FieldNote(
                      l10n.transmitters_hint_missingSize,
                      key: const Key('transmitter_missing_size_hint'),
                      padding: const EdgeInsets.only(top: 4, bottom: 16),
                    )
                  else
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
                  if (_existing != null) ...[
                    const SizedBox(height: 24),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        key: const Key('transmitter_remove_key'),
                        style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error,
                        ),
                        onPressed: _confirmRemoveKey,
                        icon: const Icon(Icons.delete_outline),
                        label: Text(l10n.transmitters_key_remove),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }

  /// Removes the key being edited, alone (issue #3676): a wrong channel or
  /// a mistyped serial goes without the item, its other keys or its gear
  /// history. Deleting the whole transmitter is the item's delete.
  Future<void> _confirmRemoveKey() async {
    final existing = _existing;
    if (existing == null) return;
    final confirmed = await confirmRemoveTransmitterKey(context);
    if (!confirmed || !mounted) return;
    try {
      await ref.read(transmitterRepositoryProvider).delete(existing.id);
      // The dropout findings read the item's serials through its keys.
      scheduleConditionFindingsRefresh({widget.equipmentId});
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${context.l10n.common_label_error}: $e')),
      );
      return;
    }
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}

/// Muted explanatory line beside a field: the shared FormCaption style,
/// without its overline indent, since these sit flush with the fields.
class _FieldNote extends StatelessWidget {
  const _FieldNote(
    this.text, {
    super.key,
    this.padding = const EdgeInsets.only(bottom: 2),
  });

  final String text;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
