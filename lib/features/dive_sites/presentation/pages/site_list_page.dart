import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_content.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_map_content.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_summary_widget.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_detail_page.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';

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
        if (ResponsiveBreakpoints.isMasterDetail(context)) {
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
