import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/presentation/pages/course_detail_page.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// The course page's overflow menu opens the course in Connections.
void main() {
  final course = Course(
    id: 'course-1',
    diverId: 'diver-1',
    name: 'Advanced Open Water',
    agency: CertificationAgency.padi,
    startDate: DateTime(2026, 5, 27),
    createdAt: DateTime(2026, 5, 27),
    updatedAt: DateTime(2026, 5, 28),
  );

  // The page keeps an indefinite animation running, so pumpAndSettle would
  // never return; a few frames let routes and menus finish their transitions.
  Future<void> pumpFrames(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  testWidgets('Open in Connections centres the map on the course', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/courses/${course.id}',
      routes: [
        GoRoute(
          path: '/courses/:id',
          builder: (_, s) =>
              CourseDetailPage(courseId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/insights/connections',
          builder: (context, state) =>
              Scaffold(body: Text('CONNECTIONS ${state.uri.query}')),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        overrides: [
          courseByIdProvider(course.id).overrideWith((ref) async => course),
          courseDivesProvider(course.id).overrideWith((ref) async => const []),
          courseProgressProvider(course.id).overrideWith(
            (ref) async =>
                CourseProgress(courseId: course.id, requirements: const []),
          ),
          suggestedDivesProvider(
            course.id,
          ).overrideWith((ref) async => const []),
        ],
      ),
    );
    await pumpFrames(tester);

    await tester.tap(find.byTooltip('More options'));
    await pumpFrames(tester);
    await tester.tap(find.text('Open in Connections'));
    await pumpFrames(tester);
    expect(
      find.text('CONNECTIONS mode=around&focus=course:course-1'),
      findsOneWidget,
    );
  });
}
