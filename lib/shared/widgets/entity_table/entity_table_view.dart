import 'package:flutter/material.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_header_cell.dart';

/// Row height for each row in the table.
const double kEntityTableRowHeight = 38.0;
const double _kCheckboxWidth = 48.0;

/// Generic full-width data table for displaying entity lists with pinned
/// columns and synchronized horizontal scrolling.
///
/// This is the shared table widget used by all entity types (Dives, Sites,
/// Trips, Equipment, etc.). Entity-specific behavior is provided via the
/// [adapter] and callbacks.
class EntityTableView<T, F extends EntityField> extends StatefulWidget {
  /// The entities to display as rows.
  final List<T> entities;

  /// Extract a unique string ID from an entity (for selection/highlight).
  final String Function(T entity) idExtractor;

  /// Adapter for extracting and formatting field values from entities.
  final EntityFieldAdapter<T, F> adapter;

  /// Current column configuration (columns, sort, widths).
  final EntityTableViewConfig<F> config;

  /// Unit formatter for value formatting.
  final UnitFormatter units;

  /// Called when user taps a column header to change sort field.
  final void Function(F field) onSortFieldChanged;

  /// Called when user resizes a column.
  final void Function(F field, double width) onResizeColumn;

  /// Called when user taps a row.
  final void Function(String entityId) onEntityTap;

  /// Called when user double-taps a row.
  final void Function(String entityId)? onEntityDoubleTap;

  /// Called when user long-presses a row.
  final void Function(String entityId)? onEntityLongPress;

  /// IDs of selected entities (for bulk selection mode).
  final Set<String> selectedIds;

  /// Whether bulk selection mode is active.
  final bool isSelectionMode;

  /// ID of the currently highlighted entity (for single-select highlight).
  final String? highlightedId;

  const EntityTableView({
    super.key,
    required this.entities,
    required this.idExtractor,
    required this.adapter,
    required this.config,
    required this.units,
    required this.onSortFieldChanged,
    required this.onResizeColumn,
    required this.onEntityTap,
    this.onEntityDoubleTap,
    this.onEntityLongPress,
    this.selectedIds = const {},
    this.isSelectionMode = false,
    this.highlightedId,
  });

  @override
  State<EntityTableView<T, F>> createState() => _EntityTableViewState<T, F>();
}

