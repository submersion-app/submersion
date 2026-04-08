import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/buddies/domain/constants/buddy_field.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_column_picker.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';
import 'package:submersion/shared/widgets/table_mode_layout/table_mode_layout.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_list_content.dart';
import 'package:submersion/features/buddies/presentation/widgets/buddy_summary_widget.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_detail_page.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_edit_page.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

class BuddyListPage extends ConsumerWidget {
  const BuddyListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fab = FloatingActionButton.extended(
      onPressed: () {
        final isDesktop = ResponsiveBreakpoints.isMasterDetail(context);
        final viewMode = ref.read(buddyListViewModeProvider);
        if (isDesktop && viewMode != ListViewMode.table) {
          final state = GoRouterState.of(context);
          final currentPath = state.uri.path;
          context.go('$currentPath?mode=new');
        } else {
          context.push('/buddies/new');
        }
      },
      tooltip: context.l10n.buddies_action_addTooltip,
      icon: const Icon(Icons.person_add),
      label: Text(context.l10n.buddies_action_add),
    );

    // Table mode: use shared TableModeLayout for full-width table with
    // optional detail pane.
    final viewMode = ref.watch(buddyListViewModeProvider);
    if (viewMode == ListViewMode.table) {
      return FocusTraversalGroup(
        child: TableModeLayout(
          sectionKey: 'buddies',
          appBarTitle: context.l10n.nav_buddies,
          tableContent: const BuddyListContent(showAppBar: false),
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
          createBuilder: (context, onSaved, onCancel) => BuddyEditPage(
            embedded: true,
            onSaved: onSaved,
            onCancel: onCancel,
          ),
          selectedId: ref.watch(highlightedBuddyIdProvider),
          onEntitySelected: (id) {
            ref.read(highlightedBuddyIdProvider.notifier).state = id;
          },
          columnSettingsAction: IconButton(
            icon: const Icon(Icons.view_column_outlined),
            tooltip: 'Column settings',
            onPressed: () {
              final config = ref.read(buddyTableConfigProvider);
              final notifier = ref.read(buddyTableConfigProvider.notifier);
              showEntityTableColumnPicker<BuddyField>(
                context,
                config: config,
                adapter: BuddyFieldAdapter.instance,
                onToggleColumn: notifier.toggleColumn,
                onReorderColumn: notifier.reorderColumn,
                onTogglePin: notifier.togglePin,
              );
            },
          ),
          appBarActions: [
            IconButton(
              icon: const Icon(Icons.sort, size: 20),
              tooltip: context.l10n.buddies_action_sort,
              onPressed: () {
                final sort = ref.read(buddySortProvider);
                showSortBottomSheet<BuddySortField>(
                  context: context,
                  title: context.l10n.buddies_action_sortTitle,
                  currentField: sort.field,
                  currentDirection: sort.direction,
                  fields: BuddySortField.values,
                  getFieldDisplayName: (field) => field.displayName,
                  getFieldIcon: (field) => field.icon,
                  onSortChanged: (field, direction) {
                    ref.read(buddySortProvider.notifier).state = SortState(
                      field: field,
                      direction: direction,
                    );
                  },
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.search, size: 20),
              tooltip: context.l10n.buddies_action_search,
              onPressed: () {
                showSearch(
                  context: context,
                  delegate: BuddySearchDelegate(ref),
                );
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (value) {
                if (value.startsWith('view_')) {
                  final mode = ListViewMode.fromName(
                    value.replaceFirst('view_', ''),
                  );
                  ref.read(buddyListViewModeProvider.notifier).state = mode;
                }
              },
              itemBuilder: (context) {
                final currentMode = ref.read(buddyListViewModeProvider);
                return [
                  ...ListViewModeToggle.menuItems(
                    context,
                    currentMode: currentMode,
                    modes: const [
                      ListViewMode.detailed,
                      ListViewMode.compact,
                      ListViewMode.table,
                    ],
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
      return FocusTraversalGroup(
        child: MasterDetailScaffold(
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
          createBuilder: (context, onSaved, onCancel) => BuddyEditPage(
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
      child: BuddyListContent(showAppBar: true, floatingActionButton: fab),
    );
  }
}
