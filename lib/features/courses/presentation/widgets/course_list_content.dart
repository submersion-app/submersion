import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/shared/widgets/sort_bottom_sheet.dart';
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
    final sort = ref.watch(courseSortProvider);
    final coursesAsync = ref.watch(courseListNotifierProvider);

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
        title: const Text('Training Courses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onPressed: () => _showSortSheet(context),
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

  Widget _buildCompactAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
      child: Row(
        children: [
          Text(
            'Training Courses',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort',
            onPressed: () => _showSortSheet(context),
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
              label: const Text('All'),
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
              label: const Text('In Progress'),
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
              label: const Text('Completed'),
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
        ? 'No courses in progress'
        : _filterStatus == 'completed'
        ? 'No completed courses'
        : 'No training courses yet';

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
            'Add your first course to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
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
          Text('Error: $error', style: TextStyle(color: colorScheme.error)),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () {
              ref.read(courseListNotifierProvider.notifier).refresh();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  void _showSortSheet(BuildContext context) {
    final sort = ref.read(courseSortProvider);
    showSortBottomSheet<CourseSortField>(
      context: context,
      title: 'Sort Courses',
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
