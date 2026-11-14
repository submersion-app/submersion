import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_bar_text_action.dart';

/// The top bar of a record page while it is unlocked: Cancel, what is being
/// edited, and Save.
///
/// It is tinted and underlined in the accent colour so an unlocked page
/// cannot be mistaken for a locked one, and it has no back arrow: the only
/// ways out of a sitting are Cancel and Save.
class RecordEditBar extends StatelessWidget implements PreferredSizeWidget {
  const RecordEditBar({
    super.key,
    required this.title,
    required this.canSave,
    required this.isSaving,
    required this.onCancel,
    required this.onSave,
  });

  final String title;

  /// Whether there is anything to save.
  final bool canSave;

  final bool isSaving;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 4,
      scrolledUnderElevation: 0,
      // Blended to an opaque colour: a translucent tint would pick up
      // whatever scrolls beneath the bar.
      backgroundColor: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.14),
        scheme.surface,
      ),
      shape: Border(bottom: BorderSide(color: scheme.primary, width: 2)),
      // Cancel sits in the title row, not in `leading`, so a long
      // translation takes the width it needs instead of a fixed slot.
      title: Row(
        children: [
          AppBarTextAction(
            label: l10n.forms_cancel,
            onPressed: isSaving ? null : onCancel,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      actions: [
        AppBarTextAction(
          label: l10n.forms_save,
          onPressed: canSave && !isSaving ? onSave : null,
          busy: isSaving,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}
