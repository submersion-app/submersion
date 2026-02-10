import 'package:flutter/material.dart';

/// An animated collapsible container for the list pane in map-list layouts.
///
/// Animates between full width and collapsed (zero width) states.
/// Shows a toggle button to collapse/expand.
class CollapsibleListPane extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback onToggle;
  final double width;
  final Widget child;

  const CollapsibleListPane({
    super.key,
    required this.isCollapsed,
    required this.onToggle,
    required this.child,
    this.width = 440,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          constraints: BoxConstraints(
            maxWidth: isCollapsed ? 0 : width,
            minWidth: isCollapsed ? 0 : width,
          ),
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              maxWidth: width,
              minWidth: width,
              child: child,
            ),
          ),
        ),
        // Collapse toggle button positioned outside the clipping area
        if (!isCollapsed)
          Positioned(
            right: 0,
            top: 8,
            child: Material(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(20),
              ),
              elevation: 2,
              child: Semantics(
                button: true,
                label: 'Hide list',
                child: InkWell(
                  onTap: onToggle,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    child: Icon(
                      Icons.chevron_left,
                      size: 20,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
