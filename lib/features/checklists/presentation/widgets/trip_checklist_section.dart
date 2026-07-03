import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/checklists/presentation/widgets/apply_template_sheet.dart';
import 'package:submersion/features/checklists/presentation/widgets/checklist_item_edit_sheet.dart';
import 'package:submersion/features/checklists/presentation/widgets/checklist_item_tile.dart';
import 'package:submersion/features/checklists/presentation/widgets/save_as_template_dialog.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Full checklist UI for a trip: items grouped by category, add-item
/// affordance, and an overflow menu with apply/save-as-template actions.
/// Embedded both as the Checklist tab (liveaboards) and as a card section
/// on the overview (simple trips).
class TripChecklistSection extends ConsumerWidget {
  final Trip trip;

  const TripChecklistSection({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(tripChecklistProvider(trip.id));

    // Render from AsyncValue.value so reloads do not flash a spinner
    // (established pattern - see project memory on AsyncValue flicker).
    final items = itemsAsync.value;
    if (items == null) {
      if (itemsAsync.hasError) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Text(itemsAsync.error.toString()),
        );
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final categorySuggestions = items
        .map((i) => i.category)
        .whereType<String>()
        .toSet()
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, ref, items),
        if (items.isEmpty)
          _buildEmptyState(context)
        else
          ..._buildGroupedItems(context, ref, items, categorySuggestions),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(context.l10n.checklists_addItem),
            onPressed: () => showChecklistItemEditSheet(
              context: context,
              tripId: trip.id,
              categorySuggestions: categorySuggestions,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    List<TripChecklistItem> items,
  ) {
    final theme = Theme.of(context);
    final done = items.where((i) => i.isDone).length;
    return Row(
      children: [
        Expanded(
          child: Text(
            context.l10n.checklists_section_title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        if (items.isNotEmpty)
          Flexible(
            child: Text(
              context.l10n.checklists_progress(done, items.length),
              style: theme.textTheme.labelMedium,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        _buildOverflowMenu(context, ref, items),
      ],
    );
  }

  Widget _buildOverflowMenu(
    BuildContext context,
    WidgetRef ref,
    List<TripChecklistItem> items,
  ) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'apply') {
          showApplyTemplateSheet(context: context, trip: trip);
        }
        if (value == 'save') {
          showSaveAsTemplateDialog(context: context, trip: trip);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'apply',
          child: Text(context.l10n.checklists_menu_applyTemplate),
        ),
        PopupMenuItem(
          value: 'save',
          enabled: items.isNotEmpty,
          child: Text(context.l10n.checklists_menu_saveAsTemplate),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        trip.isUpcoming
            ? context.l10n.checklists_empty_upcoming
            : context.l10n.checklists_empty_past,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  List<Widget> _buildGroupedItems(
    BuildContext context,
    WidgetRef ref,
    List<TripChecklistItem> items,
    List<String> categorySuggestions,
  ) {
    final theme = Theme.of(context);
    final repository = ref.read(tripChecklistRepositoryProvider);
    // Group by category preserving first-seen order; null category last.
    final grouped = <String?, List<TripChecklistItem>>{};
    for (final item in items.where((i) => i.category != null)) {
      grouped.putIfAbsent(item.category, () => []).add(item);
    }
    final uncategorized = items.where((i) => i.category == null).toList();
    if (uncategorized.isNotEmpty) grouped[null] = uncategorized;

    final widgets = <Widget>[];
    grouped.forEach((category, groupItems) {
      if (category != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text(
              category,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        );
      }
      for (final item in groupItems) {
        widgets.add(
          ChecklistItemTile(
            item: item,
            showOverdue: trip.isUpcoming,
            onToggle: (value) => repository.toggleDone(item.id, isDone: value),
            onEdit: () => showChecklistItemEditSheet(
              context: context,
              tripId: trip.id,
              item: item,
              categorySuggestions: categorySuggestions,
            ),
            onDelete: () => repository.deleteItem(item.id),
          ),
        );
      }
    });
    return widgets;
  }
}
