import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/domain/services/set_bundle_resolver.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/set_bundle_sections.dart';
import 'package:submersion/features/weight_presets/presentation/providers/weight_preset_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// What a set applies besides its own gear, read-only, for the set page
/// (issue #4525): the sets it includes (each opens its own page), its
/// weight presets with their lead, its cylinder configurations, and the
/// total of the whole bundle.
///
/// Shows nothing for a set that carries only its own gear.
class SetBundleSummaryCard extends ConsumerWidget {
  const SetBundleSummaryCard({super.key, required this.set});

  final EquipmentSet set;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (set.includedSetIds.isEmpty &&
        set.weightPresetIds.isEmpty &&
        set.cylinderConfigIds.isEmpty) {
      return const SizedBox.shrink();
    }
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final units = ref.watch(unitFormatterProvider);
    final sets = ref.watch(equipmentSetsProvider).valueOrNull ?? const [];
    final presets = ref.watch(weightPresetsProvider).valueOrNull ?? const [];
    final configs = ref.watch(cylinderConfigsProvider).valueOrNull ?? const [];
    final setsById = {for (final s in sets) s.id: s};
    final presetsById = {for (final p in presets) p.id: p};
    final configsById = {for (final c in configs) c.id: c};
    final bundle = SetBundleResolver.resolve(
      set,
      setsById: {...setsById, set.id: set},
      presetsById: presetsById,
      configsById: configsById,
    );

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(text, style: theme.textTheme.titleSmall),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (set.includedSetIds.isNotEmpty) ...[
              heading(l10n.equipment_setEdit_includedSets_title),
              for (final id in set.includedSetIds)
                if (setsById[id] case final included?)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.layers_outlined),
                    title: Text(included.name),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/equipment/sets/${included.id}'),
                  ),
            ],
            if (set.weightPresetIds.isNotEmpty) ...[
              heading(l10n.equipment_setEdit_weights_title),
              for (final id in set.weightPresetIds)
                if (presetsById[id] case final preset?)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.fitness_center),
                    title: Text(preset.displayName),
                    trailing: Text(units.formatWeight(preset.totalKg)),
                  ),
            ],
            if (set.cylinderConfigIds.isNotEmpty) ...[
              heading(l10n.equipment_setEdit_tanks_title),
              for (final id in set.cylinderConfigIds)
                if (configsById[id] case final config?)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.propane_tank_outlined),
                    title: Text(config.name),
                    trailing: Text(
                      l10n.equipment_sets_cylinderCount(config.cylinderCount),
                    ),
                  ),
            ],
            const SizedBox(height: 8),
            Text(
              l10n.equipment_setEdit_bundle_total(
                setBundleSummaryText(
                  l10n,
                  units.formatWeight,
                  gearCount: bundle.gearIds.length,
                  leadKg: bundle.totalWeightKg,
                  cylinderCount: bundle.cylinders.length,
                ),
              ),
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// The set that brings [equipmentId] to [set] when it is not the set's own
/// gear, or null for the set's own. Names where an effective item comes
/// from on the set page.
EquipmentSet? includedSourceOf(
  EquipmentSet set,
  String equipmentId,
  Map<String, EquipmentSet> setsById,
) {
  if (set.equipmentIds.contains(equipmentId)) return null;
  for (final id in set.includedSetIds) {
    final included = setsById[id];
    if (included != null && included.equipmentIds.contains(equipmentId)) {
      return included;
    }
  }
  return null;
}
