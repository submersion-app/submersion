import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist.dart'
    as domain;
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/checklists/presentation/widgets/apply_template_sheet.dart';
import 'package:submersion/features/checklists/presentation/widgets/checklist_name_dialog.dart';
import 'package:submersion/features/checklists/presentation/widgets/checklist_snack_bar.dart';
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
/// menu: the whole row is one bigger target for the one thing it does.
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

class _TripChecklistsPanelState extends ConsumerState<TripChecklistsPanel>
    with AutomaticKeepAliveClientMixin {
  final _addMenuKey = GlobalKey<PopupMenuButtonState<String>>();
  Set<String> _justCreatedChecklistIds = const {};

  // TabBarView disposes a tab it moves away from, which would collapse every
  // block on the way back. Not a PageStorageKey on the tiles: a TextField
  // inside one would read the tile's stored bool as its scroll offset.
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
            // A tile reads initiallyExpanded only when it is first built, and
            // the new row usually reaches this list before the write that
            // made it returns. Keying on the flag rebuilds that one block
            // when it flips, so it opens whichever came first.
            key: ValueKey((
              checklists[i].id,
              _justCreatedChecklistIds.contains(checklists[i].id),
            )),
            trip: widget.trip,
            checklist: checklists[i],
            initiallyExpanded: _justCreatedChecklistIds.contains(
              checklists[i].id,
            ),
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
        trailing: PopupMenuButton<String>(
          key: _addMenuKey,
          onSelected: (value) {
            switch (value) {
              case 'apply':
                _addChecklistFromTemplate();
              case 'new':
                _createBlankChecklist();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'apply',
              child: Text(context.l10n.checklists_menu_applyTemplate),
            ),
            PopupMenuItem(
              value: 'new',
              child: Text(context.l10n.checklists_menu_newChecklist),
            ),
          ],
        ),
        onTap: () => _addMenuKey.currentState?.showButtonMenu(),
      ),
    );
  }

  void _markJustCreated(String checklistId) {
    setState(
      () =>
          _justCreatedChecklistIds = {..._justCreatedChecklistIds, checklistId},
    );
  }

  Future<void> _createBlankChecklist() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => ChecklistNameDialog(
        title: context.l10n.checklists_newChecklist_title,
      ),
    );
    if (name == null || !mounted) return;
    final checklist = await ref
        .read(tripChecklistsRepositoryProvider)
        .createChecklist(tripId: widget.trip.id, name: name);
    if (!mounted) return;
    _markJustCreated(checklist.id);
  }

  Future<void> _addChecklistFromTemplate() async {
    final templateId = await showTemplatePickerSheet(context: context);
    if (templateId == null || !mounted) return;

    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    final template = await ref.read(
      checklistTemplateProvider(templateId).future,
    );
    if (!mounted) return;
    if (template == null) {
      showChecklistSnackBar(messenger, l10n.checklists_apply_templateGone);
      return;
    }

    // Both read up front: ref is unusable once the panel unmounts, and the
    // create and apply below must finish together even if the diver leaves.
    final checklistsRepository = ref.read(tripChecklistsRepositoryProvider);
    final itemsRepository = ref.read(tripChecklistRepositoryProvider);
    final checklist = await checklistsRepository.createChecklist(
      tripId: widget.trip.id,
      name: template.name,
    );
    final ({int added, int skipped}) result;
    try {
      result = await itemsRepository.applyTemplate(
        templateId: templateId,
        checklistId: checklist.id,
        trip: widget.trip,
      );
    } catch (e) {
      // Nothing was applied, so drop the checklist this just created rather
      // than leaving an empty, template-named orphan the diver would have to
      // notice and remove by hand.
      await checklistsRepository.deleteChecklist(checklist.id);
      if (!mounted) return;
      // A StateError means the template vanished between the read above and
      // here (a concurrent sync, say). The repository has logged anything
      // else.
      showChecklistSnackBar(
        messenger,
        e is StateError
            ? l10n.checklists_apply_templateGone
            : l10n.common_error_tryAgain,
      );
      return;
    }
    if (!mounted) return;
    _markJustCreated(checklist.id);
    showChecklistSnackBar(
      messenger,
      l10n.checklists_apply_success(result.added),
    );
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
