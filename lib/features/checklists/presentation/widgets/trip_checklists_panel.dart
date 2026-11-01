import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/trip_checklist.dart'
    as domain;
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/checklists/presentation/widgets/apply_template_sheet.dart';
import 'package:submersion/features/checklists/presentation/widgets/trip_checklist_block.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// A trip's checklists (issue #3356): a list of collapsible
/// [TripChecklistBlock]s, one per checklist, with a persistent "add
/// checklist" row always at the bottom. Replaces the old single flat
/// `TripChecklistSection` now that a trip can carry several independently
/// named, independently tracked lists.
///
/// Adding a checklist always goes through a template: the same "pick a
/// template" menu that existed before issue #3356 (as the trip's one and
/// only checklist's overflow menu) is now the row every checklist -- and
/// the always-present "add checklist" placeholder -- shares. Picking a
/// template on the placeholder creates a new checklist named after it and
/// applies its items; there is no separate "type a name" dialog.
class TripChecklistsPanel extends ConsumerWidget {
  final Trip trip;

  const TripChecklistsPanel({super.key, required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checklistsAsync = ref.watch(tripChecklistsProvider(trip.id));
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
            trip: trip,
            checklist: checklists[i],
            onMoveUp: i == 0
                ? null
                : () => _moveChecklist(ref, checklists, i, -1),
            onMoveDown: i == checklists.length - 1
                ? null
                : () => _moveChecklist(ref, checklists, i, 1),
          ),
        _buildAddChecklistPlaceholder(context, ref),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        trip.isUpcoming
            ? context.l10n.checklists_noChecklists_upcoming
            : context.l10n.checklists_noChecklists_past,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  /// The row that is always present at the end of the list, with the same
  /// "pick a template" overflow menu every checklist block has. Picking a
  /// template here creates a new checklist (named after it) rather than
  /// acting on an existing one.
  Widget _buildAddChecklistPlaceholder(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.add),
        title: Text(context.l10n.checklists_addChecklist),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'apply') _addChecklistFromTemplate(context, ref);
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'apply',
              child: Text(context.l10n.checklists_menu_applyTemplate),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addChecklistFromTemplate(
    BuildContext context,
    WidgetRef ref,
  ) async {
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
      tripId: trip.id,
      name: template.name,
    );
    try {
      final result = await ref
          .read(tripChecklistRepositoryProvider)
          .applyTemplate(
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
    WidgetRef ref,
    List<domain.TripChecklist> checklists,
    int index,
    int delta,
  ) async {
    final orderedIds = checklists.map((c) => c.id).toList();
    final moved = orderedIds.removeAt(index);
    orderedIds.insert(index + delta, moved);
    await ref
        .read(tripChecklistsRepositoryProvider)
        .reorderChecklists(trip.id, orderedIds);
  }
}
