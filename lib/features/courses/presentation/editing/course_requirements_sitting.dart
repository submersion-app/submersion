import 'package:flutter/widgets.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/constants/course_templates.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/courses/presentation/editing/course_card_ids.dart';
import 'package:submersion/features/courses/presentation/widgets/add_requirement_sheet.dart';
import 'package:submersion/features/courses/presentation/widgets/credit_dive_picker_sheet.dart';
import 'package:submersion/features/courses/presentation/widgets/template_picker_sheet.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';
import 'package:submersion/shared/widgets/record_editing/sitting_list.dart';

/// A course's requirement tracker held in its page's sitting (issue #4527,
/// phase 3): requirements added, applied from a template, edited, ticked
/// or removed, and dives credited or uncredited, all written at Save in the
/// sitting's one entry.

final String _requirements = CourseCardId.requirements.name;

/// The course's requirements with their credited dives, as the tracker
/// draws them. A new requirement carries the id it is created with at Save.
final courseRequirementsList = SittingList<Course, CourseRequirementProgress>(
  key: 'course.requirements',
  cardId: _requirements,
  read: (c) async => (await CourseRequirementRepository().getCourseProgress(
    c.id,
  )).requirements,
  write: (c, loaded, current) => CourseRequirementRepository()
      .writeRequirementChanges(c.id, loaded: loaded, current: current),
);

int _lastSortOrder(List<CourseRequirementProgress> rows) => rows.fold(
  0,
  (last, r) => r.requirement.sortOrder > last ? r.requirement.sortOrder : last,
);

CourseRequirementProgress _newRow({
  required String courseId,
  required String name,
  required RequirementKind kind,
  required int targetCount,
  required int sortOrder,
  required DateTime now,
}) => CourseRequirementProgress(
  requirement: CourseRequirement(
    id: const Uuid().v4(),
    courseId: courseId,
    name: name.trim(),
    kind: kind,
    targetCount: targetCount,
    sortOrder: sortOrder,
    createdAt: now,
    updatedAt: now,
  ),
  linkedDives: const [],
);

/// [rows] with [draft] added after the last row.
List<CourseRequirementProgress> withRequirementAdded(
  List<CourseRequirementProgress> rows,
  RequirementDraft draft, {
  required String courseId,
  DateTime? now,
}) => [
  ...rows,
  _newRow(
    courseId: courseId,
    name: draft.name,
    kind: draft.kind,
    targetCount: draft.targetCount,
    sortOrder: _lastSortOrder(rows) + 1,
    now: now ?? DateTime.now(),
  ),
];

/// [rows] with [template]'s requirements appended after the last row.
/// Applying it twice appends twice, as the tracker always has.
List<CourseRequirementProgress> withTemplateApplied(
  List<CourseRequirementProgress> rows,
  CourseTemplate template, {
  required String courseId,
  DateTime? now,
}) {
  final at = now ?? DateTime.now();
  var sortOrder = _lastSortOrder(rows);
  return [
    ...rows,
    for (final item in template.requirements)
      _newRow(
        courseId: courseId,
        name: item.name,
        kind: item.kind,
        targetCount: item.targetCount,
        sortOrder: ++sortOrder,
        now: at,
      ),
  ];
}

List<CourseRequirementProgress> _withRequirement(
  List<CourseRequirementProgress> rows,
  String id,
  CourseRequirementProgress Function(CourseRequirementProgress row) change,
) => [for (final r in rows) r.requirement.id == id ? change(r) : r];

/// [rows] with requirement [id] renamed, retyped and retargeted as [draft]
/// says, its credits kept. A dive requirement has no tick, as the
/// repository's update has it.
List<CourseRequirementProgress> withRequirementEdited(
  List<CourseRequirementProgress> rows,
  String id,
  RequirementDraft draft,
) => _withRequirement(rows, id, (r) {
  final edited = r.requirement.copyWith(
    name: draft.name.trim(),
    kind: draft.kind,
    targetCount: draft.targetCount,
  );
  return CourseRequirementProgress(
    requirement: draft.kind == RequirementKind.dive
        ? edited.clearCompletedAt()
        : edited,
    linkedDives: r.linkedDives,
  );
});

/// [rows] with checklist requirement [id] ticked at [now], or unticked.
List<CourseRequirementProgress> withRequirementTicked(
  List<CourseRequirementProgress> rows,
  String id,
  bool done, {
  DateTime? now,
}) => _withRequirement(
  rows,
  id,
  (r) => CourseRequirementProgress(
    requirement: done
        ? r.requirement.copyWith(completedAt: now ?? DateTime.now())
        : r.requirement.clearCompletedAt(),
    linkedDives: r.linkedDives,
  ),
);

/// [rows] without requirement [id].
List<CourseRequirementProgress> withRequirementRemoved(
  List<CourseRequirementProgress> rows,
  String id,
) => [
  for (final r in rows)
    if (r.requirement.id != id) r,
];

/// [rows] with [dive] credited toward requirement [requirementId]; [rows]
/// itself when the dive already credits one of them, since a dive credits
/// one requirement of a course.
List<CourseRequirementProgress> withDiveCredited(
  List<CourseRequirementProgress> rows,
  String requirementId,
  RequirementDiveSummary dive,
) {
  final credited = rows.any(
    (r) => r.linkedDives.any((d) => d.diveId == dive.diveId),
  );
  if (credited) return rows;
  return _withRequirement(
    rows,
    requirementId,
    (r) => CourseRequirementProgress(
      requirement: r.requirement,
      linkedDives: [...r.linkedDives, dive],
    ),
  );
}

