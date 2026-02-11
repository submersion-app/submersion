import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/l10n/l10n_extension.dart';
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
                  _buildSectionHeader(
                    context,
                    context.l10n.courses_section_details,
                    Icons.school,
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    context,
                    context.l10n.courses_label_agency,
                    course.agency.displayName,
                    Icons.business,
                  ),
                  _buildDetailRow(
                    context,
                    context.l10n.courses_label_startDate,
                    dateFormat.format(course.startDate),
                    Icons.calendar_today,
                  ),
                  if (course.completionDate != null)
                    _buildDetailRow(
                      context,
                      context.l10n.courses_label_completed,
                      dateFormat.format(course.completionDate!),
                      Icons.check_circle,
                    ),
                  if (course.location != null)
                    _buildDetailRow(
                      context,
                      context.l10n.courses_label_location,
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
                    _buildSectionHeader(
                      context,
                      context.l10n.courses_section_instructor,
                      Icons.person,
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      context,
                      context.l10n.courses_label_name,
                      course.instructorName!,
                      Icons.badge,
                    ),
                    if (course.instructorNumber != null)
                      _buildDetailRow(
                        context,
                        context.l10n.courses_label_instructorNumber,
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
                    context.l10n.courses_section_trainingDives,
                    Icons.scuba_diving,
                  ),
                  const SizedBox(height: 12),
                  divesAsync.when(
                    data: (dives) {
                      if (dives.isEmpty) {
                        return Text(
                          context.l10n.courses_detail_noTrainingDives,
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
                      context.l10n.courses_error_loadingDives,
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
                    _buildSectionHeader(
                      context,
                      context.l10n.courses_section_notes,
                      Icons.notes,
                    ),
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
                label: Text(context.l10n.courses_action_markCompleted),
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
            tooltip: context.l10n.courses_action_edit,
            onPressed: () => context.push('/courses/${course.id}/edit'),
          ),
          PopupMenuButton<String>(
            tooltip: context.l10n.courses_action_moreOptions,
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDelete(context, ref, course);
              } else if (value == 'export') {
                _exportTrainingLog(context, ref, course);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined),
                    const SizedBox(width: 8),
                    Text(context.l10n.courses_action_exportTrainingLog),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.common_action_delete,
                      style: const TextStyle(color: Colors.red),
                    ),
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
    final statusLabel = course.isCompleted
        ? context.l10n.courses_status_completed
        : context.l10n.courses_status_inProgress;
    final durationLabel = course.durationDays != null
        ? context.l10n.courses_status_durationDays(course.durationDays!)
        : context.l10n.courses_status_daysSinceStart(course.daysSinceStart);

    return Semantics(
      label: context.l10n.courses_status_semanticLabel(
        statusLabel,
        durationLabel,
      ),
      child: Card(
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
                      course.isCompleted
                          ? context.l10n.courses_status_completed
                          : context.l10n.courses_status_inProgress,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: course.isCompleted
                            ? Colors.green
                            : colorScheme.primary,
                      ),
                    ),
                    if (course.durationDays != null)
                      Text(
                        context.l10n.courses_status_durationDays(
                          course.durationDays!,
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Text(
                        context.l10n.courses_status_daysSinceStart(
                          course.daysSinceStart,
                        ),
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
    return Semantics(
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
            ),
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
                  context.l10n.courses_section_earnedCertification,
                  Icons.card_membership,
                ),
                const SizedBox(height: 12),
                certAsync.when(
                  data: (cert) {
                    if (cert == null) {
                      return Text(
                        context.l10n.courses_detail_certificationNotFound,
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
                    context.l10n.courses_error_loadingCertification,
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
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 8, 8),
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
            tooltip: context.l10n.courses_action_edit,
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
            tooltip: context.l10n.courses_action_moreOptions,
            onSelected: (value) {
              if (value == 'delete') {
                _confirmDelete(context, ref, course);
              } else if (value == 'export') {
                _exportTrainingLog(context, ref, course);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined),
                    const SizedBox(width: 8),
                    Text(context.l10n.courses_action_exportTrainingLog),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete_outline, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.common_action_delete,
                      style: const TextStyle(color: Colors.red),
                    ),
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
      appBar: AppBar(title: Text(context.l10n.courses_title_singular)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildNotFound(BuildContext context) {
    if (embedded) {
      return Center(child: Text(context.l10n.courses_detail_notFound));
    }
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.courses_title_singular)),
      body: Center(child: Text(context.l10n.courses_detail_notFound)),
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
      appBar: AppBar(title: Text(context.l10n.courses_title_singular)),
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
        title: Text(context.l10n.courses_dialog_markCompletedTitle),
        content: Text(context.l10n.courses_dialog_markCompletedMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.courses_dialog_complete),
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
        title: Text(context.l10n.courses_dialog_deleteTitle),
        content: Text(context.l10n.courses_dialog_deleteMessage(course.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.common_action_cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.common_action_delete),
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
            content: Text(
              context.l10n.courses_message_exportFailed(e.toString()),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
