import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/accessibility/semantic_helpers.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_set.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_set_providers.dart';

/// Content widget for the equipment set list, used in master-detail layout.
///
/// Displays the list of equipment sets, empty state, or error state.
/// Can be embedded in a Scaffold (via EquipmentSetListPage) or directly
/// in a TabBarView or master-detail layout.
class EquipmentSetListContent extends ConsumerWidget {
  /// Called when an item is tapped. If null, navigates via context.push.
  final void Function(String?)? onItemSelected;

  /// The currently selected set ID, used for highlight in master-detail.
  final String? selectedId;

  /// When false, renders a compact header bar instead of relying on
  /// the parent Scaffold's AppBar.
  final bool showAppBar;

  final Widget? headerExtension;

  const EquipmentSetListContent({
    super.key,
    this.onItemSelected,
    this.selectedId,
    this.showAppBar = true,
    this.headerExtension,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setsAsync = ref.watch(equipmentSetListNotifierProvider);

    final content = setsAsync.when(
      data: (sets) => sets.isEmpty
          ? _buildEmptyState(context)
          : _buildSetsList(context, ref, sets),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(context, ref, error),
    );

    if (!showAppBar) {
      return Column(
        children: [
          _buildCompactAppBar(context),
          ?headerExtension,
          Expanded(child: content),
        ],
      );
    }

    return content;
  }

  Widget _buildCompactAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8, height: 40),
          Text(
            context.l10n.equipment_appBar_title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
        ],
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

  Widget _buildSetsList(
    BuildContext context,
    WidgetRef ref,
    List<EquipmentSet> sets,
  ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(equipmentSetListNotifierProvider.notifier).refresh();
      },
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: sets.length,
        itemBuilder: (context, index) {
          final set = sets[index];
          final isSelected = selectedId == set.id;
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
              color: isSelected
                  ? Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.5)
                  : null,
              child: ListTile(
                onTap: () {
                  if (onItemSelected != null) {
                    onItemSelected!(set.id);
                  } else {
                    context.push('/equipment/sets/${set.id}');
                  }
                },
                leading: CircleAvatar(
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.primaryContainer,
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
                        label: context.l10n
                            .equipment_sets_itemCountSemanticLabel(
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
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(context.l10n.equipment_sets_errorLoading('$error')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () =>
                ref.read(equipmentSetListNotifierProvider.notifier).refresh(),
            child: Text(context.l10n.equipment_sets_retryButton),
          ),
        ],
      ),
    );
  }
}
