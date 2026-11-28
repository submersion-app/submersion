import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// Says over the item on screen that it will be unlinked when the diver
/// saves (issue #5126), with Undo, which drops the held Unlink and nothing
/// else.
class MediaViewerUnlinkStrip extends StatelessWidget {
  const MediaViewerUnlinkStrip({
    super.key = const ValueKey('viewer_unlink_strip'),
    required this.message,
    required this.onUndo,
  });

  final String message;
  final VoidCallback onUndo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = scheme.onTertiaryContainer;
    return Material(
      color: scheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
        child: Row(
          children: [
            Icon(Icons.link_off, color: foreground),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(message, style: TextStyle(color: foreground)),
              ),
            ),
            TextButton(
              key: const ValueKey('viewer_unlink_undo'),
              style: TextButton.styleFrom(foregroundColor: foreground),
              onPressed: onUndo,
              child: Text(context.l10n.media_viewer_unlinkUndo),
            ),
          ],
        ),
      ),
    );
  }
}
