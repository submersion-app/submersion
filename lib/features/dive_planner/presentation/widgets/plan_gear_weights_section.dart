import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/placement_predictor.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/weight_planner/presentation/providers/plan_buoyancy_twin_provider.dart';
import 'package:submersion/features/weight_planner/presentation/providers/weight_planner_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/twin_summary_rows.dart';

/// Gear & Weights card in the plan editor: attach equipment to the plan and
/// show a live weight prediction with an accept action that snapshots it
/// onto the plan.
class PlanGearWeightsSection extends ConsumerWidget {
  const PlanGearWeightsSection({super.key});

  void _showGearPicker(BuildContext context, WidgetRef ref) {
    final state = ref.read(divePlanNotifierProvider);
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
          selectedEquipmentIds: state.equipmentIds.toSet(),
          onEquipmentSelected: (equipment) {
            final notifier = ref.read(divePlanNotifierProvider.notifier);
            final current = ref.read(divePlanNotifierProvider).equipmentIds;
            if (!current.contains(equipment.id)) {
              notifier.setEquipmentIds([...current, equipment.id]);
            }
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  void _showSetPicker(BuildContext context, WidgetRef ref) {
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
            final notifier = ref.read(divePlanNotifierProvider.notifier);
            final current = ref.read(divePlanNotifierProvider).equipmentIds;
            final merged = {...current, for (final item in items) item.id};
            notifier.setEquipmentIds(merged.toList());
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(divePlanNotifierProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final prediction = ref.watch(planWeightPredictionProvider);
    final equipment = ref.watch(allEquipmentProvider).valueOrNull ?? const [];
    final itemsById = {for (final item in equipment) item.id: item};
    final buoyancy = ref.watch(planBuoyancyTwinProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    Icons.fitness_center,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.l10n.planner_gearWeights_title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.inventory_2),
                  tooltip: context.l10n.planner_gearWeights_useSet,
                  onPressed: () => _showSetPicker(context, ref),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: context.l10n.planner_gearWeights_addGear,
                  onPressed: () => _showGearPicker(context, ref),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (state.equipmentIds.isEmpty)
              Text(
                context.l10n.planner_gearWeights_empty,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final id in state.equipmentIds)
                    InputChip(
                      label: Text(itemsById[id]?.name ?? id),
                      onDeleted: () => ref
                          .read(divePlanNotifierProvider.notifier)
                          .setEquipmentIds(
                            state.equipmentIds.where((e) => e != id).toList(),
                          ),
                    ),
                ],
              ),
            if (prediction != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.planner_gearWeights_predicted(
                        units.formatWeight(prediction.totalKg),
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final observations =
                          ref.read(weightObservationsProvider).valueOrNull ??
                          const [];
                      String? exposureItemId;
                      for (final id in state.equipmentIds) {
                        final type = itemsById[id]?.type;
                        if (type == EquipmentType.wetsuit ||
                            type == EquipmentType.drysuit) {
                          exposureItemId = id;
                          break;
                        }
                      }
                      final placement = PlacementPredictor.predict(
                        totalKg: prediction.totalKg,
                        observations: observations,
                        exposureItemId: exposureItemId,
                        incrementKg: settings.weightUnit == WeightUnit.kilograms
                            ? 0.5
                            : 0.45359237,
                      );
                      ref
                          .read(divePlanNotifierProvider.notifier)
                          .setPlannedWeight(prediction.totalKg, placement);
                    },
                    child: Text(context.l10n.planner_gearWeights_accept),
                  ),
                ],
              ),
            ],
            if (state.plannedWeightKg != null)
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.planner_gearWeights_planned(
                      units.formatWeight(state.plannedWeightKg!),
                    ),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            if (buoyancy != null) ...[
              const Divider(height: 24),
              Text(
                context.l10n.buoyancy_throughDive,
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TwinSummaryRows(
                outputs: buoyancy.outputs,
                units: units,
                wingLiftCapacityKg: buoyancy.wingLiftCapacityKg,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
