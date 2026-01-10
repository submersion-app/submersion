import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';

import '../../../../shared/widgets/master_detail/master_detail_scaffold.dart';
import '../../../../shared/widgets/master_detail/responsive_breakpoints.dart';
import '../widgets/site_list_content.dart';
import '../widgets/site_summary_widget.dart';
import 'site_detail_page.dart';
import 'site_edit_page.dart';

class SiteListPage extends ConsumerWidget {
  const SiteListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
      icon: const Icon(Icons.add_location),
      label: const Text('Add Site'),
    );

    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      return MasterDetailScaffold(
        sectionId: 'sites',
        masterBuilder: (context, onItemSelected, selectedId) => SiteListContent(
          onItemSelected: onItemSelected,
          selectedId: selectedId,
          showAppBar: false,
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
        editBuilder: (context, id, onSaved, onCancel) => SiteEditPage(
          siteId: id,
          embedded: true,
          onSaved: onSaved,
          onCancel: onCancel,
        ),
        createBuilder: (context, onSaved, onCancel) =>
            SiteEditPage(embedded: true, onSaved: onSaved, onCancel: onCancel),
        floatingActionButton: fab,
      );
    }

    return SiteListContent(showAppBar: true, floatingActionButton: fab);
  }
}
