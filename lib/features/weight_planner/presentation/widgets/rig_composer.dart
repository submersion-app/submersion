import 'package:flutter/material.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The rig inputs for a weight prediction: gear chips (with set/item
/// pickers), tank preset rows, water type, and body weight. Shared by the
/// Weight Planner tool; the plan editor derives tanks/water from the plan.
class RigComposer extends ConsumerWidget {
  final List<EquipmentItem> gear;
  final List<TankPresetEntity> tanks;
  final WaterType waterType;
  final TextEditingController bodyWeightController;
  final UnitFormatter units;
  final bool showSaveBodyWeight;
  final ValueChanged<EquipmentItem> onGearAdded;
  final ValueChanged<List<EquipmentItem>> onGearSetAdded;
  final ValueChanged<EquipmentItem> onGearRemoved;
  final ValueChanged<TankPresetEntity> onTankAdded;
  final ValueChanged<int> onTankRemoved;
  final void Function(int index, TankPresetEntity preset) onTankChanged;
  final ValueChanged<WaterType> onWaterChanged;
  final VoidCallback onSaveBodyWeight;
  final VoidCallback onChanged;

  const RigComposer({
    super.key,
    required this.gear,
    required this.tanks,
    required this.waterType,
    required this.bodyWeightController,
    required this.units,
    required this.showSaveBodyWeight,
    required this.onGearAdded,
    required this.onGearSetAdded,
    required this.onGearRemoved,
    required this.onTankAdded,
    required this.onTankRemoved,
    required this.onTankChanged,
    required this.onWaterChanged,
    required this.onSaveBodyWeight,
    required this.onChanged,
  });

  void _showGearPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => EquipmentPickerSheet(
          scrollController: scrollController,
          selectedEquipmentIds: gear.map((e) => e.id).toSet(),
          onEquipmentSelected: (equipment) {
            onGearAdded(equipment);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _showSetPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => EquipmentSetPickerSheet(
          scrollController: scrollController,
          onSetSelected: (set, items) {
            onGearSetAdded(items);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final presets = ref.watch(tankPresetsProvider).valueOrNull ?? const [];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.equipment_appBar_title,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.inventory_2, size: 18),
                  label: Text(context.l10n.tools_weight_useSet),
                  onPressed: () => _showSetPicker(context),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.l10n.tools_weight_addGear),
                  onPressed: () => _showGearPicker(context),
                ),
              ],
            ),
            if (gear.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  context.l10n.tools_weight_noGear,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final item in gear)
                    InputChip(
                      label: Text(item.name),
                      onDeleted: () => onGearRemoved(item),
                    ),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.tools_weight_tanks,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(context.l10n.tools_weight_addTank),
                  onPressed: presets.isEmpty
                      ? null
                      : () => onTankAdded(presets.first),
                ),
              ],
            ),
            for (var i = 0; i < tanks.length; i++)
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<TankPresetEntity>(
                      initialValue: presets
                          .where((p) => p.name == tanks[i].name)
                          .firstOrNull,
                      items: [
                        for (final preset in presets)
                          DropdownMenuItem(
                            value: preset,
                            child: Text(preset.displayName),
                          ),
                      ],
                      onChanged: (preset) {
                        if (preset != null) onTankChanged(i, preset);
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: tanks.length > 1 ? () => onTankRemoved(i) : null,
                  ),
                ],
              ),
            const SizedBox(height: 12),
            Text(
              context.l10n.tools_weight_waterType,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            SegmentedButton<WaterType>(
              segments: [
                for (final type in WaterType.values)
                  ButtonSegment(value: type, label: Text(type.displayName)),
              ],
              selected: {waterType},
              onSelectionChanged: (selection) =>
                  onWaterChanged(selection.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bodyWeightController,
              decoration: InputDecoration(
                labelText: context.l10n.tools_weight_bodyWeightOptional,
                suffixText: units.weightSymbol,
                suffixIcon: showSaveBodyWeight
                    ? IconButton(
                        icon: const Icon(Icons.save_outlined),
                        tooltip: context.l10n.tools_weight_saveToProfile,
                        onPressed: onSaveBodyWeight,
                      )
                    : null,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => onChanged(),
            ),
          ],
        ),
      ),
    );
  }
}
