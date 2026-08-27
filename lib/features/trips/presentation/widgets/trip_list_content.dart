import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_view.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_leading.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_entry_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';
import 'package:submersion/features/trips/domain/constants/trip_field.dart';
import 'package:submersion/features/trips/domain/entities/trip.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/features/trips/presentation/widgets/compact_trip_list_tile.dart';
import 'package:submersion/features/trips/presentation/widgets/dense_trip_list_tile.dart';
import 'package:submersion/features/trips/presentation/widgets/upcoming_trip_banner.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

/// Content widget for the trip list, used in master-detail layout.
class TripListContent extends ConsumerStatefulWidget {
  final void Function(String?)? onItemSelected;
  final String? selectedId;
  final bool showAppBar;
  final Widget? floatingActionButton;

  const TripListContent({
    super.key,
    this.onItemSelected,
    this.selectedId,
    this.showAppBar = true,
    this.floatingActionButton,
  });

  @override
  ConsumerState<TripListContent> createState() => _TripListContentState();
}

class _TripListContentState extends ConsumerState<TripListContent> {
  /// Owns the bulk-selection state machine for this list.
  final SelectionController _selection = SelectionController();

  /// Convenience mirrors of the controller, so the widget tree reads clearly.
  bool get _isSelectionMode => _selection.value.isActive;
  Set<String> get _selectedIds => _selection.value.checkedIds;

  final ScrollController _scrollController = ScrollController();
  String? _lastScrolledToId;
  bool _selectionFromList = false;

  @override
  void initState() {
    super.initState();
    if (widget.selectedId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToSelectedItem();
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _selection.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TripListContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedId != null &&
        widget.selectedId != oldWidget.selectedId &&
        widget.selectedId != _lastScrolledToId) {
      if (_selectionFromList) {
        _selectionFromList = false;
        _lastScrolledToId = widget.selectedId;
      } else {
        _scrollToSelectedItem();
      }
    }
  }

