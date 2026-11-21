import 'package:flutter/material.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/certification_agencies/presentation/widgets/certification_agency_dropdown.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/course_status_colors.dart';
import 'package:submersion/features/courses/presentation/editing/course_edit_fields.dart';
import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/shared/widgets/app_date_picker.dart';
import 'package:submersion/shared/widgets/markdown_notes/markdown_notes_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_field.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/field_text_binding.dart';

/// The course page's card editors (issue #4527, phase 3). Each sets only
/// its own card's values, with the old edit form's widgets and rules.

/// A text binding of [field], whose blank text is a value (none, for an
/// optional one).
FieldTextBinding<Course, V> _bindText<V>(
  EditSession<Course> session,
  EditField<Course, V> field,
  String Function(V value) format,
) => FieldTextBinding.plain(session: session, field: field, format: format);

/// Status, the page's header block: the course's name, its state and
/// duration (calculated, read only), and Mark completed while it is in
/// progress.
class CourseStatusCardEditor extends StatefulWidget {
  const CourseStatusCardEditor({super.key, required this.session});

  final EditSession<Course> session;

  @override
  State<CourseStatusCardEditor> createState() => _CourseStatusCardEditorState();
}

class _CourseStatusCardEditorState extends State<CourseStatusCardEditor> {
  EditSession<Course> get _session => widget.session;

  late final _name = _bindText<String>(_session, courseNameField, (v) => v);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final course = _session.working;
        final accent = courseStatusAccent(
          theme.colorScheme,
          completed: course.isCompleted,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('course-edit-name'),
              controller: _name.controller,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.courses_field_courseName,
                hintText: l10n.courses_field_courseNameHint,
                prefixIcon: const Icon(Icons.school),
                errorText: courseNameValid(course.name)
                    ? null
                    : l10n.courses_validation_nameRequired,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  course.isCompleted ? Icons.check_circle : Icons.pending,
                  color: accent,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        course.isCompleted
                            ? l10n.courses_status_completed
                            : l10n.courses_status_inProgress,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                      Text(
                        course.durationDays != null
                            ? l10n.courses_status_durationDays(
                                course.durationDays!,
                              )
                            : l10n.courses_status_daysSinceStart(
                                course.daysSinceStart,
                              ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!course.isCompleted) ...[
              const SizedBox(height: 16),
              // No question: in a sitting, Cancel takes it back.
              FilledButton.icon(
                onPressed: () => _session.set(
                  courseCompletionDateField,
                  courseCompletedSwitched(true),
                ),
                icon: const Icon(Icons.check),
                label: Text(l10n.courses_action_markCompleted),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Details: the agency, the start date, completed with its date, and the
/// location.
class CourseDetailsCardEditor extends ConsumerStatefulWidget {
  const CourseDetailsCardEditor({super.key, required this.session});

  final EditSession<Course> session;

  @override
  ConsumerState<CourseDetailsCardEditor> createState() =>
      _CourseDetailsCardEditorState();
}

class _CourseDetailsCardEditorState
    extends ConsumerState<CourseDetailsCardEditor> {
  EditSession<Course> get _session => widget.session;

  late final _location = _bindText<String?>(
    _session,
    courseLocationField,
    (v) => v ?? '',
  );

  @override
  void dispose() {
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final course = _session.working;
    final bounds = courseDatePickerBounds(
      isStart: isStart,
      start: course.startDate,
      completion: course.completionDate,
    );
    final picked = await showAppDatePicker(
      context: context,
      initialDate: bounds.initial,
      firstDate: bounds.first,
      lastDate: bounds.last,
    );
    if (picked == null || !mounted || _session.isDisposed) return;
    if (isStart) {
      final dates = courseStartPicked(
        picked,
        _session.valueOf(courseCompletionDateField),
      );
      _session.set(courseStartDateField, dates.start);
      _session.set(courseCompletionDateField, dates.completion);
    } else {
      _session.set(courseCompletionDateField, picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final formatter = ref.watch(unitFormatterProvider);
    return ListenableBuilder(
      listenable: _session,
      builder: (context, _) {
        final completion = _session.valueOf(courseCompletionDateField);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CertificationAgencyDropdown(
              value: _session.valueOf(courseAgencyField),
              labelText: l10n.courses_label_agency,
              onChanged: (value) => _session.set(courseAgencyField, value),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text(l10n.courses_label_startDate),
              subtitle: Text(
                formatter.formatDate(_session.valueOf(courseStartDateField)),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickDate(isStart: true),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.check_circle),
              title: Text(l10n.courses_label_completed),
              subtitle: Text(
                completion != null
                    ? formatter.formatDate(completion)
                    : l10n.courses_label_courseInProgress,
              ),
              value: completion != null,
              onChanged: (on) => _session.set(
                courseCompletionDateField,
                courseCompletedSwitched(on),
              ),
            ),
            if (completion != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const SizedBox(width: 24),
                title: Text(l10n.courses_label_completionDate),
                subtitle: Text(formatter.formatDate(completion)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickDate(isStart: false),
              ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('course-edit-location'),
              controller: _location.controller,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: l10n.courses_field_location,
                prefixIcon: const Icon(Icons.place),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Notes, as Markdown.
class CourseNotesCardEditor extends StatefulWidget {
  const CourseNotesCardEditor({super.key, required this.session});

  final EditSession<Course> session;

  @override
  State<CourseNotesCardEditor> createState() => _CourseNotesCardEditorState();
}

class _CourseNotesCardEditorState extends State<CourseNotesCardEditor> {
  late final _binding = _bindText<String>(
    widget.session,
    courseNotesField,
    (v) => v,
  );

  @override
  void dispose() {
    _binding.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MarkdownNotesField(
    controller: _binding.controller,
    autofocus: true,
    decoration: InputDecoration(
      labelText: context.l10n.courses_field_notes,
      prefixIcon: const Icon(Icons.notes),
      alignLabelWithHint: true,
    ),
    maxLines: 4,
    textCapitalization: TextCapitalization.sentences,
  );
}
