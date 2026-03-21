import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_list_view_mode.dart';

/// Popup menu button for switching between dive list view modes.
///
/// Shows the icon of the current mode; tapping reveals all three options.
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

  IconData _iconForMode(DiveListViewMode mode) {
    return switch (mode) {
      DiveListViewMode.detailed => Icons.view_agenda,
      DiveListViewMode.compact => Icons.view_list,
      DiveListViewMode.dense => Icons.list,
    };
  }

  String _labelForMode(DiveListViewMode mode) {
    return switch (mode) {
      DiveListViewMode.detailed => 'Detailed',
      DiveListViewMode.compact => 'Compact',
      DiveListViewMode.dense => 'Dense',
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DiveListViewMode>(
      icon: Icon(_iconForMode(currentMode), size: iconSize),
      tooltip: 'View mode',
      onSelected: onModeChanged,
      itemBuilder: (context) => DiveListViewMode.values.map((mode) {
        return PopupMenuItem(
          value: mode,
          child: Row(
            children: [
              Icon(
                _iconForMode(mode),
                size: 20,
                color: mode == currentMode
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              const SizedBox(width: 12),
              Text(
                _labelForMode(mode),
                style: mode == currentMode
                    ? TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      )
                    : null,
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
