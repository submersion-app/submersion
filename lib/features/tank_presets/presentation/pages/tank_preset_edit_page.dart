import 'dart:async';

import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_log/presentation/widgets/tank_enum_display.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';
import 'package:submersion/shared/widgets/record_editing/record_editor_host.dart';
import 'package:submersion/shared/widgets/record_editing/record_sitting_refusal.dart';

/// What the tank preset editor's form shows, as the diver sees it: the
/// sitting's draft (issue #4527, phase 4). Text as shown, so a pressure in
/// psi or a volume in cubic feet that would not convert back exactly never
/// reads as a change.
typedef TankPresetDraft = ({
  String name,
  String volume,
  String pressure,
  TankMaterial material,
  String description,
});

class TankPresetEditPage extends ConsumerStatefulWidget {
  final String? presetId;

  const TankPresetEditPage({super.key, this.presetId});

  bool get isEditing => presetId != null;

  @override
  ConsumerState<TankPresetEditPage> createState() => _TankPresetEditPageState();
}

class _TankPresetEditPageState extends ConsumerState<TankPresetEditPage>
    with RecordEditorHost<TankPresetEditPage, TankPresetDraft> {
  final _formKey = GlobalKey<FormState>();

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
    for (final controller in [
      _displayNameController,
      _volumeController,
      _workingPressureController,
      _descriptionController,
    ]) {
      controller.addListener(editorChanged);
    }

    if (widget.isEditing) {
      _loadPreset();
    } else {
      // A new preset starts empty: its sitting opens on the empty form, so
      // the first frame already shows the Cancel and Save bar.
      openEditor();
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
            _volumeController.text = formatRoundedForInput(
              preset.volumeCuft,
              1,
            );
          } else {
            // A small bottle keeps two decimals, as the tank editor does:
            // a 0.85 L argon bottle must not save as 0.9 (issue #4243).
            _volumeController.text = formatRoundedForInput(
              preset.volumeLiters,
              UnitFormatter.tankVolumeLiterDecimals(preset.volumeLiters),
            );
          }

          // Convert pressure to user's preferred units
          _workingPressureController.text = formatRoundedForInput(
            units.convertPressure(preset.workingPressureBar),
            0,
          );
        });
        openEditor();
      } else if (preset == null && mounted) {
        // A stale link or a preset deleted on another device: there is
        // nothing to edit, so say so and go back to the list.
        _leaveUnopened(context.l10n.tankPresets_edit_notFound);
      }
    } catch (e) {
      if (mounted) {
        _leaveUnopened(
          context.l10n.tankPresets_edit_errorLoading(e.toString()),
          isError: true,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Says [message] and leaves a preset that could not be opened: an empty
  /// form with no Save would only mislead.
  void _leaveUnopened(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
    leaveEditor();
  }

  @override
  void dispose() {
    disposeEditor();
    _displayNameController.dispose();
    _volumeController.dispose();
    _workingPressureController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final units = ref.watch(unitFormatterProvider);

    return editorScaffold(
      context,
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
                    decoration: InputDecoration(
                      labelText: context.l10n.tankPresets_edit_name,
                      hintText: context.l10n.tankPresets_edit_nameHint,
                      helperText: context.l10n.tankPresets_edit_nameHelper,
                    ),
                    textCapitalization: TextCapitalization.words,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return context.l10n.tankPresets_edit_nameRequired;
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
                            labelText: context.l10n.tankPresets_edit_volume,
                            suffixText: units.volumeSymbol,
                            helperText:
                                units.settings.volumeUnit ==
                                    VolumeUnit.cubicFeet
                                ? context.l10n.tankPresets_edit_volumeHelperCuft
                                : context
                                      .l10n
                                      .tankPresets_edit_volumeHelperLiters,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return context.l10n.tankPresets_edit_required;
                            }
                            return numberValidator(
                              context,
                              check: (volume) => volume <= 0
                                  ? context.l10n.tankPresets_edit_validVolume
                                  : null,
                            )(value);
                          },
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextFormField(
                          controller: _workingPressureController,
                          decoration: InputDecoration(
                            labelText:
                                context.l10n.tankPresets_edit_workingPressure,
                            suffixText: units.pressureSymbol,
                            helperText:
                                context.l10n.tankPresets_edit_ratedPressure,
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return context.l10n.tankPresets_edit_required;
                            }
                            return numberValidator(
                              context,
                              integer: true,
                              check: (pressure) => pressure <= 0
                                  ? context.l10n.tankPresets_edit_validPressure
                                  : null,
                            )(value);
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
                    decoration: InputDecoration(
                      labelText: context.l10n.tankPresets_edit_material,
                    ),
                    items: TankMaterial.values.map((material) {
                      return DropdownMenuItem(
                        value: material,
                        child: Text(material.localizedName(context.l10n)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _material = value);
                        editorChanged();
                      }
                    },
                  ),
                  const SizedBox(height: 24),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText:
                          context.l10n.tankPresets_edit_descriptionOptional,
                      hintText: context.l10n.tankPresets_edit_descriptionHint,
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 32),

                  // Info Card showing calculated values
                  _buildInfoCard(units),
                ],
              ),
            ),
    );
  }

  // The editor's sitting (issue #4527, phase 4).

  @override
  String get editorTable => 'tank_presets';

  @override
  String get editorLeaveLocation => '/tank-presets';

  @override
  String? get editorStoredId => widget.presetId;

  @override
  String editorTitle(BuildContext context) => widget.isEditing
      ? context.l10n.tankPresets_edit_title
      : context.l10n.tankPresets_new_title;

  @override
  TankPresetDraft readEditorDraft() => (
    name: _displayNameController.text,
    volume: _volumeController.text,
    pressure: _workingPressureController.text,
    material: _material,
    description: _descriptionController.text,
  );

  @override
  bool validateEditor() => _formKey.currentState!.validate();

  static double? _readable(TextEditingController controller) =>
      switch (readNumber(controller.text)) {
        NumberValue(:final value) => value,
        NumberBlank() || NumberInvalid() => null,
      };

  Widget _buildInfoCard(UnitFormatter units) {
    // Nothing to show until both read; an unreadable field shows its error.
    final volumeDisplay = _readable(_volumeController);
    final pressureDisplay = _readable(_workingPressureController);

    if (volumeDisplay == null || pressureDisplay == null) {
      return const SizedBox.shrink();
    }

    // Calculate the values for display
    final pressureBar = units.pressureToBar(pressureDisplay);
    double volumeLiters;
    double volumeCuft;

    if (units.settings.volumeUnit == VolumeUnit.cubicFeet) {
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
              context.l10n.tankPresets_edit_tankSpecifications,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.tankPresets_edit_waterVolume(
                volumeLiters.toStringAsFixed(
                  UnitFormatter.tankVolumeLiterDecimals(volumeLiters),
                ),
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              context.l10n.tankPresets_edit_gasCapacity(
                volumeCuft.toStringAsFixed(0),
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            Text(
              context.l10n.tankPresets_edit_workingPressureBar(
                pressureBar.round(),
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Future<void> writeEditor(String recordId) async {
    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);
    final repository = ref.read(tankPresetRepositoryProvider);

    // The validators already rejected anything unreadable in the diver's
    // locale, so both fields parse here.
    final displayName = _displayNameController.text.trim();
    final volumeDisplay = _readable(_volumeController)!;
    final pressureDisplay = _readable(_workingPressureController)!;
    final description = _descriptionController.text.trim();

    // A stored preset keeps the values whose text the diver left alone: the
    // text is rounded for display (whole psi, cuft from a rated capacity),
    // and converting it back would change a preset that was only renamed.
    // What it keeps is the preset as stored now, not as it was when the
    // page opened: a value changed meanwhile (a sync from another device)
    // in a field the diver did not touch is not written back over.
    final existing = _existingPreset;
    final editing = widget.isEditing && existing != null;
    final start = editing ? editorStartDraft : null;
    final material = _material;
    final nameText = _displayNameController.text;
    final descriptionText = _descriptionController.text;
    final inCuft = settings.volumeUnit == VolumeUnit.cubicFeet;
    final pressureChanged =
        start == null || _workingPressureController.text != start.pressure;
    // In cubic feet the volume shown is a capacity at the working pressure,
    // so a new pressure gives a new volume as well.
    final volumeChanged =
        start == null ||
        _volumeController.text != start.volume ||
        (inCuft && pressureChanged);

    TankPresetEntity? stored;
    if (editing) {
      stored = await repository.getPresetById(recordId);
      // Deleted elsewhere while it was edited (a sync from another device):
      // an update would write nothing and still read as saved.
      if (stored == null) {
        throw RecordSittingRefusal((l10n) => l10n.tankPresets_edit_notFound);
      }
    }

    // Convert to storage units (metric)
    final workingPressureBar = pressureChanged || stored == null
        ? units.pressureToBar(pressureDisplay)
        : stored.workingPressureBar;
    final volumeLiters = !volumeChanged && stored != null
        ? stored.volumeLiters
        : inCuft
        // liters = (cuft * 28.3168) / pressure_bar
        ? (volumeDisplay * 28.3168) / workingPressureBar
        : volumeDisplay;

    // A stored preset is always updated, never created again: with no
    // start draft to compare with, every field counts as changed.
    if (stored != null) {
      final nameChanged = start == null || nameText != start.name;
      final materialChanged = start == null || material != start.material;
      final descriptionChanged =
          start == null || descriptionText != start.description;
      await repository.updatePreset(
        stored.copyWith(
          name: nameChanged
              ? TankPresetEntity.generateSlug(displayName)
              : stored.name,
          displayName: nameChanged ? displayName : stored.displayName,
          volumeLiters: volumeLiters,
          workingPressureBar: workingPressureBar,
          material: materialChanged ? material : stored.material,
          description: descriptionChanged ? description : stored.description,
          updatedAt: DateTime.now(),
        ),
      );
      return;
    }
    final diverId = editorDiverId;
    if (diverId == null) {
      throw StateError('A new tank preset needs an active diver');
    }
    await repository.createPreset(
      TankPresetEntity.create(
        id: recordId,
        diverId: diverId,
        name: TankPresetEntity.generateSlug(displayName),
        displayName: displayName,
        volumeLiters: volumeLiters,
        workingPressureBar: workingPressureBar,
        material: _material,
        description: description,
      ),
    );
  }

  @override
  void afterEditorSaved(ScaffoldMessengerState messenger) {
    final displayName = _displayNameController.text.trim();
    unawaited(ref.read(tankPresetListNotifierProvider.notifier).refresh());
    ref.invalidate(customTankPresetsProvider);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          widget.isEditing
              ? context.l10n.tankPresets_edit_updated(displayName)
              : context.l10n.tankPresets_edit_created(displayName),
        ),
      ),
    );
  }
}
