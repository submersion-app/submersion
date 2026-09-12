import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_leading.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_entry_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_view.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/debounced_search_results.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_type_order.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/domain/models/equipment_arrangement.dart';
import 'package:submersion/features/equipment/domain/models/equipment_filter_state.dart';
import 'package:submersion/features/equipment/domain/services/equipment_arranger.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_arrangement_provider.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_component_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/assembly_chips.dart';
import 'package:submersion/features/equipment/presentation/widgets/dense_equipment_list_tile.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_filter_sheet.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_group_header.dart';
import 'package:submersion/features/equipment/presentation/widgets/equipment_list_sort_sheet.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_enum_display.dart';

/// Content widget for the equipment list, used in master-detail layout.
class EquipmentListContent extends ConsumerStatefulWidget {
  final void Function(String?)? onItemSelected;
  final String? selectedId;
  final bool showAppBar;
  final Widget? floatingActionButton;
  final Widget? headerExtension;

  const EquipmentListContent({
    super.key,
    this.onItemSelected,
    this.selectedId,
    this.showAppBar = true,
    this.floatingActionButton,
    this.headerExtension,
  });

  @override
  ConsumerState<EquipmentListContent> createState() =>
      _EquipmentListContentState();
}

class _EquipmentListContentState extends ConsumerState<EquipmentListContent> {
  /// Owns the bulk-selection state machine for this list.
  final SelectionController _selection = SelectionController();

  /// Convenience mirrors of the controller, so the widget tree reads clearly.
  bool get _isSelectionMode => _selection.value.isActive;
  Set<String> get _selectedIds => _selection.value.checkedIds;

  final ScrollController _scrollController = ScrollController();
  String? _lastScrolledToId;

  /// The type axis the rows had when [_lastScrolledToId] was brought into
  /// view. The arrangement starts at the defaults and adopts the stored one
  /// a moment later, so the first scroll can be positioned for an order the
  /// list is about to leave; a different type axis here means the row has
  /// moved and must be scrolled to again.
  ///
  /// Only the type axis (and the locale, which reorders alphabetical
  /// headings): the page orders items by its own sort, so the arrangement's
  /// item sort (a dive-surface setting) moves no row here, and re-scrolling
  /// on it would yank the diver back to the selected row.
  Object? _scrolledTypeAxis;

  /// The type axis the list was last built with, for [didUpdateWidget],
  /// which runs before the next build and outside it.
  Object? _currentTypeAxis;
  bool _selectionFromList = false;

  @override
  void dispose() {
    _scrollController.dispose();
    _selection.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(EquipmentListContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId != null &&
        widget.selectedId != oldWidget.selectedId &&
        widget.selectedId != _lastScrolledToId) {
      if (_selectionFromList) {
        _selectionFromList = false;
        _lastScrolledToId = widget.selectedId;
        _scrolledTypeAxis = _currentTypeAxis;
      }
      // External selection changes are handled by _buildEquipmentList
      // when the sorted data is available.
    }
  }

  /// What moves rows on this page: the arrangement's type axis, plus the
  /// locale when the types are ordered alphabetically, since that order
  /// sorts by the translated type name and a new language reorders it with
  /// no arrangement change. The curated orders and "none" ignore the labels,
  /// so there a language switch moves no row and must not re-scroll.
  ///
  /// With no type order the arranger ignores the grouping switch and the
  /// type direction as well, so they collapse to one key there.
  static Object _typeAxisOf(EquipmentArrangement arrangement, Locale locale) {
    if (arrangement.typeOrder == EquipmentTypeOrder.none) {
      return EquipmentTypeOrder.none;
    }
    return (
      arrangement.groupByType,
      arrangement.typeOrder,
      arrangement.typeOrderDescending,
      arrangement.typeOrder == EquipmentTypeOrder.alphabetical ? locale : null,
    );
  }

  /// Whether [mode] draws the shared arrangement: the card modes only.
  static bool _honoursArrangement(ListViewMode mode) =>
      mode == ListViewMode.detailed || mode == ListViewMode.compact;

  /// Orders the flat modes by the page sort alone: with no type order the
  /// arranger draws no headings and [arrangeEquipment]'s item comparator,
  /// always the page's here, is the only key.
  static const EquipmentArrangement _pageSortOnly = EquipmentArrangement(
    typeOrder: EquipmentTypeOrder.none,
    groupByType: false,
    itemSortField: EquipmentItemSortField.name,
    itemSortDirection: SortDirection.ascending,
  );

