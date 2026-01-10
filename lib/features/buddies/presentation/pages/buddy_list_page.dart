import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/master_detail/master_detail_scaffold.dart';
import '../../../../shared/widgets/master_detail/responsive_breakpoints.dart';
import '../widgets/buddy_list_content.dart';
import '../widgets/buddy_summary_widget.dart';
import 'buddy_detail_page.dart';
import 'buddy_edit_page.dart';

class BuddyListPage extends ConsumerWidget {
  const BuddyListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fab = FloatingActionButton.extended(
      onPressed: () {
        if (ResponsiveBreakpoints.isMasterDetail(context)) {
          final state = GoRouterState.of(context);
          final currentPath = state.uri.path;
          context.go('$currentPath?mode=new');
        } else {
          context.push('/buddies/new');
        }
      },
      icon: const Icon(Icons.person_add),
      label: const Text('Add Buddy'),
    );

    // Desktop: Use master-detail layout
    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      return MasterDetailScaffold(
        sectionId: 'buddies',
        masterBuilder: (context, onItemSelected, selectedId) =>
            BuddyListContent(
              onItemSelected: onItemSelected,
              selectedId: selectedId,
              showAppBar: false,
            ),
        detailBuilder: (context, buddyId) => BuddyDetailPage(
          buddyId: buddyId,
          embedded: true,
          onDeleted: () {
            final state = GoRouterState.of(context);
            context.go(state.uri.path);
          },
        ),
        summaryBuilder: (context) => const BuddySummaryWidget(),
        editBuilder: (context, buddyId, onSaved, onCancel) => BuddyEditPage(
          buddyId: buddyId,
          embedded: true,
          onSaved: onSaved,
          onCancel: onCancel,
        ),
        createBuilder: (context, onSaved, onCancel) =>
            BuddyEditPage(embedded: true, onSaved: onSaved, onCancel: onCancel),
        floatingActionButton: fab,
      );
    }

    // Mobile: Use list content with full scaffold
    return BuddyListContent(showAppBar: true, floatingActionButton: fab);
  }
}
