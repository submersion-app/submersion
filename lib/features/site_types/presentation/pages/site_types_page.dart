import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/features/site_types/presentation/providers/site_type_providers.dart';
import 'package:submersion/features/site_types/presentation/site_type_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Settings > Manage Data > Site Types (issue #1765): the built-in types,
/// read-only, and the diver's custom types with inline edit and delete. Uses
/// the Manage-page shape shared with Dive Roles and Dive Types: a lower-right
/// extended FAB to add, two icon actions per editable row.
class SiteTypesPage extends ConsumerWidget {
  const SiteTypesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final typesAsync = ref.watch(siteTypeListNotifierProvider);
    final stats = ref.watch(siteTypeStatisticsProvider).value ?? const [];
    final siteCounts = {for (final s in stats) s.siteType.id: s.siteCount};

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.pop()),
        title: Text(l10n.siteTypes_title),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNameDialog(context, ref),
        tooltip: l10n.siteTypes_addTooltip,
        icon: const Icon(Icons.add),
        label: Text(l10n.siteTypes_addTooltip),
      ),
      body: typesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (types) {
          final custom = types.where((t) => !t.isBuiltIn).toList();
          final builtIn = types.where((t) => t.isBuiltIn).toList();
          return ListView(
            // Room for the FAB over the last row.
            padding: const EdgeInsets.only(bottom: 88),
            children: [
              if (custom.isNotEmpty) ...[
                _header(context, l10n.siteTypes_custom),
                for (final type in custom)
                  _tile(context, ref, type, siteCounts[type.id] ?? 0),
                const Divider(),
              ],
              _header(context, l10n.siteTypes_builtIn),
              for (final type in builtIn)
                _tile(context, ref, type, siteCounts[type.id] ?? 0),
            ],
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
    child: Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: Theme.of(context).colorScheme.primary,
      ),
    ),
  );

  Widget _tile(
    BuildContext context,
    WidgetRef ref,
    SiteTypeEntity type,
    int siteCount,
  ) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(
        type.isBuiltIn ? Icons.category : Icons.category_outlined,
        color: type.isBuiltIn ? colorScheme.primary : colorScheme.secondary,
      ),
      title: Text(type.localizedName(l10n)),
      subtitle: Text(l10n.siteTypes_siteCount(siteCount)),
      trailing: type.isBuiltIn
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: l10n.siteTypes_editTooltip,
                  onPressed: () =>
                      _showNameDialog(context, ref, existing: type),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.siteTypes_deleteTooltip,
                  onPressed: () =>
                      _confirmDelete(context, ref, type, siteCount),
                ),
              ],
            ),
    );
  }

  Future<void> _showNameDialog(
    BuildContext context,
    WidgetRef ref, {
    SiteTypeEntity? existing,
  }) async {
    final l10n = context.l10n;
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _SiteTypeNameDialog(existing: existing),
    );
    if (name == null || !context.mounted) return;
    final notifier = ref.read(siteTypeListNotifierProvider.notifier);
    try {
      if (existing == null) {
        await notifier.addSiteTypeByName(name);
      } else {
        await notifier.updateSiteType(existing.copyWith(name: name));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.siteTypes_snackbar_error('$e')),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    SiteTypeEntity type,
    int siteCount,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final l10n = dialogContext.l10n;
        return AlertDialog(
          title: Text(l10n.siteTypes_deleteDialog_title),
          content: Text(
            siteCount > 0
                ? l10n.siteTypes_deleteDialog_inUse(siteCount, type.name)
                : l10n.siteTypes_deleteDialog_content(type.name),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(l10n.common_action_cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              child: Text(l10n.common_action_delete),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;
    await ref
        .read(siteTypeListNotifierProvider.notifier)
        .deleteSiteType(type.id);
  }
}

/// Name entry for adding or renaming a custom site type. Owns its text
/// controller so it is disposed with the dialog.
class _SiteTypeNameDialog extends StatefulWidget {
  const _SiteTypeNameDialog({this.existing});

  final SiteTypeEntity? existing;

  @override
  State<_SiteTypeNameDialog> createState() => _SiteTypeNameDialogState();
}

class _SiteTypeNameDialogState extends State<_SiteTypeNameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(_controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isNew = widget.existing == null;
    return AlertDialog(
      title: Text(
        isNew
            ? l10n.siteTypes_dialog_addTitle
            : l10n.siteTypes_dialog_editTitle,
      ),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: l10n.siteTypes_dialog_nameLabel,
          ),
          validator: (v) => (v == null || v.trim().isEmpty)
              ? l10n.siteTypes_dialog_nameRequired
              : null,
          onFieldSubmitted: (_) => _submit(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.common_action_cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(isNew ? l10n.common_action_add : l10n.common_action_save),
        ),
      ],
    );
  }
}
