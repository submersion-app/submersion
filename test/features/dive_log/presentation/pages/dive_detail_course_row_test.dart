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
    agency: CertificationAgency.padi,
    startDate: DateTime(2023, 1, 1),
    createdAt: DateTime(2023, 1, 1),
    updatedAt: DateTime(2023, 1, 1),
  );

  Dive diveWith({String? courseId}) => Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2023, 1, 1),
    courseId: courseId,
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
          builder: (context, state) =>
              const Scaffold(body: Text('COURSE_STUB_PAGE')),
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
          courseForDiveProvider(
            dive.id,
          ).overrideWith((ref) async => dive.courseId == null ? null : course),
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

    expect(find.text('Training Course'), findsOneWidget);
    expect(find.text('Advanced Open Water'), findsWidgets);
  });

  testWidgets('Details card omits the course row when none is linked', (
    tester,
  ) async {
    await pumpDetail(tester, diveWith());

    expect(find.text('Training Course'), findsNothing);
  });

  testWidgets('tapping the course row opens the course', (tester) async {
    await pumpDetail(tester, diveWith(courseId: course.id));

    // Drive a REAL pointer rather than invoking InkWell.onTap directly: the
    // row sits inside a Card full of stacked decorated boxes, and only a real
    // tap proves it is not a hit-test dead zone.
    await tester.tap(find.text('Training Course'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('COURSE_STUB_PAGE'), findsOneWidget);
  });
}
