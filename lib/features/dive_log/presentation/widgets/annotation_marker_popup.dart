import 'package:flutter/material.dart';

import 'package:submersion/core/utils/minutes_seconds.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/l10n/l10n_extension.dart';

enum _PopupChoice { openInNotes, move, editTime, remove }

/// Wider than a menu's default 280, which [showMenu] would clamp it to, so
/// the three actions share a line. A phone narrower than this shrinks it.
const _popupWidth = 300.0;

/// The popup a tapped annotation marker opens (#4109), anchored to the dot:
/// the linked words in full, the time and depth in the diver's units (the
/// time opens the time editor), and Open in Notes, Move and Remove. Each
/// action closes the popup before it runs.
Future<void> showAnnotationMarkerPopup(
  BuildContext context, {
  required ProfileEvent annotation,
  required Offset globalPosition,
  required UnitFormatter units,
  required VoidCallback onOpenInNotes,
  required VoidCallback onMove,
  required VoidCallback onEditTime,
  required VoidCallback onRemove,
}) async {
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox? ??
      context.findRenderObject() as RenderBox;
  final position = RelativeRect.fromRect(
    Rect.fromCenter(center: globalPosition, width: 1, height: 1),
    Offset.zero & overlay.size,
  );
  final choice = await showMenu<_PopupChoice>(
    context: context,
    position: position,
    constraints: const BoxConstraints(maxWidth: _popupWidth),
    items: [
      PopupMenuItem<_PopupChoice>(
        enabled: false,
        padding: EdgeInsets.zero,
        child: _PopupBody(annotation: annotation, units: units),
      ),
    ],
  );
  switch (choice) {
    case _PopupChoice.openInNotes:
      onOpenInNotes();
    case _PopupChoice.move:
      onMove();
    case _PopupChoice.editTime:
      onEditTime();
    case _PopupChoice.remove:
      onRemove();
    case null:
      break;
  }
}

class _PopupBody extends StatelessWidget {
  const _PopupBody({required this.annotation, required this.units});

  final ProfileEvent annotation;
  final UnitFormatter units;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final time = formatMinutesSeconds(annotation.timestamp);
    final depth = annotation.depth;
    final meta = depth == null
        ? time
        : l10n.diveLog_annotation_popup_meta(time, units.formatDepth(depth));
    void choose(_PopupChoice c) => Navigator.of(context).pop(c);
    return DefaultTextStyle.merge(
      style: TextStyle(color: colors.onSurface),
      child: SizedBox(
        width: _popupWidth,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                annotation.description ?? '',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              InkWell(
                onTap: () => choose(_PopupChoice.editTime),
                borderRadius: BorderRadius.circular(4),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    meta,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.primary,
                      decoration: TextDecoration.underline,
                      decorationColor: colors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              // Wraps to a column when the three labels outgrow the width.
              OverflowBar(
                alignment: MainAxisAlignment.end,
                overflowAlignment: OverflowBarAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => choose(_PopupChoice.openInNotes),
                    child: Text(l10n.diveLog_annotation_popup_openInNotes),
                  ),
                  TextButton(
                    onPressed: () => choose(_PopupChoice.move),
                    child: Text(l10n.diveLog_annotation_popup_move),
                  ),
                  TextButton(
                    onPressed: () => choose(_PopupChoice.remove),
                    child: Text(l10n.diveLog_annotation_popup_remove),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
