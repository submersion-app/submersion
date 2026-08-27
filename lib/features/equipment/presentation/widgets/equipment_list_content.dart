import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/features/equipment/presentation/utils/equipment_type_icon.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
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
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_field.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/domain/entities/service_clock_status.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/equipment/presentation/widgets/dense_equipment_list_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

/// Special filter value for computed "service due" items
const String _serviceDueFilter = '_service_due_';

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
  bool _selectionFromList = false;
  Object? _selectedFilter;

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
      }
      // External selection changes are handled by _buildEquipmentList
      // when the sorted data is available.
    }
  }

  /// Scroll the list to bring the item at [index] into view.
  ///
  /// Uses an estimated item height (Card + ListTile ~ 80px) since
  /// ListView.builder is lazy and off-screen items have no context.
  void _scrollToIndex(int index) {
    if (!mounted || !_scrollController.hasClients) return;

    const estimatedItemHeight = 80.0;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final viewportHeight = _scrollController.position.viewportDimension;
    final targetOffset = (index * estimatedItemHeight) - (viewportHeight / 3);
    final clampedOffset = targetOffset.clamp(0.0, maxScroll);

    _scrollController.animateTo(
      clampedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    _lastScrolledToId = widget.selectedId;
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
    if (_selectedFilter == _serviceDueFilter) {
      ref.invalidate(serviceDueEquipmentProvider);
    } else if (_selectedFilter == null) {
      ref.invalidate(activeEquipmentProvider);
    } else {
      ref.invalidate(
        equipmentByStatusProvider(_selectedFilter as EquipmentStatus),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sort = ref.watch(equipmentSortProvider);
    final viewMode = ref.watch(equipmentListViewModeProvider);
    // The urgency map drives the Service Due sort and (in table mode) the
    // forecast columns, and it evaluates clocks for all active gear -- so only
    // watch it when needed, not on the common name/type list sorts.
    final needsUrgency =
        viewMode == ListViewMode.table ||
        sort.field == EquipmentSortField.serviceDue;
    final serviceUrgency = needsUrgency
        ? (ref.watch(equipmentServiceUrgencyProvider).value ??
              const <String, ServiceClockStatus>{})
        : const <String, ServiceClockStatus>{};

    final AsyncValue<List<EquipmentItem>> equipmentAsync;
    if (_selectedFilter == _serviceDueFilter) {
      equipmentAsync = ref.watch(serviceDueEquipmentProvider);
    } else if (_selectedFilter == null) {
      // The default view hides retired gear; the Retired status filter is
      // the way to see it (#636).
      equipmentAsync = ref.watch(activeEquipmentProvider);
    } else {
      final status = _selectedFilter as EquipmentStatus;
      equipmentAsync = ref.watch(equipmentByStatusProvider(status));
    }

    // Table mode uses a dedicated scaffold with column configuration support.
    if (viewMode == ListViewMode.table) {
      final sortedAsync = equipmentAsync.whenData(
        (equipment) => applyEquipmentSorting(
          equipment,
          sort,
          serviceUrgency: serviceUrgency,
        ),
      );
      return _buildTableModeScaffold(context, sortedAsync);
    }

    // The visible list depends on which status filter is active, so derive
    // selectable ids from the same branch the list renders.
    final sortedVisible = applyEquipmentSorting(
      equipmentAsync.value ?? const <EquipmentItem>[],
      sort,
      serviceUrgency: serviceUrgency,
    );
    final visibleIds = sortedVisible.map((e) => e.id).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selection.pruneTo(visibleIds);
    });

    // Built inside the selection listener below so rows re-render as checks
    // change; computing it here would leave the list frozen mid-selection.
    Widget buildContent() {
      return equipmentAsync.when(
        data: (equipment) {
          final sorted = applyEquipmentSorting(
            equipment,
            sort,
            serviceUrgency: serviceUrgency,
          );
          return sorted.isEmpty
              ? _buildEmptyState(context, ref)
              : _buildEquipmentList(context, ref, sorted);
        },
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
              _buildFilterChips(context),
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
              _buildFilterChips(context),
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
  Future<void> _applyRetirement({required bool retire}) async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;

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

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          retire
              ? context.l10n.equipment_snackbar_retired
              : context.l10n.equipment_snackbar_reactivated,
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;

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
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(equipmentListNotifierProvider.notifier);
    _selection.exit();

    for (final id in ids) {
      await notifier.deleteEquipment(id);
    }

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.common_bulkDelete_snackbar(ids.length)),
      ),
    );
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
  ) {
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
            _buildFilterChips(context),
            Expanded(child: _buildTableView(context, equipmentAsync)),
          ],
        ),
      ),
    );
  }

  /// Build the [EntityTableView] for equipment table mode.
  Widget _buildTableView(
    BuildContext context,
    AsyncValue<List<EquipmentItem>> equipmentAsync,
  ) {
    return equipmentAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => _buildErrorState(context, e),
      data: (equipment) {
        if (equipment.isEmpty) {
          return _buildEmptyState(context, ref);
        }
        final config = ref.watch(equipmentTableConfigProvider);
        final notifier = ref.read(equipmentTableConfigProvider.notifier);
        final settings = ref.watch(settingsProvider);
        final units = UnitFormatter(settings);
        final serviceUrgency =
            ref.watch(equipmentServiceUrgencyProvider).value ?? const {};

        return EntityTableView<EquipmentItem, EquipmentField>(
          entities: equipment,
          idExtractor: (e) => e.id,
          adapter: EquipmentFieldAdapter(worstClocks: serviceUrgency),
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
    final sort = ref.read(equipmentSortProvider);
    showSortBottomSheet<EquipmentSortField>(
      context: context,
      title: context.l10n.equipment_list_sortTitle,
      currentField: sort.field,
      currentDirection: sort.direction,
      fields: EquipmentSortField.values,
      getFieldDisplayName: (field) => field.localizedName(context.l10n),
      getFieldIcon: (field) => field.icon,
      onSortChanged: (field, direction) {
        ref.read(equipmentSortProvider.notifier).state = SortState(
          field: field,
          direction: direction,
        );
      },
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(
            Icons.filter_list,
            size: 20,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Text(
            context.l10n.equipment_list_filterLabel,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.outline.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DropdownButton<Object?>(
                value: _selectedFilter,
                underline: const SizedBox(),
                focusColor: Colors.transparent,
                isExpanded: true,
                items: [
                  DropdownMenuItem<Object?>(
                    value: null,
                    child: Text(context.l10n.equipment_list_filterAll),
                  ),
                  DropdownMenuItem<Object?>(
                    value: _serviceDueFilter,
                    child: Text(context.l10n.equipment_list_filterServiceDue),
                  ),
                  ...EquipmentStatus.values
                      .where((status) => status != EquipmentStatus.needsService)
                      .map((status) {
                        return DropdownMenuItem<Object?>(
                          value: status,
                          child: Text(status.displayName),
                        );
                      }),
                ],
                onChanged: (value) {
                  setState(() => _selectedFilter = value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEquipmentList(
    BuildContext context,
    WidgetRef ref,
    List<EquipmentItem> equipment,
  ) {
    // Scroll to selected item when data is available but we haven't
    // scrolled yet (e.g., navigated from dive detail or set detail).
    if (widget.selectedId != null &&
        widget.selectedId != _lastScrolledToId &&
        !_selectionFromList) {
      final selectedIndex = equipment.indexWhere(
        (e) => e.id == widget.selectedId,
      );
      if (selectedIndex >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToIndex(selectedIndex);
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
        itemCount: equipment.length,
        itemBuilder: (context, index) {
          final item = equipment[index];
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

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    String filterText;
    if (_selectedFilter == null) {
      filterText = context.l10n.equipment_list_emptyState_filterText_equipment;
    } else if (_selectedFilter == _serviceDueFilter) {
      filterText = context.l10n.equipment_list_emptyState_filterText_serviceDue;
    } else {
      filterText = context.l10n.equipment_list_emptyState_filterText_status(
        (_selectedFilter as EquipmentStatus).displayName.toLowerCase(),
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
            _selectedFilter == null
                ? context.l10n.equipment_list_emptyState_addPrompt
                : _selectedFilter == _serviceDueFilter
                ? context.l10n.equipment_list_emptyState_serviceDueUpToDate
                : context.l10n.equipment_list_emptyState_noStatusMatch,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          if (_selectedFilter == null) ...[
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
    final worstClock = ref.watch(equipmentWorstClockProvider).value?[item.id];
    final isOverdue =
        worstClock?.status.severity == ServiceClockSeverity.overdue;
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
        subtitle: item.fullName != item.name ? Text(item.fullName) : null,
        trailing: _buildTrailing(context, worstClock),
      ),
    );
  }

  Widget _buildTrailing(BuildContext context, DueClock? worstClock) {
    final theme = Theme.of(context);

    final typeLabel = Text(
      item.type.displayName,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    if (worstClock != null) {
      final overdue =
          worstClock.status.severity == ServiceClockSeverity.overdue;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          typeLabel,
          const SizedBox(height: 2),
          Text(
            overdue
                ? context.l10n.equipment_list_worstClock(
                    worstClock.status.kind.name,
                  )
                : worstClock.status.kind.name,
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
            item.status.displayName,
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
