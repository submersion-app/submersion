import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist.dart'
    as domain;
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/checklists/presentation/widgets/apply_template_sheet.dart';
import 'package:submersion/features/checklists/presentation/widgets/checklist_name_dialog.dart';
import 'package:submersion/features/checklists/presentation/widgets/trip_checklist_block.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A trip's checklists (issue #3356): a list of collapsible
/// [TripChecklistBlock]s, one per checklist, with a persistent "add
/// checklist" row always at the bottom. Replaces the old single flat
/// `TripChecklistSection` now that a trip can carry several independently
/// named, independently tracked lists.
///
/// The always-present "add checklist" placeholder shares the same overflow
/// menu every checklist block has, plus one entry of its own: "New
/// checklist...", which prompts for a name and creates an empty checklist
/// (the diver can add sections/items by hand, or save it as a template
/// later through that checklist's own menu). "Apply template..." instead
/// creates a new checklist named after the picked template and applies its
/// items, with no name prompt. Tapping anywhere on the row opens that same
/// menu, anchored at the trailing icon exactly as tapping the icon itself
/// would -- the whole row is one bigger target for the one thing it does.
///
/// Whichever way a checklist was just created, it renders expanded (see
/// [TripChecklistBlock.initiallyExpanded]) so the diver sees its contents,
/// or the empty-state "Add section" prompt, right away; every other
/// checklist still starts collapsed.
class TripChecklistsPanel extends ConsumerStatefulWidget {
  final Trip trip;

  const TripChecklistsPanel({super.key, required this.trip});

  @override
  ConsumerState<TripChecklistsPanel> createState() =>
      _TripChecklistsPanelState();
}

class _TripChecklistsPanelState extends ConsumerState<TripChecklistsPanel> {
  final GlobalKey _addMenuAnchorKey = GlobalKey();
  String? _justCreatedChecklistId;

  @override
  Widget build(BuildContext context) {
    final checklistsAsync = ref.watch(tripChecklistsProvider(widget.trip.id));
    final checklists = checklistsAsync.value;

    if (checklists == null) {
      if (checklistsAsync.hasError) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Text(checklistsAsync.error.toString()),
        );
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (checklists.isEmpty) _buildEmptyState(context),
        for (var i = 0; i < checklists.length; i++)
          TripChecklistBlock(
            key: ValueKey(checklists[i].id),
            trip: widget.trip,
            checklist: checklists[i],
            initiallyExpanded: checklists[i].id == _justCreatedChecklistId,
            onMoveUp: i == 0 ? null : () => _moveChecklist(checklists, i, -1),
            onMoveDown: i == checklists.length - 1
                ? null
                : () => _moveChecklist(checklists, i, 1),
          ),
        _buildAddChecklistPlaceholder(context),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        widget.trip.isUpcoming
            ? context.l10n.checklists_noChecklists_upcoming
            : context.l10n.checklists_noChecklists_past,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// The row that is always present at the end of the list, with the same
  /// "pick a template" overflow menu every checklist block has, plus "New
  /// checklist..." for one with no template behind it. Picking either here
  /// creates a new checklist rather than acting on an existing one.
  Widget _buildAddChecklistPlaceholder(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.add),
        title: Text(context.l10n.checklists_addChecklist),
        trailing: IconButton(
          key: _addMenuAnchorKey,
          icon: const Icon(Icons.more_vert),
          onPressed: () => _showAddChecklistMenu(context),
        ),
        onTap: () => _showAddChecklistMenu(context),
      ),
    );
  }

  /// Opens the same menu whether tapped via the row or the trailing icon,
  /// anchored at the icon's position either way -- the row is one bigger
  /// tap target for that icon's menu, not a second, differently-placed one.
  Future<void> _showAddChecklistMenu(BuildContext context) async {
    final anchorBox =
        _addMenuAnchorKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (anchorBox == null || overlayBox == null) return;

    final topLeft = anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final bottomRight = anchorBox.localToGlobal(
      anchorBox.size.bottomRight(Offset.zero),
      ancestor: overlayBox,
    );
    final l10n = context.l10n;
    final value = await showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(topLeft, bottomRight),
        Offset.zero & overlayBox.size,
      ),
      items: [
        PopupMenuItem(
          value: 'apply',
          child: Text(l10n.checklists_menu_applyTemplate),
        ),
        PopupMenuItem(
          value: 'new',
          child: Text(l10n.checklists_menu_newChecklist),
        ),
      ],
    );
    if (!context.mounted) return;
    switch (value) {
      case 'apply':
        await _addChecklistFromTemplate(context);
      case 'new':
        await _createBlankChecklist(context);
    }
  }

  Future<void> _createBlankChecklist(BuildContext context) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => ChecklistNameDialog(
        title: context.l10n.checklists_newChecklist_title,
      ),
    );
    if (name == null || !context.mounted) return;
    final checklist = await ref
        .read(tripChecklistsRepositoryProvider)
        .createChecklist(tripId: widget.trip.id, name: name);
    if (!mounted) return;
    setState(() => _justCreatedChecklistId = checklist.id);
  }

  Future<void> _addChecklistFromTemplate(BuildContext context) async {
    final templateId = await showTemplatePickerSheet(context: context);
    if (templateId == null || !context.mounted) return;

    final template = await ref.read(
      checklistTemplateProvider(templateId).future,
    );
    if (template == null || !context.mounted) return;

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final checklistsRepository = ref.read(tripChecklistsRepositoryProvider);
    final checklist = await checklistsRepository.createChecklist(
      tripId: widget.trip.id,
      name: template.name,
    );
    try {
      final result = await ref
          .read(tripChecklistRepositoryProvider)
          .applyTemplate(
            templateId: templateId,
            checklistId: checklist.id,
            trip: widget.trip,
          );
      if (!context.mounted) return;
      setState(() => _justCreatedChecklistId = checklist.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.checklists_apply_success(result.added)),
          duration: const Duration(seconds: 4),
          showCloseIcon: true,
        ),
      );
    } on StateError {
      // The template vanished between the read above and here (a
      // concurrent sync, say): drop the checklist this just created rather
      // than leaving an empty, template-named orphan the diver would have
      // to notice and remove by hand.
      await checklistsRepository.deleteChecklist(checklist.id);
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

  Future<void> _moveChecklist(
    List<domain.TripChecklist> checklists,
    int index,
    int delta,
  ) async {
    final orderedIds = checklists.map((c) => c.id).toList();
    final moved = orderedIds.removeAt(index);
    orderedIds.insert(index + delta, moved);
    await ref
        .read(tripChecklistsRepositoryProvider)
        .reorderChecklists(widget.trip.id, orderedIds);
  }
}
