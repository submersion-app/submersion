import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_coordinator.dart';
import 'package:submersion/features/certifications/data/repositories/certification_repository.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/certifications/presentation/providers/certification_providers.dart';
import 'package:submersion/features/certifications/presentation/widgets/certification_multi_select_field.dart';
import 'package:submersion/features/change_log/data/repositories/change_log_repository.dart';
import 'package:submersion/features/change_log/data/services/change_log_revert_service.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/courses/data/services/course_edit_save_service.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/editing/course_certifications_sitting.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// The diver's certifications, as given.
class _Certifications extends StateNotifier<AsyncValue<List<Certification>>>
    implements CertificationListNotifier {
  _Certifications(List<Certification> all) : super(AsyncValue.data(all));

  /// The list read again, as after a certification is created.
  void put(List<Certification> all) => state = AsyncValue.data(all);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A course's earned certifications held in its page's sitting (issue
/// #4527, phase 3), written at Save in the sitting's one entry.
void main() {
  final certifications = CertificationRepository();
  final changeLog = ChangeLogRepository();

  Future<Course> stored([String id = 'k1']) async =>
      (await CourseRepository().getCourseById(id))!;

  Future<List<String>> earnedBy(String courseId) async => [
    for (final c in await certifications.getCertificationsForCourse(courseId))
      c.id,
  ];

  Future<List<Map<String, Object?>>> operations() async {
    await changeLog.settleAll();
    final rows = await DatabaseService.instance.database
        .customSelect('SELECT id, label FROM change_log_operations')
        .get();
    return [for (final row in rows) row.data];
  }

  /// Opens a sitting on the course with its certifications loaded.
  Future<EditSession<Course>> sitting() async {
    final session = EditSession(await stored());
    addTearDown(session.dispose);
    await courseCertificationsList.load(session);
    return session;
  }

  Future<void> hold(EditSession<Course> session, List<String> ids) async {
    final byId = {
      for (final c in await certifications.getAllCertifications()) c.id: c,
    };
    courseCertificationsList.set(session, [for (final id in ids) byId[id]!]);
  }

  Future<void> save(EditSession<Course> session) =>
      CourseEditSaveService(CourseRepository()).save(
        courseId: 'k1',
        apply: session.applyTo,
        changedCardIds: session.changedCardIds,
        alsoWrite: session.hasHeldWrites ? session.runHeldWrites : null,
        alsoWriteIsAChange: session.hasHeldChanges,
      );

  Future<String?> representativeOf(String courseId) async =>
      (await stored(courseId)).certificationId;

  setUp(() async {
    final db = await setUpTestDatabase();
    addTearDown(SyncCoordinator.reset);
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('d', 'D', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO courses (id, diver_id, name, agency, start_date, notes, "
      "created_at, updated_at) VALUES "
      "('k1', 'd', 'Rescue', 'padi', 0, '', 0, 0), "
      "('k0', 'd', 'Nitrox', 'padi', 0, '', 0, 0)",
    );
    await db.customStatement(
      "INSERT INTO certifications (id, diver_id, name, agency, issue_date, "
      "created_at, updated_at) VALUES "
      "('c1', 'd', 'Rescue Diver', 'padi', 1000, 0, 0), "
      "('c2', 'd', 'EFR', 'padi', 2000, 0, 0), "
      "('c3', 'd', 'Nitrox', 'padi', 500, 0, 0), "
      "('c4', 'd', 'Nitrox II', 'padi', 3000, 0, 0)",
    );
    await CourseRepository().setCourseCertifications('k0', ['c3', 'c4']);
    await changeLog.settleAll();
    await db.customStatement('DELETE FROM change_log_operations');
  });

  tearDown(tearDownTestDatabase);

  test('ticking two certifications holds both, written at Save', () async {
    final session = await sitting();
    await hold(session, ['c1', 'c2']);

    expect(await earnedBy('k1'), isEmpty);
    await save(session);

    expect((await earnedBy('k1')).toSet(), {'c1', 'c2'});
    final ops = await operations();
    expect(ops, hasLength(1));
    expect(ops.single['label'], 'record_edit:courses:k1:earnedCertifications');
  });

  test('removing one unlinks it at Save', () async {
    await CourseRepository().setCourseCertifications('k1', ['c1', 'c2']);
    final session = await sitting();
    await hold(session, ['c2']);

    await save(session);

    expect(await earnedBy('k1'), ['c2']);
  });

  test('a certification linked meanwhile on another device is kept', () async {
    final session = await sitting();
    await hold(session, ['c1']);
    // Another device links c2 to the course after the sitting read.
    await CourseRepository().setCourseCertifications('k1', ['c2']);

    await save(session);

    expect((await earnedBy('k1')).toSet(), {'c1', 'c2'});
  });

  test('a removal keeps what was linked meanwhile', () async {
    await CourseRepository().setCourseCertifications('k1', ['c1', 'c2']);
    final session = await sitting();
    await hold(session, ['c2']);
    await CourseRepository().setCourseCertifications('k1', ['c1', 'c2', 'c4']);

    await save(session);

    expect((await earnedBy('k1')).toSet(), {'c2', 'c4'});
  });

  test('a certification taken from another course, then Cancel: still on '
      'that course', () async {
    final session = await sitting();
    await hold(session, ['c3']);

    // Cancel ends the sitting without a write; the tear-down disposes it.

    expect((await earnedBy('k0')).toSet(), {'c3', 'c4'});
    expect(await representativeOf('k0'), 'c3');
    expect(await operations(), isEmpty);
  });

  test('the same, then Save: moved, both representatives recomputed in one '
      'entry, and reverting restores both', () async {
    final session = await sitting();
    await hold(session, ['c3']);

    await save(session);

    expect(await earnedBy('k1'), ['c3']);
    expect(await earnedBy('k0'), ['c4']);
    expect(await representativeOf('k1'), 'c3');
    expect(await representativeOf('k0'), 'c4');
    final ops = await operations();
    expect(ops, hasLength(1));

    final revert = ChangeLogRevertService(afterDiveWrites: (_) {});
    await revert.execute(
      await revert.planOperation(ops.single['id']! as String),
    );

    expect(await earnedBy('k1'), isEmpty);
    expect((await earnedBy('k0')).toSet(), {'c3', 'c4'});
    expect(await representativeOf('k1'), isNull);
    expect(await representativeOf('k0'), 'c3');
  });

  testWidgets('the field\'s choices are held as the certifications they '
      'name, and a removal drops only that one', (tester) async {
    late EditSession<Course> session;
    late List<Certification> all;
    await tester.runAsync(() async {
      session = EditSession(await stored());
      await courseCertificationsList.load(session);
      all = await certifications.getAllCertifications();
    });
    addTearDown(session.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...overrides,
          // The diver's certifications, which the choices are read from.
          certificationListNotifierProvider.overrideWith(
            (ref) => _Certifications(all),
          ),
        ],
        child: Scaffold(
          body: CourseEarnedCertificationsEditor(session: session),
        ),
      ),
    );
    for (
      var i = 0;
      i < 200 && find.byType(CertificationMultiSelectField).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }
    CertificationMultiSelectField field() =>
        tester.widget(find.byType(CertificationMultiSelectField));

    field().onChanged(['c1', 'c2']);
    await tester.pump();
    expect(
      [for (final c in courseCertificationsList.current(session)!) c.id],
      ['c1', 'c2'],
    );
    expect(field().selectedCertificationIds, ['c1', 'c2']);

    field().onChanged(['c2']);
    await tester.pump();
    expect(
      [for (final c in courseCertificationsList.current(session)!) c.id],
      ['c2'],
    );
    expect(session.changedCardIds, {'earnedCertifications'});
  });

  testWidgets("the field stays inert until the sitting's list has loaded", (
    tester,
  ) async {
    late EditSession<Course> session;
    await tester.runAsync(() async => session = EditSession(await stored()));
    addTearDown(session.dispose);
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        overrides: overrides,
        child: Scaffold(
          body: CourseEarnedCertificationsEditor(session: session),
        ),
      ),
    );

    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(find.byType(CertificationMultiSelectField), findsNothing);

    // The editor reads the list itself and draws it once the read answers,
    // however long a busy machine takes.
    for (
      var i = 0;
      i < 200 && find.byType(CertificationMultiSelectField).evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }

    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.byType(CertificationMultiSelectField), findsOneWidget);
  });

  testWidgets('a certification created after the sheet opened is held when '
      'the sheet reports it (#4809)', (tester) async {
    late EditSession<Course> session;
    late List<Certification> before;
    late Certification created;
    await tester.runAsync(() async {
      session = EditSession(await stored());
      await courseCertificationsList.load(session);
      before = await certifications.getAllCertifications();
      await DatabaseService.instance.database.customStatement(
        "INSERT INTO certifications (id, diver_id, name, agency, "
        "created_at, updated_at) VALUES ('c5', 'd', 'Deep', 'padi', 0, 0)",
      );
      created = (await certifications.getCertificationById('c5'))!;
    });
    addTearDown(session.dispose);
    final list = _Certifications(before);
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          certificationListNotifierProvider.overrideWith((ref) => list),
        ],
        child: Scaffold(
          body: CourseEarnedCertificationsEditor(session: session),
        ),
      ),
    );
    await tester.pump();

    // What the sheet holds: the field's callback as it was when it opened.
    final reportFromSheet = tester
        .widget<CertificationMultiSelectField>(
          find.byType(CertificationMultiSelectField),
        )
        .onChanged;
    // The new certification's page saved it and the list read it again.
    list.put([...before, created]);
    await tester.pump();

    reportFromSheet(['c5']);

    expect(
      [for (final c in courseCertificationsList.current(session)!) c.id],
      ['c5'],
    );
  });

  testWidgets('a report once the editor has gone holds nothing', (
    tester,
  ) async {
    late EditSession<Course> session;
    late List<Certification> all;
    await tester.runAsync(() async {
      session = EditSession(await stored());
      await courseCertificationsList.load(session);
      all = await certifications.getAllCertifications();
    });
    addTearDown(session.dispose);
    await tester.pumpWidget(
      testApp(
        overrides: [
          ...await getBaseOverrides(),
          certificationListNotifierProvider.overrideWith(
            (ref) => _Certifications(all),
          ),
        ],
        child: Scaffold(
          body: CourseEarnedCertificationsEditor(session: session),
        ),
      ),
    );
    await tester.pump();
    final reportFromSheet = tester
        .widget<CertificationMultiSelectField>(
          find.byType(CertificationMultiSelectField),
        )
        .onChanged;

    // The course page closed while the new certification's page was open.
    await tester.pumpWidget(const SizedBox.shrink());
    reportFromSheet(['c1']);

    expect(courseCertificationsList.current(session), isEmpty);
  });
}
