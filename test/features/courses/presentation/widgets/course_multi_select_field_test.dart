import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/courses/presentation/widgets/course_picker.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// Picking several courses for one dive (#2515).
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
    for (final (id, name) in [('an', 'Advanced Nitrox'), ('dp', 'Deco Proc')]) {
      await db
          .into(db.courses)
          .insert(
            CoursesCompanion(
              id: Value(id),
              diverId: const Value('d'),
              name: Value(name),
              agency: const Value('tdi'),
              startDate: Value(DateTime(2026, 9, 1).millisecondsSinceEpoch),
              createdAt: const Value(0),
              updatedAt: const Value(0),
            ),
          );
    }
  });
  tearDown(tearDownTestDatabase);

  Future<List<List<String>>> pump(
    WidgetTester tester,
    List<String> selected,
  ) async {
    final changes = <List<String>>[];
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: overrides,
        child: StatefulBuilder(
          builder: (context, setState) => CourseMultiSelectField(
            selectedCourseIds: selected,
            onChanged: (ids) => setState(() {
              selected = ids;
              changes.add(ids);
            }),
          ),
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(milliseconds: 50));
    }
    return changes;
  }

  testWidgets('shows a chip per selected course', (tester) async {
    await pump(tester, ['an', 'dp']);
    expect(find.widgetWithText(InputChip, 'Advanced Nitrox'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'Deco Proc'), findsOneWidget);
  });

  testWidgets('the sheet toggles courses and stays open', (tester) async {
    final changes = await pump(tester, ['an']);
    await tester.tap(find.byType(InputDecorator));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(CheckboxListTile, 'Deco Proc'));
    await tester.pumpAndSettle();
    expect(changes.last, ['an', 'dp']);
    expect(find.text('Select Training Courses'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('Select Training Courses'), findsNothing);
    expect(find.widgetWithText(InputChip, 'Deco Proc'), findsOneWidget);
  });

  testWidgets('a chip delete removes that course only', (tester) async {
    final changes = await pump(tester, ['an', 'dp']);
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, 'Advanced Nitrox'),
        matching: find.byIcon(Icons.clear),
      ),
    );
    await tester.pumpAndSettle();
    expect(changes.last, ['dp']);
  });

  testWidgets('an in-progress course carries the Active badge', (tester) async {
    await pump(tester, const []);
    await tester.tap(find.byType(InputDecorator));
    await tester.pumpAndSettle();
    // Both seeded courses have no completion date, so both are in progress.
    expect(find.text('Active'), findsNWidgets(2));
  });

  testWidgets('no selection shows the tap-to-link hint', (tester) async {
    await pump(tester, const []);
    expect(find.text('Tap to link to a training course'), findsOneWidget);
  });
}
