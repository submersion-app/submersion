import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:submersion/features/courses/presentation/editing/course_requirements_sitting.dart';
import 'package:submersion/features/courses/presentation/widgets/course_requirements_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/shared/widgets/record_editing/edit_session.dart';

import '../../../helpers/test_database.dart';

Future<void> _seed() async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
  await db.customStatement(
    "INSERT INTO courses (id, diver_id, name, agency, start_date, "
    "created_at, updated_at) "
    "VALUES ('course-1', 'diver-1', 'AOW', 'padi', 1000, 1000, 1000)",
  );
}

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      themeAnimationDuration: Duration.zero,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );
}

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  /// Opens the seeded course's Requirements card in a sitting whose rows
  /// are read, as the course page's open card is (issue #4527, phase 3).
  Future<EditSession<Course>> pumpOpenCard(WidgetTester tester) async {
    late EditSession<Course> session;
    await tester.runAsync(() async {
      session = EditSession(
        (await CourseRepository().getCourseById('course-1'))!,
      );
      await courseRequirementsList.load(session);
    });
    addTearDown(session.dispose);
    await tester.pumpWidget(
      _wrap(CourseRequirementsSection(courseId: 'course-1', editing: session)),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    return session;
  }

  testWidgets('renders requirement rows with progress header', (tester) async {
    await tester.runAsync(() async {
      await _seed();
      final repository = CourseRequirementRepository();
      await repository.createRequirement(
        courseId: 'course-1',
        name: 'Deep adventure dive',
        kind: RequirementKind.dive,
      );
      final checklist = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Knowledge development',
        kind: RequirementKind.checklist,
      );
      await repository.setChecklistComplete(checklist.id, true);
    });

    await tester.pumpWidget(
      _wrap(const CourseRequirementsSection(courseId: 'course-1')),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Deep adventure dive'), findsOneWidget);
    expect(find.text('Knowledge development'), findsOneWidget);
    expect(find.text('1 of 2 complete'), findsOneWidget);
  });

  testWidgets('the checklist checkbox ticks it, written at Save', (
    tester,
  ) async {
    late String requirementId;
    await tester.runAsync(() async {
      await _seed();
      final repository = CourseRequirementRepository();
      final req = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Knowledge development',
        kind: RequirementKind.checklist,
      );
      requirementId = req.id;
    });
    final session = await pumpOpenCard(tester);

    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await session.runHeldWrites();
      final progress = await CourseRequirementRepository().getCourseProgress(
        'course-1',
      );
      expect(
        progress.requirements
            .singleWhere((r) => r.requirement.id == requirementId)
            .isSatisfied,
        isTrue,
      );
    });
  });

  testWidgets('a suggestion chip credits the dive, written at Save', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await _seed();
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO dives (id, diver_id, dive_number, dive_date_time, "
        "created_at, updated_at) "
        "VALUES ('dive-1', 'diver-1', 47, 9000, 1000, 1000)",
      );
      await CourseRequirementRepository().createRequirement(
        courseId: 'course-1',
        name: 'Deep adventure dive',
        kind: RequirementKind.dive,
      );
    });
    final session = await pumpOpenCard(tester);

    // Expand the dive requirement tile to reveal suggestions.
    await tester.tap(find.text('Deep adventure dive'));
    await tester.pumpAndSettle();

    final chip = find.byWidgetPredicate(
      (widget) =>
          widget is ActionChip &&
          widget.label is Text &&
          ((widget.label as Text).data ?? '').contains('#47'),
    );
    expect(chip, findsOneWidget);
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await session.runHeldWrites();
      final progress = await CourseRequirementRepository().getCourseProgress(
        'course-1',
      );
      expect(progress.requirements.single.creditCount, 1);
    });
  });

  /// Seeds a checklist requirement and a dive requirement with dive-1
  /// suggested for it and dive-2 credited to it.
  Future<({String checklist, String dive})> seedTracker(
    WidgetTester tester,
  ) async {
    late ({String checklist, String dive}) ids;
    await tester.runAsync(() async {
      await _seed();
      final db = DatabaseService.instance.database;
      await db.customStatement(
        "INSERT INTO dives (id, diver_id, dive_number, dive_date_time, "
        "created_at, updated_at) VALUES "
        "('dive-1', 'diver-1', 47, 9000, 1000, 1000), "
        "('dive-2', 'diver-1', 48, 9500, 1000, 1000)",
      );
      final repository = CourseRequirementRepository();
      final checklist = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Knowledge development',
        kind: RequirementKind.checklist,
      );
      final dive = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Deep adventure dive',
        kind: RequirementKind.dive,
        targetCount: 2,
      );
      await repository.linkDive(requirementId: dive.id, diveId: 'dive-2');
      ids = (checklist: checklist.id, dive: dive.id);
    });
    return ids;
  }

  Future<String> storedState() async {
    final progress = await CourseRequirementRepository().getCourseProgress(
      'course-1',
    );
    return [
      for (final r in progress.requirements)
        '${r.requirement.name}:${r.requirement.completedAt != null}:'
            '${r.linkedDives.map((d) => d.diveId).join('+')}',
    ].join('|');
  }

  testWidgets('locked, no tap writes', (tester) async {
    await seedTracker(tester);
    late String before;
    await tester.runAsync(() async => before = await storedState());

    await tester.pumpWidget(
      _wrap(const CourseRequirementsSection(courseId: 'course-1')),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    // Nothing to add, edit, credit or uncredit, and the tick only shows.
    expect(find.byIcon(Icons.add), findsNothing);
    expect(find.byIcon(Icons.library_add_outlined), findsNothing);
    expect(find.byType(PopupMenuButton<String>), findsNothing);
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).onChanged,
      isNull,
    );
    await tester.tap(find.byType(Checkbox));
    await tester.tap(find.text('Deep adventure dive'));
    await tester.pumpAndSettle();
    expect(find.byType(ActionChip), findsNothing);
    expect(find.byIcon(Icons.link_off), findsNothing);
    expect(find.byIcon(Icons.search), findsNothing);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );

    late String after;
    await tester.runAsync(() async => after = await storedState());
    expect(after, before);
  });

  testWidgets('in a sitting, a tick writes nothing until Save', (tester) async {
    final ids = await seedTracker(tester);
    late String before;
    late EditSession<Course> session;
    await tester.runAsync(() async {
      before = await storedState();
      session = EditSession(
        (await CourseRepository().getCourseById('course-1'))!,
      );
      await courseRequirementsList.load(session);
    });
    addTearDown(session.dispose);

    await tester.pumpWidget(
      _wrap(CourseRequirementsSection(courseId: 'course-1', editing: session)),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final held = courseRequirementsList.current(session)!;
    expect(
      held.firstWhere((r) => r.requirement.id == ids.checklist).isSatisfied,
      isTrue,
    );
    expect(session.changedCardIds, {'requirements'});
    late String after;
    await tester.runAsync(() async => after = await storedState());
    expect(after, before);
  });
  testWidgets('adding a requirement completes once the sitting holds it', (
    tester,
  ) async {
    await seedTracker(tester);
    late EditSession<Course> session;
    await tester.runAsync(() async {
      // Not read yet: the add has to read the rows first.
      session = EditSession(
        (await CourseRepository().getCourseById('course-1'))!,
      );
    });
    addTearDown(session.dispose);
    await tester.pumpWidget(_wrap(const SizedBox()));

    int? rowsWhenDone = -1;
    final adding = HeldRequirementActions(
      session,
    ).add(tester.element(find.byType(SizedBox)));
    adding.then((_) {
      rowsWhenDone = courseRequirementsList.current(session)?.length;
    });
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Deep dive');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    // A real read: wait for it, however long a busy machine takes.
    for (var i = 0; i < 200 && rowsWhenDone == -1; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
    }

    // Done means held: the two stored rows and the new one.
    expect(rowsWhenDone, 3);
  });
  testWidgets('Choose dive before the read answers still opens the picker', (
    tester,
  ) async {
    final ids = await seedTracker(tester);
    late EditSession<Course> session;
    late CourseRequirement dive;
    await tester.runAsync(() async {
      session = EditSession(
        (await CourseRepository().getCourseById('course-1'))!,
      );
      dive = (await CourseRequirementRepository().getCourseProgress('course-1'))
          .requirements
          .firstWhere((r) => r.requirement.id == ids.dive)
          .requirement;
    });
    addTearDown(session.dispose);
    await tester.pumpWidget(_wrap(const SizedBox()));

    final crediting = HeldRequirementActions(
      session,
    ).credit(tester.element(find.byType(SizedBox)), dive, null);
    var opened = false;
    for (var i = 0; i < 200 && !opened; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
      opened = find.text('Choose dive').evaluate().isNotEmpty;
    }

    expect(opened, isTrue);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    await tester.runAsync(() => crediting);
  });
}
