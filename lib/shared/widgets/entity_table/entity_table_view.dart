import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';
import 'package:submersion/core/text/text_sort.dart';
import 'package:submersion/core/utils/table_value_compare.dart';

import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/shared/constants/entity_field.dart';
import 'package:submersion/shared/models/entity_table_config.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_header_cell.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_menu.dart';

/// Row height for each row in the table.
const double kEntityTableRowHeight = 38.0;
const double _kCheckboxWidth = 48.0;

/// Width reserved for [EntityTableView.leadingBuilder], when one is given.
const double _kLeadingWidth = 40.0;

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

  /// Called immediately on touch down (before tap/double-tap disambiguation).
  final void Function(String entityId)? onEntityTapDown;

  /// Called when user double-taps a row.
  final void Function(String entityId)? onEntityDoubleTap;

  /// IDs of selected entities (for bulk selection mode).
  final Set<String> selectedIds;

  /// Whether bulk selection mode is active.
  final bool isSelectionMode;

  /// ID of the currently highlighted entity (for single-select highlight).
  final String? highlightedId;

  /// Optional widget rendered at the start of each row, before the first
  /// column. Null for every table that does not opt in, so existing tables are
  /// unchanged.
  ///
  /// Used for profile photos, which are not a sortable text value and
  /// therefore do not belong in the field enum. Renders in the PINNED section
  /// so it stays put when the table is scrolled horizontally, which means the
  /// header reserves the same width to keep columns aligned.
  final Widget Function(T entity)? leadingBuilder;

  /// Hides [field]'s column. When set, every header menu offers "Hide
  /// column", disabled on the last column (#2984).
  final void Function(F field)? onHideColumn;

  /// Extra header menu items, shown above "Hide column".
  final EntityTableHeaderMenuBuilder<F>? headerMenuBuilder;

  /// Cell menu items. Null leaves cells with no menu and no long-press
  /// recognizer, as before #2984.
  final EntityTableCellMenuBuilder<T, F>? cellMenuBuilder;

  /// Whether [field]'s column is filtered (shown as a header icon).
  final bool Function(F field)? isColumnFiltered;

  /// Whether [entity]'s cell in [field]'s column has any menu items. A cell
  /// answering false gets no cell gestures, so a hold there stays the row's.
  /// Every cell has one when null.
  final bool Function(T entity, F field)? hasCellMenu;

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
    this.onEntityTapDown,
    this.onEntityDoubleTap,
    this.selectedIds = const {},
    this.isSelectionMode = false,
    this.highlightedId,
    this.leadingBuilder,
    this.onHideColumn,
    this.headerMenuBuilder,
    this.cellMenuBuilder,
    this.isColumnFiltered,
    this.hasCellMenu,
  });

  @override
  State<EntityTableView<T, F>> createState() => _EntityTableViewState<T, F>();
}

