import 'dart:math' as math;

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
  /// Screens narrower than this, at the default text size, get the
  /// [compact] layout. Larger text widens it in step, since it grows the
  /// title and Save beside the selector.
  static const double compactMaxWidth = 600;

  final bool compact;

  /// The text scale factor at 14 sp, which sizes the revision row.
  final double textScale;

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
    this.textScale = 1.0,
    required this.revisionControl,
    required this.onUndo,
    required this.onSave,
  });

  /// The app bar for the screen and text size in [context].
  factory ProfileEditorAppBar.forScreen(
    BuildContext context, {
    required Widget? revisionControl,
    required VoidCallback? onUndo,
    required VoidCallback? onSave,
  }) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    return ProfileEditorAppBar(
      compact:
          MediaQuery.sizeOf(context).width <
          compactMaxWidth * math.max(1.0, textScale),
      textScale: textScale,
      revisionControl: revisionControl,
      onUndo: onUndo,
      onSave: onSave,
    );
  }

  bool get _revisionRow => compact && revisionControl != null;

  /// Room for the selector pill (its 16 dp text line, scaled, and 8 dp of
  /// padding) and 8 dp under it, with a little air above: 44 dp at 1x.
  double get _revisionRowHeight => 28 + 16 * math.max(1.0, textScale);

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
              preferredSize: Size.fromHeight(_revisionRowHeight),
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
