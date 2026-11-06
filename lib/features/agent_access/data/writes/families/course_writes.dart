import 'package:drift/drift.dart' show Variable;

import 'package:submersion/core/constants/certification_enums.dart';
import 'package:submersion/core/constants/course_templates.dart';
import 'package:submersion/features/agent_access/data/records/record_repositories.dart';
import 'package:submersion/features/agent_access/data/writes/families/credential_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/service_ledger_rules.dart';
import 'package:submersion/features/agent_access/data/writes/families/write_reach.dart';
import 'package:submersion/features/agent_access/data/writes/field_codec.dart';
import 'package:submersion/features/agent_access/data/writes/writable_entity.dart';
import 'package:submersion/features/agent_access/domain/agent_tool_error.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/documents/domain/entities/document.dart'
    show DocumentOwner, DocumentOwnerKind;

Future<Set<String>> _ids(RecordRepositories r, String sql, String id) async => {
  for (final row
      in await r.db
          .customSelect(sql, variables: [Variable.withString(id)])
          .get())
    row.read<String>('id'),
};

Future<List<CourseRequirement>> _requirementsOf(
  RecordRepositories r,
  String courseId,
) async => [
  for (final p in (await r.courseRequirements.getCourseProgress(
    courseId,
  )).requirements)
    p.requirement,
];

CourseTemplate? _template(Object? id) =>
    CourseTemplateCatalog.templates.where((t) => t.id == id).firstOrNull;

/// Training courses, through the repository the course pages use. A course
/// can start from a template's requirements, takes dives and the cards it
/// earned as links, and picking an instructor copies the buddy's name and
/// number, as the page does.
class CourseWrites extends WritableEntry {
  CourseWrites(this._r);

  final RecordRepositories _r;

  static const _from = 'from_template';

  @override
  String get name => 'courses';

  @override
  String get table => 'courses';

  @override
  String get note =>
      '$_from is a template id (${[for (final t in CourseTemplateCatalog.templates) t.id].join(', ')}) '
      'whose requirements a course with none yet takes. certification_ids '
      'are the cards the course earned; adding one moves it off any other '
      'course.';

  @override
  late final Map<String, FieldCodec> fields = {
    'name': const FieldCodec.text(maxLength: 200, trim: true),
    'agency': const FieldCodec.text(maxLength: 100),
    'start_date': const FieldCodec.calendarDate(),
    'completion_date': const FieldCodec.calendarDate(nullable: true),
    'instructor_id': const FieldCodec.reference('buddies', nullable: true),
    'instructor_name': const FieldCodec.text(
      maxLength: 100,
      nullable: true,
      trim: true,
    ),
    'instructor_number': const FieldCodec.text(
      maxLength: 100,
      nullable: true,
      trim: true,
    ),
    'location': const FieldCodec.text(
      maxLength: 200,
      nullable: true,
      trim: true,
    ),
    'notes': const FieldCodec.text(allowBlank: true, trim: true),
    _from: const FieldCodec.text(maxLength: 100),
  };

  @override
  final Map<String, RelationSpec> relations = const {
    'certification_ids': RelationSpec(refEntity: 'certifications'),
    'dive_ids': RelationSpec(refEntity: 'dives'),
  };

  @override
  Set<String> get requiredOnCreate => const {'name', 'start_date'};

  @override
  Set<String> get effectFields => const {_from};

  @override
  Future<Set<String>> currentRelation(String id, String relation) =>
      relation == 'dive_ids'
      ? _ids(
          _r,
          'SELECT dive_id AS id FROM dive_courses WHERE course_id = ?',
          id,
        )
      : _ids(_r, 'SELECT id FROM certifications WHERE course_id = ?', id);

  @override
  Future<Map<String, Object?>> createDefaults(
    String diverId,
    Map<String, Object?> values,
  ) async => {
    'agency': CertificationAgency.padi.name,
    for (final MapEntry(:key, :value) in (await instructorCopy(
      _r,
      values['instructor_id'],
    )).entries)
      key: ?value,
  };

