import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/dive_centers/domain/constants/dive_center_field.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_column_picker.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';
import 'package:submersion/shared/widgets/table_mode_layout/table_mode_layout.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_list_content.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_map_content.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_summary_widget.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_detail_page.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_edit_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class DiveCenterListPage extends ConsumerStatefulWidget {
  const DiveCenterListPage({super.key});

  @override
  ConsumerState<DiveCenterListPage> createState() => _DiveCenterListPageState();
}

class _DiveCenterListPageState extends ConsumerState<DiveCenterListPage> {
  bool get _isMapView {
    final state = GoRouterState.of(context);
    return state.uri.queryParameters['view'] == 'map';
  }

  void _toggleMapView() {
    final router = GoRouter.of(context);
    final state = GoRouterState.of(context);
    final currentPath = state.uri.path;
    final selectedId = state.uri.queryParameters['selected'];

    if (_isMapView) {
      // Switch back to detail view
      if (selectedId != null) {
        router.go('$currentPath?selected=$selectedId');
      } else {
        router.go(currentPath);
      }
    } else {
      // Switch to map view
      if (selectedId != null) {
        router.go('$currentPath?selected=$selectedId&view=map');
      } else {
        router.go('$currentPath?view=map');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fab = FloatingActionButton.extended(
      onPressed: () {
        final isDesktop = ResponsiveBreakpoints.isMasterDetail(context);
        final viewMode = ref.read(diveCenterListViewModeProvider);
        if (isDesktop && viewMode != ListViewMode.table) {
          final state = GoRouterState.of(context);
          final currentPath = state.uri.path;
          context.go('$currentPath?mode=new');
        } else {
          context.push('/dive-centers/new');
        }
      },
      tooltip: context.l10n.diveCenters_tooltip_addNew,
      icon: const Icon(Icons.add),
      label: Text(context.l10n.diveCenters_title_add),
    );

    // Table mode: use shared TableModeLayout for full-width table with
    // optional detail pane and map.
    final viewMode = ref.watch(diveCenterListViewModeProvider);
    if (viewMode == ListViewMode.table) {
      return TableModeLayout(
        sectionKey: 'diveCenters',
        appBarTitle: context.l10n.nav_diveCenters,
        tableContent: const DiveCenterListContent(showAppBar: false),
        detailBuilder: (context, centerId) => DiveCenterDetailPage(
          centerId: centerId,
          embedded: true,
          onDeleted: () {
            final state = GoRouterState.of(context);
            context.go(state.uri.path);
          },
        ),
        summaryBuilder: (context) => const DiveCenterSummaryWidget(),
        editBuilder: (context, centerId, onSaved, onCancel) =>
            DiveCenterEditPage(
              centerId: centerId,
              embedded: true,
              onSaved: onSaved,
              onCancel: onCancel,
            ),
        createBuilder: (context, onSaved, onCancel) => DiveCenterEditPage(
          embedded: true,
          onSaved: onSaved,
          onCancel: onCancel,
        ),
        mapContent: DiveCenterMapContent(
          selectedId: ref.watch(highlightedDiveCenterIdProvider),
          onItemSelected: (centerId) {
            ref.read(highlightedDiveCenterIdProvider.notifier).state = centerId;
          },
          onDetailsTap: (centerId) => context.push('/dive-centers/$centerId'),
        ),
        selectedId: ref.watch(highlightedDiveCenterIdProvider),
        onEntitySelected: (id) {
          ref.read(highlightedDiveCenterIdProvider.notifier).state = id;
        },
        isMapViewActive: _isMapView,
        onMapViewToggle: _toggleMapView,
        columnSettingsAction: IconButton(
          icon: const Icon(Icons.view_column_outlined),
          tooltip: 'Column settings',
          onPressed: () {
            final config = ref.read(diveCenterTableConfigProvider);
            final notifier = ref.read(diveCenterTableConfigProvider.notifier);
            showEntityTableColumnPicker<DiveCenterField>(
              context,
              config: config,
              adapter: DiveCenterFieldAdapter.instance,
              onToggleColumn: notifier.toggleColumn,
              onReorderColumn: notifier.reorderColumn,
              onTogglePin: notifier.togglePin,
            );
          },
        ),
        appBarActions: [
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            tooltip: context.l10n.diveCenters_tooltip_search,
            onPressed: () {
              showSearch(
                context: context,
                delegate: DiveCenterSearchDelegate(ref),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: context.l10n.diveCenters_tooltip_sort,
            onPressed: () {
              final sort = ref.read(diveCenterSortProvider);
              showSortBottomSheet<DiveCenterSortField>(
                context: context,
                title: context.l10n.diveCenters_sort_title,
                currentField: sort.field,
                currentDirection: sort.direction,
                fields: DiveCenterSortField.values,
                getFieldDisplayName: (field) => field.displayName,
                getFieldIcon: (field) => field.icon,
                onSortChanged: (field, direction) {
                  ref.read(diveCenterSortProvider.notifier).state = SortState(
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
                ref.read(diveCenterListViewModeProvider.notifier).state = mode;
              }
            },
            itemBuilder: (context) {
              final currentMode = ref.read(diveCenterListViewModeProvider);
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
      );
    }

    // Desktop: Use master-detail layout
    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      return FocusTraversalGroup(
        child: MasterDetailScaffold(
          sectionId: 'dive-centers',
          masterBuilder: (context, onItemSelected, selectedId) =>
              DiveCenterListContent(
                onItemSelected: onItemSelected,
                selectedId: selectedId,
                showAppBar: false,
                isMapViewActive: _isMapView,
                onMapViewToggle: _toggleMapView,
              ),
          detailBuilder: (context, centerId) => DiveCenterDetailPage(
            centerId: centerId,
            embedded: true,
            onDeleted: () {
              final state = GoRouterState.of(context);
              context.go(state.uri.path);
            },
          ),
          summaryBuilder: (context) => const DiveCenterSummaryWidget(),
          mapBuilder: (context, selectedId, onItemSelected) =>
              DiveCenterMapContent(
                selectedId: selectedId,
                onItemSelected: onItemSelected,
                onDetailsTap: (centerId) =>
                    context.push('/dive-centers/$centerId'),
              ),
          editBuilder: (context, centerId, onSaved, onCancel) =>
              DiveCenterEditPage(
                centerId: centerId,
                embedded: true,
                onSaved: onSaved,
                onCancel: onCancel,
              ),
          createBuilder: (context, onSaved, onCancel) => DiveCenterEditPage(
            embedded: true,
            onSaved: onSaved,
            onCancel: onCancel,
          ),
          floatingActionButton: fab,
        ),
      );
    }

    // Mobile: Use list content with full scaffold
    return FocusTraversalGroup(
      child: DiveCenterListContent(showAppBar: true, floatingActionButton: fab),
    );
  }
}
