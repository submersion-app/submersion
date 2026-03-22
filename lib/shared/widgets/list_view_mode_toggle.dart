import 'package:flutter/material.dart';

import 'package:submersion/core/constants/list_view_mode.dart';

/// Popup menu button for switching between list view modes.
///
/// Shows the icon of the current mode; tapping reveals available options.
class ListViewModeToggle extends StatelessWidget {
  final ListViewMode currentMode;
  final ValueChanged<ListViewMode> onModeChanged;

  /// Which modes to show in the popup. Defaults to all three.
  final List<ListViewMode> availableModes;

  /// Icon size (default 20 for compact app bars).
  final double iconSize;

  const ListViewModeToggle({
    super.key,
    required this.currentMode,
    required this.onModeChanged,
    this.availableModes = ListViewMode.values,
    this.iconSize = 20,
  });

  IconData _iconForMode(ListViewMode mode) {
    return switch (mode) {
      ListViewMode.detailed => Icons.view_agenda,
      ListViewMode.compact => Icons.view_list,
      ListViewMode.dense => Icons.list,
    };
  }

  String _labelForMode(ListViewMode mode) {
    return switch (mode) {
      ListViewMode.detailed => 'Detailed',
      ListViewMode.compact => 'Compact',
      ListViewMode.dense => 'Dense',
    };
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<ListViewMode>(
      icon: Icon(_iconForMode(currentMode), size: iconSize),
      tooltip: 'View mode',
      onSelected: onModeChanged,
      itemBuilder: (context) => availableModes.map((mode) {
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
