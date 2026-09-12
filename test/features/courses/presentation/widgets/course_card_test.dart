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
  agency: CertificationAgency.padi,
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
}
