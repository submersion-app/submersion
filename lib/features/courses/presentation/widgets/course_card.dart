import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/course_status_colors.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/selection/selection_leading.dart';
import 'package:submersion/features/certification_agencies/presentation/certification_entry_display.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_context.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';

/// Card widget for displaying a course in a list
class CourseCard extends ConsumerWidget {
  final Course course;
  final VoidCallback? onTap;
  final bool isSelected;
  final bool isSelectionMode;
  final bool isChecked;
  final ValueChanged<bool>? onCheckChanged;

  const CourseCard({
    super.key,
    required this.course,
    this.onTap,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.isChecked = false,
    this.onCheckChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(certificationCatalogSyncProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final formatter = UnitFormatter(ref.watch(settingsProvider));
    final startDateStr = formatter.formatDate(course.startDate);

    final statusStr = course.isCompleted
        ? context.l10n.courses_status_completed
        : context.l10n.courses_status_inProgress;
    final instructorStr = course.instructorName != null
        ? ', ${context.l10n.courses_card_instructor(course.instructorName!)}'
        : '';

    return Semantics(
      label:
          '${course.name}, ${context.certificationCatalog.agency(course.agency).localizedName(context.l10n)}, ${context.l10n.courses_card_started(startDateStr)}, $statusStr$instructorStr',
      // Same shape as CertificationListTile and EquipmentListTile, so course
      // rows match every other section's size and spacing (issue #3382).
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.5)
            : null,
        child: ListTile(
          onTap: onTap,
          // Status icon, which becomes the checkbox in selection mode.
          leading: SelectionLeading(
            isSelectionMode: isSelectionMode,
            isChecked: isChecked,
            onChanged: onCheckChanged,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: courseStatusAccent(
                  colorScheme,
                  completed: course.isCompleted,
                ).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                course.isCompleted
                    ? Icons.check_circle_outline
                    : Icons.school_outlined,
                color: courseStatusAccent(
                  colorScheme,
                  completed: course.isCompleted,
                ),
              ),
            ),
          ),
          title: Text(
            course.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            [
              context.certificationCatalog
                  .agency(course.agency)
                  .localizedName(context.l10n),
              startDateStr,
              ?course.instructorName,
            ].join(' - '),
          ),
          trailing: _buildStatusBadge(context),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (course.isCompleted) {
      final accent = courseStatusAccent(colorScheme, completed: true);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          context.l10n.courses_status_completed,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: accent,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        context.l10n.courses_status_inProgress,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
