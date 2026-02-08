import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/core/services/export/export_service.dart';
import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

class CourseDetailPage extends ConsumerWidget {
  final String courseId;
  final bool embedded;
  final VoidCallback? onDeleted;

  const CourseDetailPage({
    super.key,
    required this.courseId,
    this.embedded = false,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(courseByIdProvider(courseId));
    final divesAsync = ref.watch(courseDivesProvider(courseId));

    return courseAsync.when(
      data: (course) {
        if (course == null) {
          return _buildNotFound(context);
        }
        return _buildContent(context, ref, course, divesAsync);
      },
      loading: () => _buildLoading(context),
      error: (error, stack) => _buildError(context, error),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    Course course,
    AsyncValue<List<Dive>> divesAsync,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateFormat = DateFormat.yMMMd();

    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status card
          _buildStatusCard(context, course),
          const SizedBox(height: 16),

          // Course details
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(context, 'Course Details', Icons.school),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    context,
                    'Agency',
                    course.agency.displayName,
                    Icons.business,
                  ),
                  _buildDetailRow(
                    context,
                    'Start Date',
                    dateFormat.format(course.startDate),
                    Icons.calendar_today,
                  ),
                  if (course.completionDate != null)
                    _buildDetailRow(
                      context,
                      'Completed',
                      dateFormat.format(course.completionDate!),
                      Icons.check_circle,
                    ),
                  if (course.location != null)
                    _buildDetailRow(
                      context,
                      'Location',
                      course.location!,
                      Icons.place,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Instructor
          if (course.instructorName != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(context, 'Instructor', Icons.person),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      context,
                      'Name',
                      course.instructorName!,
                      Icons.badge,
                    ),
                    if (course.instructorNumber != null)
                      _buildDetailRow(
                        context,
                        'Instructor #',
                        course.instructorNumber!,
                        Icons.numbers,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Earned Certification
          if (course.certificationId != null)
            _buildCertificationSection(context, ref, course.certificationId!),

          // Training dives
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(
                    context,
                    'Training Dives',
                    Icons.scuba_diving,
                  ),
                  const SizedBox(height: 12),
                  divesAsync.when(
                    data: (dives) {
                      if (dives.isEmpty) {
                        return Text(
                          'No training dives linked yet',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                        );
                      }
                      return Column(
                        children: dives.map((dive) {
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: colorScheme.primary.withValues(
                                alpha: 0.15,
                              ),
                              child: Text(
                                '${dive.diveNumber ?? '-'}',
                                style: TextStyle(color: colorScheme.primary),
                              ),
                            ),
                            title: Text(
                              dive.site?.name ?? 'Unknown Site',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(dateFormat.format(dive.dateTime)),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            onTap: () => context.push('/dives/${dive.id}'),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    error: (error, stack) => Text(
                      'Error loading dives',
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Notes
          if (course.notes.isNotEmpty) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(context, 'Notes', Icons.notes),
                    const SizedBox(height: 12),
                    Text(course.notes),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Actions
          if (!course.isCompleted) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => _markCompleted(context, ref, course),
                icon: const Icon(Icons.check),
                label: const Text('Mark as Completed'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ],
      ),
    );

    if (embedded) {
      return Column(
        children: [
          _buildEmbeddedHeader(context, ref, course),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(course.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => context.push('/courses/${course.id}/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDelete(context, ref, course);
              } else if (value == 'export') {
                _exportTrainingLog(context, ref, course);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined),
                    SizedBox(width: 8),
                    Text('Export Training Log'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: body,
    );
  }

  Widget _buildStatusCard(BuildContext context, Course course) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: course.isCompleted
          ? Colors.green.withValues(alpha: 0.1)
          : colorScheme.primaryContainer.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              course.isCompleted ? Icons.check_circle : Icons.pending,
              size: 40,
              color: course.isCompleted ? Colors.green : colorScheme.primary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.isCompleted ? 'Completed' : 'In Progress',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: course.isCompleted
                          ? Colors.green
                          : colorScheme.primary,
                    ),
                  ),
                  if (course.durationDays != null)
                    Text(
                      '${course.durationDays} days',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    Text(
                      '${course.daysSinceStart} days since start',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildDetailRow(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildCertificationSection(
    BuildContext context,
    WidgetRef ref,
    String certificationId,
  ) {
    final certAsync = ref.watch(certificationByIdProvider(certificationId));
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  context,
                  'Earned Certification',
                  Icons.card_membership,
                ),
                const SizedBox(height: 12),
                certAsync.when(
                  data: (cert) {
                    if (cert == null) {
                      return Text(
                        'Certification not found',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      );
                    }
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            _abbreviateAgency(cert.agency.displayName),
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      title: Text(cert.name),
                      subtitle: Text(cert.agency.displayName),
                      trailing: Icon(
                        Icons.chevron_right,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      onTap: () => context.push('/certifications/${cert.id}'),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  error: (error, stack) => Text(
                    'Error loading certification',
                    style: TextStyle(color: colorScheme.error),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Safely abbreviate agency name to at most 4 characters
  String _abbreviateAgency(String displayName) {
    if (displayName.length <= 4) {
      return displayName;
    }
    return displayName.substring(0, 4);
  }

  Widget _buildEmbeddedHeader(
    BuildContext context,
    WidgetRef ref,
    Course course,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              course.name,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              if (ResponsiveBreakpoints.isMasterDetail(context)) {
                final state = GoRouterState.of(context);
                final currentPath = state.uri.path;
                // Use 'selected' param (not 'id') per MasterDetailScaffold convention
                context.go('$currentPath?selected=${course.id}&mode=edit');
              } else {
                context.push('/courses/${course.id}/edit');
              }
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDelete(context, ref, course);
              } else if (value == 'export') {
                _exportTrainingLog(context, ref, course);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.picture_as_pdf_outlined),
                    SizedBox(width: 8),
                    Text('Export Training Log'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    if (embedded) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Course')),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    if (embedded) {
      return const Center(child: Text('Course not found'));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Course')),
      body: const Center(child: Text('Course not found')),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    final colorScheme = Theme.of(context).colorScheme;
    final content = Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline, size: 48, color: colorScheme.error),
          const SizedBox(height: 16),
          Text('Error: $error'),
        ],
      ),
    );

    if (embedded) return content;

    return Scaffold(
      appBar: AppBar(title: const Text('Course')),
      body: content,
    );
  }

  Future<void> _markCompleted(
    BuildContext context,
    WidgetRef ref,
    Course course,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark Course as Completed?'),
        content: const Text('This will set the completion date to today.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final updated = course.copyWith(completionDate: DateTime.now());
      await ref.read(courseListNotifierProvider.notifier).updateCourse(updated);
      ref.invalidate(courseByIdProvider(course.id));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Course course,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Course?'),
        content: Text(
          'Are you sure you want to delete "${course.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref
          .read(courseListNotifierProvider.notifier)
          .deleteCourse(course.id);
      if (onDeleted != null) {
        onDeleted!();
      } else if (context.mounted) {
        context.pop();
      }
    }
  }

  Future<void> _exportTrainingLog(
    BuildContext context,
    WidgetRef ref,
    Course course,
  ) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Load training dives for this course
      final dives = await ref.read(courseDivesProvider(course.id).future);

      // Export to PDF
      final exportService = ExportService();
      await exportService.exportCourseTrainingLogToPdf(course, dives);

      // Dismiss loading
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    } catch (e) {
      // Dismiss loading
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export training log: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
