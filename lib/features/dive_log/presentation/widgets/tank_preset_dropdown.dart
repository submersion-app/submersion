import 'package:flutter/material.dart';

import 'package:submersion/core/constants/tank_preset_display.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/domain/services/tank_preset_visibility.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The tank editor's "Tank Preset" field: the diver's own [cylinders]
/// (issue #163), then custom presets, then built-in ones.
///
/// A preset is a selection: choosing one calls [onPresetChanged] and the
/// field shows it. A cylinder is an action: choosing one calls
/// [onCylinderChosen], and the field goes back to showing [presetName],
/// which the host sets to the preset the copied size matches. The tank never
/// links to the cylinder, so that is also what reopening the dive shows.
class TankPresetDropdown extends ConsumerStatefulWidget {
  /// The preset the tank uses, or null for none.
  final String? presetName;

  /// The cylinders to offer. Empty offers none.
  final List<EquipmentItem> cylinders;

  final ValueChanged<TankPresetEntity?> onPresetChanged;
  final ValueChanged<EquipmentItem> onCylinderChosen;

  const TankPresetDropdown({
    super.key,
    required this.presetName,
    required this.cylinders,
    required this.onPresetChanged,
    required this.onCylinderChosen,
  });

  @override
  ConsumerState<TankPresetDropdown> createState() => _TankPresetDropdownState();
}

class _TankPresetDropdownState extends ConsumerState<TankPresetDropdown> {
  /// Bumped on every cylinder choice. It is part of the field's key, so the
  /// field rebuilds from [TankPresetDropdown.presetName] instead of keeping
  /// the cylinder it was handed, even when the matched preset is unchanged.
  int _generation = 0;

  @override
  Widget build(BuildContext context) {
    final presetsAsync = ref.watch(tankPresetsProvider);
    return presetsAsync.when(
      // A reload (a synced settings change, a preset edit) keeps the
      // dropdown in place instead of swapping it for a progress bar.
      skipLoadingOnReload: true,
      loading: () => const LinearProgressIndicator(),
      error: (e, st) => Text('Error: $e'),
      data: (visiblePresets) => _buildField(context, visiblePresets),
    );
  }

  Widget _buildField(
    BuildContext context,
    List<TankPresetEntity> visiblePresets,
  ) {
    final presetName = widget.presetName;
    // A tank logged with a preset the diver has since hidden keeps showing
    // it (issue #2305).
    final presets = withKeptTankPresets(visiblePresets, [presetName]);
    final customPresets = presets.where((p) => !p.isBuiltIn);
    final builtInPresets = presets.where((p) => p.isBuiltIn);
    final matchingPreset = presetName == null
        ? null
        : presets.where((p) => p.name == presetName).firstOrNull;

    return DropdownButtonFormField<_PresetChoice?>(
      key: ValueKey((matchingPreset?.id ?? 'no-preset', _generation)),
      initialValue: matchingPreset == null
          ? null
          : _PresetEntry(matchingPreset),
      // Each dropdown here is one Expanded of a shared Row, so it is narrow.
      // Without this a long label (a custom preset name, "Carbon Fiber")
      // overflows instead of ellipsizing.
      isExpanded: true,
      decoration: InputDecoration(
        labelText: context.l10n.diveLog_tank_label_tankPreset,
        isDense: true,
      ),
      items: [
        DropdownMenuItem<_PresetChoice?>(
          value: null,
          child: Text(context.l10n.diveLog_tank_selectPreset),
        ),
        // The diver's own cylinders first, marked like the "My cylinders"
        // button (issue #2599).
        for (final cylinder in widget.cylinders)
          DropdownMenuItem(
            value: _CylinderEntry(cylinder),
            child: _IconLabel(
              key: Key('tank-preset-cylinder-${cylinder.id}'),
              icon: Icons.inventory_2_outlined,
              // Choosing a cylinder also adds it to the dive's gear, so a
              // screen reader must tell it apart from a preset of the same
              // name.
              iconSemanticLabel: context.l10n.diveLog_tank_ownCylinderTitle,
              label: cylinder.name,
            ),
          ),
        // Custom presets (shown with a star icon)
        for (final preset in customPresets)
          DropdownMenuItem(
            value: _PresetEntry(preset),
            child: _IconLabel(icon: Icons.star, label: preset.displayName),
          ),
        // Built-in presets. Their stored displayName is the stable English
        // identifier that exports and sync carry, so the localized label is
        // resolved here at render time.
        for (final preset in builtInPresets)
          DropdownMenuItem(
            value: _PresetEntry(preset),
            child: Text(
              builtInTankPresetName(context.l10n, preset.name) ??
                  preset.displayName,
            ),
          ),
      ],
      onChanged: (choice) {
        switch (choice) {
          case null:
            widget.onPresetChanged(null);
          case _PresetEntry(:final preset):
            widget.onPresetChanged(preset);
          case _CylinderEntry(:final cylinder):
            setState(() => _generation++);
            widget.onCylinderChosen(cylinder);
        }
      },
    );
  }
}

/// One entry of the preset dropdown. Entries compare by what they wrap, so
/// the field's initial value matches the entry built for the same preset.
sealed class _PresetChoice {
  const _PresetChoice();
}

final class _PresetEntry extends _PresetChoice {
  final TankPresetEntity preset;

  const _PresetEntry(this.preset);

  @override
  bool operator ==(Object other) =>
      other is _PresetEntry && other.preset.id == preset.id;

  @override
  int get hashCode => Object.hash(_PresetEntry, preset.id);
}

final class _CylinderEntry extends _PresetChoice {
  final EquipmentItem cylinder;

  const _CylinderEntry(this.cylinder);

  @override
  bool operator ==(Object other) =>
      other is _CylinderEntry && other.cylinder.id == cylinder.id;

  @override
  int get hashCode => Object.hash(_CylinderEntry, cylinder.id);
}

class _IconLabel extends StatelessWidget {
  final IconData icon;
  final String label;

  /// What the icon says to a screen reader; null leaves it unread.
  final String? iconSemanticLabel;

  const _IconLabel({
    super.key,
    required this.icon,
    required this.label,
    this.iconSemanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final semanticLabel = iconSemanticLabel;
    return Row(
      children: [
        if (semanticLabel == null)
          ExcludeSemantics(child: Icon(icon, size: 16))
        else
          Icon(icon, size: 16, semanticLabel: semanticLabel),
        const SizedBox(width: 8),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}
