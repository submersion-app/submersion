import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/checklists/domain/entities/checklist_template.dart';
import 'package:submersion/features/checklists/presentation/providers/checklist_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings page listing reusable checklist templates.
class ChecklistTemplatesPage extends ConsumerWidget {
  const ChecklistTemplatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(checklistTemplatesProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.checklists_templates_pageTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/checklist-templates/new'),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.checklists_templates_addTemplate),
      ),
      body: templatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(error.toString())),
        data: (templates) {
          if (templates.isEmpty) {
            return Center(child: Text(context.l10n.checklists_templates_empty));
          }
          return ListView.separated(
            itemCount: templates.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) =>
                _TemplateTile(template: templates[index]),
          );
        },
      ),
    );
  }
}

class _TemplateTile extends ConsumerWidget {
  final ChecklistTemplate template;

  const _TemplateTile({required this.template});

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.checklists_templates_deleteTitle),
        content: Text(l10n.checklists_templates_deleteContent(template.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.common_action_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(checklistTemplateRepositoryProvider)
          .deleteTemplate(template.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(checklistTemplateItemsProvider(template.id));
    final count = itemsAsync.value?.length;
    return ListTile(
      leading: const Icon(Icons.checklist),
      title: Text(template.name),
      subtitle: Text(
        count == null
            ? template.description
            : context.l10n.checklists_applySheet_itemCount(count),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () =>
                context.push('/checklist-templates/${template.id}/edit'),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, ref),
          ),
        ],
      ),
      onTap: () => context.push('/checklist-templates/${template.id}/edit'),
    );
  }
}
