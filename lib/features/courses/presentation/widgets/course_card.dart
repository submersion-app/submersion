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
    final agencyName = context.certificationCatalog
        .agency(course.agency)
        .localizedName(context.l10n);
    final accent = courseStatusAccent(
      colorScheme,
      completed: course.isCompleted,
    );

    final statusStr = course.isCompleted
        ? context.l10n.courses_status_completed
        : context.l10n.courses_status_inProgress;
    final instructorStr = course.instructorName != null
        ? ', ${context.l10n.courses_card_instructor(course.instructorName!)}'
        : '';

    return Semantics(
      label:
          '${course.name}, $agencyName, ${context.l10n.courses_card_started(startDateStr)}, $statusStr$instructorStr',
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
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                course.isCompleted
                    ? Icons.check_circle_outline
                    : Icons.school_outlined,
                color: accent,
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
              agencyName,
              startDateStr,
              if (course.instructorName != null)
                context.l10n.courses_card_instructor(course.instructorName!),
            ].join(' - '),
            // One line, so a long instructor name cannot make this row taller
            // than the other sections' tiles.
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: _buildStatusBadge(context, statusStr, accent),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String label, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: accent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
