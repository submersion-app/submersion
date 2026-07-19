import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';

/// Dashboard card: one compact progress row per in-progress course that has
/// requirements. Renders nothing (and reserves no space) otherwise, so the
/// dashboard column spacing is owned here via a bottom margin.
class ActiveCourseProgressCard extends ConsumerWidget {
  const ActiveCourseProgressCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(activeCoursesProgressProvider);
    final entries = (entriesAsync.value ?? const <ActiveCourseProgress>[])
        .where((entry) => entry.progress.totalCount > 0)
        .toList();
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 20,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.dashboard_activeCourses_title,
                    style: theme.textTheme.titleMedium,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              for (final entry in entries)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => context.push('/courses/${entry.course.id}'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.course.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 80,
                          child: LinearProgressIndicator(
                            value:
                                entry.progress.satisfiedCount /
                                entry.progress.totalCount,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${entry.progress.satisfiedCount}'
                          '/${entry.progress.totalCount}',
                          style: theme.textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
