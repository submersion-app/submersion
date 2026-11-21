import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/courses/presentation/widgets/course_picker.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// A course created from the course picker is chosen in its place (#4809).
void main() {
  setUp(() async {
    final db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          const DiversCompanion(
            id: Value('d'),
            name: Value('D'),
            createdAt: Value(0),
            updatedAt: Value(0),
          ),
        );
    await db
        .into(db.courses)
        .insert(
          CoursesCompanion(
            id: const Value('an'),
            diverId: const Value('d'),
            name: const Value('Advanced Nitrox'),
            agency: const Value('tdi'),
            startDate: Value(DateTime(2026, 9, 1).millisecondsSinceEpoch),
            createdAt: const Value(0),
            updatedAt: const Value(0),
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  /// The new-course page, standing in for the real one: pops [createdId]
  /// on Create, nothing on Cancel.
  GoRoute newCourseRoute(String createdId) => GoRoute(
    path: '/courses/new',
    builder: (context, _) => Scaffold(
      body: Column(
        children: [
          TextButton(
            onPressed: () => context.pop(createdId),
            child: const Text('Create stub'),
          ),
          TextButton(
            onPressed: () => context.pop(),
            child: const Text('Cancel stub'),
          ),
        ],
      ),
    ),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pumpAndSettle();
  }

  Future<List<List<String>>> pumpField(
    WidgetTester tester,
    List<String> selected,
  ) async {
    final changes = <List<String>>[];
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => CourseMultiSelectField(
                selectedCourseIds: selected,
                onChanged: (ids) => setState(() {
                  selected = ids;
                  changes.add(ids);
                }),
              ),
            ),
          ),
        ),
        newCourseRoute('new-course'),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: await getBaseOverrides(),
      ),
    );
    await settle(tester);
    return changes;
  }

  testWidgets('a course created from the sheet is chosen with the others', (
    tester,
  ) async {
    final changes = await pumpField(tester, ['an']);
    await tester.tap(find.byType(InputDecorator));
    await settle(tester);

    await tester.tap(find.byTooltip('New Course'));
    await settle(tester);
    expect(find.text('Create stub'), findsOneWidget);

    await tester.tap(find.text('Create stub'));
    await settle(tester);
    expect(changes.last, ['an', 'new-course']);
  });

  testWidgets('a cancelled new course chooses nothing', (tester) async {
    final changes = await pumpField(tester, ['an']);
    await tester.tap(find.byType(InputDecorator));
    await settle(tester);

    await tester.tap(find.byTooltip('New Course'));
    await settle(tester);
    await tester.tap(find.text('Cancel stub'));
    await settle(tester);
    expect(changes, isEmpty);
  });

  testWidgets('a course created after toggles keeps those toggles', (
    tester,
  ) async {
    final changes = await pumpField(tester, ['an']);
    await tester.tap(find.byType(InputDecorator));
    await settle(tester);
    // Untick the one course, then ask for a new one.
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Advanced Nitrox'));
    await settle(tester);
    expect(changes.last, isEmpty);

    await tester.tap(find.byTooltip('New Course'));
    await settle(tester);
    await tester.tap(find.text('Create stub'));
    await settle(tester);
    expect(changes.last, ['new-course']);
  });

  testWidgets('the sheet answers once the created course is reported, so a '
      'caller that reads the pick afterwards has it', (tester) async {
    var picked = <String>[];
    var done = false;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  await showCourseMultiPickerSheet(
                    context,
                    selectedCourseIds: const [],
                    onChanged: (ids) => picked = ids,
                  );
                  done = true;
                },
                child: const Text('Add courses'),
              ),
            ),
          ),
        ),
        newCourseRoute('new-course'),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: await getBaseOverrides(),
      ),
    );
    await settle(tester);

    await tester.tap(find.text('Add courses'));
    await settle(tester);
    await tester.tap(find.byTooltip('New Course'));
    await settle(tester);
    expect(done, isFalse);

    await tester.tap(find.text('Create stub'));
    await settle(tester);
    expect(done, isTrue);
    expect(picked, ['new-course']);
  });
}
