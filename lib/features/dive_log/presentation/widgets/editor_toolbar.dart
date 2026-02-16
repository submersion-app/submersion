import 'package:flutter/material.dart';

import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';

/// Mode selector toolbar for the profile editor.
///
/// Displays a segmented button with four editing modes:
/// Select, Smooth, Outlier, and Draw.
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
        segments: const [
          ButtonSegment(
            value: EditorMode.select,
            icon: Icon(Icons.touch_app),
            label: Text('Select'),
          ),
          ButtonSegment(
            value: EditorMode.smooth,
            icon: Icon(Icons.auto_fix_high),
            label: Text('Smooth'),
          ),
          ButtonSegment(
            value: EditorMode.outlier,
            icon: Icon(Icons.warning_amber),
            label: Text('Outlier'),
          ),
          ButtonSegment(
            value: EditorMode.draw,
            icon: Icon(Icons.draw),
            label: Text('Draw'),
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
