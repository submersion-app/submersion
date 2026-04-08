import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/trips/domain/constants/trip_field.dart';
import 'package:submersion/features/trips/presentation/providers/trip_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_column_picker.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';
import 'package:submersion/shared/widgets/table_mode_layout/table_mode_layout.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_list_content.dart';
import 'package:submersion/features/trips/presentation/widgets/trip_summary_widget.dart';
import 'package:submersion/features/trips/presentation/pages/trip_detail_page.dart';
import 'package:submersion/features/trips/presentation/pages/trip_edit_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class TripListPage extends ConsumerWidget {
  const TripListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fab = FloatingActionButton.extended(
      onPressed: () {
        final isDesktop = ResponsiveBreakpoints.isMasterDetail(context);
        final viewMode = ref.read(tripListViewModeProvider);
        if (isDesktop && viewMode != ListViewMode.table) {
          final state = GoRouterState.of(context);
          final currentPath = state.uri.path;
          context.go('$currentPath?mode=new');
        } else {
          context.push('/trips/new');
        }
      },
      icon: const Icon(Icons.add),
      label: Text(context.l10n.trips_list_fab_addTrip),
      tooltip: context.l10n.trips_list_tooltip_addTrip,
    );

    // Table mode: use shared TableModeLayout for full-width table with
    // optional detail pane.
    final viewMode = ref.watch(tripListViewModeProvider);
    if (viewMode == ListViewMode.table) {
      return FocusTraversalGroup(
        child: TableModeLayout(
          sectionKey: 'trips',
          appBarTitle: context.l10n.nav_trips,
          tableContent: const TripListContent(showAppBar: false),
          detailBuilder: (context, tripId) => TripDetailPage(
            tripId: tripId,
            embedded: true,
            onDeleted: () {
              final state = GoRouterState.of(context);
              context.go(state.uri.path);
            },
          ),
          summaryBuilder: (context) => const TripSummaryWidget(),
          editBuilder: (context, tripId, onSaved, onCancel) => TripEditPage(
            tripId: tripId,
            embedded: true,
            onSaved: onSaved,
            onCancel: onCancel,
          ),
          createBuilder: (context, onSaved, onCancel) => TripEditPage(
            embedded: true,
            onSaved: onSaved,
            onCancel: onCancel,
          ),
          selectedId: ref.watch(highlightedTripIdProvider),
          onEntitySelected: (id) {
            ref.read(highlightedTripIdProvider.notifier).state = id;
          },
          columnSettingsAction: IconButton(
            icon: const Icon(Icons.view_column_outlined),
            tooltip: 'Column settings',
            onPressed: () {
              final config = ref.read(tripTableConfigProvider);
              final notifier = ref.read(tripTableConfigProvider.notifier);
              showEntityTableColumnPicker<TripField>(
                context,
                config: config,
                adapter: TripFieldAdapter.instance,
                onToggleColumn: notifier.toggleColumn,
                onReorderColumn: notifier.reorderColumn,
                onTogglePin: notifier.togglePin,
              );
            },
          ),
          appBarActions: [
            IconButton(
              icon: const Icon(Icons.search, size: 20),
              tooltip: context.l10n.trips_list_tooltip_search,
              onPressed: () {
                showSearch(context: context, delegate: TripSearchDelegate());
              },
            ),
            IconButton(
              icon: const Icon(Icons.sort, size: 20),
              tooltip: context.l10n.trips_list_tooltip_sort,
              onPressed: () {
                final sort = ref.read(tripSortProvider);
                showSortBottomSheet<TripSortField>(
                  context: context,
                  title: context.l10n.trips_list_sort_title,
                  currentField: sort.field,
                  currentDirection: sort.direction,
                  fields: TripSortField.values,
                  getFieldDisplayName: (field) => field.displayName,
                  getFieldIcon: (field) => field.icon,
                  onSortChanged: (field, direction) {
                    ref.read(tripSortProvider.notifier).state = SortState(
                      field: field,
                      direction: direction,
                    );
                  },
                );
              },
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
          floatingActionButton: fab,
        ),
      );
    }

    // Desktop: Use master-detail layout
    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      return MasterDetailScaffold(
        sectionId: 'trips',
        masterBuilder: (context, onItemSelected, selectedId) => TripListContent(
          onItemSelected: onItemSelected,
          selectedId: selectedId,
          showAppBar: false,
        ),
        detailBuilder: (context, tripId) => TripDetailPage(
          tripId: tripId,
          embedded: true,
          onDeleted: () {
            final state = GoRouterState.of(context);
            context.go(state.uri.path);
          },
        ),
        summaryBuilder: (context) => const TripSummaryWidget(),
        editBuilder: (context, tripId, onSaved, onCancel) => TripEditPage(
          tripId: tripId,
          embedded: true,
          onSaved: onSaved,
          onCancel: onCancel,
        ),
        createBuilder: (context, onSaved, onCancel) =>
            TripEditPage(embedded: true, onSaved: onSaved, onCancel: onCancel),
        floatingActionButton: fab,
      );
    }

    // Mobile: Use list content with full scaffold
    return FocusTraversalGroup(
      child: TripListContent(showAppBar: true, floatingActionButton: fab),
    );
  }
}
