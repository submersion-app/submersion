import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Bottom sheet listing templates; tapping one applies it to the trip.
Future<void> showApplyTemplateSheet({
  required BuildContext context,
  required Trip trip,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ApplyTemplateSheet(trip: trip),
  );
}

class _ApplyTemplateSheet extends ConsumerWidget {
  final Trip trip;

  const _ApplyTemplateSheet({required this.trip});

  Future<void> _apply(
    BuildContext context,
    WidgetRef ref,
    String templateId,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final l10n = context.l10n;
    final repository = ref.read(tripChecklistRepositoryProvider);

    // Confirm the append when the trip already has items, showing add/skip
    // counts computed the same way TripChecklistRepository.applyTemplate
    // resolves them: by title plus the trip section a template item's own
    // section title would resolve to (an existing trip section matched
    // case-insensitively, or -- for the count only, nothing is created here
    // -- a placeholder that cannot collide with any existing item's section,
    // mirroring "applyTemplate would create a new section here").
    final existing = await repository.getByTripId(trip.id);
    if (!context.mounted) return;
    if (existing.isNotEmpty) {
      final templateItems = await ref.read(
        checklistTemplateItemsProvider(templateId).future,
      );
      final templateSections = await ref.read(
        checklistTemplateSectionsProvider(templateId).future,
      );
      final templateSectionTitleById = {
        for (final s in templateSections) s.id: s.title,
      };
      final sections = await repository.getSectionsForTrip(trip.id);
      // First match wins, as TripChecklistRepository.matchSectionByTitle
      // resolves it, so two same-titled sections count the way the apply
      // itself will.
      final sectionIdByTitle = <String, String>{};
      for (final s in sections) {
        sectionIdByTitle.putIfAbsent(s.title.toLowerCase(), () => s.id);
      }
      Object? resolveSectionKey(String? sectionId) {
        final title = sectionId == null
            ? null
            : templateSectionTitleById[sectionId];
        final trimmed = title?.trim();
        if (trimmed == null || trimmed.isEmpty) return null;
        final lower = trimmed.toLowerCase();
        return sectionIdByTitle[lower] ?? '__new_section__:$lower';
      }

      final existingKeys = existing.map((i) => (i.title, i.sectionId)).toSet();
      final skipped = templateItems
          .where(
            (i) => existingKeys.contains((
              i.title,
              resolveSectionKey(i.sectionId),
            )),
          )
          .length;
      final added = templateItems.length - skipped;
      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.checklists_applySheet_title),
          content: Text(
            l10n.checklists_applySheet_confirmAppend(added, skipped),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      if (!context.mounted) return;
    }

    try {
      final result = await repository.applyTemplate(
        templateId: templateId,
        trip: trip,
      );
      // The sheet may have been drag-dismissed during applyTemplate; without
      // this guard the pre-captured navigator would pop the underlying route.
      if (!context.mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.checklists_apply_success(result.added)),
          duration: const Duration(seconds: 4),
          showCloseIcon: true,
        ),
      );
    } on StateError {
      if (!context.mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.checklists_apply_templateGone),
          duration: const Duration(seconds: 4),
          showCloseIcon: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(checklistTemplatesProvider);
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.checklists_applySheet_title,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            templatesAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, _) => Text(error.toString()),
              data: (templates) {
                if (templates.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(context.l10n.checklists_applySheet_empty),
                  );
                }
                return Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final template in templates)
                        _TemplateTile(
                          templateId: template.id,
                          name: template.name,
                          onTap: () => _apply(context, ref, template.id),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplateTile extends ConsumerWidget {
  final String templateId;
  final String name;
  final VoidCallback onTap;

  const _TemplateTile({
    required this.templateId,
    required this.name,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(checklistTemplateItemsProvider(templateId));
    final count = itemsAsync.value?.length;
    return ListTile(
      leading: const Icon(Icons.checklist),
      title: Text(name),
      subtitle: count == null
          ? null
          : Text(context.l10n.checklists_applySheet_itemCount(count)),
      onTap: onTap,
    );
  }
}
