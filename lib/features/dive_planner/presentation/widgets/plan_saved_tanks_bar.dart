import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config_item.dart';
import 'package:submersion/features/cylinder_configs/domain/services/dive_tank_config_adapter.dart';
import 'package:submersion/features/cylinder_configs/domain/services/tank_config_capture.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/domain/services/dive_plan_state_mapper.dart';
import 'package:submersion/features/planner/domain/services/tank_role_resolver.dart';
import 'package:submersion/features/planner/presentation/widgets/plan_name_dialog.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

const _uuid = Uuid();

/// Whether the saved-tanks bar is open. Session-scoped, like the rest of the
/// planner's collapse state: a diver who opened it wants it open while they
/// build this plan, not forever.
final savedTanksExpandedProvider = StateProvider<bool>((_) => false);

/// A bar above the plan's tanks that opens into the diver's saved cylinders.
///
/// Saved cylinders are the app's cylinder-configuration items, so a rig
/// entered once - in the planner, the dive editor, or the equipment pages -
/// is a tap away from any plan. Each cylinder is its own object: the box lists
/// them flat, tapping one adds that one tank to the plan, and saving stores
/// one tank at a time under a name the diver gives it. Tanks saved from the
/// planner collect in a single configuration named after this bar, so the
/// equipment pages show them as one tidy list rather than one configuration
/// per tank.
class PlanSavedTanksBar extends ConsumerWidget {
  const PlanSavedTanksBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final expanded = ref.watch(savedTanksExpandedProvider);
    final configs =
        ref.watch(cylinderConfigsProvider).valueOrNull ??
        const <CylinderConfig>[];
    final items = [
      for (final config in configs)
        for (final item in config.items) item,
    ];
    final units = UnitFormatter(ref.watch(settingsProvider));
    final planTanks = ref.watch(
      divePlanNotifierProvider.select((s) => s.tanks),
    );

    final title = items.isNotEmpty
        ? '${l10n.divePlanner_savedTanks_title} (${items.length})'
        : l10n.divePlanner_savedTanks_title;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => ref
              .read(savedTanksExpandedProvider.notifier)
              .update((open) => !open),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(
              children: [
                Icon(
                  Icons.bookmark_outline,
                  size: 18,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: theme.textTheme.labelLarge)),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
        if (expanded)
          Container(
            margin: const EdgeInsets.only(top: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (items.isEmpty)
                  Text(
                    l10n.divePlanner_savedTanks_empty,
                    style: theme.textTheme.bodySmall,
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final item in items)
                        _SavedTankChip(
                          item: item,
                          units: units,
                          onPick: (item) => _addTank(ref, item),
                        ),
                    ],
                  ),
                const SizedBox(height: 4),
                // Side by side when the pane is wide enough, stacked when it
                // is not: the editor pane can be narrower than two buttons.
                OverflowBar(
                  alignment: MainAxisAlignment.spaceBetween,
                  overflowAlignment: OverflowBarAlignment.start,
                  spacing: 8,
                  children: [
                    // One tank at a time: the diver picks which of the plan's
                    // tanks to keep, then names it.
                    PopupMenuButton<DiveTank>(
                      enabled: planTanks.isNotEmpty,
                      tooltip: l10n.divePlanner_savedTanks_save,
                      onSelected: (tank) => _saveTank(context, ref, tank),
                      itemBuilder: (context) => [
                        for (final tank in planTanks)
                          PopupMenuItem<DiveTank>(
                            value: tank,
                            child: Text(
                              '${tank.name ?? tank.gasMix.name} · '
                              '${tank.gasMix.name} · '
                              '${units.formatTankVolume(tank.volume, tank.workingPressure)}',
                            ),
                          ),
                      ],
                      child: _MenuLabel(
                        icon: Icons.save_outlined,
                        text: l10n.divePlanner_savedTanks_save,
                        enabled: planTanks.isNotEmpty,
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          context.push('/equipment/cylinder-configs'),
                      child: Text(l10n.divePlanner_savedTanks_manage),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  /// Append one saved cylinder to the plan as a new tank, gas and all.
  void _addTank(WidgetRef ref, CylinderConfigItem item) {
    final state = ref.read(divePlanNotifierProvider);
    final tank = const DiveTankConfigAdapter().tankFromItem(
      item,
      id: _uuid.v4(),
      order: state.tanks.length,
    );
    ref.read(divePlanNotifierProvider.notifier).addTank(tank);
  }

  /// Save one of the plan's tanks as a saved cylinder under a name the diver
  /// gives it, then open the bar so they see it there.
  ///
  /// The tank joins the configuration named after this bar, created on first
  /// use for the active diver, so every tank saved from the planner lives in
  /// one place on the equipment pages.
  ///
  /// The role is derived on the way out. Inside the planner a tank's stored
  /// role is the diver's raw input - `bailout`, or the `backGas` placeholder
  /// meaning "derive me" - and `TankRoleResolver` works the real role out
  /// from the gas and the segments each time it is needed. A saved cylinder
  /// has no plan around it to derive from, so it has to carry the resolved
  /// role or every bottle saved from here would read back as back gas.
  Future<void> _saveTank(
    BuildContext context,
    WidgetRef ref,
    DiveTank tank,
  ) async {
    final l10n = context.l10n;
    final name = await showPlanNameDialog(
      context,
      initialName: tank.name ?? tank.gasMix.name,
      title: l10n.divePlanner_savedTanks_saveTitle,
      fieldLabel: l10n.divePlanner_savedTanks_nameField,
    );
    if (name == null || !context.mounted) return;

    try {
      final repository = ref.read(cylinderConfigRepositoryProvider);
      final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
      final folderName = l10n.divePlanner_savedTanks_title;

      final existing = (await repository.getAllConfigs(
        diverId: diverId,
        includeItems: true,
      )).where((c) => c.equipmentId == null && c.name == folderName);
      final folder = existing.isEmpty ? null : existing.first;
      final configId =
          folder?.id ??
          await repository.createConfig(diverId: diverId, name: folderName);

      final roles = const TankRoleResolver().rolesFor(
        divePlanFromState(ref.read(divePlanNotifierProvider)),
      );
      final captured = const TankConfigCapture().fromTanks(
        tanks: [tank.copyWith(name: name, role: roles[tank.id] ?? tank.role)],
        configId: configId,
        // The repository mints ids for empty ones.
        newId: (_) => '',
      );
      await repository.saveItems(configId, [...?folder?.items, ...captured]);
      if (!context.mounted) return;
      invalidateCylinderConfigs(ref, configId: configId);
      ref.read(savedTanksExpandedProvider.notifier).state = true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.divePlanner_savedTanks_saved)),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }
}

/// A text-button look for the save menu, so it sits level with Manage.
class _MenuLabel extends StatelessWidget {
  const _MenuLabel({
    required this.icon,
    required this.text,
    required this.enabled,
  });

  final IconData icon;
  final String text;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(text, style: theme.textTheme.labelLarge?.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _SavedTankChip extends StatelessWidget {
  const _SavedTankChip({
    required this.item,
    required this.units,
    required this.onPick,
  });

  final CylinderConfigItem item;
  final UnitFormatter units;
  final ValueChanged<CylinderConfigItem> onPick;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gas = GasMix(o2: item.o2Percent, he: item.hePercent);
    final size = units.formatTankVolume(item.volumeL, item.workingPressureBar);
    return ActionChip(
      avatar: const Icon(Icons.add, size: 16),
      label: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(item.label ?? gas.name),
          Text('${gas.name} • $size', style: theme.textTheme.bodySmall),
        ],
      ),
      onPressed: () => onPick(item),
    );
  }
}
