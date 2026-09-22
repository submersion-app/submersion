import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/planned_dive_banner.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late DiveRepository repository;

  setUp(() async {
    await setUpTestDatabase();
    repository = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> pumpDetail(
    WidgetTester tester, {
    required Dive dive,
    bool embedded = false,
  }) async {
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (context, state) {
            final page = DiveDetailPage(diveId: dive.id, embedded: embedded);
            return embedded ? Scaffold(body: page) : page;
          },
        ),
      ],
    );
    final originalOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.toString().contains('overflowed')) return;
      originalOnError?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveRepositoryProvider.overrideWithValue(repository),
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a planned dive shows the banner and the menu action', (
    tester,
  ) async {
    final dive = createTestDiveWithBottomTime(
      diveNumber: null,
    ).copyWith(isPlanned: true);
    await pumpDetail(tester, dive: dive);

    expect(find.byType(PlannedDiveBanner), findsOneWidget);
    expect(find.text('Planned dive'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Mark as logged'), findsWidgets);
  });

  testWidgets('a logged dive shows neither the banner nor the action', (
    tester,
  ) async {
    await pumpDetail(tester, dive: createTestDiveWithBottomTime());

    expect(find.byType(PlannedDiveBanner), findsNothing);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Mark as logged'), findsNothing);
  });

  testWidgets('Mark as logged promotes the dive', (tester) async {
    final planned = await repository.createPlannedDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1, 9)),
    );
    await pumpDetail(tester, dive: planned);

    // The banner's button is the quickest path; the menu item shares it.
    await tester.tap(find.widgetWithText(TextButton, 'Mark as logged'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final saved = await repository.getDiveById(planned.id);
    expect(saved?.isPlanned, isFalse);
    expect(saved?.diveNumber, 1);
    expect(find.text('Marked as logged'), findsOneWidget);
  });

  testWidgets('a second Mark as logged reports instead of throwing', (
    tester,
  ) async {
    final planned = await repository.createPlannedDive(
      Dive(id: '', dateTime: DateTime(2026, 6, 1, 9)),
    );
    // The override keeps serving the planned dive, so the banner stays up
    // after the promotion, exactly as it does for the moment between a
    // double tap and the refresh.
    await pumpDetail(tester, dive: planned);
    final button = find.widgetWithText(TextButton, 'Mark as logged');

    await tester.tap(button);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(button);
    await tester.pump();
    // The messenger queues: the failure shows once "Marked as logged" has
    // run its course.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text("Couldn't mark the dive as logged."), findsOneWidget);
    expect((await repository.getDiveById(planned.id))?.diveNumber, 1);
  });

  testWidgets('the embedded layout shows the banner too', (tester) async {
    final dive = createTestDiveWithBottomTime(
      diveNumber: null,
    ).copyWith(isPlanned: true);
    await pumpDetail(tester, dive: dive, embedded: true);
    expect(find.byType(PlannedDiveBanner), findsOneWidget);
  });
}
