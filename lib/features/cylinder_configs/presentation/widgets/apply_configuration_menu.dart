import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_configs/domain/entities/cylinder_config.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Lets the diver pick a configuration to merge into the dive's cylinders.
///
/// Renders nothing when the diver has no configurations, so the control never
/// appears as a dead end.
class ApplyConfigurationMenu extends ConsumerWidget {
  const ApplyConfigurationMenu({super.key, required this.onSelected});

  final ValueChanged<CylinderConfig> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final configs = ref.watch(cylinderConfigsProvider).valueOrNull ?? const [];
    if (configs.isEmpty) return const SizedBox.shrink();

    final unitNames = <String, String>{
      for (final item
          in ref.watch(allEquipmentProvider).valueOrNull ?? const [])
        item.id: item.name,
    };

    final owned = <String, List<CylinderConfig>>{};
    final generic = <CylinderConfig>[];
    for (final config in configs) {
      final unitId = config.equipmentId;
      if (unitId == null) {
        generic.add(config);
      } else {
        owned.putIfAbsent(unitId, () => []).add(config);
      }
    }

    return PopupMenuButton<CylinderConfig>(
      tooltip: l10n.cylinderConfigs_applyAction,
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final entry in owned.entries) ...[
          PopupMenuItem<CylinderConfig>(
            enabled: false,
            child: Text(
              unitNames[entry.key] ?? l10n.cylinderConfigs_forUnit,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          for (final config in entry.value)
            PopupMenuItem<CylinderConfig>(
              value: config,
              child: Text(config.name),
            ),
        ],
        if (generic.isNotEmpty) ...[
          PopupMenuItem<CylinderConfig>(
            enabled: false,
            child: Text(
              l10n.cylinderConfigs_gasPlans,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
          for (final config in generic)
            PopupMenuItem<CylinderConfig>(
              value: config,
              child: Text(config.name),
            ),
        ],
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.playlist_add_check, size: 20),
            const SizedBox(width: 8),
            Text(l10n.cylinderConfigs_applyAction),
          ],
        ),
      ),
    );
  }
}
