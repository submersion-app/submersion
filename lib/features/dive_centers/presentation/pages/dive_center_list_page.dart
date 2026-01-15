import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_list_content.dart';
import 'package:submersion/features/dive_centers/presentation/widgets/dive_center_summary_widget.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_detail_page.dart';
import 'package:submersion/features/dive_centers/presentation/pages/dive_center_edit_page.dart';

class DiveCenterListPage extends ConsumerWidget {
  const DiveCenterListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      icon: const Icon(Icons.add),
      label: const Text('Add Dive Center'),
    );

    // Desktop: Use master-detail layout
    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      return MasterDetailScaffold(
        sectionId: 'dive-centers',
        masterBuilder: (context, onItemSelected, selectedId) =>
            DiveCenterListContent(
              onItemSelected: onItemSelected,
              selectedId: selectedId,
              showAppBar: false,
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
      );
    }

    // Mobile: Use list content with full scaffold
    return DiveCenterListContent(showAppBar: true, floatingActionButton: fab);
  }
}
