import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_log/presentation/widgets/dive_type_badge.dart';
import 'package:submersion/features/dive_types/domain/entities/dive_type_entity.dart';
import 'package:submersion/features/dive_types/presentation/dive_type_display.dart';
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddDiveTypeDialog(context, ref),
        tooltip: context.l10n.diveTypes_addTooltip,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.diveTypes_addTooltip),
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
    // Previewed here so a diver knows what a header badge collapses their
    // selection to: the fixed translated abbreviation for a built-in type
    // (see builtInDiveTypeShortName), or the diver's own short name for a
    // custom one. Hidden when there's nothing to preview -- no short name
    // set, or (for a built-in) identical to the full name (e.g. English
    // "Wreck").
    final fullName = diveType.localizedName(context.l10n);
    final builtInShort = canDelete
        ? null
        : builtInDiveTypeShortName(context.l10n, diveType.id);
    final customShort = canDelete ? diveType.shortName?.trim() : null;
    final shortName = canDelete
        ? (customShort?.isNotEmpty == true ? customShort : null)
        : (builtInShort == fullName ? null : builtInShort);

    return ListTile(
      leading: Icon(
        canDelete ? Icons.label_outline : Icons.label,
        color: canDelete
            ? Theme.of(context).colorScheme.secondary
            : Theme.of(context).colorScheme.primary,
      ),
      title: Text(fullName),
      subtitle: Text(
        canDelete
            ? context.l10n.diveTypes_custom
            : context.l10n.diveTypes_builtIn,
      ),
      onTap: () => _showEditDiveTypeDialog(context, ref, diveType),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shortName != null) ...[
            DiveTypeBadge(label: shortName),
            if (canDelete) const SizedBox(width: 8),
          ],
          if (canDelete)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _confirmDelete(context, ref, diveType),
              tooltip: context.l10n.diveTypes_deleteTooltip,
            ),
        ],
      ),
    );
  }

  Future<void> _showAddDiveTypeDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final nameController = TextEditingController();
    final shortNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<({String name, String? shortName})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.diveTypes_addDialog_title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: dialogContext.l10n.diveTypes_addDialog_nameLabel,
                  hintText: dialogContext.l10n.diveTypes_addDialog_nameHint,
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return dialogContext
                        .l10n
                        .diveTypes_addDialog_nameValidation;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: shortNameController,
                decoration: InputDecoration(
                  labelText:
                      dialogContext.l10n.diveTypes_addDialog_shortNameLabel,
                  hintText:
                      dialogContext.l10n.diveTypes_addDialog_shortNameHint,
                  helperText:
                      dialogContext.l10n.diveTypes_addDialog_shortNameHelper,
                  helperMaxLines: 2,
                ),
                textCapitalization: TextCapitalization.words,
              ),
            ],
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
                Navigator.of(dialogContext).pop((
                  name: nameController.text.trim(),
                  shortName: shortNameController.text.trim().isEmpty
                      ? null
                      : shortNameController.text.trim(),
                ));
              }
            },
            child: Text(dialogContext.l10n.diveTypes_addDialog_addButton),
          ),
        ],
      ),
    );

    if (result != null && result.name.isNotEmpty) {
      try {
        final notifier = ref.read(diveTypeListNotifierProvider.notifier);
        await notifier.addDiveTypeByName(
          result.name,
          shortName: result.shortName,
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.diveTypes_snackbar_added(result.name)),
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

  /// Edit an existing dive type: name and short name for custom types (the
  /// name field is disabled for built-ins, whose protected core definition
  /// updateDiveType refuses to touch), plus the two badge-row visibility
  /// checkboxes, which are editable on every type regardless of isBuiltIn --
  /// visibility is a per-diver display preference, not part of that
  /// protected definition.
  Future<void> _showEditDiveTypeDialog(
    BuildContext context,
    WidgetRef ref,
    DiveTypeEntity diveType,
  ) async {
    final canEditName = !diveType.isBuiltIn;
    // Built-in names are disabled for editing, so show the localized name
    // (matching the list tile) rather than the seeded English DB value --
    // otherwise a German-locale diver would see "Wreck" instead of
    // "Wracktauchen" in a field they can't even change.
    final nameController = TextEditingController(
      text: canEditName ? diveType.name : diveType.localizedName(context.l10n),
    );
    final shortNameController = TextEditingController(
      text: diveType.shortName ?? '',
    );
    final formKey = GlobalKey<FormState>();
    var showInDetailHeader = diveType.showInDetailHeader;
    var showInListView = diveType.showInListView;

    final result =
        await showDialog<
          ({
            String name,
            String? shortName,
            bool showInDetailHeader,
            bool showInListView,
          })
        >(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (dialogContext, setState) => AlertDialog(
              title: Text(dialogContext.l10n.diveTypes_editDialog_title),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: nameController,
                      enabled: canEditName,
                      autofocus: canEditName,
                      decoration: InputDecoration(
                        labelText:
                            dialogContext.l10n.diveTypes_addDialog_nameLabel,
                        helperText: canEditName
                            ? null
                            : dialogContext
                                  .l10n
                                  .diveTypes_editDialog_builtInNameHelper,
                        helperMaxLines: 2,
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: canEditName
                          ? (value) {
                              if (value == null || value.trim().isEmpty) {
                                return dialogContext
                                    .l10n
                                    .diveTypes_addDialog_nameValidation;
                              }
                              return null;
                            }
                          : null,
                    ),
                    if (canEditName) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: shortNameController,
                        decoration: InputDecoration(
                          labelText: dialogContext
                              .l10n
                              .diveTypes_addDialog_shortNameLabel,
                          hintText: dialogContext
                              .l10n
                              .diveTypes_addDialog_shortNameHint,
                          helperText: dialogContext
                              .l10n
                              .diveTypes_addDialog_shortNameHelper,
                          helperMaxLines: 2,
                        ),
                        textCapitalization: TextCapitalization.words,
                      ),
                    ],
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: showInDetailHeader,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        dialogContext.l10n.diveTypes_showInHeaderLabel,
                      ),
                      subtitle: Text(
                        dialogContext.l10n.diveTypes_showInHeaderTooltip,
                      ),
                      onChanged: (value) =>
                          setState(() => showInDetailHeader = value ?? true),
                    ),
                    CheckboxListTile(
                      value: showInListView,
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      title: Text(dialogContext.l10n.diveTypes_showInListLabel),
                      subtitle: Text(
                        dialogContext.l10n.diveTypes_showInListTooltip,
                      ),
                      onChanged: (value) =>
                          setState(() => showInListView = value ?? true),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(dialogContext.l10n.common_action_cancel),
                ),
                FilledButton(
                  onPressed: () {
                    if (!canEditName || formKey.currentState!.validate()) {
                      Navigator.of(dialogContext).pop((
                        name: nameController.text.trim(),
                        shortName: shortNameController.text.trim().isEmpty
                            ? null
                            : shortNameController.text.trim(),
                        showInDetailHeader: showInDetailHeader,
                        showInListView: showInListView,
                      ));
                    }
                  },
                  child: Text(
                    dialogContext.l10n.diveTypes_editDialog_saveButton,
                  ),
                ),
              ],
            ),
          ),
        );

    if (result == null) return;

    try {
      final notifier = ref.read(diveTypeListNotifierProvider.notifier);
      if (canEditName) {
        await notifier.updateDiveType(
          diveType.copyWith(
            name: result.name,
            shortName: result.shortName,
            showInDetailHeader: result.showInDetailHeader,
            showInListView: result.showInListView,
          ),
        );
      } else {
        await notifier.setDiveTypeVisibility(
          diveType.id,
          showInDetailHeader: result.showInDetailHeader,
          showInListView: result.showInListView,
        );
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.diveTypes_snackbar_updated(result.name)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.diveTypes_snackbar_errorUpdating(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
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
