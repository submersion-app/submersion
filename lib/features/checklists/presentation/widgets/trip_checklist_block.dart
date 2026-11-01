import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist.dart'
    as domain;
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

/// One collapsible block for one of a trip's checklists (issue #3356): a
/// header with the checklist's name, its own progress bar (shown whether
/// expanded or not), reorder arrows, and an overflow menu (apply/save
/// template, rename, clear, delete), expanding to the familiar
/// sections/items editor scoped to just this checklist.
///
/// Every checklist starts collapsed when a trip is opened -- with several
/// checklists on a trip, nothing is auto-expanded, unlike this widget's
/// single-checklist predecessor.
class TripChecklistBlock extends ConsumerWidget {
  final Trip trip;
  final domain.TripChecklist checklist;

  /// Null when this is the only (or first/last) checklist in its direction,
  /// disabling that arrow.
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  const TripChecklistBlock({
    super.key,
    required this.trip,
    required this.checklist,
    this.onMoveUp,
    this.onMoveDown,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(tripChecklistProvider(checklist.id));
    final sectionsAsync = ref.watch(
      tripChecklistSectionsProvider(checklist.id),
    );

    // Render from AsyncValue.value so reloads do not flash a spinner
    // (established pattern - see project memory on AsyncValue flicker).
    final items = itemsAsync.value;
    final sections = sectionsAsync.value;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text(
          checklist.name,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: items == null || items.isEmpty
            ? null
            : Text(
                context.l10n.checklists_progress(
                  items.where((i) => i.isDone).length,
                  items.length,
                ),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up),
              onPressed: onMoveUp,
              tooltip: WidgetsLocalizations.of(context).reorderItemUp,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down),
              onPressed: onMoveDown,
              tooltip: WidgetsLocalizations.of(context).reorderItemDown,
            ),
            _buildOverflowMenu(context, ref, items ?? const []),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildBody(
              context,
              itemsAsync,
              sectionsAsync,
              ref,
              items,
              sections,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AsyncValue<List<TripChecklistItem>> itemsAsync,
    AsyncValue<List<domain.TripChecklistSection>> sectionsAsync,
    WidgetRef ref,
    List<TripChecklistItem>? items,
    List<domain.TripChecklistSection>? sections,
  ) {
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
        // A diver may lay out empty sections before adding any items (the
        // whole point of issue #3360's "create a section empty" case), so
        // the planning invitation is shown alongside the section editor,
        // not instead of it -- otherwise a brand new checklist with
        // neither items nor sections would have no way to create that
        // first section at all, since the only "+ Add section" affordance
        // lives inside the editor this would otherwise hide.
        if (items.isEmpty && sections.isEmpty) _buildEmptyState(context),
        _buildGroupedItems(context, ref, items, sections, sectionTitles),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(context.l10n.checklists_addItem),
            onPressed: () => showChecklistItemEditSheet(
              context: context,
              checklistId: checklist.id,
              categorySuggestions: sectionTitles,
            ),
          ),
        ),
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
        switch (value) {
          case 'apply':
            _applyTemplate(context, ref);
          case 'save':
            showSaveAsTemplateDialog(
              context: context,
              trip: trip,
              checklistId: checklist.id,
            );
          case 'clear':
            _clearChecklist(context, ref, items.length);
          case 'rename':
            _renameChecklist(context, ref);
          case 'delete':
            _deleteChecklist(context, ref);
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
        PopupMenuItem(
          value: 'rename',
          child: Text(context.l10n.checklists_menu_rename),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Text(context.l10n.checklists_menu_delete),
        ),
      ],
    );
  }

  /// Replaces this checklist's entire content with a chosen template, after
  /// a destructive-replace confirmation (issue #3356): unlike the trip-wide
  /// merge the pre-#3356 single checklist used, picking a template here
  /// never mixes with what the checklist already has -- it wholesale swaps
  /// it, the same way picking a different template for an already-applied
  /// checklist is expected to work.
  Future<void> _applyTemplate(BuildContext context, WidgetRef ref) async {
    final templateId = await showTemplatePickerSheet(context: context);
    if (templateId == null || !context.mounted) return;

    final l10n = context.l10n;
    final template = await ref.read(
      checklistTemplateProvider(templateId).future,
    );
    if (template == null || !context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.checklists_replaceTemplate_title),
        content: Text(
          l10n.checklists_replaceTemplate_content(
            checklist.name,
            template.name,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.checklists_replaceTemplate_confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(tripChecklistRepositoryProvider)
          .replaceWithTemplate(
            templateId: templateId,
            checklistId: checklist.id,
            trip: trip,
          );
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.checklists_apply_success(result.added)),
          duration: const Duration(seconds: 4),
          showCloseIcon: true,
        ),
      );
    } on StateError {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.checklists_apply_templateGone),
          duration: const Duration(seconds: 4),
          showCloseIcon: true,
        ),
      );
    }
  }

  /// Drops this checklist's items but keeps its sections, after confirming.
  /// The count is taken from the items already on screen so the dialog
  /// cannot promise a number the user never saw; the repository re-reads
  /// the rows it deletes and logs a tombstone per item, so a concurrent
  /// edit cannot slip through unsynced.
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

    await repository.clearItems(checklist.id);
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

  Future<void> _renameChecklist(BuildContext context, WidgetRef ref) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameChecklistDialog(initialName: checklist.name),
    );
    if (name == null || !context.mounted) return;
    await ref
        .read(tripChecklistsRepositoryProvider)
        .renameChecklist(checklist.id, name);
  }

  Future<void> _deleteChecklist(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.checklists_delete_title),
        content: Text(l10n.checklists_delete_content(checklist.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.checklists_delete_confirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref
        .read(tripChecklistsRepositoryProvider)
        .deleteChecklist(checklist.id);
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
          checklistId: checklist.id,
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
        await repository.createSection(checklistId: checklist.id, title: title);
      },
      onRenameSection: (id, title) => repository.renameSection(id, title),
      onReorderSections: (orderedIds) =>
          repository.reorderSections(checklist.id, orderedIds),
      onDeleteSection: (id, {moveItemsToSectionId}) => repository.deleteSection(
        id,
        moveItemsToSectionId: moveItemsToSectionId,
      ),
      onMoveItem: (itemId, targetSectionId, orderedIds) => repository.moveItem(
        checklistId: checklist.id,
        itemId: itemId,
        targetSectionId: targetSectionId,
        orderedIds: orderedIds,
      ),
      onDeleteItem: (item) => repository.deleteItem(item.id),
    );
  }
}

/// Owns its [TextEditingController] through its own State so disposal
/// happens when the framework actually removes this widget from the tree
/// (after the dialog's exit transition finishes), not right after
/// `showDialog` returns -- disposing eagerly there raced the still-animating
/// `TextFormField` and threw "A TextEditingController was used after being
/// disposed."
class _RenameChecklistDialog extends StatefulWidget {
  final String initialName;

  const _RenameChecklistDialog({required this.initialName});

  @override
  State<_RenameChecklistDialog> createState() => _RenameChecklistDialogState();
}

class _RenameChecklistDialogState extends State<_RenameChecklistDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.checklists_renameChecklist_title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.checklists_nameLabel),
          validator: (value) => (value == null || value.trim().isEmpty)
              ? l10n.checklists_nameRequired
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;
            Navigator.of(context).pop(_controller.text.trim());
          },
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
    );
  }
}
