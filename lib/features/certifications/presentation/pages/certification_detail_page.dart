import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/shared/widgets/master_detail/responsive_breakpoints.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';

class CertificationDetailPage extends ConsumerStatefulWidget {
  final String certificationId;
  final bool embedded;
  final VoidCallback? onDeleted;

  const CertificationDetailPage({
    super.key,
    required this.certificationId,
    this.embedded = false,
    this.onDeleted,
  });

  @override
  ConsumerState<CertificationDetailPage> createState() =>
      _CertificationDetailPageState();
}

class _CertificationDetailPageState
    extends ConsumerState<CertificationDetailPage> {
  bool _hasRedirected = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.embedded &&
        !_hasRedirected &&
        ResponsiveBreakpoints.isMasterDetail(context)) {
      _hasRedirected = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/certifications?selected=${widget.certificationId}');
        }
      });
    }

    final certificationAsync = ref.watch(
      certificationByIdProvider(widget.certificationId),
    );

    return certificationAsync.when(
      data: (certification) {
        if (certification == null) {
          if (widget.embedded) {
            return const Center(child: Text('Certification not found'));
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Certification')),
            body: const Center(child: Text('Certification not found')),
          );
        }
        return _CertificationDetailContent(
          certification: certification,
          embedded: widget.embedded,
          onDeleted: widget.onDeleted,
        );
      },
      loading: () {
        if (widget.embedded) {
          return const Center(child: CircularProgressIndicator());
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Certification')),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, stack) {
        if (widget.embedded) {
          return Center(child: Text('Error: $error'));
        }
        return Scaffold(
          appBar: AppBar(title: const Text('Certification')),
          body: Center(child: Text('Error: $error')),
        );
      },
    );
  }
}

class _CertificationDetailContent extends ConsumerWidget {
  final Certification certification;
  final bool embedded;
  final VoidCallback? onDeleted;

