import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/detail_row/detail_row.dart';

/// The Details card's training-course rows (#1219, #2515): one tappable row
/// per course, the group label on the first row only. Renders nothing until
/// the courses load, rather than reserving blank space.
class DiveCourseRows extends ConsumerWidget {
  const DiveCourseRows({super.key, required this.diveId});

  final String diveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses =
        // The retained value: a reload after a link change keeps the rows.
        ref.watch(coursesForDiveProvider(diveId)).value ?? const <Course>[];
    if (courses.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < courses.length; i++)
          _CourseRow(course: courses[i], showLabel: i == 0),
      ],
    );
  }
}

class _CourseRow extends StatelessWidget {
  const _CourseRow({required this.course, required this.showLabel});

  final Course course;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      label: context.l10n.diveLog_detail_semantics_viewCourse(course.name),
      child: InkWell(
        onTap: () => context.push('/courses/${course.id}'),
        // Only the first row carries the label; the rest leave the label
        // cell empty so every course name lines up under the first.
        child: DetailRow(
          label: showLabel
              ? context.l10n.diveLog_edit_section_trainingCourses
              : '',
          value: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  course.name,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              ExcludeSemantics(
                child: Icon(Icons.chevron_right, size: 16, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The Signatures card header's course chips (#2515), one per course, each
/// opening its course. Wraps rather than overflowing on a phone-width pane.
class DiveCourseChips extends ConsumerWidget {
  const DiveCourseChips({super.key, required this.diveId});

  final String diveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses =
        // The retained value: a reload after a link change keeps the rows.
        ref.watch(coursesForDiveProvider(diveId)).value ?? const <Course>[];
    if (courses.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 4,
      runSpacing: 4,
      children: [for (final c in courses) _CourseChip(course: c)],
    );
  }
}

class _CourseChip extends StatelessWidget {
  const _CourseChip({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: context.l10n.diveLog_detail_semantics_viewCourse(course.name),
      child: InkWell(
        onTap: () => context.push('/courses/${course.id}'),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.school,
                size: 14,
                color: colorScheme.onPrimaryContainer,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  course.name,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
