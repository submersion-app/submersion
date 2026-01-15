import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_list_content.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_summary_widget.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_detail_page.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_edit_page.dart';

class CertificationListPage extends ConsumerWidget {
  const CertificationListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fab = FloatingActionButton.extended(
      onPressed: () {
        if (ResponsiveBreakpoints.isMasterDetail(context)) {
          final state = GoRouterState.of(context);
          final currentPath = state.uri.path;
          context.go('$currentPath?mode=new');
        } else {
          context.push('/certifications/new');
        }
      },
      icon: const Icon(Icons.add_card),
      label: const Text('Add Certification'),
    );

    // Desktop: Use master-detail layout
    if (ResponsiveBreakpoints.isMasterDetail(context)) {
      return MasterDetailScaffold(
        sectionId: 'certifications',
        masterBuilder: (context, onItemSelected, selectedId) =>
            CertificationListContent(
              onItemSelected: onItemSelected,
              selectedId: selectedId,
              showAppBar: false,
            ),
        detailBuilder: (context, certificationId) => CertificationDetailPage(
          certificationId: certificationId,
          embedded: true,
          onDeleted: () {
            final state = GoRouterState.of(context);
            context.go(state.uri.path);
          },
        ),
        summaryBuilder: (context) => const CertificationSummaryWidget(),
        editBuilder: (context, certificationId, onSaved, onCancel) =>
            CertificationEditPage(
              certificationId: certificationId,
              embedded: true,
              onSaved: onSaved,
              onCancel: onCancel,
            ),
        createBuilder: (context, onSaved, onCancel) => CertificationEditPage(
          embedded: true,
          onSaved: onSaved,
          onCancel: onCancel,
        ),
        floatingActionButton: fab,
      );
    }

    // Mobile: Use list content with full scaffold
    return CertificationListContent(
      showAppBar: true,
      floatingActionButton: fab,
    );
  }
}
