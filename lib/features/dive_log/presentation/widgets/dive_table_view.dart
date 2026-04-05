import 'package:flutter/material.dart';
import 'package:linked_scroll_controller/linked_scroll_controller.dart';

import 'package:submersion/core/constants/dive_field.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/view_config_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/table_column_picker.dart';
import 'package:submersion/features/dive_log/presentation/widgets/table_header_cell.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Row height for each dive row in the table.
const double _kRowHeight = 38.0;
const double _kCheckboxWidth = 48.0;

/// Full-width data table for displaying dive lists with pinned columns
/// and synchronized horizontal scrolling.
///
/// The layout uses a column-oriented approach:
/// - Header row: pinned header cells (fixed) + horizontally scrollable header
/// - Body: pinned column ListView (fixed) + horizontally scrollable ListView
/// - Horizontal scroll is synced between header and body via
///   [LinkedScrollControllerGroup]
/// - Vertical scroll is synced between the two body ListViews via
///   [NotificationListener]
class DiveTableView extends ConsumerStatefulWidget {
  final List<Dive> dives;
  final Map<String, Duration?> surfaceIntervals;
  final void Function(String diveId) onDiveTap;
  final void Function(String diveId)? onDiveLongPress;
  final Set<String> selectedIds;
  final bool isSelectionMode;
  final String? highlightedId;

  const DiveTableView({
    super.key,
    required this.dives,
    required this.surfaceIntervals,
    required this.onDiveTap,
    this.onDiveLongPress,
    this.selectedIds = const {},
    this.isSelectionMode = false,
    this.highlightedId,
  });

  @override
  ConsumerState<DiveTableView> createState() => _DiveTableViewState();
}

class _DiveTableViewState extends ConsumerState<DiveTableView> {
  // Horizontal scroll sync between header and body
  late final LinkedScrollControllerGroup _horizontalGroup;
  late final ScrollController _headerHorizontalController;
  late final ScrollController _bodyHorizontalController;

  // Vertical scroll controllers for pinned and scrollable body columns
  late final ScrollController _pinnedVerticalController;
  late final ScrollController _scrollableVerticalController;

  // Guard to prevent recursive scroll sync
  bool _isSyncingVertical = false;