  @override
  Future<Map<String, int>> alsoCreates(
    String diverId,
    Map<String, Object?> values,
  ) async => switch (_template(values[_from])) {
    final t? => {'course_requirements': t.requirements.length},
    null => const {},
  };

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    final course = {...?check.document, ...check.values};
    if (check.values[_from] case final Object from) {
      if (_template(from) == null) {
        return PlanBlock(
          BlockReason.invalidValue,
          '$_from: no course template $from.',
        );
      }
      if (check.id != null &&
          (await _requirementsOf(_r, check.id!)).isNotEmpty) {
        return const PlanBlock(
          BlockReason.duplicateRecord,
          '$_from: this course has requirements; a template would add them '
          'twice.',
        );
      }
    }
    final start = calendarDay(course['start_date']);
    final end = calendarDay(course['completion_date']);
    if (start != null && end != null && end.isBefore(start)) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'completion_date: on or after start_date.',
      );
    }
    for (final key in const ['start_date', 'completion_date']) {
      final day = calendarDay(check.values[key]);
      if (day != null && (day.year < 1950 || day.year > 2100)) {
        return PlanBlock(
          BlockReason.invalidValue,
          '$key: a day from 1950 to 2100.',
        );
      }
    }
    if (!check.values.containsKey('agency')) return null;
    return credentialProblem(
      _r,
      course['agency']! as String,
      null,
      check.ownerId,
    );
  }

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async {
    final cards = update.relations['certification_ids']?.add ?? const {};
    final others = <String>{};
    for (final cardId in cards) {
      final card = await _r.certifications.getCertificationById(cardId);
      if (card?.courseId case final other? when other != id) others.add(other);
    }
    final dives = update.relations['dive_ids'];
    final moved = (dives?.add.length ?? 0) + (dives?.remove.length ?? 0);
    final template = _template(update.values[_from]);
    return SideEffects(
      fields: {
        for (final MapEntry(:key, :value) in (await instructorCopy(
          _r,
          update.values['instructor_id'],
        )).entries)
          if (!update.values.containsKey(key) && document[key] != value)
            key: value,
      },
      touched: {
        if (others.isNotEmpty) 'courses': others.length,
        if (moved > 0) 'dives': moved,
      },
      created: {
        if (template != null)
          'course_requirements': template.requirements.length,
      },
    );
  }

  @override
  Future<List<DocumentOwner>> deletedDocumentOwners(String id) async => [
    DocumentOwner(DocumentOwnerKind.course, id),
  ];

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async {
    final documents = await countDocuments(await deletedDocumentOwners(id));
    final cards = await currentRelation(id, 'certification_ids');
    final dives = {
      ...await currentRelation(id, 'dive_ids'),
      ...await _ids(_r, 'SELECT id FROM dives WHERE course_id = ?', id),
    };
    return DeleteReach(
      records: {if (documents > 0) 'documents': documents},
      parts: await countCascaded('courses', id, except: const {'documents'}),
      unlinked: {
        ...await countUnlinked('courses', id, except: const {'documents'}),
        if (cards.isNotEmpty) 'certifications': cards.length,
      },
      touched: {if (dives.isNotEmpty) 'dives': dives.length},
    );
  }

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final now = DateTime.now();
    final course = await _r.courses.createCourse(
      _applied(
        Course(
          id: '',
          diverId: diverId,
          name: values['name']! as String,
          agency: CertificationAgency.padi.name,
          startDate: calendarDay(values['start_date'])!,
          createdAt: now,
          updatedAt: now,
        ),
        values,
      ),
    );
    if (_template(values[_from]) case final template?) {
      await _r.courseRequirements.applyTemplate(course.id, template);
    }
    return course.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final v = {
      ...await instructorCopy(_r, update.values['instructor_id']),
      ...update.values,
    };
    if (v.keys.any((k) => k != _from)) {
      final current =
          await _r.courses.getCourseById(id) ??
          (throw AgentToolException(
            AgentToolErrorCode.writeRefused,
            'Course $id no longer exists.',
            details: {'id': id},
          ));
      await _r.courses.updateCourse(_applied(current, v));
    }
    if (_template(v[_from]) case final template?) {
      await _r.courseRequirements.applyTemplate(id, template);
    }
    if (update.relations['certification_ids'] case final cards?) {
      final current = await currentRelation(id, 'certification_ids');
      await _r.courses.setCourseCertifications(id, [
        for (final c in {...current, ...cards.add})
          if (!cards.remove.contains(c)) c,
      ]);
    }
    if (update.relations['dive_ids'] case final dives?) {
      for (final diveId in dives.add) {
        await _r.courses.linkDiveToCourse(diveId, id);
      }
      for (final diveId in dives.remove) {
        await _r.courses.unlinkDiveFromCourse(diveId, id);
      }
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.courses.deleteCourse(id);

  static Course _applied(Course course, Map<String, Object?> values) {
    T? kept<T>(String key, T? held) =>
        values.containsKey(key) ? values[key] as T? : held;
    return Course(
      id: course.id,
      diverId: course.diverId,
      name: kept('name', course.name)!,
      agency: kept('agency', course.agency)!,
      startDate: values.containsKey('start_date')
          ? calendarDay(values['start_date'])!
          : course.startDate,
      completionDate: values.containsKey('completion_date')
          ? calendarDay(values['completion_date'])
          : course.completionDate,
      instructorId: kept('instructor_id', course.instructorId),
      instructorName: kept('instructor_name', course.instructorName),
      instructorNumber: kept('instructor_number', course.instructorNumber),
      certificationId: course.certificationId,
      location: kept('location', course.location),
      notes: kept('notes', course.notes)!,
      createdAt: course.createdAt,
      updatedAt: course.updatedAt,
    );
  }
}

