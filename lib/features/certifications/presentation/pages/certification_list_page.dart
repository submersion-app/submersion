import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/features/certifications/domain/constants/certification_field.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_sort_sheet.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_view_switch_selector.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/table_selection_owner.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_column_picker.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/remembered_selection.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/table_mode_layout/table_mode_layout.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_list_content.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_summary_widget.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_detail_page.dart';
import 'package:submersion/features/certifications/presentation/pages/certification_edit_page.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_query_providers.dart';
import 'package:submersion/features/certifications/query/certification_query_entity.dart';
import 'package:submersion/features/query/presentation/widgets/query_filter_sheet.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_search_delegate.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_list_count_provider.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_context.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';
import 'package:submersion/shared/widgets/section_header_title.dart';

class CertificationListPage extends ConsumerStatefulWidget {
  const CertificationListPage({super.key, this.headerTitle});

  /// Replaces every layout's header title, as Training's tab switch does
  /// (#3437).
  final SectionHeaderTitle? headerTitle;

  @override
  ConsumerState<CertificationListPage> createState() =>
      _CertificationListPageState();
}

class _CertificationListPageState extends ConsumerState<CertificationListPage>
    with TableSelectionOwner {
  @override
  Widget build(BuildContext context) {
    ref.watch(certificationCatalogSyncProvider);
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

    resetTableSelectionOffTable(certificationListViewModeProvider);

    // Table mode: use shared TableModeLayout for full-width table with
    // optional detail pane.
    final viewMode = ref.watch(certificationListViewModeProvider);
    if (viewMode == ListViewMode.table) {
      final countLabel = certificationListCountLabel(context, ref);
      return FocusTraversalGroup(
        child: TableModeLayout(
          sectionKey: 'certifications',
          rememberedSelectedId: ref.watch(rememberedCertificationIdProvider),
          appBarTitle: context.l10n.nav_certifications,
          appBarSubtitle: countLabel,
          appBarTitleWidget: widget.headerTitle?.build(
            context,
            SectionHeaderSlot.table,
            countLabel,
          ),
          appBarToolbarHeight: widget.headerTitle?.appBarHeight(
            context,
            countLabel,
          ),
          phoneAppBarPin: widget.headerTitle?.pinAppBar,
          tableContent: CertificationListContent(
            showAppBar: false,
            selectionController: tableSelection,
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
          selectedId: ref.watch(highlightedCertificationIdProvider),
          onEntitySelected: (id) {
            ref.read(highlightedCertificationIdProvider.notifier).state = id;
          },
          columnSettingsAction: IconButton(
            icon: const Icon(Icons.view_column_outlined),
            tooltip: context.l10n.columnConfig_tooltip_columnSettings,
            onPressed: () => showEntityTableColumnPicker<CertificationField>(
              context,
              configProvider: certificationTableConfigProvider,
              adapter: CertificationFieldAdapter.withCatalog(
                context.certificationCatalog,
              ),
            ),
          ),
          appBarActions: [
            IconButton(
              icon: const Icon(Icons.wallet, size: 20),
              tooltip: context.l10n.certifications_list_tooltip_walletView,
              onPressed: () => context.push('/certifications/wallet'),
            ),
            IconButton(
              icon: const Icon(Icons.search, size: 20),
              tooltip: context.l10n.certifications_list_tooltip_search,
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: CertificationSearchDelegate(),
                );
              },
            ),
            QueryFilterAction(
              provider: certificationQueryProvider,
              subject: QuerySubject.certifications,
              root: certificationQueryEntity,
              compact: true,
            ),
            IconButton(
              icon: const Icon(Icons.sort, size: 20),
              tooltip: context.l10n.certifications_list_tooltip_sort,
              // Table mode stays flat -- no grouping control here (#3359) --
              // but still offers the List/Wallet switch the sort sheet
              // carries everywhere else.
              onPressed: () => showCertificationSortSheet(
                context,
                ref,
                currentView: CertificationView.list,
                includeGroupBySelector: false,
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value.startsWith('view_')) {
                  final mode = ListViewMode.fromName(
                    value.replaceFirst('view_', ''),
                  );
                  ref.read(certificationListViewModeProvider.notifier).state =
                      mode;
                }
              },
              itemBuilder: (context) {
                final currentMode = ref.read(certificationListViewModeProvider);
                return [
                  ...tableSelectItemsEntries(context),
                  ...ListViewModeToggle.menuItems(
                    context,
                    currentMode: currentMode,
                    modes: const [ListViewMode.detailed, ListViewMode.table],
                  ),
                ];
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
        sectionId: RecordListSection.certifications,
        rememberedSelectedId: ref.watch(rememberedCertificationIdProvider),
        masterBuilder: (context, onItemSelected, selectedId) =>
            CertificationListContent(
              onItemSelected: onItemSelected,
              selectedId: selectedId,
              showAppBar: false,
              headerTitle: widget.headerTitle,
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
        headerTitle: widget.headerTitle,
        floatingActionButton: fab,
      ),
    );
  }
}
