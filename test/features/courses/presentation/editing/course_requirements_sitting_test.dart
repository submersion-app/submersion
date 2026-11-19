import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/course_templates.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/data/services/course_edit_save_service.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/courses/presentation/editing/course_edit_fields.dart';
import 'package:submersion/features/courses/presentation/editing/course_requirements_sitting.dart';
import 'package:submersion/features/courses/presentation/widgets/add_requirement_sheet.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/test_database.dart';

/// A course's requirement tracker held in its page's sitting (issue #4527,
/// phase 3): each edit changes only the sitting's rows.
void main() {
  final now = DateTime(2026, 11, 19, 9);

  CourseRequirementProgress row(
    String id, {
    RequirementKind kind = RequirementKind.dive,
    int sortOrder = 1,
    DateTime? completedAt,
    List<String> dives = const [],
  }) => CourseRequirementProgress(
    requirement: CourseRequirement(
      id: id,
      courseId: 'k1',
      name: 'Requirement $id',
      kind: kind,
      sortOrder: sortOrder,
      completedAt: completedAt,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    ),
    linkedDives: [for (final d in dives) summary(d)],
  );

  test('an added requirement goes after the last row', () {
    final rows = withRequirementAdded(
      [row('a', sortOrder: 4)],
      const RequirementDraft(
        name: ' Deep ',
        kind: RequirementKind.dive,
        targetCount: 2,
      ),
      courseId: 'k1',
      now: now,
    );

    expect(rows, hasLength(2));
    final added = rows.last.requirement;
    expect(added.id, isNot('a'));
    expect(added.name, 'Deep');
    expect(added.targetCount, 2);
    expect(added.sortOrder, 5);
    expect(rows.last.linkedDives, isEmpty);
  });

  test("a template appends after the sitting's last row, and twice appends "
      'twice', () {
    final template = CourseTemplateCatalog.templates.first;
    final once = withTemplateApplied(
      [row('a', sortOrder: 3)],
      template,
      courseId: 'k1',
      now: now,
    );
    final twice = withTemplateApplied(once, template, courseId: 'k1', now: now);

    expect(once, hasLength(1 + template.requirements.length));
    expect(once[1].requirement.sortOrder, 4);
    expect(once[1].requirement.name, template.requirements.first.name);
    expect(twice, hasLength(1 + 2 * template.requirements.length));
    expect({for (final r in twice) r.requirement.id}, hasLength(twice.length));
  });

  test('editing a requirement keeps its credits', () {
    final rows = withRequirementEdited(
      [
        row('a', dives: ['v1']),
      ],
      'a',
      const RequirementDraft(
        name: 'Renamed',
        kind: RequirementKind.dive,
        targetCount: 3,
      ),
    );

    expect(rows.single.requirement.name, 'Renamed');
    expect(rows.single.requirement.targetCount, 3);
    expect(rows.single.linkedDives.single.diveId, 'v1');
  });

  test('turning a checklist into a dive requirement clears its tick', () {
    final rows = withRequirementEdited(
      [row('a', kind: RequirementKind.checklist, completedAt: now)],
      'a',
      const RequirementDraft(
        name: 'Requirement a',
        kind: RequirementKind.dive,
        targetCount: 1,
      ),
    );

    expect(rows.single.requirement.completedAt, isNull);
  });

  test('ticking sets the time it was ticked, unticking clears it', () {
    final ticked = withRequirementTicked(
      [row('a', kind: RequirementKind.checklist)],
      'a',
      true,
      now: now,
    );
    expect(ticked.single.requirement.completedAt, now);

    final unticked = withRequirementTicked(ticked, 'a', false);
    expect(unticked.single.requirement.completedAt, isNull);
  });

  test('a removed requirement leaves the rows', () {
    expect(withRequirementRemoved([row('a'), row('b')], 'a'), [row('b')]);
  });

  test('crediting a dive adds it to the requirement', () {
    final rows = withDiveCredited([row('a'), row('b')], 'b', summary('v1'));

    expect(rows[1].linkedDives.single.diveId, 'v1');
    expect(rows[0].linkedDives, isEmpty);
  });

  test('crediting a dive already credited in the sitting changes nothing', () {
    final rows = [
      row('a', dives: ['v1']),
      row('b'),
    ];

    expect(withDiveCredited(rows, 'b', summary('v1')), same(rows));
  });

  test('uncrediting a dive removes it from the requirement', () {
    final rows = withDiveUncredited(
      [
        row('a', dives: ['v1', 'v2']),
      ],
      'a',
      'v1',
    );

    expect([for (final d in rows.single.linkedDives) d.diveId], ['v2']);
  });

  test('suggestions leave out dives credited in the sitting', () {
    final rows = [
      row('a', dives: ['v1']),
    ];

    expect(
      [
        for (final d in suggestionsInSitting([
          summary('v1'),
          summary('v2'),
        ], rows))
          d.diveId,
      ],
      ['v2'],
    );
  });

  test('the picker leaves out held credits and gets held uncredits back', () {
    final loaded = [
      row('a', dives: ['v1']),
      row('b'),
    ];
    final current = [
      row('a'),
      row('b', dives: ['v2']),
    ];

    final scope = pickerScopeInSitting(loaded: loaded, current: current);

    expect(scope.exclude, {'v2'});
    expect([for (final d in scope.restored) d.diveId], ['v1']);
  });

  group('written with the course (issue #4527)', () {
    final requirements = CourseRequirementRepository();
    final changeLog = ChangeLogRepository();

    Future<Course> stored() async =>
        (await CourseRepository().getCourseById('k1'))!;

    Future<List<CourseRequirementProgress>> storedRows() async =>
        (await requirements.getCourseProgress('k1')).requirements;

    List<String> creditsOf(List<CourseRequirementProgress> rows, String id) => [
      for (final d
          in rows.firstWhere((r) => r.requirement.id == id).linkedDives)
        d.diveId,
    ];

    Future<List<Map<String, Object?>>> operations() async {
      await changeLog.settleAll();
      final rows = await DatabaseService.instance.database
          .customSelect('SELECT id, label FROM change_log_operations')
          .get();
      return [for (final row in rows) row.data];
    }

    /// Opens a sitting on the course with its requirements loaded.
    Future<EditSession<Course>> sitting() async {
      final session = EditSession(await stored());
      addTearDown(session.dispose);
      await courseRequirementsList.load(session);
      return session;
    }

    void change(
      EditSession<Course> session,
      List<CourseRequirementProgress> Function(
        List<CourseRequirementProgress> rows,
      )
      edit,
    ) => courseRequirementsList.set(
      session,
      edit(courseRequirementsList.current(session)!),
    );

    Future<void> save(EditSession<Course> session) =>
        CourseEditSaveService(CourseRepository()).save(
          courseId: 'k1',
          apply: session.applyTo,
          changedCardIds: session.changedCardIds,
          alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
          alsoWriteIsAChange: session.hasHeldChanges,
        );

    late String a;
    late String b;

    setUp(() async {
      final db = await setUpTestDatabase();
      addTearDown(SyncCoordinator.reset);
      await db.customStatement(
        "INSERT INTO divers (id, name, created_at, updated_at) "
        "VALUES ('d', 'D', 0, 0)",
      );
      await db.customStatement(
        "INSERT INTO courses (id, diver_id, name, agency, start_date, "
        "notes, created_at, updated_at) "
        "VALUES ('k1', 'd', 'Rescue', 'padi', 0, '', 0, 0)",
      );
      await db.customStatement(
        "INSERT INTO dives (id, diver_id, dive_date_time, created_at, "
        "updated_at) VALUES ('v1', 'd', 0, 0, 0)",
      );
      a = (await requirements.createRequirement(
        courseId: 'k1',
        name: 'A',
        kind: RequirementKind.dive,
      )).id;
      b = (await requirements.createRequirement(
        courseId: 'k1',
        name: 'B',
        kind: RequirementKind.checklist,
      )).id;
      await requirements.linkDive(requirementId: a, diveId: 'v1');
      await changeLog.settleAll();
      await db.customStatement('DELETE FROM change_log_operations');
    });

    tearDown(tearDownTestDatabase);

    test('a requirement added, a dive credited to it, then Save: one entry, '
        'the requirement before its credit', () async {
      final session = await sitting();
      change(session, (rows) => withDiveUncredited(rows, a, 'v1'));
      change(
        session,
        (rows) => withRequirementAdded(
          rows,
          const RequirementDraft(
            name: 'Deep',
            kind: RequirementKind.dive,
            targetCount: 1,
          ),
          courseId: 'k1',
        ),
      );
      final added = courseRequirementsList
          .current(session)!
          .last
          .requirement
          .id;
      change(session, (rows) => withDiveCredited(rows, added, summary('v1')));

      await save(session);

      final rows = await storedRows();
      expect(rows, hasLength(3));
      expect(creditsOf(rows, a), isEmpty);
      expect(creditsOf(rows, added), ['v1']);
      final ops = await operations();
      expect(ops, hasLength(1));
      expect(ops.single['label'], 'record_edit:courses:k1:requirements');
    });

    test('a tick made before the read answers is kept', () async {
      final session = EditSession(await stored());
      addTearDown(session.dispose);

      await HeldRequirementActions(session).tick(
        (await storedRows())
            .firstWhere((r) => r.requirement.id == b)
            .requirement,
        true,
      );

      final held = courseRequirementsList.current(session)!;
      expect(held.firstWhere((r) => r.requirement.id == b).isSatisfied, isTrue);
    });

    test('two actions before the read answers are both kept', () async {
      final session = EditSession(await stored());
      addTearDown(session.dispose);
      final rows = await storedRows();
      final actions = HeldRequirementActions(session);

      await Future.wait([
        actions.tick(
          rows.firstWhere((r) => r.requirement.id == b).requirement,
          true,
        ),
        actions.uncredit(
          rows.firstWhere((r) => r.requirement.id == a).requirement,
          'v1',
        ),
      ]);

      final held = courseRequirementsList.current(session)!;
      expect(held.firstWhere((r) => r.requirement.id == b).isSatisfied, isTrue);
      expect(creditsOf(held, a), isEmpty);
    });

    test('the same, then Cancel: neither written', () async {
      final session = await sitting();
      change(
        session,
        (rows) => withRequirementAdded(
          rows,
          const RequirementDraft(
            name: 'Deep',
            kind: RequirementKind.dive,
            targetCount: 1,
          ),
          courseId: 'k1',
        ),
      );
      final added = courseRequirementsList
          .current(session)!
          .last
          .requirement
          .id;
      change(session, (rows) => withDiveUncredited(rows, a, 'v1'));
      change(session, (rows) => withDiveCredited(rows, added, summary('v1')));

      // Cancel ends the sitting without a write; the tear-down disposes it.

      final rows = await storedRows();
      expect(rows, hasLength(2));
      expect(creditsOf(rows, a), ['v1']);
      expect(await operations(), isEmpty);
    });

    test('a tick and a name change are one entry, and reverting it restores '
        'the tick and the credits', () async {
      final session = await sitting();
      change(session, (rows) => withRequirementTicked(rows, b, true));
      change(session, (rows) => withDiveUncredited(rows, a, 'v1'));
      session.set(courseNameField, 'Rescue Diver');

      await save(session);

      expect((await stored()).name, 'Rescue Diver');
      var rows = await storedRows();
      expect(
        rows.firstWhere((r) => r.requirement.id == b).requirement.completedAt,
        isNotNull,
      );
      final ops = await operations();
      expect(ops, hasLength(1));
      expect(ops.single['label'], 'record_edit:courses:k1:requirements,status');

      final revert = ChangeLogRevertService(afterDiveWrites: (_) {});
      await revert.execute(
        await revert.planOperation(ops.single['id']! as String),
      );

      expect((await stored()).name, 'Rescue');
      rows = await storedRows();
      expect(
        rows.firstWhere((r) => r.requirement.id == b).requirement.completedAt,
        isNull,
      );
      expect(creditsOf(rows, a), ['v1']);
    });
  });
}

RequirementDiveSummary summary(String id) =>
    RequirementDiveSummary(diveId: id, dateTime: DateTime.utc(2026, 1, 1));
