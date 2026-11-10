import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/draft_dive_banner.dart';
import 'package:submersion/features/dive_log/presentation/widgets/planned_dive_banner.dart';
import 'package:submersion/features/planner/presentation/providers/plan_log_links.dart';
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
    String? linkedPlanId,
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
          planForLoggedDiveProvider(
            dive.id,
          ).overrideWith((ref) async => linkedPlanId),
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

  Dive draftDive() => createTestDiveWithBottomTime(diveNumber: null).copyWith(
    isDraft: true,
    entryTime: DateTime(2026, 6, 1, 9),
    exitTime: DateTime(2026, 6, 1, 9, 50),
  );

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a draft shows its banner and the menu offers Mark as complete '
      '(#637)', (tester) async {
    await pumpDetail(tester, dive: draftDive());

    expect(find.byType(DraftDiveBanner), findsOneWidget);
    expect(find.byType(PlannedDiveBanner), findsNothing);
    await openMenu(tester);
    expect(find.text('Mark as complete'), findsWidgets);
    expect(find.text('Mark as logged'), findsNothing);
  });

  testWidgets('a logged dive shows no draft banner or action', (tester) async {
    await pumpDetail(tester, dive: createTestDiveWithBottomTime());

    expect(find.byType(DraftDiveBanner), findsNothing);
    await openMenu(tester);
    expect(find.text('Mark as complete'), findsNothing);
  });

  testWidgets('Mark as complete logs the draft with the next number', (
    tester,
  ) async {
    final draft = await repository.createDive(
      Dive(
        id: '',
        dateTime: DateTime(2026, 6, 1, 9),
        entryTime: DateTime(2026, 6, 1, 9),
        exitTime: DateTime(2026, 6, 1, 9, 50),
        isDraft: true,
      ),
    );
    await pumpDetail(tester, dive: draft);

    await tester.tap(find.widgetWithText(TextButton, 'Mark as complete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final saved = await repository.getDiveById(draft.id);
    expect(saved?.isDraft, isFalse);
    expect(saved?.diveNumber, 1);
    expect(find.text('Marked as complete'), findsOneWidget);
  });

  testWidgets('the embedded layout shows the draft banner too', (tester) async {
    await pumpDetail(tester, dive: draftDive(), embedded: true);
    expect(find.byType(DraftDiveBanner), findsOneWidget);
  });

  testWidgets('a draft exports under Draft dive, not Dive #0', (tester) async {
    await pumpDetail(tester, dive: draftDive());

    await openMenu(tester);
    await tester.tap(find.text('Export').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Draft dive'),
      ),
      findsOneWidget,
    );
    expect(find.textContaining('#0'), findsNothing);
  });
}