  void _scrollToSelectedItem() {
    if (widget.selectedId == null) return;

    final tripsAsync = ref.read(tripListNotifierProvider);
    tripsAsync.whenData((trips) {
      final index = trips.indexWhere((t) => t.trip.id == widget.selectedId);
      if (index >= 0 && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_scrollController.hasClients || trips.isEmpty) return;

          final maxScroll = _scrollController.position.maxScrollExtent;
          final viewportHeight = _scrollController.position.viewportDimension;
          final totalContentHeight = maxScroll + viewportHeight - 80;
          final avgItemHeight = totalContentHeight / trips.length;
          final targetOffset = (index * avgItemHeight) - (viewportHeight / 3);
          final clampedOffset = targetOffset.clamp(0.0, maxScroll);

          _scrollController.animateTo(
            clampedOffset,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
          _lastScrolledToId = widget.selectedId;
        });
      }
    });
  }

  void _handleItemTap(Trip trip) {
    ref.read(highlightedTripIdProvider.notifier).state = trip.id;
    if (widget.onItemSelected != null) {
      _selectionFromList = true;
      widget.onItemSelected!(trip.id);
    } else {
      context.push('/trips/${trip.id}');
    }
  }

  void _showSortSheet(BuildContext context) {
    final sort = ref.read(tripSortProvider);

    showSortBottomSheet<TripSortField>(
      context: context,
      title: context.l10n.trips_list_sort_title,
      currentField: sort.field,
      currentDirection: sort.direction,
      fields: TripSortField.values,
      getFieldDisplayName: (field) => field.localizedName(context.l10n),
      getFieldIcon: (field) => field.icon,
      onSortChanged: (field, direction) {
        ref.read(tripSortProvider.notifier).state = SortState(
          field: field,
          direction: direction,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(tripFilterProvider);
    final tripsAsync = ref.watch(sortedFilteredTripsProvider);
    final viewMode = ref.watch(tripListViewModeProvider);

    // Table mode uses a dedicated scaffold with column configuration support.
    if (viewMode == ListViewMode.table) {
      return _buildTableModeScaffold(context, tripsAsync, filter);
    }

    // Built inside the selection listener below so rows re-render as checks
    // change; computing it here would leave the list frozen mid-selection.
    Widget buildContent() {
      return tripsAsync.when(
        data: (trips) => trips.isEmpty
            ? _buildEmptyState(context, filter.hasActiveFilters)
            : _buildTripList(context, ref, trips, filter.hasActiveFilters),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, error),
      );
    }

    final loadedTrips = tripsAsync.value ?? const <TripWithStats>[];
    final visibleIds = loadedTrips.map((t) => t.trip.id).toList();

    // Drop checked trips that fell out of the filtered list, so a bulk action
    // can never reach a trip that is not on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selection.pruneTo(visibleIds);
    });

    if (!widget.showAppBar) {
      return SelectableListScope(
        controller: _selection,
        selectableIds: visibleIds,
        child: ValueListenableBuilder<SelectionState>(
          valueListenable: _selection,
          builder: (context, selection, _) => Column(
            children: [
              selection.isActive
                  ? _buildSelectionBar(loadedTrips, SelectionBarShell.pane)
                  : _buildCompactAppBar(context),
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
              ? _buildSelectionBar(loadedTrips, SelectionBarShell.appBar)
              : AppBar(
                  title: FeatureAppBarTitle(
                    featureId: 'trips',
                    title: context.l10n.trips_appBar_title,
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: context.l10n.trips_list_tooltip_search,
                      onPressed: () {
                        showSearch(
                          context: context,
                          delegate: TripSearchDelegate(context.l10n),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.sort),
                      tooltip: context.l10n.trips_list_tooltip_sort,
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
                          ref.read(tripListViewModeProvider.notifier).state =
                              mode;
                        }
                      },
                      itemBuilder: (context) {
                        final currentMode = ref.read(tripListViewModeProvider);
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
          body: buildContent(),
          floatingActionButton: selection.isActive
              ? null
              : widget.floatingActionButton,
        ),
      ),
    );
  }

  /// Build the table content for table mode.
  ///
  /// When embedded inside [TableModeLayout], provides only the table content.
  /// The app bar, map, and column settings are managed by [TableModeLayout].
  /// Trips offer no extras beyond the baseline.
  ///
  /// The per-trip export menu item is a stub -- both its CSV and PDF entries
  /// only show a "coming soon" snackbar (trip_detail_page.dart:573) -- so
  /// there is no working single-item action to lift into a bulk one.
  SelectionAppBar _buildSelectionBar(
    List<TripWithStats> trips,
    SelectionBarShell shell,
  ) {
    return SelectionAppBar(
      controller: _selection,
      selectableIds: trips.map((t) => t.trip.id).toList(),
      actions: const [],
      shell: shell,
      onDelete: _confirmAndDelete,
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
    final notifier = ref.read(tripListNotifierProvider.notifier);
    _selection.exit();

    for (final id in ids) {
      await notifier.deleteTrip(id);
    }

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.common_bulkDelete_snackbar(ids.length)),
      ),
    );
  }

  /// One tap policy for every trip row.
  ///
  /// A held modifier turns a tap into an implicit entry -- the one path
  /// that still evaporates at zero checked, since touch has no gesture
  /// entry left.
  void _handleRowTap(Trip trip) {
    if (SelectableListScope.isModifierPressed()) {
      _selection.enterImplicit(trip.id);
      return;
    }
    if (_isSelectionMode) {
      _selection.toggle(trip.id);
      return;
    }
    _handleItemTap(trip);
  }

  Widget _buildTableModeScaffold(
    BuildContext context,
    AsyncValue<List<TripWithStats>> tripsAsync,
    TripFilterState filter,
  ) {
    final loadedTrips = tripsAsync.value ?? const <TripWithStats>[];
    final visibleIds = loadedTrips.map((t) => t.trip.id).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selection.pruneTo(visibleIds);
    });

    return SelectableListScope(
      controller: _selection,
      selectableIds: visibleIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) {
          // Built inside the builder so the table's own rows re-render as
          // checks change; building it outside left them on a stale
          // selectedIds while only the bar updated.
          final tableContent = _buildTableView(context, tripsAsync, filter);

          // Table mode has no app bar of its own, so both bars live here: the
          // contextual one while selecting, and the Select affordance while
          // not. They share a slot and a height, so the table does not shift
          // as the mode opens.
          return Column(
            children: [
              if (selection.isActive)
                _buildSelectionBar(loadedTrips, SelectionBarShell.pane)
              else
                SelectionEntryBar(controller: _selection),
              Expanded(child: tableContent),
            ],
          );
        },
      ),
    );
  }

  /// Build the [EntityTableView] for trip table mode.
  Widget _buildTableView(
    BuildContext context,
    AsyncValue<List<TripWithStats>> tripsAsync,
    TripFilterState filter,
  ) {
    return tripsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => _buildErrorState(context, e),
      data: (trips) {
        if (trips.isEmpty) {
          return _buildEmptyState(context, filter.hasActiveFilters);
        }
        final config = ref.watch(tripTableConfigProvider);
        final notifier = ref.read(tripTableConfigProvider.notifier);
        final settings = ref.watch(settingsProvider);
        final units = UnitFormatter(settings);

        return Column(
          children: [
            if (filter.hasActiveFilters) _buildActiveFiltersBar(context, ref),
            Expanded(
              child: EntityTableView<TripWithStats, TripField>(
                entities: trips,
                idExtractor: (t) => t.trip.id,
                adapter: TripFieldAdapter.instance,
                config: config,
                units: units,
                onSortFieldChanged: notifier.setSortField,
                onResizeColumn: notifier.resizeColumn,
                onEntityTapDown: (id) {
                  ref.read(highlightedTripIdProvider.notifier).state = id;
                },
                onEntityTap: (id) {
                  if (_isSelectionMode) _selection.toggle(id);
                },
                selectedIds: _selectedIds,
                isSelectionMode: _isSelectionMode,
                onEntityDoubleTap: (id) {
                  context.push('/trips/$id');
                },
                highlightedId: ref.watch(highlightedTripIdProvider),
              ),
            ),
          ],
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
          // child. Pairing Flexible with Spacer gave each flex: 1, so the
          // Spacer took exactly half the free space instead of the remainder
          // and the leftover half fell after the last icon, left-shifting the
          // whole action row. The title still yields before the row overflows,
          // because FeatureAppBarTitle ellipsises.
          Expanded(
            child: FeatureAppBarTitle(
              featureId: 'trips',
              title: context.l10n.trips_appBar_title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            tooltip: context.l10n.trips_list_tooltip_search,
            onPressed: () {
              showSearch(
                context: context,
                delegate: TripSearchDelegate(context.l10n),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: context.l10n.trips_list_tooltip_sort,
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
                ref.read(tripListViewModeProvider.notifier).state = mode;
              }
            },
            itemBuilder: (context) {
              final currentMode = ref.read(tripListViewModeProvider);
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

  Widget _buildActiveFiltersBar(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(tripFilterProvider);
    final chips = <Widget>[];

    if (filter.equipmentId != null) {
      final equipmentName =
          ref.watch(equipmentItemProvider(filter.equipmentId!)).value?.name ??
          context.l10n.equipment_appBar_title;
      chips.add(
        InputChip(
          label: Text(equipmentName),
          onDeleted: () {
            ref.read(tripFilterProvider.notifier).state = filter.copyWith(
              clearEquipmentId: true,
            );
          },
          deleteIcon: const Icon(Icons.close, size: 18),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: chips
                    .map(
                      (chip) => Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: chip,
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(tripFilterProvider.notifier).state =
                  const TripFilterState();
            },
            child: Text(context.l10n.trips_list_filters_clearAll),
          ),
        ],
      ),
    );
  }

  Widget _buildTripList(
    BuildContext context,
    WidgetRef ref,
    List<TripWithStats> trips,
    bool hasActiveFilters,
  ) {
    final diversCount = ref
        .watch(allDiversProvider)
        .when(data: (d) => d.length, loading: () => 0, error: (_, _) => 0);

    final upcoming = trips.where((t) => t.trip.isUpcoming).toList()
      ..sort((a, b) => a.trip.startDate.compareTo(b.trip.startDate));
    final past = trips.where((t) => !t.trip.isUpcoming).toList();
    // Flatten into one item list: header sentinels + trips, so the
    // existing ListView.builder/itemBuilder structure is preserved.
    final rows = <Object>[
      if (upcoming.isNotEmpty) _SectionHeader.upcoming,
      ...upcoming,
      if (upcoming.isNotEmpty && past.isNotEmpty) _SectionHeader.past,
      ...past,
    ];

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(tripListNotifierProvider.notifier).refresh();
      },
      child: Column(
        children: [
          if (hasActiveFilters) _buildActiveFiltersBar(context, ref),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                if (row is _SectionHeader) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                    child: Text(
                      row == _SectionHeader.upcoming
                          ? context.l10n.trips_list_upcomingSection
                          : context.l10n.trips_list_pastSection,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }
                final tripWithStats = row as TripWithStats;
                final isSelected =
                    widget.selectedId == tripWithStats.trip.id ||
                    ref.watch(highlightedTripIdProvider) ==
                        tripWithStats.trip.id;
                final viewMode = ref.watch(tripListViewModeProvider);
                final showSharedBadge =
                    tripWithStats.trip.isShared && diversCount >= 2;
                final isChecked = _selectedIds.contains(tripWithStats.trip.id);
                void onCheckChanged(bool _) =>
                    _selection.toggle(tripWithStats.trip.id);
                final selectableTile = switch (viewMode) {
                  ListViewMode.detailed => TripListTile(
                    tripWithStats: tripWithStats,
                    isSelected: isSelected,
                    onTap: () => _handleRowTap(tripWithStats.trip),
                    showSharedBadge: showSharedBadge,
                    isSelectionMode: _isSelectionMode,
                    isChecked: isChecked,
                    onCheckChanged: onCheckChanged,
                  ),
                  ListViewMode.compact => CompactTripListTile(
                    tripWithStats: tripWithStats,
                    isSelected: isSelected,
                    onTap: () => _handleRowTap(tripWithStats.trip),
                    showSharedBadge: showSharedBadge,
                    isSelectionMode: _isSelectionMode,
                    isChecked: isChecked,
                    onCheckChanged: onCheckChanged,
                  ),
                  ListViewMode.dense || ListViewMode.table => DenseTripListTile(
                    tripWithStats: tripWithStats,
                    isSelected: isSelected,
                    onTap: () => _handleRowTap(tripWithStats.trip),
                    showSharedBadge: showSharedBadge,
                    isSelectionMode: _isSelectionMode,
                    isChecked: isChecked,
                    onCheckChanged: onCheckChanged,
                  ),
                };
                if (!tripWithStats.trip.isUpcoming) return selectableTile;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                      child: UpcomingTripBanner(trip: tripWithStats.trip),
                    ),
                    selectableTile,
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool hasActiveFilters) {
    if (hasActiveFilters) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_list_off,
              size: 80,
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.trips_list_empty_filtered_title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.trips_list_empty_filtered_subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.flight_takeoff,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.trips_list_empty_title,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.trips_list_empty_subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              if (ResponsiveBreakpoints.isMasterDetail(context)) {
                final routerState = GoRouterState.of(context);
                context.go('${routerState.uri.path}?mode=new');
              } else {
                context.push('/trips/new');
              }
            },
            icon: const Icon(Icons.add),
            label: Text(context.l10n.trips_list_empty_button),
          ),
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
          Text(context.l10n.trips_list_error_loading('$error')),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () =>
                ref.read(tripListNotifierProvider.notifier).refresh(),
            child: Text(context.l10n.trips_list_button_retry),
          ),
        ],
      ),
    );
  }
}