/// [rows] with dive [diveId] no longer credited toward [requirementId].
List<CourseRequirementProgress> withDiveUncredited(
  List<CourseRequirementProgress> rows,
  String requirementId,
  String diveId,
) => _withRequirement(
  rows,
  requirementId,
  (r) => CourseRequirementProgress(
    requirement: r.requirement,
    linkedDives: [
      for (final d in r.linkedDives)
        if (d.diveId != diveId) d,
    ],
  ),
);

Set<String> _creditedDiveIds(List<CourseRequirementProgress> rows) => {
  for (final r in rows)
    for (final d in r.linkedDives) d.diveId,
};

/// The stored suggestions less the dives credited in the sitting.
List<RequirementDiveSummary> suggestionsInSitting(
  List<RequirementDiveSummary> stored,
  List<CourseRequirementProgress> rows,
) {
  final credited = _creditedDiveIds(rows);
  return [
    for (final d in stored)
      if (!credited.contains(d.diveId)) d,
  ];
}

/// What the dive picker leaves out in a sitting ([exclude], the dives the
/// sitting credits and the store does not) and gets back ([restored], the
/// dives the store credits and the sitting has uncredited).
({Set<String> exclude, List<RequirementDiveSummary> restored})
pickerScopeInSitting({
  required List<CourseRequirementProgress> loaded,
  required List<CourseRequirementProgress> current,
}) {
  final before = _creditedDiveIds(loaded);
  final after = _creditedDiveIds(current);
  final seen = <String>{};
  return (
    exclude: after.difference(before),
    restored: [
      for (final r in loaded)
        for (final d in r.linkedDives)
          if (!after.contains(d.diveId) && seen.add(d.diveId)) d,
    ],
  );
}

/// What the requirement tracker does when the diver acts on it, held in
/// the page's sitting ([HeldRequirementActions]).
abstract interface class RequirementActions {
  Future<void> add(BuildContext context);
  Future<void> applyTemplate(BuildContext context);
  Future<void> edit(BuildContext context, CourseRequirement requirement);
  Future<void> remove(CourseRequirement requirement);
  Future<void> tick(CourseRequirement requirement, bool done);

  /// Credits [suggestion], or the dive the diver picks when it is null.
  Future<void> credit(
    BuildContext context,
    CourseRequirement requirement,
    RequirementDiveSummary? suggestion,
  );
  Future<void> uncredit(CourseRequirement requirement, String diveId);
}

/// The tracker's actions in a course page's sitting: each changes only the
/// sitting's rows, written at Save.
class HeldRequirementActions implements RequirementActions {
  HeldRequirementActions(this._session);

  final EditSession<Course> _session;

  String get _courseId => _session.stored.id;

  /// Applies [edit] to the sitting's rows, reading them first when the
  /// sitting has not yet, so nothing done before the read answers is lost.
  Future<void> _change(
    List<CourseRequirementProgress> Function(
      List<CourseRequirementProgress> rows,
    )
    edit,
  ) async {
    final rows = await courseRequirementsList.currentOrRead(_session);
    if (rows == null || _session.isDisposed) return;
    courseRequirementsList.set(_session, edit(rows));
  }

  @override
  Future<void> add(BuildContext context) async {
    final draft = await showAddRequirementSheet(context);
    if (draft == null) return;
    await _change(
      (rows) => withRequirementAdded(rows, draft, courseId: _courseId),
    );
  }

  @override
  Future<void> applyTemplate(BuildContext context) async {
    final template = await showTemplatePickerSheet(context);
    if (template == null) return;
    await _change(
      (rows) => withTemplateApplied(rows, template, courseId: _courseId),
    );
  }

  @override
  Future<void> edit(BuildContext context, CourseRequirement requirement) async {
    final draft = await showAddRequirementSheet(context, existing: requirement);
    if (draft == null) return;
    await _change((rows) => withRequirementEdited(rows, requirement.id, draft));
  }

  @override
  Future<void> remove(CourseRequirement requirement) =>
      _change((rows) => withRequirementRemoved(rows, requirement.id));

  @override
  Future<void> tick(CourseRequirement requirement, bool done) =>
      _change((rows) => withRequirementTicked(rows, requirement.id, done));

  @override
  Future<void> credit(
    BuildContext context,
    CourseRequirement requirement,
    RequirementDiveSummary? suggestion,
  ) async {
    var dive = suggestion;
    if (dive == null) {
      final current = await courseRequirementsList.currentOrRead(_session);
      final loaded = courseRequirementsList.loaded(_session);
      if (loaded == null || current == null || !context.mounted) return;
      final scope = pickerScopeInSitting(loaded: loaded, current: current);
      dive = await showCreditDivePickerSheet(
        context,
        courseId: requirement.courseId,
        excludeDiveIds: scope.exclude,
        restoredDives: scope.restored,
      );
    }
    final chosen = dive;
    if (chosen == null) return;
    await _change((rows) => withDiveCredited(rows, requirement.id, chosen));
  }

  @override
  Future<void> uncredit(CourseRequirement requirement, String diveId) =>
      _change((rows) => withDiveUncredited(rows, requirement.id, diveId));
}