class _EntityTableViewState<T, F extends EntityField>
    extends State<EntityTableView<T, F>> {
  String? _hoveredEntityId;

  static const _desktop = {
    TargetPlatform.macOS,
    TargetPlatform.windows,
    TargetPlatform.linux,
  };

  /// Always-visible scrollbars on desktop, the platform default on touch.
  bool? get _thumbVisibility =>
      _desktop.contains(defaultTargetPlatform) ? true : null;

  /// Widths of columns being dragged right now (#2984): the column redraws
  /// on every move, and the config is written once, on drag end.
  Map<F, double> _liveWidths = const {};

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
    // A table built with a highlighted row (the list was returned to, #3301)
    // shows that row rather than the top of the table.
    if (widget.highlightedId != null) {
      // Built with rows, the reveal is decided now, found or not: a row a
      // later filter brings into view is not jumped to.
      _revealedOnBuild = widget.entities.isNotEmpty;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToHighlightedRow(jump: true);
      });
    }
  }

  /// Whether the highlighted row has been brought into view since this
  /// table was built, so rows arriving after that do not move it again.
  bool _revealedOnBuild = false;

  @override
  void didUpdateWidget(EntityTableView<T, F> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightedId != null &&
        widget.highlightedId != oldWidget.highlightedId) {
      _scrollToHighlightedRow();
    } else if (!_revealedOnBuild &&
        widget.highlightedId != null &&
        oldWidget.entities.isEmpty &&
        widget.entities.isNotEmpty) {
      // Built before its rows arrived: reveal the row once they do.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToHighlightedRow(jump: true);
      });
    }
  }

  /// Scrolls the highlighted row into view, by [jump] when the table is
  /// being restored so it does not visibly travel from the top.
  void _scrollToHighlightedRow({bool jump = false}) {
    if (widget.highlightedId == null) return;

    final sorted = _sortedEntities();
    final index = sorted.indexWhere(
      (e) => widget.idExtractor(e) == widget.highlightedId,
    );
    if (index < 0) return;
    if (jump) _revealedOnBuild = true;

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

    if (jump) {
      _pinnedVerticalController.jumpTo(targetOffset);
      return;
    }
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
    final collator = TextCollator();
    sorted.sort((a, b) {
      final va = widget.adapter.extractValue(field, a);
      final vb = widget.adapter.extractValue(field, b);

      if (va == null && vb == null) return 0;
      if (va == null) return 1;
      if (vb == null) return -1;

      final cmp = compareTableValues(
        va,
        vb,
        collator: collator,
        formatted: (value) =>
            widget.adapter.formatValue(field, value, widget.units),
      );

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

  double _widthOf(EntityTableColumnConfig<F> c) =>
      _liveWidths[c.field] ?? c.width;

  double _pinnedWidth() {
    return _pinnedColumns().fold(0.0, (sum, c) => sum + _widthOf(c));
  }

  double _scrollableWidth() {
    return _scrollableColumns().fold(0.0, (sum, c) => sum + _widthOf(c));
  }

  void _resizeLive(F field, double width) =>
      setState(() => _liveWidths = {..._liveWidths, field: width});

  void _resizeCommit(F field) {
    final width = _liveWidths[field];
    if (width == null) return;
    widget.onResizeColumn(field, width);
    setState(
      () => _liveWidths = {
        for (final e in _liveWidths.entries)
          if (e.key != field) e.key: e.value,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Cell rendering
  // ---------------------------------------------------------------------------

  bool get _hasHeaderMenu =>
      widget.onHideColumn != null || widget.headerMenuBuilder != null;

  void _openHeaderMenu(BuildContext context, F field, Offset position) {
    // Labels resolve here, never in build, so tables pumped without
    // localizations still build.
    final l10n = context.l10n;
    showEntityTableMenu(
      context,
      position: position,
      sections: [
        widget.headerMenuBuilder?.call(context, field) ?? const [],
        if (widget.onHideColumn != null)
          [
            EntityTableMenuAction(
              label: l10n.tableMode_menu_hideColumn,
              enabled: widget.config.columns.length > 1,
              onSelected: () => widget.onHideColumn!(field),
            ),
          ],
      ],
    );
  }

  /// One header cell, with its menu and filter indicator wired.
  Widget _headerCell(EntityTableColumnConfig<F> col) => Builder(
    builder: (context) => EntityTableHeaderCell(
      field: col.field,
      width: _widthOf(col),
      isSorted: widget.config.sortField == col.field,
      sortAscending: widget.config.sortAscending,
      onTap: () => widget.onSortFieldChanged(col.field),
      onResize: (w) => _resizeLive(col.field, w),
      onResizeEnd: () => _resizeCommit(col.field),
      isFiltered: widget.isColumnFiltered?.call(col.field) ?? false,
      onOpenMenu: _hasHeaderMenu
          ? (position) => _openHeaderMenu(context, col.field, position)
          : null,
    ),
  );

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

    final cell = Container(
      width: _widthOf(column),
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
    final menu = widget.cellMenuBuilder;
    if (menu == null ||
        !(widget.hasCellMenu?.call(entity, column.field) ?? true)) {
      return cell;
    }
    return Builder(
      builder: (cellContext) {
        void open(Offset position) => showEntityTableMenu(
          cellContext,
          position: position,
          sections: [menu(cellContext, entity, column.field)],
        );
        return GestureDetector(
          onSecondaryTapUp: (d) => open(d.globalPosition),
          onLongPressStart: (d) => open(d.globalPosition),
          child: cell,
        );
      },
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
      return colorScheme.primaryContainer.withValues(alpha: 0.8);
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

    // One explicit scrollbar per axis on the body (#2984), never one per
    // inner scrollable (pinned list, header, body) as the desktop default
    // would draw.
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
      child: Column(
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
                if (widget.leadingBuilder != null)
                  const SizedBox(
                    width: _kLeadingWidth,
                    height: kEntityTableRowHeight,
                  ),
                ...pinned.map(_headerCell),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _headerHorizontalController,
                    physics: const ClampingScrollPhysics(),
                    child: Row(children: scrollable.map(_headerCell).toList()),
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
                      (widget.isSelectionMode ? _kCheckboxWidth : 0) +
                      (widget.leadingBuilder != null ? _kLeadingWidth : 0),
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
                        child: Listener(
                          onPointerDown: widget.onEntityTapDown != null
                              ? (_) => widget.onEntityTapDown!(entityId)
                              : null,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.onEntityTap(entityId),
                            onDoubleTap: widget.onEntityDoubleTap != null
                                ? () => widget.onEntityDoubleTap!(entityId)
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
                                  if (widget.leadingBuilder != null)
                                    SizedBox(
                                      width: _kLeadingWidth,
                                      height: kEntityTableRowHeight,
                                      child: Center(
                                        child: widget.leadingBuilder!(entity),
                                      ),
                                    ),
                                  ...pinned.asMap().entries.map((entry) {
                                    return _buildCell(
                                      entity: entity,
                                      column: entry.value,
                                      theme: theme,
                                      rowIndex: index,
                                      isSelected: isSelected,
                                      isLastPinned:
                                          entry.key == pinned.length - 1,
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // Scrollable body columns. Both bars sit outside the
                // horizontal scroller, so the vertical one stays at the
                // viewport's edge; the body list is one scrollable below the
                // horizontal one (depth 1).
                Expanded(
                  child: Scrollbar(
                    controller: _bodyHorizontalController,
                    thumbVisibility: _thumbVisibility,
                    notificationPredicate: (n) =>
                        n.depth == 0 && n.metrics.axis == Axis.horizontal,
                    child: Scrollbar(
                      controller: _scrollableVerticalController,
                      thumbVisibility: _thumbVisibility,
                      notificationPredicate: (n) =>
                          n.depth == 1 && n.metrics.axis == Axis.vertical,
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
                                child: Listener(
                                  onPointerDown: widget.onEntityTapDown != null
                                      ? (_) => widget.onEntityTapDown!(entityId)
                                      : null,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () => widget.onEntityTap(entityId),
                                    onDoubleTap:
                                        widget.onEntityDoubleTap != null
                                        ? () => widget.onEntityDoubleTap!(
                                            entityId,
                                          )
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
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
