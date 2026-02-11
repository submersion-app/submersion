import 'package:flutter/material.dart';
import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';

class EquipmentSetListPage extends ConsumerWidget {
  const EquipmentSetListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setsAsync = ref.watch(equipmentSetListNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.equipment_sets_appBar_title)),
      body: setsAsync.when(
        data: (sets) => sets.isEmpty
            ? _buildEmptyState(context)
            : _buildSetsList(context, sets),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(context.l10n.equipment_sets_errorLoading('$error')),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref
                    .read(equipmentSetListNotifierProvider.notifier)
                    .refresh(),
                child: Text(context.l10n.equipment_sets_retryButton),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/equipment/sets/new'),
        tooltip: context.l10n.equipment_sets_fabTooltip,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.equipment_sets_fab_createSet),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.folder_outlined,
                size: 80,
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.equipment_sets_emptyState_title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.equipment_sets_emptyState_description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/equipment/sets/new'),
              icon: const Icon(Icons.add),
              label: Text(
                context.l10n.equipment_sets_emptyState_createFirstButton,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSetsList(BuildContext context, List<EquipmentSet> sets) {
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: sets.length,
      itemBuilder: (context, index) {
        final set = sets[index];
        final itemCountText = set.itemCount == 1
            ? context.l10n.equipment_sets_itemCountSingular(set.itemCount)
            : context.l10n.equipment_sets_itemCountPlural(set.itemCount);
        return Semantics(
          label: listItemLabel(
            title: set.name,
            subtitle: set.description.isNotEmpty
                ? set.description
                : itemCountText,
          ),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              onTap: () => context.push('/equipment/sets/${set.id}'),
              leading: CircleAvatar(
                backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                child: Icon(
                  Icons.folder,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              title: Text(set.name),
              subtitle: Text(
                set.description.isNotEmpty ? set.description : itemCountText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: set.itemCount > 0
                  ? Semantics(
                      label: context.l10n.equipment_sets_itemCountSemanticLabel(
                        '${set.itemCount}',
                      ),
                      child: Chip(
                        label: Text('${set.itemCount}'),
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}
