import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// The notes editor's formatting bar: heading, bold, italic and the two
/// list buttons, then the Preview toggle at the right end (#3683).
///
/// The bar sits inside the text field's tap region, so a tap on a button
/// does not count as a tap outside the field (which would unfocus it on
/// desktop). Buttons do not take focus when tapped, and stay reachable by
/// Tab for keyboard users.
class MarkdownNotesToolbar extends StatelessWidget {
  const MarkdownNotesToolbar({
    super.key,
    required this.previewing,
    required this.onHeading,
    required this.onBold,
    required this.onItalic,
    required this.onBulletList,
    required this.onNumberedList,
    required this.onPreviewChanged,
  });

  final bool previewing;
  final VoidCallback onHeading;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onBulletList;
  final VoidCallback onNumberedList;
  final ValueChanged<bool> onPreviewChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;

    Widget action(IconData icon, String tooltip, VoidCallback onPressed) {
      return IconButton(
        icon: Icon(icon),
        tooltip: tooltip,
        iconSize: 20,
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints.tightFor(width: 40, height: 40),
        padding: EdgeInsets.zero,
        onPressed: previewing ? null : onPressed,
      );
    }

    return TextFieldTapRegion(
      child: Row(
        children: [
          // The buttons scroll sideways on a narrow phone; Preview
          // always stays in view at the end.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  action(
                    Icons.title,
                    l10n.notesEditor_action_heading,
                    onHeading,
                  ),
                  action(
                    Icons.format_bold,
                    l10n.notesEditor_action_bold,
                    onBold,
                  ),
                  action(
                    Icons.format_italic,
                    l10n.notesEditor_action_italic,
                    onItalic,
                  ),
                  action(
                    Icons.format_list_bulleted,
                    l10n.notesEditor_action_bulletList,
                    onBulletList,
                  ),
                  action(
                    Icons.format_list_numbered,
                    l10n.notesEditor_action_numberedList,
                    onNumberedList,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          FilterChip(
            avatar: Icon(
              Icons.visibility_outlined,
              size: 18,
              color: previewing ? colors.onPrimary : colors.onSurfaceVariant,
            ),
            label: Text(l10n.notesEditor_action_preview),
            labelStyle: TextStyle(
              color: previewing ? colors.onPrimary : colors.onSurface,
            ),
            selected: previewing,
            showCheckmark: false,
            selectedColor: colors.primary,
            visualDensity: VisualDensity.compact,
            onSelected: onPreviewChanged,
          ),
        ],
      ),
    );
  }
}
