import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pre_dive/domain/entities/pre_dive_checklist_template.dart';
import 'package:submersion/features/pre_dive/presentation/providers/pre_dive_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings page listing pre-dive checklist templates: read-only built-ins
/// (clonable) plus fully editable user templates.
class PreDiveTemplatesPage extends ConsumerWidget {
  const PreDiveTemplatesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final templatesAsync = ref.watch(preDiveTemplatesProvider);
    final templates = templatesAsync.value;

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.preDive_templates_title)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/pre-dive-checklists/new'),
        icon: const Icon(Icons.add),
        label: Text(context.l10n.checklists_templates_addTemplate),
      ),
      body: templates == null
          ? Center(
              child: templatesAsync.hasError
                  ? Text(templatesAsync.error.toString())
                  : const CircularProgressIndicator(),
            )
          : templates.isEmpty
          ? Center(child: Text(context.l10n.preDive_templates_empty))
          : ListView.separated(
              itemCount: templates.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) =>
                  _TemplateTile(template: templates[index]),
            ),
    );
  }
}

class _TemplateTile extends ConsumerWidget {
  final PreDiveChecklistTemplate template;

  const _TemplateTile({required this.template});

  Future<void> _clone(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final diverId = await ref.read(validatedCurrentDiverIdProvider.future);
    await ref
        .read(preDiveTemplateRepositoryProvider)
        .cloneTemplate(
          template.id,
          diverId: diverId,
          newName: template.name + l10n.preDive_templates_cloneSuffix,
        );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.preDive_templates_delete),
        content: Text(l10n.preDive_templates_deleteConfirm),
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
          .read(preDiveTemplateRepositoryProvider)
          .deleteTemplate(template.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final subtitleParts = [
      if (template.category != null) template.category!,
      if (template.strictOrder) l10n.preDive_templates_strictOrderBadge,
    ];
    return ListTile(
      leading: Icon(template.isBuiltIn ? Icons.lock_outline : Icons.fact_check),
      title: Text(template.name),
      subtitle: subtitleParts.isEmpty
          ? (template.description.isEmpty ? null : Text(template.description))
          : Text(subtitleParts.join(' - ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (template.isBuiltIn)
            Chip(
              label: Text(l10n.preDive_templates_builtInBadge),
              visualDensity: VisualDensity.compact,
            ),
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'clone':
                  _clone(context, ref);
                case 'delete':
                  _confirmDelete(context, ref);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'clone',
                child: Text(l10n.preDive_templates_clone),
              ),
              if (!template.isBuiltIn)
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l10n.preDive_templates_delete),
                ),
            ],
          ),
        ],
      ),
      onTap: template.isBuiltIn
          ? null
          : () => context.push('/pre-dive-checklists/${template.id}/edit'),
    );
  }
}
