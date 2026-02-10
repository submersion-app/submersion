import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_list_content.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_map_content.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_summary_widget.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_detail_page.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_edit_page.dart';

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
        if (ResponsiveBreakpoints.isMasterDetail(context)) {
          final state = GoRouterState.of(context);
          final currentPath = state.uri.path;
          context.go('$currentPath?mode=new');
        } else {
          context.push('/dive-centers/new');
        }
      },
      tooltip: 'Add a new dive center',
      icon: const Icon(Icons.add),
      label: const Text('Add Dive Center'),
    );

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