  @override
  void initState() {
    super.initState();
    _horizontalGroup = LinkedScrollControllerGroup();
    _headerHorizontalController = _horizontalGroup.addAndGet();
    _bodyHorizontalController = _horizontalGroup.addAndGet();

    _pinnedVerticalController = ScrollController();
    _scrollableVerticalController = ScrollController();
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

  List<Dive> _sortedDives(TableViewConfig config) {
    if (config.sortField == null) return widget.dives;

    final field = config.sortField!;
    final ascending = config.sortAscending;
    final settings = ref.read(settingsProvider);
    final units = UnitFormatter(settings);

    final sorted = List<Dive>.from(widget.dives);
    sorted.sort((a, b) {
      final va = field.extractFromDive(a);
      final vb = field.extractFromDive(b);

      // Nulls always sort to the end
      if (va == null && vb == null) return 0;
      if (va == null) return 1;
      if (vb == null) return -1;

      int cmp;
      if (va is Comparable && vb is Comparable) {
        cmp = va.compareTo(vb);
      } else {
        // Fall back to string comparison of formatted values
        cmp = field
            .formatValue(va, units)
            .compareTo(field.formatValue(vb, units));
      }

      return ascending ? cmp : -cmp;
    });

    return sorted;
  }

  // ---------------------------------------------------------------------------
  // Column helpers
  // ---------------------------------------------------------------------------

  List<TableColumnConfig> _pinnedColumns(TableViewConfig config) {
    return config.columns.where((c) => c.isPinned).toList();
  }

  List<TableColumnConfig> _scrollableColumns(TableViewConfig config) {
    return config.columns.where((c) => !c.isPinned).toList();
  }

  double _pinnedWidth(TableViewConfig config) {
    return _pinnedColumns(config).fold(0.0, (sum, c) => sum + c.width);
  }

  double _scrollableWidth(TableViewConfig config) {
    return _scrollableColumns(config).fold(0.0, (sum, c) => sum + c.width);
  }

  // ---------------------------------------------------------------------------
  // Vertical scroll sync
  // ---------------------------------------------------------------------------

  void _syncVerticalScroll(ScrollController source, ScrollController target) {
    if (_isSyncingVertical) return;
    _isSyncingVertical = true;
    if (target.hasClients) {
      target.jumpTo(source.offset);
    }
    _isSyncingVertical = false;
  }

  // ---------------------------------------------------------------------------
  // Cell rendering
  // ---------------------------------------------------------------------------

  /// Whether the given field should be right-aligned (numeric fields).
  bool _isRightAligned(DiveField field) {
    switch (field) {
      case DiveField.diveNumber:
      case DiveField.maxDepth:
      case DiveField.avgDepth:
      case DiveField.bottomTime:
      case DiveField.runtime:
      case DiveField.waterTemp:
      case DiveField.airTemp:
      case DiveField.swellHeight:
      case DiveField.altitude:
      case DiveField.surfacePressure:
      case DiveField.windSpeed:
      case DiveField.humidity:
      case DiveField.tankCount:
      case DiveField.startPressure:
      case DiveField.endPressure:
      case DiveField.sacRate:
      case DiveField.gasConsumed:
      case DiveField.totalWeight:
      case DiveField.gradientFactorLow:
      case DiveField.gradientFactorHigh:
      case DiveField.cnsStart:
      case DiveField.cnsEnd:
      case DiveField.otu:
      case DiveField.setpointLow:
      case DiveField.setpointHigh:
      case DiveField.setpointDeco:
      case DiveField.ratingStars:
      case DiveField.surfaceInterval:
      case DiveField.siteLatitude:
      case DiveField.siteLongitude:
        return true;
      default:
        return false;
    }
  }

  Widget _buildCell({
    required Dive dive,
    required TableColumnConfig column,
    required UnitFormatter units,
    required ThemeData theme,
    required int rowIndex,
    required bool isSelected,
    bool isLastPinned = false,
  }) {
    final value = column.field.extractFromDive(dive);
    final text = column.field.formatValue(value, units);
    final rightAligned = _isRightAligned(column.field);

    return Container(
      width: column.width,
      height: _kRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: rightAligned ? Alignment.centerRight : Alignment.centerLeft,
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
    required ColorScheme colorScheme,
  }) {
    if (isSelected) {
      return colorScheme.primaryContainer;
    }
    if (isHighlighted) {
      return colorScheme.primaryContainer.withValues(alpha: 0.3);
    }
    if (index.isOdd) {
      return colorScheme.surfaceContainerLowest;
    }
    return Colors.transparent;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(tableViewConfigProvider);
    final settings = ref.watch(settingsProvider);
    final units = UnitFormatter(settings);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final pinned = _pinnedColumns(config);
    final scrollable = _scrollableColumns(config);
    final sortedDives = _sortedDives(config);
    final pinnedWidth = _pinnedWidth(config);
    final scrollableWidth = _scrollableWidth(config);

    return Stack(
      children: [
        Column(
          children: [
            // -----------------------------------------------------------------
            // Header row
            // -----------------------------------------------------------------
            SizedBox(
              height: _kRowHeight,
              child: Row(
                children: [
                  // Checkbox header (empty cell, visible in selection mode)
                  if (widget.isSelectionMode)
                    const SizedBox(width: _kCheckboxWidth, height: _kRowHeight),

                  // Pinned header cells
                  ...pinned.map((col) {
                    return TableHeaderCell(
                      field: col.field,
                      width: col.width,
                      isSorted: config.sortField == col.field,
                      sortAscending: config.sortAscending,
                      onTap: () => ref
                          .read(tableViewConfigProvider.notifier)
                          .setSortField(col.field),
                      onResize: (newWidth) => ref
                          .read(tableViewConfigProvider.notifier)
                          .resizeColumn(col.field, newWidth),
                    );
                  }),

                  // Scrollable header cells
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      controller: _headerHorizontalController,
                      physics: const ClampingScrollPhysics(),
                      child: Row(
                        children: scrollable.map((col) {
                          return TableHeaderCell(
                            field: col.field,
                            width: col.width,
                            isSorted: config.sortField == col.field,
                            sortAscending: config.sortAscending,
                            onTap: () => ref
                                .read(tableViewConfigProvider.notifier)
                                .setSortField(col.field),
                            onResize: (newWidth) => ref
                                .read(tableViewConfigProvider.notifier)
                                .resizeColumn(col.field, newWidth),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // -----------------------------------------------------------------
            // Table body
            // -----------------------------------------------------------------
            Expanded(
              child: Row(
                children: [
                  // Pinned body columns (fixed left)
                  SizedBox(
                    width:
                        pinnedWidth +
                        (widget.isSelectionMode ? _kCheckboxWidth : 0),
                    child: NotificationListener<ScrollUpdateNotification>(
                      onNotification: (notification) {
                        _syncVerticalScroll(
                          _pinnedVerticalController,
                          _scrollableVerticalController,
                        );
                        return false;
                      },
                      child: ListView.builder(
                        controller: _pinnedVerticalController,
                        itemExtent: _kRowHeight,
                        itemCount: sortedDives.length,
                        itemBuilder: (context, index) {
                          final dive = sortedDives[index];
                          final isSelected =
                              widget.isSelectionMode &&
                              widget.selectedIds.contains(dive.id);
                          final isHighlighted =
                              !widget.isSelectionMode &&
                              widget.highlightedId == dive.id;

                          return GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.onDiveTap(dive.id),
                            onLongPress: widget.onDiveLongPress != null
                                ? () => widget.onDiveLongPress!(dive.id)
                                : null,
                            child: ColoredBox(
                              color: _rowBackground(
                                index: index,
                                isSelected: isSelected,
                                isHighlighted: isHighlighted,
                                colorScheme: colorScheme,
                              ),
                              child: Row(
                                children: [
                                  if (widget.isSelectionMode)
                                    SizedBox(
                                      width: _kCheckboxWidth,
                                      height: _kRowHeight,
                                      child: Checkbox(
                                        value: isSelected,
                                        onChanged: (_) =>
                                            widget.onDiveTap(dive.id),
                                        materialTapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ),
                                  ...pinned.asMap().entries.map((entry) {
                                    return _buildCell(
                                      dive: dive,
                                      column: entry.value,
                                      units: units,
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
                          );
                        },
                      ),
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
                        child: NotificationListener<ScrollUpdateNotification>(
                          onNotification: (notification) {
                            _syncVerticalScroll(
                              _scrollableVerticalController,
                              _pinnedVerticalController,
                            );
                            return false;
                          },
                          child: ListView.builder(
                            controller: _scrollableVerticalController,
                            physics: const ClampingScrollPhysics(),
                            itemExtent: _kRowHeight,
                            itemCount: sortedDives.length,
                            itemBuilder: (context, index) {
                              final dive = sortedDives[index];
                              final isSelected =
                                  widget.isSelectionMode &&
                                  widget.selectedIds.contains(dive.id);
                              final isHighlighted =
                                  !widget.isSelectionMode &&
                                  widget.highlightedId == dive.id;

                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => widget.onDiveTap(dive.id),
                                onLongPress: widget.onDiveLongPress != null
                                    ? () => widget.onDiveLongPress!(dive.id)
                                    : null,
                                child: ColoredBox(
                                  color: _rowBackground(
                                    index: index,
                                    isSelected: isSelected,
                                    isHighlighted: isHighlighted,
                                    colorScheme: colorScheme,
                                  ),
                                  child: Row(
                                    children: scrollable.map((col) {
                                      return _buildCell(
                                        dive: dive,
                                        column: col,
                                        units: units,
                                        theme: theme,
                                        rowIndex: index,
                                        isSelected: isSelected,
                                      );
                                    }).toList(),
                                  ),
                                ),
                              );
                            },
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

        // Gear/settings icon overlay at top-right
        Positioned(
          top: 4,
          right: 4,
          child: SizedBox(
            width: 30,
            height: 30,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              icon: Icon(
                Icons.settings,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              tooltip: 'Column settings',
              onPressed: () => showTableColumnPicker(context),
            ),
          ),
        ),
      ],
    );
  }
}
