import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/features/courses/domain/constants/course_field.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_column_picker.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';
import 'package:submersion/shared/widgets/table_mode_layout/table_mode_layout.dart';
import 'package:submersion/features/courses/presentation/widgets/course_list_content.dart';
import 'package:submersion/features/courses/presentation/widgets/course_summary_widget.dart';
import 'package:submersion/features/courses/presentation/pages/course_detail_page.dart';
import 'package:submersion/features/courses/presentation/pages/course_edit_page.dart';

class CourseListPage extends ConsumerWidget {
  const CourseListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fab = FloatingActionButton.extended(
      onPressed: () {
        final isDesktop = ResponsiveBreakpoints.isMasterDetail(context);
        final viewMode = ref.read(courseListViewModeProvider);
        if (isDesktop && viewMode != ListViewMode.table) {
          final state = GoRouterState.of(context);
          final currentPath = state.uri.path;
          context.go('$currentPath?mode=new');
        } else {
          context.push('/courses/new');
        }
      },
      tooltip: context.l10n.courses_action_add,
      icon: const Icon(Icons.add),
      label: Text(context.l10n.courses_action_add),
    );

    // Table mode: use shared TableModeLayout for full-width table with
    // optional detail pane.
    final viewMode = ref.watch(courseListViewModeProvider);
    if (viewMode == ListViewMode.table) {
      return FocusTraversalGroup(
        child: TableModeLayout(
          sectionKey: 'courses',
          appBarTitle: context.l10n.nav_courses,
          tableContent: const CourseListContent(showAppBar: false),
          detailBuilder: (context, courseId) => CourseDetailPage(
            courseId: courseId,
            embedded: true,
            onDeleted: () {
              final state = GoRouterState.of(context);
              context.go(state.uri.path);
            },
          ),
          summaryBuilder: (context) => const CourseSummaryWidget(),
          editBuilder: (context, courseId, onSaved, onCancel) => CourseEditPage(
            courseId: courseId,
            embedded: true,
            onSaved: () => onSaved(courseId),
            onCancel: onCancel,
          ),
          createBuilder: (context, onSaved, onCancel) => CourseEditPage(
            embedded: true,
            onSavedWithId: onSaved,
            onCancel: onCancel,
          ),
          selectedId: ref.watch(highlightedCourseIdProvider),
          onEntitySelected: (id) {
            ref.read(highlightedCourseIdProvider.notifier).state = id;
          },
          columnSettingsAction: IconButton(
            icon: const Icon(Icons.view_column_outlined),
            tooltip: 'Column settings',
            onPressed: () {
              final config = ref.read(courseTableConfigProvider);
              final notifier = ref.read(courseTableConfigProvider.notifier);
              showEntityTableColumnPicker<CourseField>(
                context,
                config: config,
                adapter: CourseFieldAdapter.instance,
                onToggleColumn: notifier.toggleColumn,
                onReorderColumn: notifier.reorderColumn,
                onTogglePin: notifier.togglePin,
              );
            },
          ),
          appBarActions: [
            IconButton(
              icon: const Icon(Icons.sort, size: 20),
              tooltip: context.l10n.courses_action_sort,
              onPressed: () {
                final sort = ref.read(courseSortProvider);
                showSortBottomSheet<CourseSortField>(
                  context: context,
                  title: context.l10n.courses_action_sortTitle,
                  currentField: sort.field,
                  currentDirection: sort.direction,
                  fields: CourseSortField.values,
                  getFieldDisplayName: (field) => field.displayName,
                  getFieldIcon: (field) => field.icon,
                  onSortChanged: (field, direction) {
                    ref.read(courseSortProvider.notifier).state = SortState(
                      field: field,
                      direction: direction,
                    );
                  },
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
                  ref.read(courseListViewModeProvider.notifier).state = mode;
                }
              },
              itemBuilder: (context) {
                final currentMode = ref.read(courseListViewModeProvider);
                return [
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
        sectionId: 'courses',
        masterBuilder: (context, onItemSelected, selectedId) =>
            CourseListContent(
              onItemSelected: onItemSelected,
              selectedId: selectedId,
              showAppBar: false,
            ),
        detailBuilder: (context, courseId) => CourseDetailPage(
          courseId: courseId,
          embedded: true,
          onDeleted: () {
            final state = GoRouterState.of(context);
            context.go(state.uri.path);
          },
        ),
        summaryBuilder: (context) => const CourseSummaryWidget(),
        editBuilder: (context, courseId, onSaved, onCancel) => CourseEditPage(
          courseId: courseId,
          embedded: true,
          onSaved: () => onSaved(courseId),
          onCancel: onCancel,
        ),
        createBuilder: (context, onSaved, onCancel) => CourseEditPage(
          embedded: true,
          onSavedWithId: onSaved,
          onCancel: onCancel,
        ),
        floatingActionButton: fab,
      );
    }

    // Mobile: Use list content with full scaffold
    return FocusTraversalGroup(
      child: CourseListContent(showAppBar: true, floatingActionButton: fab),
    );
  }
}
