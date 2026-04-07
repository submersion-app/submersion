import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/certifications/domain/constants/certification_field.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_column_picker.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/table_mode_layout/table_mode_layout.dart';
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
        final isDesktop = ResponsiveBreakpoints.isMasterDetail(context);
        final viewMode = ref.read(certificationListViewModeProvider);
        if (isDesktop && viewMode != ListViewMode.table) {
          final state = GoRouterState.of(context);
          final currentPath = state.uri.path;
          context.go('$currentPath?mode=new');
        } else {
          context.push('/certifications/new');
        }
      },
      tooltip: context.l10n.certifications_list_tooltip_addCertification,
      icon: const Icon(Icons.add_card),
      label: Text(context.l10n.certifications_list_fab_addCertification),
    );

    // Table mode: use shared TableModeLayout for full-width table with
    // optional detail pane.
    final viewMode = ref.watch(certificationListViewModeProvider);
    if (viewMode == ListViewMode.table) {
      return FocusTraversalGroup(
        child: TableModeLayout(
          sectionKey: 'certifications',
          appBarTitle: context.l10n.nav_certifications,
          tableContent: const CertificationListContent(showAppBar: false),
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
          selectedId: ref.watch(highlightedCertificationIdProvider),
          onEntitySelected: (id) {
            ref.read(highlightedCertificationIdProvider.notifier).state = id;
          },
          appBarActions: [
            IconButton(
              icon: const Icon(Icons.view_column_outlined),
              tooltip: 'Column settings',
              onPressed: () {
                final config = ref.read(certificationTableConfigProvider);
                final notifier = ref.read(
                  certificationTableConfigProvider.notifier,
                );
                showEntityTableColumnPicker<CertificationField>(
                  context,
                  config: config,
                  adapter: CertificationFieldAdapter.instance,
                  onToggleColumn: notifier.toggleColumn,
                  onReorderColumn: notifier.reorderColumn,
                  onTogglePin: notifier.togglePin,
                );
              },
            ),
          ],
          floatingActionButton: fab,
        ),
      );
    }

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
    return FocusTraversalGroup(
      child: CertificationListContent(
        showAppBar: true,
        floatingActionButton: fab,
      ),
    );
  }
}
