import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Summary widget shown when no equipment is selected.
class EquipmentSummaryWidget extends ConsumerWidget {
  const EquipmentSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allEquipmentAsync = ref.watch(allEquipmentProvider);
    final serviceDueAsync = ref.watch(serviceDueEquipmentProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            allEquipmentAsync.when(
              data: (equipment) => _buildOverview(
                context,
                ref,
                equipment,
                serviceDueAsync.value ?? [],
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('${context.l10n.common_label_error}: $e')),
            ),
            const SizedBox(height: 24),
            _buildQuickActions(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.backpack,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              context.l10n.equipment_summary_title,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.equipment_summary_selectPrompt,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildOverview(
    BuildContext context,
    WidgetRef ref,
    List equipment,
    List serviceDue,
  ) {
    // Calculate stats
    int activeCount = 0;
    double totalValue = 0;

    for (final item in equipment) {
      if (item.isActive) {
        activeCount++;
      }
      if (item.purchasePrice != null) {
        totalValue += item.purchasePrice;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.equipment_summary_overviewTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              context,
              icon: Icons.backpack,
              value: '${equipment.length}',
              label: context.l10n.equipment_summary_totalItems,
              color: Colors.blue,
            ),
            _buildStatCard(
              context,
              icon: Icons.check_circle,
              value: '$activeCount',
              label: context.l10n.equipment_summary_active,
              color: Colors.green,
            ),
            if (serviceDue.isNotEmpty)
              _buildStatCard(
                context,
                icon: Icons.build,
                value: '${serviceDue.length}',
                label: context.l10n.equipment_summary_serviceDue,
                color: Colors.red,
              ),
            if (totalValue > 0)
              _buildStatCard(
                context,
                icon: Icons.attach_money,
                value: '\$${totalValue.toStringAsFixed(0)}',
                label: context.l10n.equipment_summary_totalValue,
                color: Colors.orange,
              ),
          ],
        ),
        if (serviceDue.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildServiceDueSection(context, serviceDue),
        ],
        if (equipment.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildEquipmentListPreview(context, equipment),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Semantics(
      label: statLabel(name: label, value: value),
      child: SizedBox(
        width: 120,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceDueSection(BuildContext context, List serviceDue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.warning, size: 20, color: Colors.red),
            const SizedBox(width: 8),
            Text(
              context.l10n.equipment_summary_serviceDueTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: Column(
            children: serviceDue.take(3).map((item) {
              return Semantics(
                button: true,
                label: '${item.name}, ${item.type.displayName}, service due',
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    child: Icon(
                      Icons.build,
                      color: Theme.of(context).colorScheme.onError,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    item.name,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  subtitle: Text(
                    item.type.displayName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  trailing: ExcludeSemantics(
                    child: Icon(
                      Icons.chevron_right,
                      color: Theme.of(context).colorScheme.onErrorContainer,
                    ),
                  ),
                  onTap: () {
                    final state = GoRouterState.of(context);
                    final currentPath = state.uri.path;
                    context.go('$currentPath?selected=${item.id}');
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEquipmentListPreview(BuildContext context, List equipment) {
    final previewItems = equipment.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.equipment_summary_recentEquipmentTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: previewItems.map((item) {
              return Semantics(
                button: true,
                label: '${item.name}, ${item.type.displayName}',
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.tertiaryContainer,
                    child: Icon(
                      Icons.backpack,
                      color: Theme.of(context).colorScheme.onTertiaryContainer,
                    ),
                  ),
                  title: Text(item.name),
                  subtitle: Text(item.type.displayName),
                  trailing: const ExcludeSemantics(
                    child: Icon(Icons.chevron_right),
                  ),
                  onTap: () {
                    final state = GoRouterState.of(context);
                    final currentPath = state.uri.path;
                    context.go('$currentPath?selected=${item.id}');
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.equipment_summary_quickActionsTitle,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () {
                final state = GoRouterState.of(context);
                final currentPath = state.uri.path;
                context.go('$currentPath?mode=new');
              },
              icon: const Icon(Icons.add),
              label: Text(context.l10n.equipment_summary_addEquipmentButton),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/equipment/sets'),
              icon: const Icon(Icons.folder),
              label: Text(context.l10n.equipment_summary_equipmentSetsButton),
            ),
          ],
        ),
      ],
    );
  }
}
