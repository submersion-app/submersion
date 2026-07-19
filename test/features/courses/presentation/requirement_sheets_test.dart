import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/presentation/widgets/course_requirements_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

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

  testWidgets('add requirement flow creates a checklist row', (tester) async {
    await tester.runAsync(_seed);

    await tester.pumpWidget(
      _wrap(const CourseRequirementsSection(courseId: 'course-1')),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    // Empty state shows the add button.
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

    await tester.runAsync(() async {
      final progress = await CourseRequirementRepository().getCourseProgress(
        'course-1',
      );
      expect(
        progress.requirements.single.requirement.name,
        'Knowledge development',
      );
    });
  });

  testWidgets('template picker applies the selected template', (tester) async {
    await tester.runAsync(_seed);

    await tester.pumpWidget(
      _wrap(const CourseRequirementsSection(courseId: 'course-1')),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    final templateButton = find.text('Add from template');
    await tester.ensureVisible(templateButton);
    await tester.tap(templateButton);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Advanced Open Water'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final progress = await CourseRequirementRepository().getCourseProgress(
        'course-1',
      );
      expect(progress.requirements.length, 4);
    });
  });
}
