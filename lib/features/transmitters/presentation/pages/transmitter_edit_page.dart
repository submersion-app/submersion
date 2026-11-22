import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/services/export/csv/codec/tank_capacity.dart';
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
import 'package:submersion/features/transmitters/data/services/transmitter_key_adoption.dart';
import 'package:submersion/features/transmitters/domain/entities/transmitter.dart';
import 'package:submersion/features/transmitters/presentation/providers/transmitter_providers.dart';
import 'package:submersion/features/transmitters/presentation/widgets/transmitter_key_remove_dialog.dart';
import 'package:submersion/features/equipment/data/services/sensor_summary_scheduler.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
import 'package:submersion/features/transmitters/presentation/pages/transmitter_key_after_save.dart';
import 'package:submersion/features/transmitters/presentation/pages/transmitter_key_draft.dart';
import 'package:submersion/features/transmitters/presentation/widgets/transmitter_field_note.dart';
import 'package:submersion/features/transmitters/presentation/pages/transmitter_key_saved.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';
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

class _TransmitterEditPageState extends ConsumerState<TransmitterEditPage>
    with RecordEditorHost<TransmitterEditPage, TransmitterKeyDraft> {
  static final _log = LoggerService.forClass(TransmitterEditPage);

  final _formKey = GlobalKey<FormState>();

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
  bool _loaded = false;
  String? _keyError;
  String? _duplicateError;

  /// What the last Save wrote, for the work that follows its commit.
  TransmitterKeyWrite? _written;
  bool _offerApply = false;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _serialController,
      _channelController,
      _volumeController,
      _workingPressureController,
    ]) {
      controller.addListener(editorChanged);
    }
    _load();
  }

  @override
  void dispose() {
    disposeEditor();
    _serialController.dispose();
    _channelController.dispose();
    _volumeController.dispose();
    _workingPressureController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = ref.read(transmitterRepositoryProvider);
    final EquipmentItem? item;
    final List<Transmitter> keys;
    final Transmitter? editing;
    try {
      item = await ref.read(equipmentItemProvider(widget.equipmentId).future);
      keys = await repo.getForEquipment(widget.equipmentId);
      editing = widget.transmitterId == null
          ? null
          : await repo.getById(widget.transmitterId!);
    } catch (e, stackTrace) {
      _log.warning('Loading the key failed', error: e, stackTrace: stackTrace);
      if (mounted) _leaveUnopened(context.l10n.recordEdit_loadFailed);
      return;
    }
    if (!mounted) return;
    // A stale link, or a key removed on another device: there is nothing
    // to edit, so say so and go back to the item.
    if (widget.transmitterId != null && editing == null) {
      _leaveUnopened(context.l10n.transmitters_edit_notFound);
      return;
    }
    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);
    // A new key starts from the setup the item's keys already share.
    final setup = editing ?? keys.firstOrNull;
    setState(() {
      _existing = editing;
      _loaded = true;
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
    // A new key starts from the item's serial and the setup its keys
    // share, and a downloaded key not yet set up from what the download
    // registered: seeds, so either can be saved as it opens.
    if (editing == null) {
      openEditor(from: blankTransmitterKeyDraft);
    } else if (!editing.isConfigured) {
      openEditor(from: _draft(configured: false));
    } else {
      openEditor();
    }
    final cylinderId = setup?.equipmentId;
    if (cylinderId == null) return;
    try {
      final gear = await ref.read(equipmentItemProvider(cylinderId).future);
      if (mounted) setState(() => _equipmentName = gear?.name);
    } catch (e, stackTrace) {
      // Only the cylinder's name: the key opens without it.
      _log.warning(
        'Reading the cylinder failed',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Says [message] and leaves a key that could not be opened.
  void _leaveUnopened(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    leaveEditor();
  }

  /// The form as it reads now.
  TransmitterKeyDraft _draft({bool configured = true}) => (
    serial: _serialController.text,
    computerId: _computerId,
    channel: _channelController.text,
    role: _role,
    cylinderId: _equipmentId,
    presetName: _presetName,
    volume: _volumeController.text,
    pressure: _workingPressureController.text,
    material: _material,
    configured: configured,
  );

  /// Changes the form and hands it to the sitting.
  void _change(VoidCallback change) {
    setState(change);
    editorChanged();
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
      // With no working pressure, at the one the app assumes for a tank
      // with none, as the key's Save reads it back.
      final cuft =
          volumeL *
          (workingPressureBar != null && workingPressureBar > 0
              ? workingPressureBar
              : assumedWorkingPressureBar) /
          28.3168;
      _volumeController.text = settings.volumeUnit == VolumeUnit.cubicFeet
          ? formatRoundedForInput(cuft, 1)
          // A small bottle keeps two decimals, as the tank editor does: a
          // 0.85 L argon bottle must not save as 0.9 (issue #4243).
          : formatRoundedForInput(
              volumeL,
              UnitFormatter.tankVolumeLiterDecimals(volumeL),
            );
    } else {
      _volumeController.text = '';
    }
    _workingPressureController.text = workingPressureBar != null
        ? formatRoundedForInput(units.convertPressure(workingPressureBar), 0)
        : '';
  }

  void _applyPreset(TankPresetEntity preset) {
    final settings = ref.read(settingsProvider);
    _change(() {
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
    _change(() {
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
    // A cylinder marked as a suit inflation bottle says what the transmitter
    // reads, ahead of any role its history suggests (issue #4243), and so
    // does doubles kept as one item worn as a twin set (issue #4641).
    final TankRole role;
    if (item.isSuitInflationCylinder) {
      role = TankRole.suitInflation;
    } else if (item.isWornAsTwinSet) {
      role = TankRole.twinSet;
    } else {
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
    }
    _change(() {
      _role = role;
      _roleFieldGeneration++;
    });
  }

  Future<void> _pickGear() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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

  @override
  String get editorTable => 'transmitters';

  @override
  String? get editorStoredId => widget.transmitterId;

  @override
  String? get editorLeaveLocation => '/equipment/${widget.equipmentId}';

  @override
  String editorTitle(BuildContext context) => widget.isEditing
      ? context.l10n.transmitters_edit_title
      : context.l10n.transmitters_new_title;

  @override
  TransmitterKeyDraft readEditorDraft() => _draft();

  @override
  bool validateEditor() {
    setState(() {
      _keyError = null;
      _duplicateError = null;
    });
    // Field errors first: an unreadable channel is a typo to fix, not a
    // missing key, and used to save as no channel at all (#1900).
    if (!_formKey.currentState!.validate()) return false;
    if (!transmitterDraftNamesKey(_draft())) {
      setState(() => _keyError = context.l10n.transmitters_validation_key);
      return false;
    }
    return true;
  }

  /// The key, then the setup of every other key behind the item (role and
  /// cylinder are the transmitter's, so each takes them and is marked
  /// configured), in the sitting's one transaction.
  @override
  Future<void> writeEditor(String recordId) async {
    final repo = ref.read(transmitterRepositoryProvider);
    final settings = ref.read(settingsProvider);
    Transmitter? stored;
    if (!editorCreating) {
      // The key as stored now: what the diver left alone keeps it.
      stored = await repo.getById(recordId);
      if (stored == null) {
        throw RecordSittingRefusal((l10n) => l10n.transmitters_edit_notFound);
      }
    } else if (editorDiverId == null) {
      throw StateError('A new transmitter key needs an active diver');
    }
    final entry = transmitterKeyToSave(
      draft: _draft(),
      start: stored == null ? null : editorStartDraft,
      stored: stored,
      id: recordId,
      diverId: editorDiverId,
      itemId: widget.equipmentId,
      itemName: _itemName,
      settings: settings,
      now: DateTime.now(),
    );
    final write = await writeTransmitterKey(
      entry,
      isNew: stored == null,
      repository: repo,
    );
    final saved = write.saved;
    // A takeover saves over the unclaimed key's row: the sitting names the
    // key it wrote.
    if (saved.id != recordId) {
      await relabelRecordSitting(table: editorTable, recordId: saved.id);
    }
    await repo.saveSetup(
      widget.equipmentId,
      role: saved.role,
      cylinderId: saved.equipmentId,
      volumeL: saved.volumeL,
      workingPressureBar: saved.workingPressureBar,
      material: saved.material,
      presetName: saved.presetName,
      exceptKeyId: saved.id,
    );
    _written = write;
    // The first setup after a download is the moment the diver most wants
    // the dives already imported fixed too, so the item page offers the
    // retroactive apply once (spec section 5). Edits never apply on their
    // own.
    _offerApply =
        stored == null || !stored.isConfigured || write.tookOver != null;
  }

  @override
  bool editorSaveFailed(Object error) {
    if (error is! TransmitterConflictException) return false;
    setState(
      () => _duplicateError = context.l10n.transmitters_validation_duplicate(
        error.existing.label,
      ),
    );
    return true;
  }

  @override
  Object? get editorSavedResult => TransmitterKeySaved(offerApply: _offerApply);

  @override
  void afterEditorSaved(ScaffoldMessengerState messenger) {
    final written = _written;
    if (written == null) return;
    // Read now: the work below runs on after the page has gone.
    final keySerial = normalizeTransmitterSerial(
      written.saved.transmitterSerial,
    );
    unawaited(
      afterTransmitterKeySaved(
        written,
        equipmentId: widget.equipmentId,
        // An item with no serial of its own takes the key's, as an item
        // created from a serial does (issue #3676); one it already has is
        // never overwritten.
        serialForItem: _itemSerial == null ? keySerial : null,
        equipment: ref.read(equipmentRepositoryProvider),
        equipmentList: ref.read(equipmentListNotifierProvider.notifier),
      ),
    );
  }

  @override
  List<RecordEditorOperation> editorOperations(BuildContext context) => [
    if (_existing != null)
      RecordEditorOperation(
        key: const ValueKey('transmitter_remove_key'),
        icon: Icons.delete_outline,
        label: context.l10n.transmitters_key_remove,
        run: _removeKey,
        destructive: true,
      ),
  ];

  String? _positive(String? text) => numberValidator(
    context,
    check: (value) =>
        value <= 0 ? context.l10n.transmitters_validation_positive : null,
  )(text);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final units = ref.watch(unitFormatterProvider);
    final presets = ref.watch(tankPresetsProvider);
    final computers = ref.watch(allDiveComputersProvider);

    return editorScaffold(
      context,
      body: !_loaded
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
                            onChanged: (id) => _change(() => _computerId = id),
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
                    onChanged: (role) => _change(() {
                      _role = role ?? _role;
                      _roleTouched = true;
                    }),
                  ),
                  const SizedBox(height: 16),
                  TransmitterFieldNote(l10n.transmitters_field_gear_subtitle),
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
                            onPressed: () => _change(() {
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
                            _change(() => _presetName = null);
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
                                units.settings.volumeUnit ==
                                    VolumeUnit.cubicFeet
                                ? units.volumeSymbol
                                : 'L',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: _positive,
                          onChanged: (_) => _change(() {
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
                          onChanged: (_) => _change(() {
                            _presetName = null;
                            _missingSizeHint = false;
                          }),
                        ),
                      ),
                    ],
                  ),
                  if (_missingSizeHint)
                    TransmitterFieldNote(
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
                    onChanged: (m) => _change(() => _material = m),
                  ),
                ],
              ),
            ),
    );
  }

  /// Removes the key being edited, alone (issue #3676): a wrong channel or
  /// a mistyped serial goes without the item, its other keys or its gear
  /// history. Deleting the whole transmitter is the item's delete. Answers
  /// whether it removed the key; the page then leaves.
  Future<bool> _removeKey() async {
    final existing = _existing;
    if (existing == null) return false;
    final confirmed = await confirmRemoveTransmitterKey(context);
    if (!confirmed || !mounted) return false;
    try {
      await ref.read(transmitterRepositoryProvider).delete(existing.id);
      // The dropout findings read the item's serials through its keys.
      scheduleConditionFindingsRefresh({widget.equipmentId});
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.l10n.common_label_error}: $e')),
        );
      }
      return false;
    }
  }
}
