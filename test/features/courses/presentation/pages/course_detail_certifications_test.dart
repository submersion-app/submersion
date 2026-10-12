import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/certifications/domain/entities/certification.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/domain/entities/course_progress.dart';
import 'package:submersion/features/courses/presentation/pages/course_detail_page.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/courses/presentation/providers/course_requirement_providers.dart';

import '../../../../helpers/test_app.dart';
import '../../../../helpers/test_database.dart';

/// The course detail lists every certification the course earned (#2515).
void main() {
  final now = DateTime(2026, 9, 1);
  final course = Course(
    id: 'andp',
    diverId: 'd',
    name: 'TDI AN/DP',
    agency: 'tdi',
    startDate: now,
    createdAt: now,
    updatedAt: now,
  );
  Certification cert(String id, String name, String card) => Certification(
    id: id,
    name: name,
    agency: 'tdi',
    cardNumber: card,
    courseId: 'andp',
    createdAt: now,
    updatedAt: now,
  );

  setUp(setUpTestDatabase);
  tearDown(tearDownTestDatabase);

  Future<void> pump(
    WidgetTester tester,
    List<Certification> certs, {
    Object? error,
  }) async {
    tester.view.physicalSize = const Size(900, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/courses/andp',
      routes: [
        GoRoute(
          path: '/courses/:id',
          builder: (_, s) =>
              CourseDetailPage(courseId: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/certifications/:id',
          builder: (_, s) =>
              Scaffold(body: Text('CERT ${s.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: [
          courseByIdProvider('andp').overrideWith((ref) async => course),
          courseDivesProvider('andp').overrideWith((ref) async => const []),
          courseProgressProvider('andp').overrideWith(
            (ref) async =>
                const CourseProgress(courseId: 'andp', requirements: []),
          ),
          suggestedDivesProvider('andp').overrideWith((ref) async => const []),
          certificationsForCourseProvider(
            'andp',
          ).overrideWith((ref) async => error == null ? certs : throw error),
        ],
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('lists each earned certification with its card number', (
    tester,
  ) async {
    await pump(tester, [
      cert('k-an', 'Advanced Nitrox', 'TDI-48211'),
      cert('k-dp', 'Decompression Procedures', 'TDI-48212'),
    ]);

    expect(find.text('Earned Certifications'), findsOneWidget);
    expect(find.text('Advanced Nitrox'), findsOneWidget);
    expect(find.text('Decompression Procedures'), findsOneWidget);
    expect(find.textContaining('TDI-48212'), findsOneWidget);

    await tester.tap(find.text('Decompression Procedures'));
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('CERT k-dp'), findsOneWidget);
  });

  testWidgets('a course with no certifications shows no section', (
    tester,
  ) async {
    await pump(tester, const []);
    expect(find.text('Earned Certifications'), findsNothing);
  });

  testWidgets('a failed load says so instead of hiding the section', (
    tester,
  ) async {
    await pump(tester, const [], error: StateError('db closed'));
    expect(find.text('Earned Certifications'), findsOneWidget);
    expect(find.text('Error loading certification'), findsOneWidget);
  });
}
