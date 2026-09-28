import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip_cylinder.dart';
import 'package:submersion/features/trips/presentation/helpers/trip_cylinder_specs_input.dart';
import 'package:submersion/features/trips/presentation/providers/trip_cylinder_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/number_input_validation.dart';

/// Opens the editor for one trip cylinder slot: its label, size, working
/// pressure and note. Picking a preset fills the size and pressure; typing
/// a size makes the slot a custom cylinder.
Future<void> showTripCylinderEditSheet(
  BuildContext context, {
  required TripCylinder cylinder,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _TripCylinderEditSheet(cylinder: cylinder),
  );
}

class _TripCylinderEditSheet extends ConsumerStatefulWidget {
  final TripCylinder cylinder;

  const _TripCylinderEditSheet({required this.cylinder});

  @override
  ConsumerState<_TripCylinderEditSheet> createState() =>
      _TripCylinderEditSheetState();
}

class _TripCylinderEditSheetState
    extends ConsumerState<_TripCylinderEditSheet> {
  late final TextEditingController _label;
  late final TextEditingController _size;
  late final TextEditingController _workingPressure;
  late final TextEditingController _notes;
  String? _presetName;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final c = widget.cylinder;
    final units = UnitFormatter(ref.read(settingsProvider));
    final preset = _presetNamed(c.presetName);
    _presetName = c.presetName;
    _label = TextEditingController(text: c.label);
    _size = TextEditingController(
      text: cylinderSizeForInput(
        units,
        liters: c.volume,
        workingPressureBar: c.workingPressure,
        ratedCuft: preset?.ratedCapacityCuft,
      ),
    );
    _workingPressure = TextEditingController(
      text: cylinderWorkingPressureForInput(units, c.workingPressure),
    );
    _notes = TextEditingController(text: c.notes);
    // Opened before the presets loaded, an imperial size fell back to the
    // ideal gas figure; show the preset's rated capacity once it arrives,
    // unless the diver has already made the slot custom.
    ref.listenManual(tankPresetsProvider, (previous, next) {
      if (previous?.hasValue ?? false) return;
      final loaded = _presetNamed(_presetName);
      if (loaded == null || !mounted) return;
      _size.text = cylinderSizeForInput(
        UnitFormatter(ref.read(settingsProvider)),
        liters: c.volume,
        workingPressureBar: c.workingPressure,
        ratedCuft: loaded.ratedCapacityCuft,
      );
    });
  }

  @override
  void dispose() {
    _label.dispose();
    _size.dispose();
    _workingPressure.dispose();
    _notes.dispose();
    super.dispose();
  }

  TankPresetEntity? _presetNamed(String? name) {
    if (name == null) return null;
    final presets = ref.read(tankPresetsProvider).value ?? const [];
    for (final p in presets) {
      if (p.name == name) return p;
    }
    return null;
  }

  void _pickPreset(String? name) {
    final units = UnitFormatter(ref.read(settingsProvider));
    final preset = _presetNamed(name);
    setState(() {
      _presetName = name;
      if (preset != null) {
        _size.text = cylinderSizeForInput(
          units,
          liters: preset.volumeLiters,
          workingPressureBar: preset.workingPressureBar,
          ratedCuft: preset.ratedCapacityCuft,
        );
        _workingPressure.text = cylinderWorkingPressureForInput(
          units,
          preset.workingPressureBar,
        );
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final l10n = context.l10n;
    final units = UnitFormatter(ref.read(settingsProvider));
    final label = _label.text.trim();
    if (label.isEmpty) {
      setState(() => _error = l10n.trips_cylinders_edit_errorLabel);
      return;
    }
    final preset = _presetNamed(_presetName);
    final specs = cylinderSpecsFromInput(
      units,
      sizeText: _size.text,
      workingPressureText: _workingPressure.text,
      preset: preset,
    );
    if (specs.invalid || specs.needsPressure) {
      setState(
        () => _error = specs.invalid
            // Unreadable or negative says which; what is left is a zero.
            ? invalidNumberText(context, _size.text, allowNegative: false) ??
                  invalidNumberText(
                    context,
                    _workingPressure.text,
                    allowNegative: false,
                  ) ??
                  l10n.numberInput_atLeastOne
            : l10n.trips_cylinders_edit_errorNeedsPressure,
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final c = widget.cylinder;
      await ref
          .read(tripCylinderRepositoryProvider)
          .updateCylinder(
            c.copyWith(
              label: label,
              volume: specs.volumeLiters,
              workingPressure: specs.workingPressureBar,
              material: preset?.material ?? c.material,
              presetName: preset?.name,
              notes: _notes.text,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // A sync can delete the slot while the sheet is open.
      if (mounted) setState(() => _error = l10n.common_error_tryAgain);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = UnitFormatter(ref.watch(settingsProvider));
    final presetsAsync = ref.watch(tankPresetsProvider);
    final presets = presetsAsync.value ?? const [];
    // A preset-backed slot needs the presets to save: without them an
    // unchanged save would lose its preset and exact specs. A custom slot
    // does not depend on them.
    final presetsMissing =
        !presetsAsync.hasValue && widget.cylinder.presetName != null;
    final known = presets.any((p) => p.name == _presetName);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.trips_cylinders_edit_title,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _label,
              decoration: InputDecoration(
                labelText: l10n.trips_cylinders_edit_label,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              key: const Key('trip-cylinder-preset'),
              initialValue: known ? _presetName : null,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.trips_cylinders_add_preset,
              ),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text(l10n.trips_cylinders_edit_presetCustom),
                ),
                for (final p in presets)
                  DropdownMenuItem<String?>(
                    value: p.name,
                    child: Text(p.displayName),
                  ),
              ],
              onChanged: _pickPreset,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _size,
              decoration: InputDecoration(
                labelText: l10n.trips_cylinders_edit_volume(units.volumeSymbol),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              // A typed size is no longer the preset's.
              onChanged: (_) {
                if (_presetName != null) setState(() => _presetName = null);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _workingPressure,
              // A typed pressure is no longer the preset's either.
              onChanged: (_) {
                if (_presetName != null) setState(() => _presetName = null);
              },
              decoration: InputDecoration(
                labelText: l10n.trips_cylinders_edit_workingPressure(
                  units.pressureSymbol,
                ),
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: InputDecoration(labelText: l10n.trips_cylinders_note),
              maxLines: 3,
            ),
            if (presetsMissing && presetsAsync.hasError
                    ? l10n.common_error_tryAgain
                    : _error
                case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Spacer(),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.common_action_cancel),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving || presetsMissing ? null : _save,
                  child: Text(l10n.common_action_save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
