import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Shared shell for every edit form.
///
/// Full-page mode: Scaffold + AppBar with a Save action, wrapped in a
/// PopScope unsaved-changes guard.
/// Embedded mode (master-detail): compact header with icon, title, Cancel
/// and Save - replaces the per-page hand-rolled headers. Embedded panes are
/// not routes of their own, so the discard guard runs on the Cancel action
/// instead of a PopScope.
/// Both modes center content at the form max width.
class EditFormScaffold extends StatelessWidget {
  const EditFormScaffold({
    super.key,
    required this.title,
    required this.embedded,
    required this.isSaving,
    required this.hasUnsavedChanges,
    required this.onSave,
    required this.child,
    this.onCancel,
    this.headerIcon,
    this.actions,
  });

  final String title;
  final bool embedded;
  final bool isSaving;
  final bool hasUnsavedChanges;
  final VoidCallback onSave;
  final VoidCallback? onCancel;
  final Widget child;
  final IconData? headerIcon;

  /// Extra actions (e.g. delete) rendered before the save button.
  final List<Widget>? actions;

  Future<bool> _confirmDiscard(BuildContext context) async {
    final l10n = context.l10n;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.forms_discard_title),
        content: Text(l10n.forms_discard_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.forms_discard_keepEditing),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.forms_discard_discard),
          ),
        ],
      ),
    );
    return discard == true;
  }

  Future<void> _handlePop(BuildContext context, bool didPop) async {
    if (didPop) return;
    final navigator = Navigator.of(context);
    final shouldPop = await _confirmDiscard(context);
    // The dialog can outlive this route; don't pop a disposed context.
    if (shouldPop && context.mounted) navigator.pop();
  }

  Future<void> _handleCancel(BuildContext context) async {
    if (hasUnsavedChanges && !await _confirmDiscard(context)) return;
    if (context.mounted) onCancel?.call();
  }

  Widget _saveButton(BuildContext context, {required bool filled}) {
    if (isSaving) {
      return Padding(
        padding: const EdgeInsets.all(12),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: filled ? null : AppBarTheme.of(context).foregroundColor,
          ),
        ),
      );
    }
    final label = Text(context.l10n.forms_save);
    if (filled) {
      return FilledButton(onPressed: onSave, child: label);
    }
    final foreground = AppBarTheme.of(context).foregroundColor;
    return TextButton(
      style: foreground != null
          ? TextButton.styleFrom(foregroundColor: foreground)
          : null,
      onPressed: onSave,
      child: label,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (embedded) {
      final colorScheme = Theme.of(context).colorScheme;
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(headerIcon ?? Icons.edit, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ...?actions,
                if (onCancel != null)
                  TextButton(
                    onPressed: () => _handleCancel(context),
                    child: Text(context.l10n.forms_cancel),
                  ),
                const SizedBox(width: 8),
                _saveButton(context, filled: true),
              ],
            ),
          ),
          Expanded(child: child),
        ],
      );
    }

    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, _) => _handlePop(context, didPop),
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [...?actions, _saveButton(context, filled: false)],
        ),
        body: child,
      ),
    );
  }
}
