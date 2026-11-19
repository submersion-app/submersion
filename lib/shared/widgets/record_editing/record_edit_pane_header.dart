import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';

/// The list pane's header row while its record is unlocked (issue #4527):
/// Cancel, what is being edited, the record's menu and Save, as the full
/// page's editing bar has them.
///
/// It is laid over the locked row, which keeps its place beneath it, so the
/// header is the same height locked and unlocked and nothing below moves.
class RecordEditPaneHeader extends StatelessWidget {
  const RecordEditPaneHeader({
    super.key,
    required this.title,
    required this.canSave,
    required this.isSaving,
    required this.isBusy,
    required this.onCancel,
    required this.onSave,
    required this.menu,
    this.saveLabel,
  });

  final String title;

  /// Whether there is anything to save.
  final bool canSave;
  final bool isSaving;

  /// A whole-record operation is running: Cancel and Save wait for it.
  final bool isBusy;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  /// The record's menu, between the title and Save.
  final Widget menu;

  /// The Save button's word where a sitting ends otherwise (a library
  /// reader's Send, issue #4527); Save when null.
  final String? saveLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final waiting = isSaving || isBusy;
    // The same tint and accent rule as the full page's editing bar, so an
    // unlocked pane cannot be mistaken for a locked one.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.14),
          scheme.surface,
        ),
        border: Border(bottom: BorderSide(color: scheme.primary, width: 2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            AppBarTextAction(
              label: l10n.forms_cancel,
              onPressed: waiting ? null : onCancel,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            menu,
            AppBarTextAction(
              label: saveLabel ?? l10n.forms_save,
              onPressed: canSave && !waiting ? onSave : null,
              busy: isSaving,
            ),
          ],
        ),
      ),
    );
  }
}
