import 'package:flutter/material.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/certification_agencies/presentation/certification_entry_display.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_context.dart';
import 'package:submersion/features/certification_agencies/presentation/providers/certification_catalog_providers.dart';

/// The training courses a dive belongs to, as removable chips (#2515).
/// Tapping the field opens a checklist sheet that reports every toggle
/// through [onChanged], so several courses can be ticked in one visit.
class CourseMultiSelectField extends ConsumerWidget {
  const CourseMultiSelectField({
    super.key,
    required this.selectedCourseIds,
    required this.onChanged,
    this.labelText,
  });

  final List<String> selectedCourseIds;
  final ValueChanged<List<String>> onChanged;
  final String? labelText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(certificationCatalogSyncProvider);
    // The retained value, so a background reload never blanks the chips.
    final courses = ref.watch(courseListNotifierProvider).value ?? const [];
    final nameById = {for (final c in courses) c.id: c.name};
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => showCourseMultiPickerSheet(
        context,
        selectedCourseIds: selectedCourseIds,
        onChanged: onChanged,
      ),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: labelText,
          suffixIcon: const Icon(Icons.arrow_drop_down),
        ),
        child: selectedCourseIds.isEmpty
            ? Text(
                context.l10n.courses_picker_tapToLink,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              )
            : Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final id in selectedCourseIds)
                    // A course not loaded yet gets no blank chip.
                    if (nameById[id] != null)
                      InputChip(
                        avatar: const Icon(Icons.school, size: 16),
                        label: Text(nameById[id]!),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        onDeleted: () => onChanged([
                          for (final other in selectedCourseIds)
                            if (other != id) other,
                        ]),
                      ),
                ],
              ),
      ),
    );
  }
}

/// Opens the course checklist. Each toggle reaches [onChanged] at once, so
/// closing the sheet by dragging keeps the selection.
Future<void> showCourseMultiPickerSheet(
  BuildContext context, {
  required List<String> selectedCourseIds,
  required ValueChanged<List<String>> onChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => CourseMultiPickerSheet(
      selectedCourseIds: selectedCourseIds,
      onChanged: onChanged,
    ),
  );
}

/// The checklist of the diver's courses: in-progress first, then by start
/// date, newest first.
class CourseMultiPickerSheet extends ConsumerStatefulWidget {
  const CourseMultiPickerSheet({
    super.key,
    required this.selectedCourseIds,
    required this.onChanged,
  });

  final List<String> selectedCourseIds;
  final ValueChanged<List<String>> onChanged;

  @override
  ConsumerState<CourseMultiPickerSheet> createState() =>
      _CourseMultiPickerSheetState();
}

class _CourseMultiPickerSheetState
    extends ConsumerState<CourseMultiPickerSheet> {
  late List<String> _working = [...widget.selectedCourseIds];

  void _toggle(String id, bool selected) {
    final next = [
      for (final c in _working)
        if (c != id) c,
      if (selected) id,
    ];
    setState(() => _working = next);
    widget.onChanged(next);
  }

  void _createCourse() {
    Navigator.of(context).pop();
    context.push('/courses/new');
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(certificationCatalogSyncProvider);
    final coursesAsync = ref.watch(courseListNotifierProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.courses_picker_selectCoursesTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: _createCourse,
                    icon: const Icon(Icons.add),
                    tooltip: context.l10n.courses_picker_newCourse,
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(context.l10n.common_action_done),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: coursesAsync.when(
                data: (courses) {
                  if (courses.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.school_outlined,
                            size: 48,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.l10n.courses_picker_noCourses,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _createCourse,
                            icon: const Icon(Icons.add),
                            label: Text(
                              context.l10n.courses_picker_createCourse,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  final sorted = [...courses]
                    ..sort((a, b) {
                      if (a.isInProgress != b.isInProgress) {
                        return a.isInProgress ? -1 : 1;
                      }
                      return b.startDate.compareTo(a.startDate);
                    });
                  return ListView(
                    shrinkWrap: true,
                    children: [for (final c in sorted) _row(context, c)],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    context.l10n.courses_picker_errorLoading(error.toString()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, Course course) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final selected = _working.contains(course.id);
    final agency = context.certificationCatalog
        .agency(course.agency)
        .localizedName(l10n);
    final started = l10n.courses_card_started(
      UnitFormatter(ref.watch(settingsProvider)).formatDate(course.startDate),
    );
    final label =
        '$agency ${course.name}, $started'
        '${selected ? ', ${l10n.courses_picker_selected}' : ''}'
        '${course.isInProgress ? ', ${l10n.courses_picker_active}' : ''}';

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: CheckboxListTile(
        value: selected,
        onChanged: (v) => _toggle(course.id, v ?? false),
        title: Text(course.name),
        subtitle: Text('$agency - $started'),
        secondary: course.isInProgress
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  l10n.courses_picker_active,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
