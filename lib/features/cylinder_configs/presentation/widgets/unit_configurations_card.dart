import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/cylinder_configs/presentation/providers/cylinder_config_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The configurations belonging to one rebreather, shown on its detail page.
///
/// Answers the issue's "configurations for each CCR" phrasing by making them
/// reachable from the unit, even though the underlying entity is generic.
class UnitConfigurationsCard extends ConsumerWidget {
  const UnitConfigurationsCard({super.key, required this.equipmentId});

  final String equipmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final configsAsync = ref.watch(
      cylinderConfigsForEquipmentProvider(equipmentId),
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.propane_tank_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  l10n.cylinderConfigs_sectionTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => context.push(
                    '/equipment/cylinder-configs/new'
                    '?equipmentId=$equipmentId',
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.cylinderConfigs_new),
                ),
              ],
            ),
            const Divider(),
            configsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => Text('$error'),
              data: (configs) {
                if (configs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      l10n.cylinderConfigs_emptyBody,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    for (final config in configs)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(config.name),
                        subtitle: Text(
                          config.items
                              .map((i) => i.tankRole.displayName)
                              .join(', '),
                        ),
                        trailing: Text('${config.cylinderCount}'),
                        onTap: () => context.push(
                          '/equipment/cylinder-configs/${config.id}',
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
