import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/number_input.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// One editable cylinder inside a configuration.
///
/// Spec fields are plain editable values, not a live preset reference: the
/// preset picker only seeds them. A configuration records what the diver
/// actually dives, so a later preset edit must not rewrite it.
class CylinderConfigItemEditor extends ConsumerStatefulWidget {
  const CylinderConfigItemEditor({
    super.key,
    required this.item,
    required this.units,
    required this.onChanged,
    required this.onRemove,
  });

  final CylinderConfigItem item;
  final UnitFormatter units;
  final ValueChanged<CylinderConfigItem> onChanged;
  final VoidCallback onRemove;

  @override
  ConsumerState<CylinderConfigItemEditor> createState() =>
      _CylinderConfigItemEditorState();
}

class _CylinderConfigItemEditorState
    extends ConsumerState<CylinderConfigItemEditor> {
  late TextEditingController _o2;
  late TextEditingController _he;
  late TextEditingController _label;

  @override
  void initState() {
    super.initState();
    _o2 = TextEditingController(text: _trim(widget.item.o2Percent));
    _he = TextEditingController(text: _trim(widget.item.hePercent));
    _label = TextEditingController(text: widget.item.label ?? '');
  }

  @override
  void dispose() {
    _o2.dispose();
    _he.dispose();
    _label.dispose();
    super.dispose();
  }

  /// A gas fraction as the diver's locale writes it: 21 stays "21", 32.5
  /// becomes "32,5" for a comma-decimal diver. Paired with [parseUserDecimal]
  /// below, which is the half that reads it back (#1091).
  static String _trim(double value) => formatDecimalForInput(value);

  void _applyPreset(TankPresetEntity preset) {
    widget.onChanged(
      widget.item.copyWith(
        volumeL: preset.volumeLiters,
        workingPressureBar: preset.workingPressureBar,
        tankMaterial: preset.material,
        label: widget.item.label ?? preset.displayName,
      ),
    );
    if (widget.item.label == null) {
      _label.text = preset.displayName;
    }
  }

  /// A preset's cylinder size in the diver's units - gas capacity in imperial,
  /// physical volume in metric.
  String _presetSize(TankPresetEntity preset) => widget.units.formatTankVolume(
    preset.volumeLiters,
    preset.workingPressureBar,
    ratedCapacityCuft: preset.ratedCapacityCuft,
  );

  Future<void> _pickPreset() async {
    final presets = await ref.read(tankPresetsProvider.future);
    if (!mounted || presets.isEmpty) return;

    final chosen = await showModalBottomSheet<TankPresetEntity>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final preset in presets)
              ListTile(
                title: Text(preset.displayName),
                subtitle: Text(
                  '${_presetSize(preset)} - '
                  '${widget.units.formatPressure(preset.workingPressureBar)}',
                ),
                onTap: () => Navigator.of(sheetContext).pop(preset),
              ),
          ],
        ),
      ),
    );
    if (chosen != null) _applyPreset(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item = widget.item;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<TankRole>(
                  initialValue: item.tankRole,
                  decoration: InputDecoration(
                    labelText: l10n.cylinderConfigs_role,
                  ),
                  items: [
                    for (final role in TankRole.values)
                      DropdownMenuItem(
                        value: role,
                        child: Text(role.displayName),
                      ),
                  ],
                  onChanged: (role) {
                    if (role != null) {
                      widget.onChanged(item.copyWith(tankRole: role));
                    }
                  },
                ),
              ),
              IconButton(
                onPressed: widget.onRemove,
                icon: const Icon(Icons.delete_outline),
                tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _o2,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.gasCalculators_mnd_o2Percent,
                  ),
                  // Only a parseable value updates the model: transient states
                  // like a lone "." must not clobber the stored mix.
                  onChanged: (text) {
                    final parsed = parseUserDecimal(text);
                    if (parsed != null) {
                      widget.onChanged(item.copyWith(o2Percent: parsed));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _he,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: l10n.gasCalculators_mnd_hePercent,
                  ),
                  onChanged: (text) {
                    final parsed = parseUserDecimal(text);
                    if (parsed != null) {
                      widget.onChanged(item.copyWith(hePercent: parsed));
                    }
                  },
                ),
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _label,
                  decoration: InputDecoration(
                    labelText: l10n.cylinderConfigs_label,
                  ),
                  onChanged: (text) => widget.onChanged(
                    text.trim().isEmpty
                        ? item.copyWith(clearLabel: true)
                        : item.copyWith(label: text),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: _pickPreset,
                icon: const Icon(Icons.inventory_2_outlined),
                label: Text(l10n.cylinderConfigs_fromPreset),
              ),
            ],
          ),
          if (item.volumeL != null || item.workingPressureBar != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                [
                  if (item.volumeL != null)
                    widget.units.formatTankVolume(
                      item.volumeL,
                      item.workingPressureBar,
                    ),
                  if (item.workingPressureBar != null)
                    widget.units.formatPressure(item.workingPressureBar!),
                ].join(' - '),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
