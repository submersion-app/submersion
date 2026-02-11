import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';

/// A toggle button for switching between list/detail view and map view.
///
/// Shows a map icon that is highlighted when map view is active.
class MapViewToggleButton extends StatelessWidget {
  /// Whether map view is currently active.
  final bool isActive;

  /// Callback when the button is pressed.
  final VoidCallback onToggle;

  /// Icon size (default 20 for compact app bars).
  final double iconSize;

  const MapViewToggleButton({
    super.key,
    required this.isActive,
    required this.onToggle,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      toggled: isActive,
      child: IconButton(
        icon: Icon(Icons.map, size: iconSize),
        tooltip: isActive
            ? context.l10n.accessibility_label_hideMapView
            : context.l10n.accessibility_label_showMapView,
        onPressed: onToggle,
        style: isActive
            ? IconButton.styleFrom(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
              )
            : null,
      ),
    );
  }
}