  /// Scroll the list to bring the row at [index] into view.
  ///
  /// Uses estimated heights (Card + ListTile ~ 80px, a type heading ~ 32px)
  /// since ListView.builder is lazy and off-screen rows have no context.
  /// Headings are sized separately because sizing them like items overshoots
  /// by the difference for every heading above the target, which in a
  /// grouped list is nearly one per item.
  void _scrollToIndex(
    List<_EquipmentListRow> rows,
    int index,
    String targetId,
    Object typeAxis,
  ) {
    if (!mounted || !_scrollController.hasClients) return;

    const estimatedItemHeight = 80.0;
    const estimatedHeadingHeight = 32.0;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final viewportHeight = _scrollController.position.viewportDimension;
    var rowTop = 0.0;
    for (final row in rows.take(index)) {
      rowTop += row is _EquipmentHeadingRow
          ? estimatedHeadingHeight
          : estimatedItemHeight;
    }
    final targetOffset = rowTop - (viewportHeight / 3);
    final clampedOffset = targetOffset.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _lastScrolledToId = targetId;
    _scrolledTypeAxis = typeAxis;
  }

  void _handleItemTap(EquipmentItem equipment) {
    ref.read(highlightedEquipmentIdProvider.notifier).state = equipment.id;
    if (widget.onItemSelected != null) {
      _selectionFromList = true;
      widget.onItemSelected!(equipment.id);
    } else {
      context.push('/equipment/${equipment.id}');
    }
  }

  /// Invalidate whatever provider the visible list is actually reading.
  /// Must mirror the selection in [build]: the default (no filter) view
  /// reads activeEquipmentProvider, so invalidating only the status family
  /// would leave pull-to-refresh and error-retry showing stale rows.
  void _invalidateCurrentProvider(WidgetRef ref) {
    final filter = ref.read(equipmentFilterProvider);
    if (filter.serviceDueOnly) {
      // The service-due list derives from the clock evaluation, so refresh
      // that base rather than the leaf, which would replay cached verdicts.
      ref.invalidate(activeEquipmentClocksProvider);
    } else if (filter.status == null) {
      ref.invalidate(activeEquipmentProvider);
    } else {
      ref.invalidate(equipmentByStatusProvider(filter.status!));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sort = ref.watch(equipmentSortProvider);
    final viewMode = ref.watch(equipmentListViewModeProvider);
    // The urgency map drives the Service Due sort and (in table mode) the
    // forecast columns, and it evaluates clocks for all active gear -- so only
    // watch it when needed, not on the common name and date sorts.
    final needsUrgency =
        viewMode == ListViewMode.table ||
        sort.field == EquipmentSortField.serviceDue;
    final serviceUrgency = needsUrgency
        ? (ref.watch(equipmentServiceUrgencyProvider).value ??
              const <String, ServiceClockStatus>{})
        : const <String, ServiceClockStatus>{};

    final filter = ref.watch(equipmentFilterProvider);

    final AsyncValue<List<EquipmentItem>> equipmentAsync;
    if (filter.serviceDueOnly) {
      equipmentAsync = ref.watch(serviceDueEquipmentProvider);
    } else if (filter.status == null) {
      // The default view hides retired gear; the Retired status filter is
      // the way to see it (#636).
      equipmentAsync = ref.watch(activeEquipmentProvider);
    } else {
      equipmentAsync = ref.watch(equipmentByStatusProvider(filter.status!));
    }

    // Table mode uses a dedicated scaffold with column configuration support.
    if (viewMode == ListViewMode.table) {
      final sortedAsync = equipmentAsync.whenData(
        (equipment) => applyEquipmentSorting(
          filter.applyType(equipment),
          sort,
          serviceUrgency: serviceUrgency,
        ),
      );
      return _buildTableModeScaffold(
        context,
        sortedAsync,
        filter,
        hadItemsBeforeTypeFilter:
            (equipmentAsync.value ?? const <EquipmentItem>[]).isNotEmpty,
      );
    }

    // The list honours the gear arrangement every gear surface shares: its
    // type axis groups and orders the headings, while the page's own sort
    // (which alone offers Service Due) orders the gear inside each group.
    // Only the card modes do: Dense is a single-row flat layout (not offered
    // for gear, but a value stored by an older build can still select it),
    // so it stays flat on the page sort, as the table does.
    final arrangement = _honoursArrangement(viewMode)
        ? ref.watch(equipmentArrangementProvider)
        : _pageSortOnly;
    final compareItems = equipmentSortComparator(
      sort,
      serviceUrgency: serviceUrgency,
    );
    // The visible list depends on which status filter is active, so derive
    // selectable ids from the same branch the list renders, in the order it
    // renders them.
    //
    // Arranged once per build, here, and reused by the list below: that list
    // is rebuilt inside the selection listener on every check toggle, and
    // re-sorting the whole inventory there made bulk selection cost a full
    // sort per tap.
    final visibleGroups = arrangeEquipment(
      filter.applyType(equipmentAsync.value ?? const <EquipmentItem>[]),
      arrangement,
      typeLabel: (t) => t.localizedName(context.l10n),
      compareItems: compareItems,
    );
    final sortedVisible = [for (final group in visibleGroups) ...group.items];
    final visibleIds = sortedVisible.map((e) => e.id).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selection.pruneTo(visibleIds);
    });

