import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/master_detail/master_detail_scaffold.dart';
import '../../../../shared/widgets/master_detail/responsive_breakpoints.dart';
import '../widgets/diver_list_content.dart';
import '../widgets/diver_summary_widget.dart';
import 'diver_detail_page.dart';
import 'diver_edit_page.dart';

class DiverListPage extends ConsumerWidget {
  const DiverListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fab = FloatingActionButton.extended(
      onPressed: () {
        if (ResponsiveBreakpoints.isDesktop(context)) {
          final state = GoRouterState.of(context);
          final currentPath = state.uri.path;
          context.go('$currentPath?mode=new');
        } else {
          context.push('/divers/new');
        }
      },
      icon: const Icon(Icons.person_add),
      label: const Text('Add Diver'),
    );

    // Desktop: Use master-detail layout
    if (ResponsiveBreakpoints.isDesktop(context)) {
      return MasterDetailScaffold(
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
      );
    }

    // Mobile: Use list content with full scaffold
    return DiverListContent(
      showAppBar: true,
      floatingActionButton: fab,
    );
  }
}
