import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/dive_roles/presentation/dive_role_display.dart';
import 'package:submersion/features/dive_roles/presentation/providers/dive_role_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings page managing the per-dive role vocabulary (#551): built-in
/// roles are listed read-only; custom roles can be added, renamed, and
/// deleted (delete is blocked while any dive references the role).
class DiveRolesPage extends ConsumerWidget {
  const DiveRolesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diveRolesAsync = ref.watch(diveRoleListNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.diveRoles_appBar_title),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
          tooltip: context.l10n.common_action_back,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDiveRoleDialog(context, ref),
        tooltip: context.l10n.diveRoles_addTooltip,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.diveRoles_addTooltip),
      ),
      body: diveRolesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) =>
            Center(child: Text('${context.l10n.common_label_error}: $e')),
        data: (diveRoles) {
          final builtInRoles = diveRoles.where((r) => r.isBuiltIn).toList();
          final customRoles = diveRoles.where((r) => !r.isBuiltIn).toList();

          return ListView(
            children: [
              if (customRoles.isNotEmpty) ...[
                _buildSectionHeader(
                  context,
                  context.l10n.diveRoles_customHeader,
                ),
                ...customRoles.map(
                  (role) =>
                      _buildDiveRoleTile(context, ref, role, canEdit: true),
                ),
                const Divider(),
              ],
              _buildSectionHeader(
                context,
                context.l10n.diveRoles_builtInHeader,
              ),
              ...builtInRoles.map(
                (role) =>
                    _buildDiveRoleTile(context, ref, role, canEdit: false),
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

  Widget _buildDiveRoleTile(
    BuildContext context,
    WidgetRef ref,
    DiveRole role, {
    required bool canEdit,
  }) {
    return ListTile(
      leading: Icon(
        canEdit ? Icons.group_outlined : Icons.groups,
        color: canEdit
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.primary,
      ),
      title: Text(role.localizedName(context.l10n)),
      trailing: canEdit
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => _showRenameDialog(context, ref, role),
                  tooltip: context.l10n.diveRoles_renameTooltip,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _confirmDelete(context, ref, role),
                  tooltip: context.l10n.diveRoles_deleteTooltip,
                ),
              ],
            )
          : null,
    );
  }

  Future<void> _showAddDiveRoleDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final result = await _showNameDialog(
      context,
      title: context.l10n.diveRoles_addDialog_title,
      confirmLabel: context.l10n.diveRoles_addDialog_addButton,
    );
    if (result == null || result.isEmpty) return;

    try {
      final notifier = ref.read(diveRoleListNotifierProvider.notifier);
      await notifier.addDiveRoleByName(result);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveRoles_snackbar_added(result)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.diveRoles_snackbar_errorAdding(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    DiveRole role,
  ) async {
    final result = await _showNameDialog(
      context,
      title: context.l10n.diveRoles_renameDialog_title,
      confirmLabel: context.l10n.common_action_save,
      initialValue: role.name,
    );
    if (result == null || result.isEmpty || result == role.name) return;

    try {
      await ref
          .read(diveRoleListNotifierProvider.notifier)
          .renameDiveRole(role.id, result);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.l10n.common_label_error}: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<String?> _showNameDialog(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String? initialValue,
  }) {
    final nameController = TextEditingController(text: initialValue);
    final formKey = GlobalKey<FormState>();

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: nameController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: dialogContext.l10n.diveRoles_addDialog_nameLabel,
              hintText: dialogContext.l10n.diveRoles_addDialog_nameHint,
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return dialogContext.l10n.diveRoles_addDialog_nameValidation;
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
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    DiveRole role,
  ) async {
    // Deleting a role that any dive still references would orphan those
    // rows, so it is blocked outright rather than cascaded.
    final notifier = ref.read(diveRoleListNotifierProvider.notifier);
    final inUse = await notifier.isDiveRoleInUse(role.id);

    if (!context.mounted) return;

    if (inUse) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.diveRoles_snackbar_cannotDelete(role.name),
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.diveRoles_deleteDialog_title),
        content: Text(
          dialogContext.l10n.diveRoles_deleteDialog_content(role.name),
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
        await notifier.deleteDiveRole(role.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.diveRoles_snackbar_deleted(role.name)),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${context.l10n.common_label_error}: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      }
    }
  }
}
