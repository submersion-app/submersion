import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:submersion/l10n/l10n_extension.dart';
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
            return Center(
              child: Text(context.l10n.certifications_detail_notFound),
            );
          }
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.certifications_detail_appBar_title),
            ),
            body: Center(
              child: Text(context.l10n.certifications_detail_notFound),
            ),
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
          appBar: AppBar(
            title: Text(context.l10n.certifications_detail_appBar_title),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      },
      error: (error, stack) {
        if (widget.embedded) {
          return Center(child: Text('Error: $error'));
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(context.l10n.certifications_detail_appBar_title),
          ),
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

          // Card photos
          if (certification.hasPhotos) ...[
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
            tooltip: context.l10n.certifications_detail_tooltip_edit,
            onPressed: () =>
                context.push('/certifications/${certification.id}/edit'),
          ),
          PopupMenuButton<String>(
            tooltip: context.l10n.certifications_detail_tooltip_moreOptions,
            onSelected: (value) async {
              if (value == 'delete') {
                await _handleDelete(context, ref);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete, color: Colors.red),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.certifications_detail_action_delete,
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
            tooltip: context.l10n.certifications_detail_tooltip_editShort,
            onPressed: () {
              final state = GoRouterState.of(context);
              context.go(
                '${state.uri.path}?selected=${certification.id}&mode=edit',
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 20),
            tooltip: context.l10n.certifications_detail_tooltip_moreOptions,
            onSelected: (value) async {
              if (value == 'delete') {
                await _handleDelete(context, ref);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(Icons.delete, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.certifications_detail_action_delete,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.certifications_detail_snackBar_deleted),
          ),
        );
      }
    }
  }

  Widget _buildStatusBanner(BuildContext context) {
    if (certification.isExpired) {
      return Semantics(
        label:
            'Warning: This certification has expired${certification.expiryDate != null ? ' on ${DateFormat.yMMMd().format(certification.expiryDate!)}' : ''}',
        child: Container(
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
                    Text(
                      context.l10n.certifications_detail_status_expired,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (certification.expiryDate != null)
                      Text(
                        context.l10n.certifications_detail_status_expiredOn(
                          DateFormat.yMMMd().format(certification.expiryDate!),
                        ),
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
        ),
      );
    } else if (certification.expiresWithin(90)) {
      final days = certification.daysUntilExpiry ?? 0;
      return Semantics(
        label:
            'Warning: Certification expires in $days days${certification.expiryDate != null ? ' on ${DateFormat.yMMMd().format(certification.expiryDate!)}' : ''}',
        child: Container(
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
                      context.l10n.certifications_detail_status_expiresInDays(
                        days,
                      ),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (certification.expiryDate != null)
                      Text(
                        context.l10n.certifications_detail_status_expiresOn(
                          DateFormat.yMMMd().format(certification.expiryDate!),
                        ),
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
              context.l10n.certifications_detail_sectionTitle_details,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _InfoRow(
              icon: Icons.card_membership,
              label: context.l10n.certifications_detail_label_type,
              value: certification.name,
            ),
            _InfoRow(
              icon: Icons.business,
              label: context.l10n.certifications_detail_label_agency,
              value: certification.agency.displayName,
            ),
            if (certification.level != null)
              _InfoRow(
                icon: Icons.stairs,
                label: context.l10n.certifications_detail_label_level,
                value: certification.level!.displayName,
              ),
            if (certification.cardNumber != null)
              _InfoRow(
                icon: Icons.numbers,
                label: context.l10n.certifications_detail_label_cardNumber,
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
              context.l10n.certifications_detail_sectionTitle_dates,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (certification.issueDate != null)
              _InfoRow(
                icon: Icons.event_available,
                label: context.l10n.certifications_detail_label_issueDate,
                value: DateFormat.yMMMd().format(certification.issueDate!),
              ),
            if (certification.expiryDate != null)
              _InfoRow(
                icon: Icons.event_busy,
                label: context.l10n.certifications_detail_label_expiryDate,
                value: DateFormat.yMMMd().format(certification.expiryDate!),
                valueColor: certification.isExpired
                    ? Colors.red
                    : certification.expiresWithin(90)
                    ? Colors.orange
                    : null,
              ),
            if (certification.expiryDate == null)
              _InfoRow(
                icon: Icons.all_inclusive,
                label: context.l10n.certifications_detail_label_validity,
                value: context.l10n.certifications_detail_noExpiration,
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
              context.l10n.certifications_detail_sectionTitle_instructor,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (certification.instructorName != null)
              _InfoRow(
                icon: Icons.person,
                label: context.l10n.certifications_detail_label_instructorName,
                value: certification.instructorName!,
              ),
            if (certification.instructorNumber != null)
              _InfoRow(
                icon: Icons.badge,
                label:
                    context.l10n.certifications_detail_label_instructorNumber,
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
                      context
                          .l10n
                          .certifications_detail_sectionTitle_trainingCourse,
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
                        '${course.agency.displayName} - ${course.isCompleted ? context.l10n.certifications_detail_courseCompleted : context.l10n.certifications_detail_courseInProgress}',
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
              context.l10n.certifications_detail_sectionTitle_cardPhotos,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (certification.photoFront != null)
                  Expanded(
                    child: _buildPhotoThumbnail(
                      context,
                      imageData: certification.photoFront!,
                      label:
                          context.l10n.certifications_detail_photoLabel_front,
                    ),
                  ),
                if (certification.photoFront != null &&
                    certification.photoBack != null)
                  const SizedBox(width: 16),
                if (certification.photoBack != null)
                  Expanded(
                    child: _buildPhotoThumbnail(
                      context,
                      imageData: certification.photoBack!,
                      label: context.l10n.certifications_detail_photoLabel_back,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoThumbnail(
    BuildContext context, {
    required Uint8List imageData,
    required String label,
  }) {
    return Column(
      children: [
        Semantics(
          button: true,
          label: context.l10n
              .certifications_detail_semanticLabel_photoTapToView(
                label,
                certification.name,
              ),
          child: GestureDetector(
            onTap: () => _showFullscreenPhoto(context, imageData, label),
            child: AspectRatio(
              aspectRatio: 1.6,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.memory(
                  imageData,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.broken_image_outlined,
                            size: 32,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context
                                .l10n
                                .certifications_detail_photo_unableToLoad,
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  void _showFullscreenPhoto(
    BuildContext context,
    Uint8List imageData,
    String label,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(
              context.l10n.certifications_detail_photo_fullscreenTitle(
                label,
                certification.name,
              ),
            ),
          ),
          body: InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: Image.memory(
                imageData,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.broken_image_outlined,
                          size: 64,
                          color: Colors.white54,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.certifications_detail_photo_unableToLoad,
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
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
              context.l10n.certifications_detail_sectionTitle_notes,
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
            title: Text(context.l10n.certifications_detail_dialog_deleteTitle),
            content: Text(
              context.l10n.certifications_detail_dialog_deleteContent(
                certification.name,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.certifications_detail_dialog_cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(
                  context.l10n.certifications_detail_dialog_deleteConfirm,
                ),
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
    return Semantics(
      label: '$label: $value',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ExcludeSemantics(
              child: Icon(
                icon,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
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
      ),
    );
  }
}
