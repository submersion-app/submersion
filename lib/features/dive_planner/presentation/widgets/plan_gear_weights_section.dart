import 'package:flutter/material.dart';

import 'package:submersion/core/buoyancy/placement_predictor.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/equipment_set_picker_sheet.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/services/gear_expander.dart';
import 'package:submersion/features/equipment/domain/services/gear_tree.dart';
import 'package:submersion/features/equipment/presentation/helpers/gear_expansion.dart';
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

  /// Every add funnels here so an assembly expands into its parts the same
  /// way it does on a dive (issue #1487).
  Future<void> _addGear(
    WidgetRef ref,
    List<EquipmentItem> items, {
    String? viaSetId,
  }) async {
    final state = ref.read(divePlanNotifierProvider);
    final catalog = ref.read(allEquipmentProvider).valueOrNull ?? const [];
    final byId = {for (final e in catalog) e.id: e};
    final existingItems = [
      for (final id in state.equipmentIds) ?byId[id],
      for (final item in items)
        if (!state.equipmentIds.contains(item.id)) item,
    ];
    final expansion = await expandGearOnPage(
      ref,
      additions: [
        for (final i in items) (equipmentId: i.id, viaSetId: viaSetId),
      ],
      existing: state.fullGearProvenance,
      existingItems: existingItems,
    );
    ref.read(divePlanNotifierProvider.notifier).setGear([
      for (final p in expansion.provenance) p.equipmentId,
    ], expansion.provenance);
  }

  /// Removes [id] and every part attached through it.
  void _removeGear(WidgetRef ref, String id) {
    final state = ref.read(divePlanNotifierProvider);
    final kept = GearExpander.removeSubtree(state.fullGearProvenance, id);
    ref.read(divePlanNotifierProvider.notifier).setGear([
      for (final p in kept) p.equipmentId,
    ], kept);
  }

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
            Navigator.of(context).pop();
            _addGear(ref, [equipment]);
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
            Navigator.of(context).pop();
            _addGear(ref, items, viaSetId: set.id);
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
    // Parts sit inside their assembly's chip as a count (issue #1487). The
    // tree's placement decides what is a part, so an orphaned row whose
    // parent is not on the plan stays visible as its own chip.
    final rows = state.fullGearProvenance;
    final partIds = GearTree.partIds(rows);
    final partCounts = GearTree.partCounts(rows);

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
                    if (!partIds.contains(id))
                      InputChip(
                        label: Text(switch (partCounts[id]) {
                          final n? when n > 0 =>
                            context.l10n.equipment_assemblyChip_label(
                              n,
                              itemsById[id]?.name ?? id,
                            ),
                          _ => itemsById[id]?.name ?? id,
                        }),
                        onDeleted: () => _removeGear(ref, id),
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