/// A course's requirements, as the course page keeps them: a dive count
/// that credited dives fill, or a checklist item ticked off. A dive credits
/// at most one requirement of a course.
class CourseRequirementWrites extends WritableEntry {
  CourseRequirementWrites(this._r);

  final RecordRepositories _r;

  @override
  String get name => 'course_requirements';

  @override
  String get table => 'course_requirements';

  @override
  ChildOf get parent => const ChildOf(entity: 'courses', field: 'course_id');

  @override
  String get note =>
      'A dive requirement counts the dives in dive_ids up to target_count; a '
      'checklist requirement is ticked through completed_at, which a '
      'non-null value sets to the moment of the save and null clears.';

  @override
  late final Map<String, FieldCodec> fields = {
    'course_id': const FieldCodec.reference('courses'),
    'name': const FieldCodec.text(maxLength: 200, trim: true),
    'kind': FieldCodec.enumName(RequirementKind.values),
    'target_count': const FieldCodec.integer(min: 1, max: 999),
    'completed_at': const FieldCodec.instant(nullable: true),
    'notes': const FieldCodec.text(nullable: true, trim: true),
  };

  @override
  final Map<String, RelationSpec> relations = const {
    'dive_ids': RelationSpec(refEntity: 'dives'),
  };

  @override
  Set<String> get requiredOnCreate => const {'name', 'kind'};

  @override
  Future<Set<String>> currentRelation(String id, String relation) => _ids(
    _r,
    'SELECT dive_id AS id FROM course_requirement_dives WHERE requirement_id = ?',
    id,
  );

