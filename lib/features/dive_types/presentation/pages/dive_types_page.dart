import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/providers/dive_type_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

class DiveTypesPage extends ConsumerWidget {
  const DiveTypesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diveTypesAsync = ref.watch(diveTypeListNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.diveTypes_appBar_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: context.l10n.common_action_back,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDiveTypeDialog(context, ref),
        tooltip: context.l10n.diveTypes_addTooltip,
        child: const Icon(Icons.add),
      ),
      body: diveTypesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) =>
            Center(child: Text('${context.l10n.common_label_error}: $e')),
        data: (diveTypes) {
          final builtInTypes = diveTypes.where((t) => t.isBuiltIn).toList();
          final customTypes = diveTypes.where((t) => !t.isBuiltIn).toList();

          return ListView(
            children: [
              if (customTypes.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  context.l10n.diveTypes_customHeader,
                ),
                ...customTypes.map(
                  (type) =>
                      _buildDiveTypeTile(context, ref, type, canDelete: true),
                ),
                const Divider(),
              ],
              _buildSectionHeader(
                context,
                context.l10n.diveTypes_builtInHeader,
              ),
              ...builtInTypes.map(
                (type) =>
                    _buildDiveTypeTile(context, ref, type, canDelete: false),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildDiveTypeTile(
    BuildContext context,
    WidgetRef ref,
    DiveTypeEntity diveType, {
    required bool canDelete,
  }) {
    return ListTile(
      leading: Icon(
        canDelete ? Icons.label_outline : Icons.label,
        color: canDelete
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.primary,
      ),
      title: Text(diveType.name),
      subtitle: canDelete
          ? Text(context.l10n.diveTypes_custom)
          : Text(context.l10n.diveTypes_builtIn),
      trailing: canDelete
          ? IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref, diveType),
              tooltip: context.l10n.diveTypes_deleteTooltip,
            )
          : null,
    );
  }

  Future<void> _showAddDiveTypeDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.diveTypes_addDialog_title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: dialogContext.l10n.diveTypes_addDialog_nameLabel,
              hintText: dialogContext.l10n.diveTypes_addDialog_nameHint,
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return dialogContext.l10n.diveTypes_addDialog_nameValidation;
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(dialogContext.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(nameController.text.trim());
              }
            },
            child: Text(dialogContext.l10n.diveTypes_addDialog_addButton),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final notifier = ref.read(diveTypeListNotifierProvider.notifier);
        await notifier.addDiveTypeByName(result);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.diveTypes_snackbar_added(result)),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.diveTypes_snackbar_errorAdding(e.toString()),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    DiveTypeEntity diveType,
  ) async {
    // Check if dive type is in use
    final notifier = ref.read(diveTypeListNotifierProvider.notifier);
    final inUse = await notifier.isDiveTypeInUse(diveType.id);

    if (!context.mounted) return;

    if (inUse) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.diveTypes_snackbar_cannotDelete(diveType.name),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.diveTypes_deleteDialog_title),
        content: Text(
          dialogContext.l10n.diveTypes_deleteDialog_content(diveType.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            child: Text(dialogContext.l10n.common_action_delete),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await notifier.deleteDiveType(diveType.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.diveTypes_snackbar_deleted(diveType.name),
              ),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.diveTypes_snackbar_errorDeleting(e.toString()),
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}
