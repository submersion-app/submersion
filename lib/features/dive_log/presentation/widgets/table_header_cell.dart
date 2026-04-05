import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/core/constants/dive_field.dart';

/// A single column header cell for the dive table view.
///
/// Displays the field's short label, a sort indicator arrow when this column
/// is the active sort column, and an optional drag-to-resize handle on the
/// right edge.
class TableHeaderCell extends StatelessWidget {
  final DiveField field;
  final double width;
  final bool isSorted;
  final bool sortAscending;
  final VoidCallback? onTap;
  final ValueChanged<double>? onResize;
  final bool showResizeHandle;

  const TableHeaderCell({
    super.key,
    required this.field,
    required this.width,
    this.isSorted = false,
    this.sortAscending = true,
    this.onTap,
    this.onResize,
    this.showResizeHandle = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Wider hit target on mobile for easier resizing.
    final isMobile =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;
    final handleWidth = isMobile ? 24.0 : 8.0;

    return SizedBox(
      width: width,
      height: 38,
      child: Stack(
        children: [
          // Tappable header content
          Positioned.fill(
            child: InkWell(
              onTap: field.sortable ? onTap : null,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: colorScheme.outlineVariant),
                    right: BorderSide(
                      color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                      width: 0.5,
                    ),
                  ),
                  color: colorScheme.surfaceContainerLow,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        field.shortLabel,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (isSorted)
                      Icon(
                        sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 14,
                        color: colorScheme.primary,
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Resize handle on the right edge
          if (showResizeHandle && onResize != null)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (details) {
                  onResize?.call(width + details.delta.dx);
                },
                child: MouseRegion(
                  cursor: SystemMouseCursors.resizeColumn,
                  child: SizedBox(
                    width: handleWidth,
                    child: Center(
                      child: Container(
                        width: 1,
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