  @override
  Future<PlanBlock?> refuse(WriteCheck check) async {
    if (check.kind == ChangeKind.delete) return null;
    final req = {...?check.document, ...check.values};
    final dive = req['kind'] == RequirementKind.dive.name;
    if (!dive && ((req['target_count'] as int?) ?? 1) > 1) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'target_count: a checklist requirement counts once.',
      );
    }
    if (dive && check.values['completed_at'] != null) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'completed_at: a dive requirement completes through its dives.',
      );
    }
    final added = check.relations['dive_ids']?.add ?? const {};
    if (added.isEmpty) return null;
    if (!dive) {
      return const PlanBlock(
        BlockReason.invalidValue,
        'dive_ids: only a dive requirement is credited dives.',
      );
    }
    for (final diveId in added) {
      final taken = await _r.db
          .customSelect(
            'SELECT l.requirement_id AS id FROM course_requirement_dives l '
            'JOIN course_requirements r ON r.id = l.requirement_id '
            'WHERE l.dive_id = ?1 AND r.course_id = ?2 AND r.id != ?3',
            variables: [
              Variable.withString(diveId),
              Variable.withString(req['course_id']! as String),
              Variable.withString(check.id ?? ''),
            ],
          )
          .get();
      if (taken.isNotEmpty) {
        return PlanBlock(
          BlockReason.duplicateRecord,
          'dive_ids: $diveId already credits requirement '
          '${taken.first.read<String>('id')} of this course.',
        );
      }
    }
    return null;
  }

  @override
  Future<SideEffects> sideEffects(
    String id,
    String? ownerId,
    RecordUpdate update,
    Map<String, Object?> document,
  ) async =>
      update.values['kind'] == RequirementKind.dive.name &&
          document['completed_at'] != null
      ? const SideEffects(fields: {'completed_at': null})
      : const SideEffects();

  @override
  Future<DeleteReach> deleteReach(
    String id, {
    Map<String, Set<String>> alongside = const {},
  }) async =>
      DeleteReach(parts: await countCascaded('course_requirements', id));

  @override
  Future<String> create(String diverId, Map<String, Object?> values) async {
    final created = await _r.courseRequirements.createRequirement(
      courseId: values['course_id']! as String,
      name: values['name']! as String,
      kind: RequirementKind.fromName(values['kind'] as String?),
      targetCount: values['target_count'] as int? ?? 1,
      notes: values['notes'] as String?,
    );
    if (values['completed_at'] != null) {
      await _r.courseRequirements.setChecklistComplete(created.id, true);
    }
    return created.id;
  }

  @override
  Future<void> update(String id, String? ownerId, RecordUpdate update) async {
    final v = update.values;
    final repo = _r.courseRequirements;
    if (v.keys.any((k) => k != 'completed_at')) {
      final courseId = (await _ids(
        _r,
        'SELECT course_id AS id FROM course_requirements WHERE id = ?',
        id,
      )).firstOrNull;
      final current = courseId == null
          ? null
          : (await _requirementsOf(
              _r,
              courseId,
            )).where((x) => x.id == id).firstOrNull;
      if (current == null) {
        throw AgentToolException(
          AgentToolErrorCode.writeRefused,
          'Course requirement $id no longer exists.',
          details: {'id': id},
        );
      }
      await repo.updateRequirement(
        CourseRequirement(
          id: id,
          courseId: current.courseId,
          name: v['name'] as String? ?? current.name,
          kind: v.containsKey('kind')
              ? RequirementKind.fromName(v['kind'] as String?)
              : current.kind,
          targetCount: v['target_count'] as int? ?? current.targetCount,
          completedAt: current.completedAt,
          sortOrder: current.sortOrder,
          notes: v.containsKey('notes') ? v['notes'] as String? : current.notes,
          createdAt: current.createdAt,
          updatedAt: current.updatedAt,
        ),
      );
    }
    if (v.containsKey('completed_at')) {
      await repo.setChecklistComplete(id, v['completed_at'] != null);
    }
    if (update.relations['dive_ids'] case final dives?) {
      for (final diveId in dives.add) {
        await repo.linkDive(requirementId: id, diveId: diveId);
      }
      for (final diveId in dives.remove) {
        await repo.unlinkDive(requirementId: id, diveId: diveId);
      }
    }
  }

  @override
  Future<void> delete(String id, String? ownerId) =>
      _r.courseRequirements.deleteRequirement(id);
}