    // Built inside the selection listener below so rows re-render as checks
    // change; computing it here would leave the list frozen mid-selection.
    Widget buildContent() {
      return equipmentAsync.when(
        // `equipment` is `equipmentAsync.value`, which visibleGroups was
        // arranged from.
        data: (equipment) => visibleGroups.isEmpty
            ? _buildEmptyState(
                context,
                ref,
                hadItemsBeforeTypeFilter: equipment.isNotEmpty,
              )
            : _buildEquipmentList(context, ref, visibleGroups, arrangement),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, error),
      );
    }

    if (!widget.showAppBar) {
      return SelectableListScope(
        controller: _selection,
        selectableIds: visibleIds,
        child: ValueListenableBuilder<SelectionState>(
          valueListenable: _selection,
          builder: (context, selection, _) => Column(
            children: [
              selection.isActive
                  ? _buildSelectionBar(sortedVisible, SelectionBarShell.pane)
                  : _buildCompactAppBar(context),
              if (widget.headerExtension != null) widget.headerExtension!,
              if (filter.hasActiveFilters)
                _buildActiveFiltersBar(context, filter),
              Expanded(child: buildContent()),
            ],
          ),
        ),
      );
    }

    return SelectableListScope(
      controller: _selection,
      selectableIds: visibleIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) => Scaffold(
          appBar: selection.isActive
              ? _buildSelectionBar(sortedVisible, SelectionBarShell.appBar)
              : AppBar(
                  title: FeatureAppBarTitle(
                    featureId: 'equipment',
                    title: context.l10n.equipment_appBar_title,
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: context.l10n.equipment_list_searchTooltip,
                      onPressed: () {
                        showSearch(
                          context: context,
                          delegate: EquipmentSearchDelegate(context.l10n),
                        );
                      },
                    ),
                    _buildFilterAction(context, filter),
                    IconButton(
                      icon: const Icon(Icons.sort),
                      tooltip: context.l10n.equipment_list_sortTooltip,
                      onPressed: () => _showSortSheet(context),
                    ),
                    // The only way into bulk actions: entry by long-press was removed,
                    // so nothing but this control opens selection mode on touch.
                    IconButton(
                      key: const ValueKey('enter_selection'),
                      icon: const Icon(Icons.checklist),
                      tooltip: context.l10n.common_selection_enterTooltip,
                      onPressed: _selection.enterExplicit,
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value.startsWith('view_')) {
                          final mode = ListViewMode.fromName(
                            value.replaceFirst('view_', ''),
                          );
                          ref
                                  .read(equipmentListViewModeProvider.notifier)
                                  .state =
                              mode;
                        }
                      },
                      itemBuilder: (context) {
                        final currentMode = ref.read(
                          equipmentListViewModeProvider,
                        );
                        return [
                          ...ListViewModeToggle.menuItems(
                            context,
                            currentMode: currentMode,
                            modes: const [
                              ListViewMode.detailed,
                              ListViewMode.compact,
                              ListViewMode.table,
                            ],
                          ),
                        ];
                      },
                    ),
                  ],
                ),
          body: Column(
            children: [
              if (filter.hasActiveFilters)
                _buildActiveFiltersBar(context, filter),
              Expanded(child: buildContent()),
            ],
          ),
          floatingActionButton: selection.isActive
              ? null
              : widget.floatingActionButton,
        ),
      ),
    );
  }

  /// Build the table content for table mode.
  ///
  /// When embedded inside [TableModeLayout], provides the filter chips and
  /// table content. The app bar, map, and column settings are managed by
  /// [TableModeLayout].
  /// Equipment-specific extras. Select-all, deselect-all and delete come from
  /// SelectionAppBar.
  ///
  /// Retire and reactivate are enabled only on a uniform selection -- every
  /// checked item active, or none of them -- so the action never has to guess
  /// what a mixed selection means.
  List<BulkAction> _bulkActions(List<EquipmentItem> equipment) {
    bool everyChecked(Set<String> ids, bool Function(EquipmentItem) test) {
      final checked = equipment.where((e) => ids.contains(e.id));
      return checked.isNotEmpty && checked.every(test);
    }

    return [
      BulkAction(
        id: 'retire',
        icon: Icons.archive,
        label: context.l10n.equipment_menu_retireEquipment,
        isEnabled: (ids) => everyChecked(ids, (e) => e.isActive),
        onInvoke: () => _applyRetirement(retire: true),
      ),
      BulkAction(
        id: 'reactivate',
        icon: Icons.unarchive,
        label: context.l10n.equipment_menu_reactivate,
        isEnabled: (ids) => everyChecked(ids, (e) => !e.isActive),
        onInvoke: () => _applyRetirement(retire: false),
      ),
    ];
  }

  SelectionAppBar _buildSelectionBar(
    List<EquipmentItem> equipment,
    SelectionBarShell shell,
  ) {
    return SelectionAppBar(
      controller: _selection,
      selectableIds: equipment.map((e) => e.id).toList(),
      actions: _bulkActions(equipment),
      shell: shell,
      maxInlineActions: shell == SelectionBarShell.pane ? 1 : 3,
      onDelete: _confirmAndDelete,
    );
  }

  /// Retire or reactivate every checked item, mirroring the per-item actions
  /// on the detail page.
  Future<BulkActionOutcome> _applyRetirement({required bool retire}) async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return BulkActionOutcome.cancelled;

    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(equipmentListNotifierProvider.notifier);
    _selection.exit();

    for (final id in ids) {
      if (retire) {
        await notifier.retireEquipment(id);
      } else {
        await notifier.reactivateEquipment(id);
      }
    }

    if (!mounted) return BulkActionOutcome.completed;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          retire
              ? context.l10n.equipment_snackbar_retired
              : context.l10n.equipment_snackbar_reactivated,
        ),
      ),
    );
    return BulkActionOutcome.completed;
  }

  Future<BulkActionOutcome> _confirmAndDelete() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return BulkActionOutcome.cancelled;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.common_bulkDelete_title(ids.length)),
        content: Text(ctx.l10n.common_bulkDelete_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(ctx.l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return BulkActionOutcome.cancelled;

    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(equipmentListNotifierProvider.notifier);
    _selection.exit();

    for (final id in ids) {
      await notifier.deleteEquipment(id);
    }

    if (!mounted) return BulkActionOutcome.completed;
    messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.common_bulkDelete_snackbar(ids.length)),
      ),
    );
    return BulkActionOutcome.completed;
  }

  /// One tap policy for every equipment row.
  void _handleRowTap(EquipmentItem item) {
    if (SelectableListScope.isModifierPressed()) {
      _selection.enterImplicit(item.id);
      return;
    }
    if (_isSelectionMode) {
      _selection.toggle(item.id);
      return;
    }
    _handleItemTap(item);
  }

  Widget _buildTableModeScaffold(
    BuildContext context,
    AsyncValue<List<EquipmentItem>> equipmentAsync,
    EquipmentFilterState filter, {
    required bool hadItemsBeforeTypeFilter,
  }) {
    final visibleIds = (equipmentAsync.value ?? const <EquipmentItem>[])
        .map((e) => e.id)
        .toList();

    // Same pruning the list path does: drop checked items that fell out of
    // the visible list, so the count always matches what is on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selection.pruneTo(visibleIds);
    });

    // The scope carries Escape, Ctrl/Cmd-A and the Android back handling, and
    // the builder is what repaints the table as checks change -- the table is
    // built inside it for that reason.
    return SelectableListScope(
      controller: _selection,
      selectableIds: visibleIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) => Column(
          children: [
            if (widget.headerExtension != null) widget.headerExtension!,
            // Table mode has no app bar of its own, so both bars live here:
            // the contextual one while selecting, and the Select affordance
            // while not. They share a slot and a height, so the table does
            // not shift as the mode opens.
            if (selection.isActive)
              _buildSelectionBar(
                equipmentAsync.value ?? const <EquipmentItem>[],
                SelectionBarShell.pane,
              )
            else
              SelectionEntryBar(controller: _selection),
            if (filter.hasActiveFilters)
              _buildActiveFiltersBar(context, filter),
            Expanded(
              child: _buildTableView(
                context,
                equipmentAsync,
                hadItemsBeforeTypeFilter: hadItemsBeforeTypeFilter,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build the [EntityTableView] for equipment table mode.
  Widget _buildTableView(
    BuildContext context,
    AsyncValue<List<EquipmentItem>> equipmentAsync, {
    required bool hadItemsBeforeTypeFilter,
  }) {
    return equipmentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => _buildErrorState(context, e),
      data: (equipment) {
        if (equipment.isEmpty) {
          return _buildEmptyState(
            context,
            ref,
            hadItemsBeforeTypeFilter: hadItemsBeforeTypeFilter,
          );
        }
        final config = ref.watch(equipmentTableConfigProvider);
        final notifier = ref.read(equipmentTableConfigProvider.notifier);
        final settings = ref.watch(settingsProvider);
        final units = UnitFormatter(settings);
        // Table columns read the rollup (issue #1487) so an assembly's next
        // service date is its earliest part's, and gain a components count.
        final rollup =
            ref.watch(equipmentRollupClockProvider).value ?? const {};
        final index =
            ref.watch(equipmentComponentsIndexProvider).value ??
            ComponentsIndex.empty;

        return EntityTableView<EquipmentItem, EquipmentField>(
          entities: equipment,
          idExtractor: (e) => e.id,
          adapter: EquipmentFieldAdapter(
            worstClocks: {
              for (final e in rollup.entries) e.key: e.value.status,
            },
            componentCounts: {
              for (final e in index.byParent.entries) e.key: e.value.length,
            },
          ),
          config: config,
          units: units,
          onSortFieldChanged: notifier.setSortField,
          onResizeColumn: notifier.resizeColumn,
          onEntityTapDown: (id) {
            ref.read(highlightedEquipmentIdProvider.notifier).state = id;
          },
          onEntityTap: (id) {
            if (_isSelectionMode) _selection.toggle(id);
          },
          selectedIds: _selectedIds,
          isSelectionMode: _isSelectionMode,
          onEntityDoubleTap: (id) {
            context.push('/equipment/$id');
          },
          highlightedId: ref.watch(highlightedEquipmentIdProvider),
        );
      },
    );
  }

  Widget _buildCompactAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          // Expanded, and no Spacer: the title must be the row's only flexible
          // child, or Spacer takes half the free space and the leftover half
          // lands after the last icon (see trip_list_content for the detail).
          Expanded(
            child: FeatureAppBarTitle(
              featureId: 'equipment',
              title: context.l10n.equipment_appBar_title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            tooltip: context.l10n.equipment_list_searchTooltip,
            onPressed: () {
              showSearch(
                context: context,
                delegate: EquipmentSearchDelegate(context.l10n),
              );
            },
          ),
          _buildFilterAction(
            context,
            ref.watch(equipmentFilterProvider),
            iconSize: 20,
          ),
          IconButton(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: context.l10n.equipment_list_sortTooltip,
            onPressed: () => _showSortSheet(context),
          ),
          // The only way into bulk actions: entry by long-press was removed,
          // so nothing but this control opens selection mode on touch.
          IconButton(
            key: const ValueKey('enter_selection'),
            icon: const Icon(Icons.checklist, size: 20),
            tooltip: context.l10n.common_selection_enterTooltip,
            onPressed: _selection.enterExplicit,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) {
              if (value.startsWith('view_')) {
                final mode = ListViewMode.fromName(
                  value.replaceFirst('view_', ''),
                );
                ref.read(equipmentListViewModeProvider.notifier).state = mode;
              }
            },
            itemBuilder: (context) {
              final currentMode = ref.read(equipmentListViewModeProvider);
              return [
                ...ListViewModeToggle.menuItems(
                  context,
                  currentMode: currentMode,
                  modes: const [
                    ListViewMode.detailed,
                    ListViewMode.compact,
                    ListViewMode.table,
                  ],
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    // The flat modes (table, dense) ignore the grouping, so their sheet
    // leaves it out.
    showEquipmentListSortSheet(
      context,
      showGrouping: _honoursArrangement(
        ref.read(equipmentListViewModeProvider),
      ),
    );
  }

  /// The top-bar entry point to the filter panel, badged while anything is
  /// narrowed -- the same affordance the dive and site lists use.
  Widget _buildFilterAction(
    BuildContext context,
    EquipmentFilterState filter, {
    double? iconSize,
  }) {
    return IconButton(
      key: const ValueKey('equipment_filter_button'),
      icon: Badge(
        isLabelVisible: filter.hasActiveFilters,
        child: Icon(Icons.filter_list, size: iconSize),
      ),
      tooltip: context.l10n.equipment_list_filterTooltip,
      onPressed: () => showEquipmentFilterSheet(context, ref),
    );
  }

  /// Shown above the list only while a filter is on: the panel hides what is
  /// active, so this bar is what says so -- and what makes each axis
  /// removable without reopening the panel.
  Widget _buildActiveFiltersBar(
    BuildContext context,
    EquipmentFilterState filter,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ActionChip(
              key: const ValueKey('equipment_activeFilter_clearAll'),
              avatar: const Icon(Icons.clear_all, size: 18),
              label: Text(context.l10n.equipment_list_activeFilter_clear),
              onPressed: () {
                ref.read(equipmentFilterProvider.notifier).state =
                    const EquipmentFilterState();
              },
            ),
            const SizedBox(width: 8),
            if (filter.serviceDueOnly)
              _buildActiveFilterChip(
                context.l10n.equipment_list_filterServiceDue,
                () => ref.read(equipmentFilterProvider.notifier).state = filter
                    .copyWith(clearStatus: true),
              ),
            if (filter.status != null)
              _buildActiveFilterChip(
                filter.status!.localizedName(context.l10n),
                () => ref.read(equipmentFilterProvider.notifier).state = filter
                    .copyWith(clearStatus: true),
              ),
            if (filter.type != null)
              _buildActiveFilterChip(
                filter.type!.localizedName(context.l10n),
                () => ref.read(equipmentFilterProvider.notifier).state = filter
                    .copyWith(clearType: true),
                icon: equipmentTypeIcon(filter.type!),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveFilterChip(
    String label,
    VoidCallback onDeleted, {
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InputChip(
        avatar: icon == null ? null : Icon(icon, size: 18),
        label: Text(label),
        onDeleted: onDeleted,
        deleteIconColor: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildEquipmentList(
    BuildContext context,
    WidgetRef ref,
    List<EquipmentGroup> groups,
    EquipmentArrangement arrangement,
  ) {
    // One flat run of rows for the lazy builder: a heading before each group
    // when the arrangement groups, then that group's gear.
    final rows = <_EquipmentListRow>[
      for (final group in groups) ...[
        if (group.type != null) _EquipmentHeadingRow(group.type!),
        for (final item in group.items) _EquipmentItemRow(item),
      ],
    ];

    // Scroll to selected item when data is available but we haven't
    // scrolled yet (e.g., navigated from dive detail or set detail), or when
    // the arrangement has moved it since (the stored arrangement landing
    // after the first frame, or the diver regrouping). The index counts
    // heading rows too, since they take space above the item.
    final selectedId = widget.selectedId;
    final typeAxis = _typeAxisOf(arrangement, Localizations.localeOf(context));
    _currentTypeAxis = typeAxis;
    if (selectedId != null &&
        (selectedId != _lastScrolledToId || typeAxis != _scrolledTypeAxis) &&
        !_selectionFromList) {
      final selectedIndex = rows.indexWhere(
        (row) => row is _EquipmentItemRow && row.item.id == selectedId,
      );
      if (selectedIndex >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // These rows were laid out for this selection. If it changed before
          // the callback ran, scrolling now would move to the old row and
          // mark the new one as done; the newer build schedules its own.
          if (widget.selectedId != selectedId) return;
          _scrollToIndex(rows, selectedIndex, selectedId, typeAxis);
        });
      }
    }
    return RefreshIndicator(
      onRefresh: () async {
        _invalidateCurrentProvider(ref);
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: rows.length,
        itemBuilder: (context, index) {
          final EquipmentItem item;
          switch (rows[index]) {
            case _EquipmentHeadingRow(:final type):
              return Padding(
                // Level with the card edges below it.
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: EquipmentGroupHeader(type: type),
              );
            case _EquipmentItemRow(item: final rowItem):
              item = rowItem;
          }
          final isSelected =
              widget.selectedId == item.id ||
              ref.watch(highlightedEquipmentIdProvider) == item.id;
          final viewMode = ref.watch(equipmentListViewModeProvider);
          final isChecked = _selectedIds.contains(item.id);
          void onCheckChanged(bool _) => _selection.toggle(item.id);
          return switch (viewMode) {
            ListViewMode.detailed || ListViewMode.compact => EquipmentListTile(
              item: item,
              isSelected: isSelected,
              onTap: () => _handleRowTap(item),
              isSelectionMode: _isSelectionMode,
              isChecked: isChecked,
              onCheckChanged: onCheckChanged,
            ),
            ListViewMode.dense || ListViewMode.table => DenseEquipmentListTile(
              item: item,
              isSelected: isSelected,
              onTap: () => _handleRowTap(item),
              isSelectionMode: _isSelectionMode,
              isChecked: isChecked,
              onCheckChanged: onCheckChanged,
            ),
          };
        },
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    WidgetRef ref, {
    required bool hadItemsBeforeTypeFilter,
  }) {
    final filter = ref.watch(equipmentFilterProvider);

    // Blame the category only when it actually narrowed something away; if
    // the status-filtered source was already empty, the status (or the lack
    // of any gear) is the real cause and the wording should say so.
    final blameCategory = filter.type != null && hadItemsBeforeTypeFilter;

    String filterText;
    if (blameCategory) {
      filterText = context.l10n.equipment_list_emptyState_filterText_type(
        filter.type!.localizedName(context.l10n),
      );
    } else if (filter.serviceDueOnly) {
      filterText = context.l10n.equipment_list_emptyState_filterText_serviceDue;
    } else if (filter.status == null) {
      filterText = context.l10n.equipment_list_emptyState_filterText_equipment;
    } else {
      filterText = context.l10n.equipment_list_emptyState_filterText_status(
        filter.status!.localizedName(context.l10n).toLowerCase(),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.backpack,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.equipment_list_emptyState_noEquipment(filterText),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            blameCategory
                ? context.l10n.equipment_list_emptyState_noTypeMatch
                : filter.serviceDueOnly
                ? context.l10n.equipment_list_emptyState_serviceDueUpToDate
                : filter.status != null
                ? context.l10n.equipment_list_emptyState_noStatusMatch
                : context.l10n.equipment_list_emptyState_addPrompt,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (!filter.hasActiveFilters) ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                if (ResponsiveBreakpoints.isMasterDetail(context)) {
                  final routerState = GoRouterState.of(context);
                  context.go('${routerState.uri.path}?mode=new');
                } else {
                  context.push('/equipment/new');
                }
              },
              icon: const Icon(Icons.add),
              label: Text(
                context.l10n.equipment_list_emptyState_addFirstButton,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(context.l10n.equipment_list_errorLoading('$error')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => _invalidateCurrentProvider(ref),
            child: Text(context.l10n.equipment_list_retryButton),
          ),
        ],
      ),
    );
  }
}

/// List item widget for displaying equipment
class EquipmentListTile extends ConsumerWidget {
  final EquipmentItem item;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isSelectionMode;
  final bool isChecked;
  final ValueChanged<bool>? onCheckChanged;

  const EquipmentListTile({
    super.key,
    required this.item,
    this.isSelected = false,
    this.onTap,
    this.isSelectionMode = false,
    this.isChecked = false,
    this.onCheckChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // The rollup (issue #1487): a due part lights its assembly, and the
    // badge names the part. An ok rollup is no badge, as before.
    final rollup = ref.watch(equipmentRollupClockProvider).value?[item.id];
    final worstClock =
        rollup == null || rollup.status.severity == ServiceClockSeverity.ok
        ? null
        : rollup;
    final isOverdue =
        worstClock?.status.severity == ServiceClockSeverity.overdue;
    // A non-null subtitle forces the two-line tile layout, so only build one
    // when there is something to show: a differing full name, or chips.
    final index = ref.watch(equipmentComponentsIndexProvider).value;
    final hasChips =
        index != null &&
        (index.isAssembly(item.id) || index.parentIdsOf(item.id).isNotEmpty);
    final hasFullName = item.fullName != item.name;
    final accent = resolveFeatureAccent(
      context,
      ref,
      surface: AccentSurface.list,
      featureId: 'equipment',
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: isSelected
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
          : null,
      child: ListTile(
        onTap: onTap,
        leading: SelectionLeading(
          isSelectionMode: isSelectionMode,
          isChecked: isChecked,
          onChanged: onCheckChanged,
          child: CircleAvatar(
            // An overdue service is a status signal, so it keeps the error
            // colors even with accents on -- a cosmetic preference must not
            // hide a service warning.
            backgroundColor: isOverdue
                ? theme.colorScheme.errorContainer
                : accent?.withValues(alpha: 0.15) ??
                      theme.colorScheme.tertiaryContainer,
            child: Icon(
              equipmentTypeIcon(item.type),
              color: isOverdue
                  ? theme.colorScheme.onErrorContainer
                  : accent ?? theme.colorScheme.onTertiaryContainer,
            ),
          ),
        ),
        title: Text(item.name),
        subtitle: hasFullName || hasChips
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasFullName) Text(item.fullName),
                  if (hasChips) AssemblyChips(itemId: item.id),
                ],
              )
            : null,
        trailing: _buildTrailing(context, worstClock),
      ),
    );
  }

  Widget _buildTrailing(BuildContext context, RollupClock? worstClock) {
    final theme = Theme.of(context);

    final typeLabel = Text(
      item.type.localizedName(context.l10n),
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    if (worstClock != null) {
      final overdue =
          worstClock.status.severity == ServiceClockSeverity.overdue;
      final kindLabel = worstClock.ownerId == item.id
          ? worstClock.status.kind.name
          : context.l10n.equipment_components_rollupClock(
              worstClock.ownerName,
              worstClock.status.kind.name,
            );
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          typeLabel,
          const SizedBox(height: 2),
          Text(
            overdue
                ? context.l10n.equipment_list_worstClock(kindLabel)
                : kindLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: overdue
                  ? theme.colorScheme.error
                  : theme.colorScheme.tertiary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }

    if (item.status != EquipmentStatus.active) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          typeLabel,
          const SizedBox(height: 2),
          Text(
            item.status.localizedName(context.l10n),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return typeLabel;
  }
}

/// Search delegate for equipment
class EquipmentSearchDelegate extends SearchDelegate<EquipmentItem?> {
  EquipmentSearchDelegate(this._l10n);

  final AppLocalizations _l10n;

  @override
  String get searchFieldLabel => _l10n.equipment_search_fieldLabel;

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: _l10n.equipment_search_clearTooltip,
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: _l10n.equipment_search_backTooltip,
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search,
              size: 64,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              _l10n.equipment_search_hint,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return DebouncedSearchResults<EquipmentItem>(
      query: query,
      watchProvider: (ref, q) => ref.watch(equipmentSearchProvider(q)),
      dataBuilder: (context, equipment) {
        return ListView.builder(
          itemCount: equipment.length,
          itemBuilder: (context, index) {
            final item = equipment[index];
            return EquipmentListTile(
              item: item,
              onTap: () {
                close(context, item);
                context.push('/equipment/${item.id}');
              },
            );
          },
        );
      },
      emptyBuilder: (context, query) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Theme.of(
                  context,
                ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _l10n.equipment_search_noResults(query),
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
      errorBuilder: (context, error) {
        return Center(child: Text(_l10n.equipment_list_errorLoading(error)));
      },
    );
  }
}

/// One row of the lazily built equipment list: a type heading or an item.
sealed class _EquipmentListRow {
  const _EquipmentListRow();
}

class _EquipmentHeadingRow extends _EquipmentListRow {
  const _EquipmentHeadingRow(this.type);

  final EquipmentType type;
}

class _EquipmentItemRow extends _EquipmentListRow {
  const _EquipmentItemRow(this.item);

  final EquipmentItem item;
}