  const _CertificationDetailContent({
    required this.certification,
    this.embedded = false,
    this.onDeleted,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status banner
          _buildStatusBanner(context),
          const SizedBox(height: 24),

          // Header with agency logo
          _buildHeader(context),
          const SizedBox(height: 24),

          // Basic info
          _buildBasicInfoSection(context),
          const SizedBox(height: 16),

          // Dates
          _buildDatesSection(context),
          const SizedBox(height: 16),

          // Instructor info
          if (certification.instructorName != null ||
              certification.instructorNumber != null) ...[
            _buildInstructorSection(context),
            const SizedBox(height: 16),
          ],

          // Training course
          _buildCourseSection(context, ref),

          // Card photos (placeholder for future)
          if (certification.photoFrontPath != null ||
              certification.photoBackPath != null) ...[
            _buildPhotosSection(context),
            const SizedBox(height: 16),
          ],

          // Notes
          if (certification.notes.isNotEmpty) ...[_buildNotesSection(context)],
        ],
      ),
    );

    if (embedded) {
      return Column(
        children: [
          _buildEmbeddedHeader(context, ref),
          Expanded(child: body),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(certification.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () =>
                context.push('/certifications/${certification.id}/edit'),
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'delete') {
                await _handleDelete(context, ref);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
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

  Widget _buildEmbeddedHeader(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                _abbreviateAgency(certification.agency.displayName),
                style: TextStyle(
                  color: colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  certification.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  certification.agency.displayName,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            tooltip: 'Edit',
            onPressed: () {
              final state = GoRouterState.of(context);
              context.go(
                '${state.uri.path}?selected=${certification.id}&mode=edit',
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            onSelected: (value) async {
              if (value == 'delete') {
                await _handleDelete(context, ref);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red, size: 20),
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

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showDeleteConfirmation(context);
    if (confirmed && context.mounted) {
      await ref
          .read(certificationListNotifierProvider.notifier)
          .deleteCertification(certification.id);
      if (context.mounted) {
        if (embedded) {
          onDeleted?.call();
        } else {
          context.pop();
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Certification deleted')));
      }
    }
  }

  Widget _buildStatusBanner(BuildContext context) {
    if (certification.isExpired) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'This certification has expired',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (certification.expiryDate != null)
                    Text(
                      'Expired on ${DateFormat.yMMMd().format(certification.expiryDate!)}',
                      style: TextStyle(
                        color: Colors.red.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (certification.expiresWithin(90)) {
      final days = certification.daysUntilExpiry ?? 0;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Expires in $days days',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (certification.expiryDate != null)
                    Text(
                      'Expires on ${DateFormat.yMMMd().format(certification.expiryDate!)}',
                      style: TextStyle(
                        color: Colors.orange.withValues(alpha: 0.8),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildHeader(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(
                certification.agency.displayName.substring(
                  0,
                  certification.agency.displayName.length > 4
                      ? 4
                      : certification.agency.displayName.length,
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            certification.name,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            certification.agency.displayName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicInfoSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Certification Details',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.card_membership,
              label: 'Type',
              value: certification.name,
            ),
            _InfoRow(
              icon: Icons.business,
              label: 'Agency',
              value: certification.agency.displayName,
            ),
            if (certification.level != null)
              _InfoRow(
                icon: Icons.stairs,
                label: 'Level',
                value: certification.level!.displayName,
              ),
            if (certification.cardNumber != null)
              _InfoRow(
                icon: Icons.numbers,
                label: 'Card Number',
                value: certification.cardNumber!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatesSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dates',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (certification.issueDate != null)
              _InfoRow(
                icon: Icons.event_available,
                label: 'Issue Date',
                value: DateFormat.yMMMd().format(certification.issueDate!),
              ),
            if (certification.expiryDate != null)
              _InfoRow(
                icon: Icons.event_busy,
                label: 'Expiry Date',
                value: DateFormat.yMMMd().format(certification.expiryDate!),
                valueColor: certification.isExpired
                    ? Colors.red
                    : certification.expiresWithin(90)
                    ? Colors.orange
                    : null,
              ),
            if (certification.expiryDate == null)
              const _InfoRow(
                icon: Icons.all_inclusive,
                label: 'Validity',
                value: 'No Expiration',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructorSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instructor',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (certification.instructorName != null)
              _InfoRow(
                icon: Icons.person,
                label: 'Name',
                value: certification.instructorName!,
              ),
            if (certification.instructorNumber != null)
              _InfoRow(
                icon: Icons.badge,
                label: 'Instructor #',
                value: certification.instructorNumber!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCourseSection(BuildContext context, WidgetRef ref) {
    final courseAsync = ref.watch(
      courseForCertificationProvider(certification.id),
    );

    return courseAsync.when(
      data: (course) {
        if (course == null) {
          return const SizedBox.shrink();
        }

        final colorScheme = Theme.of(context).colorScheme;

        return Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Training Course',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: course.isCompleted
                              ? Colors.green.withValues(alpha: 0.15)
                              : colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          course.isCompleted
                              ? Icons.check_circle_outline
                              : Icons.school_outlined,
                          color: course.isCompleted
                              ? Colors.green
                              : colorScheme.onPrimaryContainer,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        course.name,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      subtitle: Text(
                        '${course.agency.displayName} - ${course.isCompleted ? 'Completed' : 'In Progress'}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        if (embedded) {
                          context.go('/courses?selected=${course.id}');
                        } else {
                          context.push('/courses/${course.id}');
                        }
                      },
                    ),
                    if (course.instructorDisplay.isNotEmpty) ...[
                      const Divider(),
                      _InfoRow(
                        icon: Icons.person,
                        label: 'Instructor',
                        value: course.instructorDisplay,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (error, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildPhotosSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Card Photos',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (certification.photoFrontPath != null)
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.image, size: 40),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('Front', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
                if (certification.photoFrontPath != null &&
                    certification.photoBackPath != null)
                  const SizedBox(width: 16),
                if (certification.photoBackPath != null)
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Icon(Icons.image, size: 40),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text('Back', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Notes',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(certification.notes),
          ],
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Certification?'),
            content: Text(
              'Are you sure you want to delete "${certification.name}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  /// Safely abbreviate agency name to at most 4 characters
  String _abbreviateAgency(String displayName) {
    if (displayName.length <= 4) {
      return displayName;
    }
    return displayName.substring(0, 4);
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
