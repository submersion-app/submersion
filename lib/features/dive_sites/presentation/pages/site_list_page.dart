import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_filter_sheet.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_column_picker.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';
import 'package:submersion/shared/widgets/table_mode_layout/table_mode_layout.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_content.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_map_content.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_summary_widget.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class SiteListPage extends ConsumerStatefulWidget {
  const SiteListPage({super.key});

  @override
  ConsumerState<SiteListPage> createState() => _SiteListPageState();
}

class _SiteListPageState extends ConsumerState<SiteListPage> {
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
        final viewMode = ref.read(siteListViewModeProvider);
        if (isDesktop && viewMode != ListViewMode.table) {
          final state = GoRouterState.of(context);
          final currentPath = state.uri.path;
          context.go('$currentPath?mode=new');
        } else {
          context.push('/sites/new');
        }
      },
      tooltip: context.l10n.diveSites_fab_tooltip,
      icon: const Icon(Icons.add_location),
      label: Text(context.l10n.diveSites_fab_label),
    );

    // Table mode: use shared TableModeLayout for full-width table with
    // optional detail pane and map.
    final viewMode = ref.watch(siteListViewModeProvider);
    if (viewMode == ListViewMode.table) {
      return TableModeLayout(
        sectionKey: 'sites',
        appBarTitle: context.l10n.nav_sites,
        tableContent: const SiteListContent(showAppBar: false),
        detailBuilder: (context, id) => SiteDetailPage(
          siteId: id,
          embedded: true,
          onDeleted: () {
            final state = GoRouterState.of(context);
            context.go(state.uri.path);
          },
        ),
        summaryBuilder: (context) => const SiteSummaryWidget(),
        editBuilder: (context, id, onSaved, onCancel) => SiteEditPage(
          siteId: id,
          embedded: true,
          onSaved: onSaved,
          onCancel: onCancel,
        ),
        createBuilder: (context, onSaved, onCancel) =>
            SiteEditPage(embedded: true, onSaved: onSaved, onCancel: onCancel),
        mapContent: SiteMapContent(
          selectedId: ref.watch(highlightedSiteIdProvider),
          onItemSelected: (siteId) {
            ref.read(highlightedSiteIdProvider.notifier).state = siteId;
          },
          onDetailsTap: (siteId) => context.push('/sites/$siteId'),
        ),
        selectedId: ref.watch(highlightedSiteIdProvider),
        onEntitySelected: (id) {
          ref.read(highlightedSiteIdProvider.notifier).state = id;
        },
        isMapViewActive: _isMapView,
        onMapViewToggle: _toggleMapView,
        columnSettingsAction: IconButton(
          icon: const Icon(Icons.view_column_outlined),
          tooltip: 'Column settings',
          onPressed: () {
            final config = ref.read(siteTableConfigProvider);
            final notifier = ref.read(siteTableConfigProvider.notifier);
            showEntityTableColumnPicker<SiteField>(
              context,
              config: config,
              adapter: SiteFieldAdapter.instance,
              onToggleColumn: notifier.toggleColumn,
              onReorderColumn: notifier.reorderColumn,
              onTogglePin: notifier.togglePin,
            );
          },
        ),
        appBarActions: [
          IconButton(
            icon: const Icon(Icons.search, size: 20),
            tooltip: context.l10n.diveSites_list_tooltip_searchSites,
            onPressed: () {
              showSearch(context: context, delegate: SiteSearchDelegate(ref));
            },
          ),
          IconButton(
            icon: Badge(
              isLabelVisible: ref.watch(siteFilterProvider).hasActiveFilters,
              child: const Icon(Icons.filter_list, size: 20),
            ),
            tooltip: context.l10n.diveSites_list_tooltip_filterSites,
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => SiteFilterSheet(ref: ref),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort, size: 20),
            tooltip: context.l10n.diveSites_list_tooltip_sort,
            onPressed: () {
              final sort = ref.read(siteSortProvider);
              showSortBottomSheet<SiteSortField>(
                context: context,
                title: context.l10n.diveSites_list_sort_title,
                currentField: sort.field,
                currentDirection: sort.direction,
                fields: SiteSortField.values,
                getFieldDisplayName: (field) => field.displayName,
                getFieldIcon: (field) => field.icon,
                onSortChanged: (field, direction) {
                  ref.read(siteSortProvider.notifier).state = SortState(
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
                ref.read(siteListViewModeProvider.notifier).state = mode;
              }
            },
            itemBuilder: (context) {
              final currentMode = ref.read(siteListViewModeProvider);
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
          sectionId: 'sites',
          masterBuilder: (context, onItemSelected, selectedId) =>
              SiteListContent(
                onItemSelected: onItemSelected,
                selectedId: selectedId,
                showAppBar: false,
                isMapViewActive: _isMapView,
                onMapViewToggle: _toggleMapView,
              ),
          detailBuilder: (context, id) => SiteDetailPage(
            siteId: id,
            embedded: true,
            onDeleted: () {
              final state = GoRouterState.of(context);
              final currentPath = state.uri.path;
              context.go(currentPath);
            },
          ),
          summaryBuilder: (context) => const SiteSummaryWidget(),
          mapBuilder: (context, selectedId, onItemSelected) => SiteMapContent(
            selectedId: selectedId,
            onItemSelected: onItemSelected,
            onDetailsTap: (siteId) {
              // Exit map view and show detail pane for the selected site
              final state = GoRouterState.of(context);
              final currentPath = state.uri.path;
              context.go('$currentPath?selected=$siteId');
            },
          ),
          editBuilder: (context, id, onSaved, onCancel) => SiteEditPage(
            siteId: id,
            embedded: true,
            onSaved: onSaved,
            onCancel: onCancel,
          ),
          createBuilder: (context, onSaved, onCancel) => SiteEditPage(
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
      child: SiteListContent(showAppBar: true, floatingActionButton: fab),
    );
  }
}
