import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/courses/data/repositories/course_repository.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
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

/// Seeds the course and opens its Requirements card in a sitting whose rows
/// are read, as the course page's open card is (issue #4527, phase 3).
Future<EditSession<Course>> _pumpOpenCard(WidgetTester tester) async {
  late EditSession<Course> session;
  await tester.runAsync(() async {
    await _seed();
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

void main() {
  setUp(() async {
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('add requirement flow creates a checklist row at Save', (
    tester,
  ) async {
    final session = await _pumpOpenCard(tester);

    // The empty open card shows the add button.
    final addButton = find.text('Add requirement');
    expect(addButton, findsOneWidget);
    await tester.ensureVisible(addButton);
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField).first,
      'Knowledge development',
    );
    await tester.tap(find.text('Check-off item'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Knowledge development'), findsOneWidget);

    await tester.runAsync(() async {
      await session.runHeldWrites();
      final progress = await CourseRequirementRepository().getCourseProgress(
        'course-1',
      );
      expect(
        progress.requirements.single.requirement.name,
        'Knowledge development',
      );
    });
  });

  testWidgets('template picker applies the selected template at Save', (
    tester,
  ) async {
    final session = await _pumpOpenCard(tester);

    final templateButton = find.text('Add from template');
    await tester.ensureVisible(templateButton);
    await tester.tap(templateButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Advanced Open Water'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(courseRequirementsList.current(session), hasLength(4));

    await tester.runAsync(() async {
      await session.runHeldWrites();
      final progress = await CourseRequirementRepository().getCourseProgress(
        'course-1',
      );
      expect(progress.requirements.length, 4);
    });
  });
}
