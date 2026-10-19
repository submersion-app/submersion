import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_item.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist_section.dart'
    as domain;
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/checklists/presentation/widgets/apply_template_sheet.dart';
import 'package:submersion/features/checklists/presentation/widgets/checklist_item_edit_sheet.dart';
import 'package:submersion/features/checklists/presentation/widgets/checklist_item_tile.dart';
import 'package:submersion/features/checklists/presentation/widgets/save_as_template_dialog.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/section_list_editor.dart';

/// Full checklist UI for a trip: items grouped by category, add-item
/// affordance, and an overflow menu with apply-template, save-as-template
/// and clear-checklist actions. Embedded both as the Checklist tab
/// (liveaboards) and as a card section on the overview (simple trips).
class TripChecklistSection extends ConsumerWidget {
  final Trip trip;

  const TripChecklistSection({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(tripChecklistProvider(trip.id));
    final sectionsAsync = ref.watch(tripChecklistSectionsProvider(trip.id));

    // Render from AsyncValue.value so reloads do not flash a spinner
    // (established pattern - see project memory on AsyncValue flicker).
    final items = itemsAsync.value;
    final sections = sectionsAsync.value;
    if (items == null || sections == null) {
      if (itemsAsync.hasError || sectionsAsync.hasError) {
        final error = itemsAsync.hasError
            ? itemsAsync.error
            : sectionsAsync.error;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Text(error.toString()),
        );
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Folded case-insensitively so two differently-cased section titles
    // don't both show up in the add/edit sheet's suggestions.
    final seenSectionTitles = <String>{};
    final sectionTitles = [
      for (final s in sections)
        if (seenSectionTitles.add(s.title.toLowerCase())) s.title,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context, ref, items),
        // A diver may lay out empty sections before adding any items (the
        // whole point of issue #3360's "create a section empty" case), so
        // the planning invitation is shown alongside the section editor,
        // not instead of it -- otherwise a brand new trip with neither
        // items nor sections would have no way to create that first
        // section at all, since the only "+ Add section" affordance lives
        // inside the editor this would otherwise hide.
        if (items.isEmpty && sections.isEmpty) _buildEmptyState(context),
        _buildGroupedItems(context, ref, items, sections, sectionTitles),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(context.l10n.checklists_addItem),
            onPressed: () => showChecklistItemEditSheet(
              context: context,
              tripId: trip.id,
              categorySuggestions: sectionTitles,
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
        if (value == 'clear') {
          _clearChecklist(context, ref, items.length);
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
        PopupMenuItem(
          value: 'clear',
          enabled: items.isNotEmpty,
          child: Text(context.l10n.checklists_menu_clearAll),
        ),
      ],
    );
  }

  /// Drops the trip's whole checklist after confirming. The count is taken
  /// from the items already on screen so the dialog cannot promise a number
  /// the user never saw; the repository re-reads the rows it deletes and logs
  /// a tombstone per item, so a concurrent edit cannot slip through unsynced.
  Future<void> _clearChecklist(
    BuildContext context,
    WidgetRef ref,
    int count,
  ) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(tripChecklistRepositoryProvider);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.checklists_clear_title),
        content: Text(l10n.checklists_clear_content(count)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.checklists_clear_confirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await repository.clearItems(trip.id);
    // The wipe stands either way, being the user's confirmed intent, but its
    // confirmation belongs to a page that may be gone: the route can be
    // popped while the dialog is open or while the delete is in flight.
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.checklists_clear_success(count)),
        duration: const Duration(seconds: 4),
        showCloseIcon: true,
      ),
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

  Widget _buildGroupedItems(
    BuildContext context,
    WidgetRef ref,
    List<TripChecklistItem> items,
    List<domain.TripChecklistSection> sections,
    List<String> sectionTitles,
  ) {
    final repository = ref.read(tripChecklistRepositoryProvider);
    final itemsBySection = <String, List<TripChecklistItem>>{
      for (final s in sections) s.id: [],
    };
    final unsectioned = <TripChecklistItem>[];
    for (final item in items) {
      final bucket = item.sectionId == null
          ? null
          : itemsBySection[item.sectionId];
      if (bucket == null) {
        unsectioned.add(item);
      } else {
        bucket.add(item);
      }
    }

    final sectionById = {for (final s in sections) s.id: s};

    Widget buildItem(BuildContext context, TripChecklistItem item) {
      // sectionId is a cross-table reference with no guaranteed arrival
      // order under sync (a section's delete can apply before this item's
      // own update does), so a dangling id must degrade to "no section"
      // rather than throw.
      final sectionTitle = item.sectionId == null
          ? null
          : sectionById[item.sectionId]?.title;
      return ChecklistItemTile(
        item: item,
        showOverdue: trip.isUpcoming,
        onToggle: (value) => repository.toggleDone(item.id, isDone: value),
        onEdit: () => showChecklistItemEditSheet(
          context: context,
          tripId: trip.id,
          item: item,
          categorySuggestions: sectionTitles,
          currentSectionTitle: sectionTitle,
        ),
      );
    }

    return SectionListEditor<TripChecklistItem>(
      sections: [
        for (final s in sections)
          SectionGroup(id: s.id, title: s.title, items: itemsBySection[s.id]!),
      ],
      unsectionedItems: unsectioned,
      itemId: (item) => item.id,
      itemBuilder: buildItem,
      addSectionLabel: context.l10n.sectionEditor_addSection,
      newSectionTitle: context.l10n.sectionEditor_newSectionTitle,
      noSectionLabel: context.l10n.sectionEditor_noSection,
      onAddSection: (title) async {
        await repository.createSection(tripId: trip.id, title: title);
      },
      onRenameSection: (id, title) => repository.renameSection(id, title),
      onReorderSections: (orderedIds) =>
          repository.reorderSections(trip.id, orderedIds),
      onDeleteSection: (id, {moveItemsToSectionId}) => repository.deleteSection(
        id,
        moveItemsToSectionId: moveItemsToSectionId,
      ),
      onMoveItem: (itemId, targetSectionId, orderedIds) => repository.moveItem(
        tripId: trip.id,
        itemId: itemId,
        targetSectionId: targetSectionId,
        orderedIds: orderedIds,
      ),
      onDeleteItem: (item) => repository.deleteItem(item.id),
    );
  }
}
