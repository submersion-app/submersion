import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';

/// Summary widget shown when no course is selected in master-detail layout.
class CourseSummaryWidget extends ConsumerWidget {
  const CourseSummaryWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coursesAsync = ref.watch(courseListNotifierProvider);

    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 24),
            coursesAsync.when(
              data: (courses) => _buildOverview(context, courses),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
            const SizedBox(height: 24),
            _buildQuickActions(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.school,
              size: 32,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Training Courses',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Select a course from the list to view details',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildOverview(BuildContext context, List<Course> courses) {
    final inProgressCount = courses.where((c) => c.isInProgress).length;
    final completedCount = courses.where((c) => c.isCompleted).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildStatCard(
              context,
              icon: Icons.school,
              value: '${courses.length}',
              label: 'Total',
              color: Colors.blue,
            ),
            _buildStatCard(
              context,
              icon: Icons.pending,
              value: '$inProgressCount',
              label: 'In Progress',
              color: Colors.orange,
            ),
            _buildStatCard(
              context,
              icon: Icons.check_circle,
              value: '$completedCount',
              label: 'Completed',
              color: Colors.green,
            ),
          ],
        ),
        if (courses.isNotEmpty) ...[
          const SizedBox(height: 24),
          _buildCourseListPreview(context, courses),
        ],
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return SizedBox(
      width: 120,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCourseListPreview(BuildContext context, List<Course> courses) {
    // Show in-progress courses first, then recent completed
    final sortedCourses = List<Course>.from(courses)
      ..sort((a, b) {
        // In progress first
        if (a.isInProgress && !b.isInProgress) return -1;
        if (!a.isInProgress && b.isInProgress) return 1;
        // Then by start date descending
        return b.startDate.compareTo(a.startDate);
      });
    final previewCourses = sortedCourses.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Courses',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: previewCourses.map((course) {
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: course.isCompleted
                        ? Colors.green.withValues(alpha: 0.15)
                        : Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    course.isCompleted
                        ? Icons.check_circle_outline
                        : Icons.school_outlined,
                    color: course.isCompleted
                        ? Colors.green
                        : Theme.of(context).colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                title: Text(
                  course.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(course.agency.displayName),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  final state = GoRouterState.of(context);
                  final currentPath = state.uri.path;
                  context.go('$currentPath?selected=${course.id}');
                },
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton.icon(
              onPressed: () {
                final state = GoRouterState.of(context);
                final currentPath = state.uri.path;
                context.go('$currentPath?mode=new');
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Course'),
            ),
          ],
        ),
      ],
    );
  }
}