class _EntityTableViewState<T, F extends EntityField>
    extends State<EntityTableView<T, F>> {
  String? _hoveredEntityId;

  late final LinkedScrollControllerGroup _horizontalGroup;
  late final ScrollController _headerHorizontalController;
  late final ScrollController _bodyHorizontalController;

  late final LinkedScrollControllerGroup _verticalGroup;
  late final ScrollController _pinnedVerticalController;
  late final ScrollController _scrollableVerticalController;

  @override
  void initState() {
    super.initState();
    _horizontalGroup = LinkedScrollControllerGroup();
    _headerHorizontalController = _horizontalGroup.addAndGet();
    _bodyHorizontalController = _horizontalGroup.addAndGet();

    _verticalGroup = LinkedScrollControllerGroup();
    _pinnedVerticalController = _verticalGroup.addAndGet();
    _scrollableVerticalController = _verticalGroup.addAndGet();
  }

  @override
  void didUpdateWidget(EntityTableView<T, F> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightedId != null &&
        widget.highlightedId != oldWidget.highlightedId) {
      _scrollToHighlightedRow();
    }
  }

  void _scrollToHighlightedRow() {
    if (widget.highlightedId == null) return;

    final sorted = _sortedEntities();
    final index = sorted.indexWhere(
      (e) => widget.idExtractor(e) == widget.highlightedId,
    );
    if (index < 0) return;

    if (!_pinnedVerticalController.hasClients) return;
    final viewportHeight = _pinnedVerticalController.position.viewportDimension;
    final currentOffset = _pinnedVerticalController.offset;
    final rowTop = index * kEntityTableRowHeight;
    final rowBottom = rowTop + kEntityTableRowHeight;

    if (rowTop >= currentOffset &&
        rowBottom <= currentOffset + viewportHeight) {
      return;
    }

    final targetOffset =
        (rowTop - (viewportHeight / 2) + (kEntityTableRowHeight / 2)).clamp(
          0.0,
          _pinnedVerticalController.position.maxScrollExtent,
        );

    _pinnedVerticalController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _headerHorizontalController.dispose();
    _bodyHorizontalController.dispose();
    _pinnedVerticalController.dispose();
    _scrollableVerticalController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Sorting
  // ---------------------------------------------------------------------------

  List<T> _sortedEntities() {
    final config = widget.config;
    if (config.sortField == null) return widget.entities;

    final field = config.sortField!;
    final ascending = config.sortAscending;

    final sorted = List<T>.from(widget.entities);
    sorted.sort((a, b) {
      final va = widget.adapter.extractValue(field, a);
      final vb = widget.adapter.extractValue(field, b);

      if (va == null && vb == null) return 0;
      if (va == null) return 1;
      if (vb == null) return -1;

      int cmp;
      if (va is Comparable && vb is Comparable) {
        cmp = va.compareTo(vb);
      } else {
        cmp = widget.adapter
            .formatValue(field, va, widget.units)
            .compareTo(widget.adapter.formatValue(field, vb, widget.units));
      }

      return ascending ? cmp : -cmp;
    });

    return sorted;
  }

  // ---------------------------------------------------------------------------
  // Column helpers
  // ---------------------------------------------------------------------------

  List<EntityTableColumnConfig<F>> _pinnedColumns() {
    return widget.config.columns.where((c) => c.isPinned).toList();
  }

  List<EntityTableColumnConfig<F>> _scrollableColumns() {
    return widget.config.columns.where((c) => !c.isPinned).toList();
  }

  double _pinnedWidth() {
    return _pinnedColumns().fold(0.0, (sum, c) => sum + c.width);
  }

  double _scrollableWidth() {
    return _scrollableColumns().fold(0.0, (sum, c) => sum + c.width);
  }

  // ---------------------------------------------------------------------------
  // Cell rendering
  // ---------------------------------------------------------------------------

  Widget _buildCell({
    required T entity,
    required EntityTableColumnConfig<F> column,
    required ThemeData theme,
    required int rowIndex,
    required bool isSelected,
    bool isLastPinned = false,
  }) {
    final value = widget.adapter.extractValue(column.field, entity);
    final text = widget.adapter.formatValue(column.field, value, widget.units);

    return Container(
      width: column.width,
      height: kEntityTableRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: column.field.isRightAligned
          ? Alignment.centerRight
          : Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
            width: 0.5,
          ),
          right: isLastPinned
              ? BorderSide(color: theme.colorScheme.outlineVariant)
              : BorderSide.none,
        ),
      ),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
        style: theme.textTheme.bodySmall?.copyWith(
          color: isSelected ? theme.colorScheme.onPrimaryContainer : null,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Row background color
  // ---------------------------------------------------------------------------

  Color _rowBackground({
    required int index,
    required bool isSelected,
    required bool isHighlighted,
    required bool isHovered,
    required ColorScheme colorScheme,
  }) {
    if (isSelected) return colorScheme.primaryContainer;
    if (isHighlighted) {
      return colorScheme.primaryContainer.withValues(alpha: 0.3);
    }
    if (isHovered) return colorScheme.onSurface.withValues(alpha: 0.04);
    if (index.isOdd) return colorScheme.surfaceContainerLowest;
    return Colors.transparent;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final pinned = _pinnedColumns();
    final scrollable = _scrollableColumns();
    final sorted = _sortedEntities();
    final pinnedWidth = _pinnedWidth();
    final scrollableWidth = _scrollableWidth();

    return Column(
      children: [
        // Header row
        SizedBox(
          height: kEntityTableRowHeight,
          child: Row(
            children: [
              if (widget.isSelectionMode)
                const SizedBox(
                  width: _kCheckboxWidth,
                  height: kEntityTableRowHeight,
                ),
              ...pinned.map((col) {
                return EntityTableHeaderCell(
                  field: col.field,
                  width: col.width,
                  isSorted: widget.config.sortField == col.field,
                  sortAscending: widget.config.sortAscending,
                  onTap: () => widget.onSortFieldChanged(col.field),
                  onResize: (w) => widget.onResizeColumn(col.field, w),
                );
              }),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _headerHorizontalController,
                  physics: const ClampingScrollPhysics(),
                  child: Row(
                    children: scrollable.map((col) {
                      return EntityTableHeaderCell(
                        field: col.field,
                        width: col.width,
                        isSorted: widget.config.sortField == col.field,
                        sortAscending: widget.config.sortAscending,
                        onTap: () => widget.onSortFieldChanged(col.field),
                        onResize: (w) => widget.onResizeColumn(col.field, w),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Table body
        Expanded(
          child: Row(
            children: [
              // Pinned body columns
              SizedBox(
                width:
                    pinnedWidth +
                    (widget.isSelectionMode ? _kCheckboxWidth : 0),
                child: ListView.builder(
                  controller: _pinnedVerticalController,
                  itemExtent: kEntityTableRowHeight,
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final entity = sorted[index];
                    final entityId = widget.idExtractor(entity);
                    final isSelected =
                        widget.isSelectionMode &&
                        widget.selectedIds.contains(entityId);
                    final isHighlighted =
                        !widget.isSelectionMode &&
                        widget.highlightedId == entityId;
                    final isHovered = _hoveredEntityId == entityId;

                    return MouseRegion(
                      onEnter: (_) =>
                          setState(() => _hoveredEntityId = entityId),
                      onExit: (_) {
                        if (_hoveredEntityId == entityId) {
                          setState(() => _hoveredEntityId = null);
                        }
                      },
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onEntityTap(entityId),
                        onDoubleTap: widget.onEntityDoubleTap != null
                            ? () => widget.onEntityDoubleTap!(entityId)
                            : null,
                        onLongPress: widget.onEntityLongPress != null
                            ? () => widget.onEntityLongPress!(entityId)
                            : null,
                        child: ColoredBox(
                          color: _rowBackground(
                            index: index,
                            isSelected: isSelected,
                            isHighlighted: isHighlighted,
                            isHovered: isHovered,
                            colorScheme: colorScheme,
                          ),
                          child: Row(
                            children: [
                              if (widget.isSelectionMode)
                                SizedBox(
                                  width: _kCheckboxWidth,
                                  height: kEntityTableRowHeight,
                                  child: Checkbox(
                                    value: isSelected,
                                    onChanged: (_) =>
                                        widget.onEntityTap(entityId),
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ...pinned.asMap().entries.map((entry) {
                                return _buildCell(
                                  entity: entity,
                                  column: entry.value,
                                  theme: theme,
                                  rowIndex: index,
                                  isSelected: isSelected,
                                  isLastPinned: entry.key == pinned.length - 1,
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Scrollable body columns
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _bodyHorizontalController,
                  physics: const ClampingScrollPhysics(),
                  child: SizedBox(
                    width: scrollableWidth,
                    child: ListView.builder(
                      controller: _scrollableVerticalController,
                      itemExtent: kEntityTableRowHeight,
                      itemCount: sorted.length,
                      itemBuilder: (context, index) {
                        final entity = sorted[index];
                        final entityId = widget.idExtractor(entity);
                        final isSelected =
                            widget.isSelectionMode &&
                            widget.selectedIds.contains(entityId);
                        final isHighlighted =
                            !widget.isSelectionMode &&
                            widget.highlightedId == entityId;
                        final isHovered = _hoveredEntityId == entityId;

                        return MouseRegion(
                          onEnter: (_) =>
                              setState(() => _hoveredEntityId = entityId),
                          onExit: (_) {
                            if (_hoveredEntityId == entityId) {
                              setState(() => _hoveredEntityId = null);
                            }
                          },
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.onEntityTap(entityId),
                            onDoubleTap: widget.onEntityDoubleTap != null
                                ? () => widget.onEntityDoubleTap!(entityId)
                                : null,
                            onLongPress: widget.onEntityLongPress != null
                                ? () => widget.onEntityLongPress!(entityId)
                                : null,
                            child: ColoredBox(
                              color: _rowBackground(
                                index: index,
                                isSelected: isSelected,
                                isHighlighted: isHighlighted,
                                isHovered: isHovered,
                                colorScheme: colorScheme,
                              ),
                              child: Row(
                                children: scrollable.map((col) {
                                  return _buildCell(
                                    entity: entity,
                                    column: col,
                                    theme: theme,
                                    rowIndex: index,
                                    isSelected: isSelected,
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
