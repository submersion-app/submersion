import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/environment_enum_display.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/tank_presets/domain/entities/tank_preset_entity.dart';
import 'package:submersion/features/tank_presets/presentation/providers/tank_preset_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The rig inputs for a weight prediction: gear chips (with set/item
/// pickers), tank preset rows, water type, body weight, and optional height
/// (centimetres, or feet and inches under imperial depth units). Shared by
/// the Weight Planner tool; the plan editor derives tanks/water from the plan.
class RigComposer extends ConsumerWidget {
  final List<EquipmentItem> gear;
  final List<TankPresetEntity> tanks;
  final WaterType waterType;
  final TextEditingController bodyWeightController;
  final TextEditingController heightCmController;
  final TextEditingController heightFeetController;
  final TextEditingController heightInchesController;

  /// BMI derived from the entered weight and height; null hides the readout.
  final double? bmi;
  final UnitFormatter units;
  final bool showSaveBodyWeight;
  final ValueChanged<EquipmentItem> onGearAdded;
  final void Function(EquipmentSet set, List<EquipmentItem> items)
  onGearSetAdded;
  final ValueChanged<EquipmentItem> onGearRemoved;

  /// Ids in [gear] that are parts of an assembly also in [gear]; they show
  /// inside the assembly's chip as a count rather than as chips of their
  /// own (issue #1487).
  final Set<String> partIds;

  /// Number of parts under each assembly id, for the chip label.
  final Map<String, int> partCounts;
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
    required this.heightCmController,
    required this.heightFeetController,
    required this.heightInchesController,
    this.bmi,
    required this.units,
    required this.showSaveBodyWeight,
    required this.onGearAdded,
    required this.onGearSetAdded,
    required this.onGearRemoved,
    this.partIds = const {},
    this.partCounts = const {},
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
            onGearSetAdded(set, items);
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
            // Wrap, not Row: the two action labels are unconstrained and in
            // longer locales ("Set verwenden", "Ausrüstung hinzufügen") they
            // squeeze the title to nothing and overflow the row. Wrapping keeps
            // every label readable and drops the actions to a second line only
            // when they genuinely do not fit.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  context.l10n.equipment_appBar_title,
                  style: theme.textTheme.titleMedium,
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
                    if (!partIds.contains(item.id))
                      InputChip(
                        label: Text(switch (partCounts[item.id]) {
                          final n? when n > 0 =>
                            context.l10n.equipment_assemblyChip_label(
                              n,
                              item.name,
                            ),
                          _ => item.name,
                        }),
                        onDeleted: () => onGearRemoved(item),
                      ),
                ],
              ),
            const SizedBox(height: 12),
            // Same overflow shape as the equipment header above.
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              children: [
                Text(
                  context.l10n.tools_weight_tanks,
                  style: theme.textTheme.titleMedium,
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
                  ButtonSegment(
                    value: type,
                    label: Text(type.localizedName(context.l10n)),
                  ),
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
            const SizedBox(height: 12),
            _heightFields(context),
            if (bmi != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  context.l10n.tools_weight_bmiHelper(
                    NumberFormat.decimalPatternDigits(
                      locale: Localizations.localeOf(context).toString(),
                      decimalDigits: 1,
                    ).format(bmi),
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Height entry in the diver's units. Mirrors the body-weight history
  /// dialog: one centimetre field, or feet and inches side by side.
  Widget _heightFields(BuildContext context) {
    if (units.heightIsMetric) {
      return TextField(
        controller: heightCmController,
        decoration: InputDecoration(
          labelText: context.l10n.tools_weight_heightOptional,
          suffixText: 'cm',
        ),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        onChanged: (_) => onChanged(),
      );
    }
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: heightFeetController,
            decoration: InputDecoration(
              labelText: context.l10n.bodyWeight_heightFeetLabel,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            onChanged: (_) => onChanged(),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: heightInchesController,
            decoration: InputDecoration(
              labelText: context.l10n.bodyWeight_heightInchesLabel,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            onChanged: (_) => onChanged(),
          ),
        ),
      ],
    );
  }
}
