import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/widgets/course_card.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

final _course = Course(
  id: 'c1',
  diverId: 'd1',
  name: 'Advanced Open Water Diver',
  agency: CertificationAgency.padi.name,
  startDate: DateTime(2025, 12, 28),
  instructorName: 'Maximiliane Schwarzenberger-Hoffmann',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);

void main() {
  // Selection mode puts the checkbox ahead of the status icon rather than in
  // its place (issue #1717), so the info column loses 40px. Its agency and
  // start-date line must still fit a phone-width card.
  for (final selecting in [false, true]) {
    testWidgets('fits a phone-width card '
        '${selecting ? 'in' : 'outside'} selection mode', (tester) async {
      tester.view.physicalSize = const Size(353, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        testApp(
          overrides: await getBaseOverrides(),
          locale: const Locale('en'),
          child: CourseCard(
            course: _course,
            isSelectionMode: selecting,
            onTap: () {},
            onCheckChanged: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(Checkbox), selecting ? findsOneWidget : findsNothing);
    });
  }

  // Courses used a bespoke padded card, so its rows were taller, wider inset
  // and further apart than every other section's (issue #3382). It now uses
  // the same Card + ListTile shape as CertificationListTile and
  // EquipmentListTile.
  group('matches the other sections\' list tiles (#3382)', () {
    Future<void> pump(WidgetTester tester) async {
      await tester.pumpWidget(
        testApp(
          overrides: await getBaseOverrides(),
          locale: const Locale('en'),
          child: CourseCard(course: _course, onTap: () {}),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('uses the shared card margin', (tester) async {
      await pump(tester);

      final card = tester.widget<Card>(find.byType(Card));
      expect(
        card.margin,
        const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      );
    });

    testWidgets('lays its content out as a ListTile', (tester) async {
      await pump(tester);

      expect(
        find.descendant(of: find.byType(Card), matching: find.byType(ListTile)),
        findsOneWidget,
      );
      expect(find.text('Advanced Open Water Diver'), findsOneWidget);
      expect(find.text('Completed'), findsNothing);
      expect(find.text('In Progress'), findsOneWidget);

      final subtitle = tester.widget<Text>(
        find.textContaining('Instructor: Maximiliane'),
      );
      expect(subtitle.maxLines, 1);
      expect(subtitle.overflow, TextOverflow.ellipsis);
    });

    testWidgets('rounds the status icon like the other tiles', (tester) async {
      await pump(tester);

      final box = tester.widget<Container>(
        find
            .ancestor(
              of: find.byIcon(Icons.school_outlined),
              matching: find.byType(Container),
            )
            .first,
      );
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.circular(8));
    });
  });
}
