import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';

/// A widget for selecting a training course for a dive.
class CoursePicker extends ConsumerWidget {
  final Course? selectedCourse;
  final ValueChanged<Course?> onCourseSelected;

  const CoursePicker({
    super.key,
    this.selectedCourse,
    required this.onCourseSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: selectedCourse?.isCompleted == true
            ? Colors.green.withValues(alpha: 0.15)
            : colorScheme.primaryContainer,
        child: Icon(
          selectedCourse?.isCompleted == true
              ? Icons.check_circle_outline
              : Icons.school,
          color: selectedCourse?.isCompleted == true
              ? Colors.green
              : colorScheme.onPrimaryContainer,
        ),
      ),
      title: Text(
        selectedCourse?.name ?? context.l10n.courses_picker_noneSelected,
      ),
      subtitle: selectedCourse != null
          ? Text(
              '${selectedCourse!.agency.displayName} - ${selectedCourse!.isCompleted ? context.l10n.courses_status_completed : context.l10n.courses_status_inProgress}',
            )
          : Text(context.l10n.courses_picker_tapToLink),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selectedCourse != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => onCourseSelected(null),
              tooltip: context.l10n.courses_picker_clearSelection,
            ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () => _showCoursePickerSheet(context, ref),
    );
  }

  void _showCoursePickerSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => CoursePickerSheet(
          scrollController: scrollController,
          selectedCourse: selectedCourse,
          onCourseSelected: (course) {
            Navigator.of(sheetContext).pop();
            onCourseSelected(course);
          },
        ),
      ),
    );
  }
}

/// A bottom sheet widget for selecting a course from a list.
class CoursePickerSheet extends ConsumerWidget {
  final ScrollController scrollController;
  final Course? selectedCourse;
  final ValueChanged<Course> onCourseSelected;

  const CoursePickerSheet({
    super.key,
    required this.scrollController,
    required this.selectedCourse,
    required this.onCourseSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(courseListNotifierProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Handle bar
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),

        // Title and add button
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.courses_picker_selectTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/courses/new');
                },
                icon: const Icon(Icons.add),
                label: Text(context.l10n.courses_picker_newCourse),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Course list
        Expanded(
          child: coursesAsync.when(
            data: (courses) {
              if (courses.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 48,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        context.l10n.courses_picker_noCourses,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          context.push('/courses/new');
                        },
                        icon: const Icon(Icons.add),
                        label: Text(context.l10n.courses_picker_createCourse),
                      ),
                    ],
                  ),
                );
              }

              // Sort: in-progress first, then by start date descending
              final sortedCourses = List<Course>.from(courses)
                ..sort((a, b) {
                  if (a.isInProgress && !b.isInProgress) return -1;
                  if (!a.isInProgress && b.isInProgress) return 1;
                  return b.startDate.compareTo(a.startDate);
                });

              return ListView.builder(
                controller: scrollController,
                itemCount: sortedCourses.length,
                itemBuilder: (context, index) {
                  final course = sortedCourses[index];
                  final isSelected = selectedCourse?.id == course.id;
                  final dateFormat = DateFormat.yMMMd();

                  final courseLabel =
                      '${course.agency.displayName} ${course.name}, ${context.l10n.courses_card_started(dateFormat.format(course.startDate))}${isSelected ? ', ${context.l10n.courses_picker_selected}' : ''}${course.isInProgress ? ', ${context.l10n.courses_picker_active}' : ''}';

                  return Semantics(
                    label: courseLabel,
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected
                            ? colorScheme.primary
                            : course.isCompleted
                            ? Colors.green.withValues(alpha: 0.15)
                            : colorScheme.primaryContainer,
                        child: Icon(
                          course.isCompleted
                              ? Icons.check_circle_outline
                              : Icons.school_outlined,
                          color: isSelected
                              ? colorScheme.onPrimary
                              : course.isCompleted
                              ? Colors.green
                              : colorScheme.onPrimaryContainer,
                        ),
                      ),
                      title: Text(course.name),
                      subtitle: Text(
                        '${course.agency.displayName} - ${context.l10n.courses_card_started(dateFormat.format(course.startDate))}',
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle, color: colorScheme.primary)
                          : course.isInProgress
                          ? Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                context.l10n.courses_picker_active,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                    ),
                              ),
                            )
                          : null,
                      onTap: () => onCourseSelected(course),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(
              child: Text(
                context.l10n.courses_picker_errorLoading(error.toString()),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
