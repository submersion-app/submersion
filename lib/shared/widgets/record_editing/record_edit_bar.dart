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
    this.actions = const [],
    this.isBusy = false,
    this.saveLabel,
  });

  final String title;

  /// Drawn between the title and Save: what the record offers while it is
  /// unlocked, such as the photo viewer's own actions.
  final List<Widget> actions;

  /// Whether there is anything to save.
  final bool canSave;

  final bool isSaving;

  /// Something other than a save is running on the record (a whole-record
  /// operation): Cancel and Save are disabled, with no progress mark.
  final bool isBusy;
  final VoidCallback onCancel;
  final VoidCallback onSave;

  /// The Save button's word where a sitting ends otherwise (a library
  /// reader's Send, issue #4527); Save when null.
  final String? saveLabel;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final style = unlockedRecordBarStyle(Theme.of(context).colorScheme);
    final l10n = context.l10n;
    return AppBar(
      automaticallyImplyLeading: false,
      titleSpacing: 4,
      scrolledUnderElevation: 0,
      backgroundColor: style.background,
      foregroundColor: style.foreground,
      shape: style.shape,
      // Cancel sits in the title row, not in `leading`, so a long
      // translation takes the width it needs instead of a fixed slot.
      title: Row(
        children: [
          AppBarTextAction(
            label: l10n.forms_cancel,
            onPressed: isSaving || isBusy ? null : onCancel,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      actions: [
        ...actions,
        AppBarTextAction(
          label: saveLabel ?? l10n.forms_save,
          onPressed: canSave && !isSaving && !isBusy ? onSave : null,
          busy: isSaving,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

/// How a top bar over an unlocked record page looks, shared by
/// [RecordEditBar] and a satellite page's bar: tinted and underlined in the
/// accent colour, so an unlocked page cannot be mistaken for a locked one.
({Color background, Color foreground, ShapeBorder shape})
unlockedRecordBarStyle(ColorScheme scheme) => (
  // Blended to an opaque colour: a translucent tint would pick up whatever
  // scrolls beneath the bar.
  background: Color.alphaBlend(
    scheme.primary.withValues(alpha: 0.14),
    scheme.surface,
  ),
  // The bar brings its own pale background, so it brings the foreground
  // that reads on it. A theme's app bar foreground is chosen for that
  // theme's app bar colour, which on several presets is light on dark.
  foreground: scheme.onSurface,
  shape: Border(bottom: BorderSide(color: scheme.primary, width: 2)),
);
