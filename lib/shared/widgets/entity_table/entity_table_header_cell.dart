import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_resize_handle.dart';

/// A single column header cell for the generic entity table view.
///
/// Displays the field's short label, a sort indicator arrow when this column
/// is the active sort column, and an optional drag-to-resize handle on the
/// right edge.
class EntityTableHeaderCell extends StatelessWidget {
  final EntityField field;
  final double width;
  final bool isSorted;
  final bool sortAscending;
  final VoidCallback? onTap;

  /// Called with the live absolute width while the handle is dragged.
  final ValueChanged<double>? onResize;

  /// Called once when a resize drag ends or is cancelled (#2984).
  final VoidCallback? onResizeEnd;

  /// Narrowest the handle drags to; [EntityField.minWidth] when null.
  final double? minWidth;
  final bool showResizeHandle;

  /// Opens the column's menu at a global position, on secondary tap or
  /// long-press (#2984). Null leaves the header without a menu.
  final ValueChanged<Offset>? onOpenMenu;

  /// Shows a filter icon: the list has a filter on this column.
  final bool isFiltered;

  const EntityTableHeaderCell({
    super.key,
    required this.field,
    required this.width,
    this.isSorted = false,
    this.sortAscending = true,
    this.onTap,
    this.onResize,
    this.onResizeEnd,
    this.minWidth,
    this.showResizeHandle = true,
    this.onOpenMenu,
    this.isFiltered = false,
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
            child: GestureDetector(
              onSecondaryTapUp: onOpenMenu == null
                  ? null
                  : (d) => onOpenMenu!(d.globalPosition),
              onLongPressStart: onOpenMenu == null
                  ? null
                  : (d) => onOpenMenu!(d.globalPosition),
              child: InkWell(
                onTap: field.sortable ? onTap : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  alignment: Alignment.centerLeft,
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: colorScheme.outlineVariant),
                      right: BorderSide(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.5,
                        ),
                        width: 0.5,
                      ),
                    ),
                    color: colorScheme.surfaceContainerLow,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          field.localizedDisplayName(context.l10n),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (isFiltered)
                        Padding(
                          key: ValueKey('entity-table-filtered-${field.name}'),
                          padding: const EdgeInsetsDirectional.only(end: 2),
                          child: Icon(
                            Icons.filter_alt,
                            size: 12,
                            color: colorScheme.primary,
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
          ),

          // Resize handle on the right edge
          if (showResizeHandle && onResize != null)
            // The trailing edge: the left one in a right-to-left locale.
            PositionedDirectional(
              end: 0,
              top: 0,
              bottom: 0,
              child: EntityTableResizeHandle(
                width: width,
                minWidth: minWidth ?? field.minWidth,
                handleWidth: handleWidth,
                color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                onResize: onResize!,
                onResizeEnd: onResizeEnd,
              ),
            ),
        ],
      ),
    );
  }
}
