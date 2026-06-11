import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/forms/form_style.dart';

/// Shared shell for every edit form.
///
/// Full-page mode: Scaffold + AppBar with a Save action.
/// Embedded mode (master-detail): compact header with icon, title,
/// Cancel and Save - replaces the per-page hand-rolled headers.
/// Both modes: PopScope unsaved-changes guard and max-width centering.
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

  Future<void> _handlePop(BuildContext context, bool didPop) async {
    if (didPop) return;
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
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
    if (discard == true) navigator.pop();
  }

  Widget _saveButton(BuildContext context, {required bool filled}) {
    if (isSaving) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final label = Text(context.l10n.forms_save);
    return filled
        ? FilledButton(onPressed: onSave, child: label)
        : TextButton(onPressed: onSave, child: label);
  }

  Widget _constrained(Widget body) => Center(
    child: ConstrainedBox(
      key: const Key('editFormMaxWidth'),
      constraints: const BoxConstraints(maxWidth: FormStyle.maxContentWidth),
      child: body,
    ),
  );

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
                    onPressed: onCancel,
                    child: Text(context.l10n.forms_cancel),
                  ),
                const SizedBox(width: 8),
                _saveButton(context, filled: true),
              ],
            ),
          ),
          Expanded(child: _constrained(child)),
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
        body: _constrained(child),
      ),
    );
  }
}
