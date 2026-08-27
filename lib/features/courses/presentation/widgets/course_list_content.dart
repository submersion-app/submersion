import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/sort_options_display.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/selection/bulk_action.dart';
import 'package:submersion/shared/selection/selectable_list_scope.dart';
import 'package:submersion/shared/selection/selection_app_bar.dart';
import 'package:submersion/shared/selection/selection_entry_bar.dart';
import 'package:submersion/shared/selection/selection_controller.dart';
import 'package:submersion/shared/selection/selection_state.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/widgets/entity_table/entity_table_view.dart';
import 'package:submersion/shared/widgets/list_view_mode_toggle.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';
import 'package:submersion/features/courses/domain/constants/course_field.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/presentation/widgets/course_card.dart';
import 'package:submersion/shared/widgets/feature_accent.dart';

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
  /// Owns the bulk-selection state machine for this list.
  final SelectionController _selection = SelectionController();

  /// Convenience mirrors of the controller, so the widget tree reads clearly.
  bool get _isSelectionMode => _selection.value.isActive;
  Set<String> get _selectedIds => _selection.value.checkedIds;

  final ScrollController _scrollController = ScrollController();
  String _filterStatus = 'all'; // 'all', 'in_progress', 'completed'

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _handleItemTap(Course course) {
    ref.read(highlightedCourseIdProvider.notifier).state = course.id;
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

    // List mode filters by status and sorts; the table path uses the raw
    // list. selectableIds must follow whichever is rendering, or pruning
    // fights the visible set.
    final visibleCourses = _visibleCourses(
      coursesAsync.value ?? const [],
      sort,
    );
    final visibleIds = visibleCourses.map((c) => c.id).toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selection.pruneTo(visibleIds);
    });

    // Built inside the selection listener below so rows re-render as checks
    // change; computing it here would leave the list frozen mid-selection.
    Widget buildContent() {
      return coursesAsync.when(
        data: (courses) {
          final sorted = _visibleCourses(courses, sort);
          return sorted.isEmpty
              ? _buildEmptyState(context)
              : _buildCourseList(context, sorted);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(context, error),
      );
    }

    if (!widget.showAppBar) {
      return SelectableListScope(
        controller: _selection,
        selectableIds: visibleIds,
        child: ValueListenableBuilder<SelectionState>(
          valueListenable: _selection,
          builder: (context, selection, _) => Column(
            children: [
              selection.isActive
                  ? _buildSelectionBar(visibleCourses, SelectionBarShell.pane)
                  : _buildCompactAppBar(context),
              _buildFilterChips(context),
              Expanded(child: buildContent()),
            ],
          ),
        ),
      );
    }

    return SelectableListScope(
      controller: _selection,
      selectableIds: visibleIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) => Scaffold(
          appBar: selection.isActive
              ? _buildSelectionBar(visibleCourses, SelectionBarShell.appBar)
              : AppBar(
                  title: FeatureAppBarTitle(
                    featureId: 'courses',
                    title: context.l10n.courses_title,
                  ),
                  actions: [
                    IconButton(
                      icon: const Icon(Icons.sort),
                      tooltip: context.l10n.courses_action_sort,
                      onPressed: () => _showSortSheet(context),
                    ),
                    // The only way into bulk actions: entry by long-press was removed,
                    // so nothing but this control opens selection mode on touch.
                    IconButton(
                      key: const ValueKey('enter_selection'),
                      icon: const Icon(Icons.checklist),
                      tooltip: context.l10n.common_selection_enterTooltip,
                      onPressed: _selection.enterExplicit,
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert),
                      onSelected: (value) {
                        if (value.startsWith('view_')) {
                          final mode = ListViewMode.fromName(
                            value.replaceFirst('view_', ''),
                          );
                          ref.read(courseListViewModeProvider.notifier).state =
                              mode;
                        }
                      },
                      itemBuilder: (context) {
                        final currentMode = ref.read(
                          courseListViewModeProvider,
                        );
                        return [
                          ...ListViewModeToggle.menuItems(
                            context,
                            currentMode: currentMode,
                            modes: const [
                              ListViewMode.detailed,
                              ListViewMode.table,
                            ],
                          ),
                        ];
                      },
                    ),
                  ],
                ),
          body: Column(
            children: [
              _buildFilterChips(context),
              Expanded(child: buildContent()),
            ],
          ),
          floatingActionButton: selection.isActive
              ? null
              : widget.floatingActionButton,
        ),
      ),
    );
  }

  /// Build the full scaffold/layout for table mode.
  ///
  /// When embedded inside [TableModeLayout] (showAppBar: false), provides
  /// only the compact app bar and the table content.
  /// Courses visible under the active status filter, sorted.
  ///
  /// Shared by the list and by the pruning in [build] so the selection can
  /// never hold a course the filter has hidden.
  List<Course> _visibleCourses(
    List<Course> courses,
    SortState<CourseSortField> sort,
  ) {
    final filtered = _filterStatus == 'all'
        ? courses
        : _filterStatus == 'in_progress'
        ? courses.where((c) => c.isInProgress).toList()
        : courses.where((c) => c.isCompleted).toList();
    return applyCourseSorting(filtered, sort);
  }

  /// Course-specific extras. Select-all, deselect-all and delete come from
  /// SelectionAppBar.
  List<BulkAction> _bulkActions(List<Course> courses) {
    return [
      BulkAction(
        id: 'mark_complete',
        icon: Icons.check_circle_outline,
        label: context.l10n.courses_dialog_complete,
        // Completing an already-completed course is meaningless, so the
        // action requires a uniformly in-progress selection.
        isEnabled: (ids) {
          final checked = courses.where((c) => ids.contains(c.id));
          return checked.isNotEmpty && checked.every((c) => c.isInProgress);
        },
        onInvoke: _markSelectedComplete,
      ),
    ];
  }

  SelectionAppBar _buildSelectionBar(
    List<Course> courses,
    SelectionBarShell shell,
  ) {
    return SelectionAppBar(
      controller: _selection,
      selectableIds: courses.map((c) => c.id).toList(),
      actions: _bulkActions(courses),
      shell: shell,
      maxInlineActions: shell == SelectionBarShell.pane ? 1 : 3,
      onDelete: _confirmAndDelete,
    );
  }

  /// One tap policy for every course row.
  void _handleRowTap(Course course) {
    if (SelectableListScope.isModifierPressed()) {
      _selection.enterImplicit(course.id);
      return;
    }
    if (_isSelectionMode) {
      _selection.toggle(course.id);
      return;
    }
    _handleItemTap(course);
  }

  /// Mark every checked course complete, mirroring the per-course action.
  Future<void> _markSelectedComplete() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;
    final courses = (ref.read(courseListNotifierProvider).value ?? const [])
        .where((c) => ids.contains(c.id))
        .toList();

    final notifier = ref.read(courseListNotifierProvider.notifier);
    _selection.exit();
    final now = DateTime.now();
    for (final course in courses) {
      await notifier.updateCourse(course.copyWith(completionDate: now));
    }
  }

  Future<void> _confirmAndDelete() async {
    final ids = _selectedIds.toList();
    if (ids.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.common_bulkDelete_title(ids.length)),
        content: Text(ctx.l10n.common_bulkDelete_body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: Text(ctx.l10n.common_action_delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    final notifier = ref.read(courseListNotifierProvider.notifier);
    _selection.exit();
    for (final id in ids) {
      await notifier.deleteCourse(id);
    }
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.common_bulkDelete_snackbar(ids.length)),
      ),
    );
  }

  Widget _buildTableModeScaffold(
    BuildContext context,
    AsyncValue<List<Course>> coursesAsync,
  ) {
    // The table renders the raw list, not the status-filtered one the list
    // modes render, so selectable ids come from the raw list here -- pruning
    // must follow whichever path is on screen.
    final visibleIds = (coursesAsync.value ?? const <Course>[])
        .map((c) => c.id)
        .toList();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _selection.pruneTo(visibleIds);
    });

    // The scope carries Escape, Ctrl/Cmd-A and the Android back handling, and
    // the builder is what repaints the table as checks change -- the table is
    // built inside it for that reason.
    return SelectableListScope(
      controller: _selection,
      selectableIds: visibleIds,
      child: ValueListenableBuilder<SelectionState>(
        valueListenable: _selection,
        builder: (context, selection, _) {
          final courses = coursesAsync.value ?? const <Course>[];
          // Table mode has no app bar of its own, so both bars live here:
          // the contextual one while selecting, and the Select affordance
          // while not. They share a slot and a height, so the table does not
          // shift as the mode opens.
          return Column(
            children: [
              if (selection.isActive)
                _buildSelectionBar(courses, SelectionBarShell.pane)
              else
                SelectionEntryBar(controller: _selection),
              Expanded(child: _buildTableView(context, coursesAsync)),
            ],
          );
        },
      ),
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
          onEntityTapDown: (id) {
            ref.read(highlightedCourseIdProvider.notifier).state = id;
          },
          onEntityTap: (id) {
            if (_isSelectionMode) _selection.toggle(id);
          },
          onEntityDoubleTap: (id) {
            context.push('/courses/$id');
          },
          selectedIds: _selectedIds,
          isSelectionMode: _isSelectionMode,
          highlightedId: ref.watch(highlightedCourseIdProvider),
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
          // Expanded, and no Spacer: the title must be the row's only flexible
          // child, or Spacer takes half the free space and the leftover half
          // lands after the last icon (see trip_list_content for the detail).
          Expanded(
            child: FeatureAppBarTitle(
              featureId: 'courses',
              title: context.l10n.courses_title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (viewMode != ListViewMode.table)
            IconButton(
              icon: const Icon(Icons.sort, size: 20),
              tooltip: context.l10n.courses_action_sort,
              onPressed: () => _showSortSheet(context),
            ),
          // The only way into bulk actions: entry by long-press was removed,
          // so nothing but this control opens selection mode on touch.
          IconButton(
            key: const ValueKey('enter_selection'),
            icon: const Icon(Icons.checklist, size: 20),
            tooltip: context.l10n.common_selection_enterTooltip,
            onPressed: _selection.enterExplicit,
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
              isSelected:
                  widget.selectedId == course.id ||
                  ref.watch(highlightedCourseIdProvider) == course.id,
              onTap: () => _handleRowTap(course),
              isSelectionMode: _isSelectionMode,
              isChecked: _selectedIds.contains(course.id),
              onCheckChanged: (_) => _selection.toggle(course.id),
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
      getFieldDisplayName: (field) => field.localizedName(context.l10n),
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
