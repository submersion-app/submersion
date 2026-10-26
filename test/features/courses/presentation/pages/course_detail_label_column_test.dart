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

import '../../../../helpers/detail_row_finders.dart';

/// The course Details card puts each value right beside its label, on one
/// column as wide as the longest label rather than a fixed 100 px (#3678).
void main() {
  final course = Course(
    id: 'course-1',
    diverId: 'diver-1',
    name: 'Advanced Open Water',
    agency: CertificationAgency.padi.name,
    startDate: DateTime(2026, 5, 27),
    location: 'Kralendijk',
    createdAt: DateTime(2026, 5, 27),
    updatedAt: DateTime(2026, 5, 28),
  );

  // The page keeps an indefinite animation running, so pumpAndSettle would
  // never return.
  Future<void> pumpFrames(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  testWidgets('a label wider than 100 px stays on one line beside its value', (
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

    final label = find.text('Start Date');
    // One line: as tall as "Agency", which fits in 100 px. The old fixed
    // 100 px column wrapped "Start Date" onto two.
    expect(
      tester.getSize(label).height,
      tester.getSize(find.text('Agency')).height,
    );
    final column = detailValueLeft(tester, 'Start Date');
    expect(column, tester.getTopRight(label).dx + 16);
    expect(detailValueLeft(tester, 'Agency'), column);
    expect(detailValueLeft(tester, 'Location'), column);
  });
}
