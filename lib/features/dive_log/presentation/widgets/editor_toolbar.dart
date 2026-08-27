import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// Mode selector toolbar for the profile editor.
///
/// Displays a segmented button with five editing modes:
/// Select, Smooth, Outlier, Draw, and Trim.
class EditorToolbar extends StatelessWidget {
  final EditorMode mode;
  final void Function(EditorMode) onModeChanged;

  const EditorToolbar({
    super.key,
    required this.mode,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SegmentedButton<EditorMode>(
        segments: [
          ButtonSegment(
            value: EditorMode.select,
            icon: const Icon(Icons.touch_app),
            label: Text(context.l10n.diveLog_profileEditor_mode_select),
          ),
          ButtonSegment(
            value: EditorMode.smooth,
            icon: const Icon(Icons.auto_fix_high),
            label: Text(context.l10n.diveLog_profileEditor_mode_smooth),
          ),
          ButtonSegment(
            value: EditorMode.outlier,
            icon: const Icon(Icons.warning_amber),
            label: Text(context.l10n.diveLog_profileEditor_mode_outlier),
          ),
          ButtonSegment(
            value: EditorMode.draw,
            icon: const Icon(Icons.draw),
            label: Text(context.l10n.diveLog_profileEditor_mode_draw),
          ),
          ButtonSegment(
            value: EditorMode.trim,
            icon: const Icon(Icons.content_cut),
            label: Text(context.l10n.diveLog_profileEditor_mode_trim),
          ),
        ],
        selected: {mode},
        onSelectionChanged: (selected) {
          onModeChanged(selected.first);
        },
      ),
    );
  }
}
