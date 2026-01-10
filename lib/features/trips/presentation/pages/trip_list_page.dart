import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/master_detail/master_detail_scaffold.dart';
import '../../../../shared/widgets/master_detail/responsive_breakpoints.dart';
import '../widgets/trip_list_content.dart';
import '../widgets/trip_summary_widget.dart';
import 'trip_detail_page.dart';
import 'trip_edit_page.dart';

class TripListPage extends ConsumerWidget {
  const TripListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fab = FloatingActionButton.extended(
      onPressed: () {
        if (ResponsiveBreakpoints.isDesktop(context)) {
          final state = GoRouterState.of(context);
          final currentPath = state.uri.path;
          context.go('$currentPath?mode=new');
        } else {
          context.push('/trips/new');
        }
      },
      icon: const Icon(Icons.add),
      label: const Text('Add Trip'),
    );

    // Desktop: Use master-detail layout
    if (ResponsiveBreakpoints.isDesktop(context)) {
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
    return TripListContent(showAppBar: true, floatingActionButton: fab);
  }
}
