import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/divers/presentation/widgets/diver_list_content.dart';
import 'package:submersion/features/divers/presentation/widgets/diver_summary_widget.dart';
import 'package:submersion/features/divers/presentation/pages/diver_detail_page.dart';
import 'package:submersion/features/divers/presentation/pages/diver_edit_page.dart';

class DiverListPage extends ConsumerWidget {
  const DiverListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fab = FloatingActionButton.extended(
      onPressed: () {
        if (ResponsiveBreakpoints.isMasterDetail(context)) {
          final state = GoRouterState.of(context);
          final currentPath = state.uri.path;
          context.go('$currentPath?mode=new');
        } else {
          context.push('/divers/new');
        }
      },
      tooltip: 'Add a new diver profile',
      icon: const Icon(Icons.person_add),
      label: const Text('Add Diver'),
    );

    // Desktop: Use master-detail layout
    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      return FocusTraversalGroup(
        child: MasterDetailScaffold(
          sectionId: 'divers',
          masterBuilder: (context, onItemSelected, selectedId) =>
              DiverListContent(
                onItemSelected: onItemSelected,
                selectedId: selectedId,
                showAppBar: false,
              ),
          detailBuilder: (context, diverId) => DiverDetailPage(
            diverId: diverId,
            embedded: true,
            onDeleted: () {
              final state = GoRouterState.of(context);
              context.go(state.uri.path);
            },
          ),
          summaryBuilder: (context) => const DiverSummaryWidget(),
          editBuilder: (context, diverId, onSaved, onCancel) => DiverEditPage(
            diverId: diverId,
            embedded: true,
            onSaved: onSaved,
            onCancel: onCancel,
          ),
          createBuilder: (context, onSaved, onCancel) => DiverEditPage(
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
      child: DiverListContent(showAppBar: true, floatingActionButton: fab),
    );
  }
}