/// List item widget for displaying a trip
class TripListTile extends StatelessWidget {
  final TripWithStats tripWithStats;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showSharedBadge;
  final bool isSelectionMode;
  final bool isChecked;
  final ValueChanged<bool>? onCheckChanged;

  const TripListTile({
    super.key,
    required this.tripWithStats,
    this.isSelected = false,
    this.onTap,
    this.showSharedBadge = false,
    this.isSelectionMode = false,
    this.isChecked = false,
    this.onCheckChanged,
  });

  @override
  Widget build(BuildContext context) {
    final trip = tripWithStats.trip;
    final dateFormat = DateFormat.yMMMd();
    final theme = Theme.of(context);

    final subtitleStr = trip.subtitle != null ? ', ${trip.subtitle}' : '';
    final diveCountStr = context.l10n.trips_list_tile_diveCount(
      tripWithStats.diveCount,
    );
    final runtimeStr = tripWithStats.totalRuntime > 0
        ? ', ${tripWithStats.formattedRuntime}'
        : '';
    // The two dates are joined with a dash rather than a connector word, both
    // to match the compact tile and because a translated "to" would need an
    // ARB key per locale to read correctly.
    final dateRangeStr =
        '${dateFormat.format(trip.startDate)} - ${dateFormat.format(trip.endDate)}';
    final tripLabel =
        '${trip.name}, $dateRangeStr$subtitleStr, $diveCountStr$runtimeStr';

    return Semantics(
      // Selection is a semantics flag, not label prose: assistive tech
      // announces it in the user's own language and can filter on it.
      selected: isSelected,
      label: tripLabel,
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: isSelected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
            : null,
        child: ListTile(
          onTap: onTap,
          // ListTile's Material 3 defaults resolve the title to bodyLarge and
          // the subtitle to bodyMedium. The detailed dive and site cards are
          // hand-rolled and ask for titleMedium/bodyMedium explicitly, so the
          // roles are restated here to keep all three lists on the same text
          // theme roles. Theme presets differ between the title and body roles
          // (console uses a monospace family for title roles only, minimalist
          // uses w500 for title roles and w300 for body roles), so inheriting
          // the default renders trip titles in a different font from the rest
          // of the app's lists.
          titleTextStyle: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          subtitleTextStyle: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          leading: SelectionLeading(
            isSelectionMode: isSelectionMode,
            isChecked: isChecked,
            onChanged: onCheckChanged,
            child: Consumer(
              builder: (context, ref, _) {
                final accent = resolveFeatureAccent(
                  context,
                  ref,
                  surface: AccentSurface.list,
                  featureId: 'trips',
                );
                return CircleAvatar(
                  backgroundColor:
                      accent?.withValues(alpha: 0.15) ??
                      theme.colorScheme.primaryContainer,
                  child: Icon(
                    trip.isLiveaboard ? Icons.sailing : Icons.flight_takeoff,
                    color: accent ?? theme.colorScheme.onPrimaryContainer,
                  ),
                );
              },
            ),
          ),
          title: Row(
            children: [
              Expanded(child: Text(trip.name)),
              if (showSharedBadge) ...[
                const SizedBox(width: 6),
                Tooltip(
                  message:
                      context.l10n.accessibility_label_sharedWithAllProfiles,
                  child: Icon(
                    Icons.people_outline,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date range takes the subtitle role from the ListTile above,
              // matching the dive card's date line.
              Text(
                '${dateFormat.format(trip.startDate)} - ${dateFormat.format(trip.endDate)}',
              ),
              if (trip.subtitle != null)
                Text(
                  trip.subtitle!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.scuba_diving,
                    size: 14,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    context.l10n.trips_list_tile_diveCount(
                      tripWithStats.diveCount,
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  if (tripWithStats.totalRuntime > 0) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.timer,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tripWithStats.formattedRuntime,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          isThreeLine: true,
        ),
      ),
    );
  }
}

/// Search delegate for trips
class TripSearchDelegate extends SearchDelegate<Trip?> {
  TripSearchDelegate(this._l10n);

  final AppLocalizations _l10n;

  @override
  String get searchFieldLabel => _l10n.trips_search_fieldLabel;

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          tooltip: context.l10n.trips_search_tooltip_clear,
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      tooltip: context.l10n.trips_search_tooltip_back,
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
              context.l10n.trips_search_empty_hint,
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
    return Consumer(
      builder: (context, ref, child) {
        final searchAsync = ref.watch(tripSearchProvider(query));

        return searchAsync.when(
          data: (trips) {
            if (trips.isEmpty) {
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
                      context.l10n.trips_search_noResults(query),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: trips.length,
              itemBuilder: (context, index) {
                final trip = trips[index];
                final dateFormat = DateFormat.yMMMd();
                return ListTile(
                  // Same text theme roles as TripListTile so search results do
                  // not fall back to ListTile's bodyLarge title default.
                  titleTextStyle: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                  subtitleTextStyle: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                  leading: Builder(
                    builder: (context) {
                      final accent = resolveFeatureAccent(
                        context,
                        ref,
                        surface: AccentSurface.list,
                        featureId: 'trips',
                      );
                      return CircleAvatar(
                        backgroundColor:
                            accent?.withValues(alpha: 0.15) ??
                            Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(
                          trip.isLiveaboard
                              ? Icons.sailing
                              : Icons.flight_takeoff,
                          color:
                              accent ??
                              Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      );
                    },
                  ),
                  title: Text(trip.name),
                  subtitle: Text(
                    '${dateFormat.format(trip.startDate)} - ${dateFormat.format(trip.endDate)}',
                  ),
                  onTap: () {
                    close(context, trip);
                    context.push('/trips/${trip.id}');
                  },
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) =>
              Center(child: Text('${context.l10n.common_label_error}: $error')),
        );
      },
    );
  }
}

enum _SectionHeader { upcoming, past }
