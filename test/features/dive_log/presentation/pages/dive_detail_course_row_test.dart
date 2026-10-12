import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/courses/domain/entities/course.dart';
import 'package:submersion/features/courses/presentation/providers/course_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_course_rows.dart';
import 'package:submersion/features/signatures/presentation/providers/signature_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// #1219: a dive linked to a training course showed the link only in edit
/// mode. The read-only Details card now carries a Training Course row next to
/// Trip and Dive Center.
void main() {
  final course = Course(
    id: 'course-1',
    diverId: 'diver-1',
    name: 'Advanced Open Water',
    agency: CertificationAgency.padi.name,
    startDate: DateTime(2023, 1, 1),
    createdAt: DateTime(2023, 1, 1),
    updatedAt: DateTime(2023, 1, 1),
  );

  final second = Course(
    id: 'course-2',
    diverId: 'diver-1',
    name: 'Rescue Diver',
    agency: CertificationAgency.padi.name,
    startDate: DateTime(2023, 2, 1),
    createdAt: DateTime(2023, 2, 1),
    updatedAt: DateTime(2023, 2, 1),
  );

  Dive diveWith({String? courseId, List<String>? courseIds}) => Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2023, 1, 1),
    courseIds: courseIds ?? [?courseId],
  );

  Future<void> pumpDetail(WidgetTester tester, Dive dive) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(600, 2400);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final overrides = await getBaseOverrides();

    final router = GoRouter(
      initialLocation: '/test',
      routes: [
        GoRoute(
          path: '/test',
          builder: (context, state) => DiveDetailPage(diveId: dive.id),
        ),
        GoRoute(
          path: '/courses/:id',
          builder: (context, state) => Scaffold(
            body: Text('COURSE_STUB_PAGE ${state.pathParameters['id']}'),
          ),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
          coursesForDiveProvider(dive.id).overrideWith(
            (ref) async => [
              for (final id in dive.courseIds)
                if (id == course.id) course else second,
            ],
          ),
          // The Signatures card also renders once a course is linked; stub its
          // dependencies so the test never reaches a real repository.
          signatureForDiveProvider(dive.id).overrideWith((ref) async => null),
          buddiesForDiveProvider(
            dive.id,
          ).overrideWith((ref) async => <BuddyWithRole>[]),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          // Pinned: an unpinned MaterialApp resolves against the HOST
          // machine's locale list, and this app ships 11 locales, so the
          // English literals below would vanish for a contributor whose
          // primary locale is one of them.
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Details card shows the linked training course', (tester) async {
    await pumpDetail(tester, diveWith(courseId: course.id));

    expect(find.text('Training Courses'), findsOneWidget);
    expect(find.text('Advanced Open Water'), findsWidgets);
  });

  testWidgets('Details card omits the course row when none is linked', (
    tester,
  ) async {
    await pumpDetail(tester, diveWith());

    expect(find.text('Training Courses'), findsNothing);
  });

  testWidgets('tapping the course row opens the course', (tester) async {
    await pumpDetail(tester, diveWith(courseId: course.id));

    // Drive a REAL pointer rather than invoking InkWell.onTap directly: the
    // row sits inside a Card full of stacked decorated boxes, and only a real
    // tap proves it is not a hit-test dead zone.
    await tester.tap(find.text('Training Courses'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('COURSE_STUB_PAGE course-1'), findsOneWidget);
  });

  testWidgets('a dive in two courses shows a row per course (#2515)', (
    tester,
  ) async {
    await pumpDetail(tester, diveWith(courseIds: [course.id, second.id]));

    final rows = find.byType(DiveCourseRows);
    expect(
      find.descendant(of: rows, matching: find.text('Advanced Open Water')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: rows, matching: find.text('Rescue Diver')),
      findsOneWidget,
    );
    // One label for the group, not one per row.
    expect(find.text('Training Courses'), findsOneWidget);

    await tester.tap(
      find.descendant(of: rows, matching: find.text('Rescue Diver')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('COURSE_STUB_PAGE course-2'), findsOneWidget);
  });

  testWidgets('the signature header shows a chip per course (#2515)', (
    tester,
  ) async {
    await pumpDetail(tester, diveWith(courseIds: [course.id, second.id]));

    final chips = find.byType(DiveCourseChips);
    expect(chips, findsOneWidget);
    expect(
      find.descendant(of: chips, matching: find.text('Advanced Open Water')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: chips, matching: find.text('Rescue Diver')),
      findsOneWidget,
    );
  });
}
