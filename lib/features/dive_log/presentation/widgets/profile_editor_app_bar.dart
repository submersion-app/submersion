import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The profile editor's app bar: its title, the revision selector, Undo and
/// Save.
///
/// When [compact], the selector takes a row of its own under the title and
/// Save shows as an icon named by its tooltip. Beside the title and the
/// actions, a phone in portrait left the selector no room at all
/// (issue #5056).
class ProfileEditorAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  /// Screens narrower than this get the [compact] layout.
  static const double compactMaxWidth = 600;

  static const double _revisionRowHeight = 44;

  final bool compact;

  /// The revision selector, or null when there is none to show: the editor
  /// is not on the primary source, or the dive has no revision history.
  final Widget? revisionControl;

  /// Null disables the button.
  final VoidCallback? onUndo;

  /// Null disables the button.
  final VoidCallback? onSave;

  const ProfileEditorAppBar({
    super.key,
    required this.compact,
    required this.revisionControl,
    required this.onUndo,
    required this.onSave,
  });

  /// Whether the screen in [context] is narrow enough for [compact].
  static bool isCompact(BuildContext context) =>
      MediaQuery.sizeOf(context).width < compactMaxWidth;

  bool get _revisionRow => compact && revisionControl != null;

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (_revisionRow ? _revisionRowHeight : 0));

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = Text(l10n.diveLog_profileEditor_title);
    final control = revisionControl;
    return AppBar(
      title: compact || control == null
          ? title
          : Row(
              children: [
                title,
                const SizedBox(width: 12),
                Flexible(child: control),
              ],
            ),
      bottom: _revisionRow
          ? PreferredSize(
              preferredSize: const Size.fromHeight(_revisionRowHeight),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: control,
                ),
              ),
            )
          : null,
      actions: [
        IconButton(
          icon: const Icon(Icons.undo),
          onPressed: onUndo,
          tooltip: l10n.diveLog_profileEditor_undo,
        ),
        if (compact)
          IconButton.filled(
            icon: const Icon(Icons.save),
            onPressed: onSave,
            tooltip: l10n.common_action_save,
          )
        else
          FilledButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save, size: 18),
            label: Text(l10n.common_action_save),
          ),
        const SizedBox(width: 8),
      ],
    );
  }
}
