import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_list_view_mode.dart';

/// Segmented button for switching between dive list view modes.
///
/// Shows three icons: view_agenda (detailed), view_list (compact), list (dense).
class DiveListViewModeToggle extends StatelessWidget {
  final DiveListViewMode currentMode;
  final ValueChanged<DiveListViewMode> onModeChanged;

  /// Icon size (default 20 for compact app bars).
  final double iconSize;

  const DiveListViewModeToggle({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<DiveListViewMode>(
      segments: [
        ButtonSegment(
          value: DiveListViewMode.detailed,
          icon: Icon(Icons.view_agenda, size: iconSize),
        ),
        ButtonSegment(
          value: DiveListViewMode.compact,
          icon: Icon(Icons.view_list, size: iconSize),
        ),
        ButtonSegment(
          value: DiveListViewMode.dense,
          icon: Icon(Icons.list, size: iconSize),
        ),
      ],
      selected: {currentMode},
      onSelectionChanged: (selected) {
        onModeChanged(selected.first);
      },
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}
