import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/courses/data/repositories/course_requirement_repository.dart';
import 'package:submersion/features/courses/domain/entities/course_requirement.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dashboard/presentation/widgets/active_course_progress_card.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../helpers/test_database.dart';

Widget _wrap(Widget child, SharedPreferences prefs) {
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      themeAnimationDuration: Duration.zero,
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

Future<void> _seedCourse({required bool completed}) async {
  final db = DatabaseService.instance.database;
  await db.customStatement(
    "INSERT INTO divers (id, name, created_at, updated_at) "
    "VALUES ('diver-1', 'Test Diver', 1000, 1000)",
  );
  final completionCol = completed ? '2000' : 'NULL';
  await db.customStatement(
    "INSERT INTO courses (id, diver_id, name, agency, start_date, "
    "completion_date, created_at, updated_at) "
    "VALUES ('course-1', 'diver-1', 'AOW', 'padi', 1000, $completionCol, "
    "1000, 1000)",
  );
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await setUpTestDatabase();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('hidden when there are no in-progress courses', (tester) async {
    await tester.runAsync(() => _seedCourse(completed: true));
    await tester.pumpWidget(_wrap(const ActiveCourseProgressCard(), prefs));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('hidden when an in-progress course has zero requirements '
      '(totalCount filter)', (tester) async {
    await tester.runAsync(() => _seedCourse(completed: false));
    await tester.pumpWidget(_wrap(const ActiveCourseProgressCard(), prefs));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('shows course name and satisfied fraction when active', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await _seedCourse(completed: false);
      final repository = CourseRequirementRepository();
      final req = await repository.createRequirement(
        courseId: 'course-1',
        name: 'Knowledge development',
        kind: RequirementKind.checklist,
      );
      await repository.setChecklistComplete(req.id, true);
      await repository.createRequirement(
        courseId: 'course-1',
        name: 'Deep adventure dive',
        kind: RequirementKind.dive,
      );
    });

    await tester.pumpWidget(_wrap(const ActiveCourseProgressCard(), prefs));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();

    expect(find.text('AOW'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
