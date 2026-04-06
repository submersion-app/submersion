import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_column_picker.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_view.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';
import 'package:submersion/features/courses/domain/constants/course_field.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/presentation/widgets/course_card.dart';

/// Content widget for the course list
class CourseListContent extends ConsumerStatefulWidget {
  final void Function(String?)? onItemSelected;
  final String? selectedId;
  final bool showAppBar;
  final Widget? floatingActionButton;

  const CourseListContent({
    super.key,
    this.onItemSelected,
    this.selectedId,
    this.showAppBar = true,
    this.floatingActionButton,
  });

  @override
  ConsumerState<CourseListContent> createState() => _CourseListContentState();
}

class _CourseListContentState extends ConsumerState<CourseListContent> {
  final ScrollController _scrollController = ScrollController();
  String _filterStatus = 'all'; // 'all', 'in_progress', 'completed'

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleItemTap(Course course) {
    if (widget.onItemSelected != null) {
      widget.onItemSelected!(course.id);
    } else {
      context.push('/courses/${course.id}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewMode = ref.watch(courseListViewModeProvider);
    final coursesAsync = ref.watch(courseListNotifierProvider);

    // Table mode uses a dedicated scaffold with column configuration support.
    if (viewMode == ListViewMode.table) {
      return _buildTableModeScaffold(context, coursesAsync);
    }

    final sort = ref.watch(courseSortProvider);

    final content = coursesAsync.when(
      data: (courses) {
        // Apply status filter
        final filtered = _filterStatus == 'all'
            ? courses
            : _filterStatus == 'in_progress'
            ? courses.where((c) => c.isInProgress).toList()
            : courses.where((c) => c.isCompleted).toList();

        final sorted = applyCourseSorting(filtered, sort);
        return sorted.isEmpty
            ? _buildEmptyState(context)
            : _buildCourseList(context, sorted);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(context, error),
    );

    if (!widget.showAppBar) {
      return Column(
        children: [
          _buildCompactAppBar(context),
          _buildFilterChips(context),
          Expanded(child: content),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.courses_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: context.l10n.courses_action_sort,
            onPressed: () => _showSortSheet(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
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
      ),
      body: Column(
        children: [
          _buildFilterChips(context),
          Expanded(child: content),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }

  /// Build the full scaffold/layout for table mode.
  Widget _buildTableModeScaffold(
    BuildContext context,
    AsyncValue<List<Course>> coursesAsync,
  ) {
    final tableContent = _buildTableView(context, coursesAsync);

    if (!widget.showAppBar) {
      return Column(
        children: [
          _buildCompactAppBar(context),
          Expanded(child: tableContent),
        ],
      );
    }

    return Scaffold(
      appBar: _buildTableAppBar(context),
      body: tableContent,
      floatingActionButton: widget.floatingActionButton,
    );
  }

  /// Build the AppBar for table mode with column picker button.
  AppBar _buildTableAppBar(BuildContext context) {
    return AppBar(
      title: Text(context.l10n.courses_title),
      actions: [
        IconButton(
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
        SizedBox(
          height: 24,
          child: VerticalDivider(
            width: 16,
            thickness: 1,
            color: Theme.of(
              context,
            ).colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
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
    );
  }

  /// Build the [EntityTableView] for course table mode.
  Widget _buildTableView(
    BuildContext context,
    AsyncValue<List<Course>> coursesAsync,
  ) {
    return coursesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => _buildErrorState(context, e),
      data: (courses) {
        if (courses.isEmpty) {
          return _buildEmptyState(context);
        }
        final config = ref.watch(courseTableConfigProvider);
        final notifier = ref.read(courseTableConfigProvider.notifier);
        final settings = ref.watch(settingsProvider);
        final units = UnitFormatter(settings);

        return EntityTableView<Course, CourseField>(
          entities: courses,
          idExtractor: (c) => c.id,
          adapter: CourseFieldAdapter.instance,
          config: config,
          units: units,
          onSortFieldChanged: notifier.setSortField,
          onResizeColumn: notifier.resizeColumn,
          onEntityTap: (id) {
            final match = courses.firstWhere((c) => c.id == id);
            _handleItemTap(match);
          },
          onEntityDoubleTap: (id) => context.go('/courses/$id'),
          selectedIds: const {},
          isSelectionMode: false,
          highlightedId: widget.selectedId,
        );
      },
    );
  }

  Widget _buildCompactAppBar(BuildContext context) {
    final viewMode = ref.watch(courseListViewModeProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Text(
            context.l10n.courses_title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (viewMode == ListViewMode.table)
            IconButton(
              icon: const Icon(Icons.view_column_outlined, size: 20),
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
          if (viewMode == ListViewMode.table)
            SizedBox(
              height: 24,
              child: VerticalDivider(
                width: 16,
                thickness: 1,
                color: Theme.of(
                  context,
                ).colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
          if (viewMode != ListViewMode.table)
            IconButton(
              icon: const Icon(Icons.sort, size: 20),
              tooltip: context.l10n.courses_action_sort,
              onPressed: () => _showSortSheet(context),
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
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: Text(context.l10n.courses_filter_all),
              selected: _filterStatus == 'all',
              onSelected: (selected) {
                if (selected) setState(() => _filterStatus = 'all');
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              avatar: Icon(
                Icons.pending_outlined,
                size: 18,
                color: _filterStatus == 'in_progress'
                    ? colorScheme.onPrimaryContainer
                    : null,
              ),
              label: Text(context.l10n.courses_status_inProgress),
              selected: _filterStatus == 'in_progress',
              onSelected: (selected) {
                if (selected) setState(() => _filterStatus = 'in_progress');
              },
            ),
            const SizedBox(width: 8),
            FilterChip(
              avatar: Icon(
                Icons.check_circle_outline,
                size: 18,
                color: _filterStatus == 'completed'
                    ? colorScheme.onPrimaryContainer
                    : null,
              ),
              label: Text(context.l10n.courses_status_completed),
              selected: _filterStatus == 'completed',
              onSelected: (selected) {
                if (selected) setState(() => _filterStatus = 'completed');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseList(BuildContext context, List<Course> courses) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.read(courseListNotifierProvider.notifier).refresh();
      },
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: courses.length,
        itemBuilder: (context, index) {
          final course = courses[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CourseCard(
              course: course,
              isSelected: widget.selectedId == course.id,
              onTap: () => _handleItemTap(course),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final message = _filterStatus == 'in_progress'
        ? context.l10n.courses_empty_noInProgress
        : _filterStatus == 'completed'
        ? context.l10n.courses_empty_noCompleted
        : context.l10n.courses_empty_title;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.school_outlined,
            size: 64,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.courses_empty_subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          if (_filterStatus == 'all') ...[
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                if (ResponsiveBreakpoints.isMasterDetail(context)) {
                  final routerState = GoRouterState.of(context);
                  context.go('${routerState.uri.path}?mode=new');
                } else {
                  context.push('/courses/new');
                }
              },
              icon: const Icon(Icons.add),
              label: Text(context.l10n.courses_empty_button),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: colorScheme.error),
          const SizedBox(height: 16),
          Text(
            context.l10n.courses_error_generic(error.toString()),
            style: TextStyle(color: colorScheme.error),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              ref.read(courseListNotifierProvider.notifier).refresh();
            },
            child: Text(context.l10n.courses_action_retry),
          ),
        ],
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
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
  }
}
