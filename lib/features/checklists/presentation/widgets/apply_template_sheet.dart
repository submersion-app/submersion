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
    // counts computed with the same title+category key the repository uses.
    final existing = await repository.getByTripId(trip.id);
    if (!context.mounted) return;
    if (existing.isNotEmpty) {
      final templateItems = await ref.read(
        checklistTemplateItemsProvider(templateId).future,
      );
      final existingKeys = existing.map((i) => (i.title, i.category)).toSet();
      final skipped = templateItems
          .where((i) => existingKeys.contains((i.title, i.category)))
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
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.checklists_apply_success(result.added)),
          duration: const Duration(seconds: 4),
          showCloseIcon: true,
        ),
      );
    } on StateError {
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
