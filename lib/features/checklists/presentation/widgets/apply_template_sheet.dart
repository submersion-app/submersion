import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Bottom sheet listing checklist templates; tapping one pops the sheet with
/// that template's id, or null if dismissed without a choice. What
/// "applying" a template means (creating a new checklist from it, or
/// replacing an existing one's content) is entirely up to the caller
/// (issue #3356); this sheet only picks which template.
Future<String?> showTemplatePickerSheet({required BuildContext context}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _TemplatePickerSheet(),
  );
}

class _TemplatePickerSheet extends ConsumerWidget {
  const _TemplatePickerSheet();

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
                          onTap: () => Navigator.of(context).pop(template.id),
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
