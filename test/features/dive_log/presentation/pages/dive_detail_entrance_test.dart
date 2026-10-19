import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/safety/presentation/providers/incident_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #3538: on a phone the sections below the header used to wait for
/// the slide into Dive Details before they were built, so the page filled in
/// late. They now build with the header, the way they do in the desktop
/// pane, and their data starts loading as the page slides in.
void main() {
  const phone = Size(390, 844);
  const notes = 'Drifted along the wall past two turtles.';

  Future<GoRouter> pumpRouter(
    WidgetTester tester, {
    String initialLocation = '/dives',
    List<Override> extraOverrides = const [],
  }) async {
    tester.view.physicalSize = phone;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final dive = createTestDiveWithBottomTime(
      id: 'b',
      diveNumber: 7,
    ).copyWith(notes: notes);
    final overrides = await getBaseOverrides();
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/dives',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('DIVE LIST'))),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) =>
                  DiveDetailPage(diveId: state.pathParameters['id']!),
            ),
          ],
        ),
      ],
    );

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.toString().contains('overflowed')) return;
      originalOnError?.call(d);
    };
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          ...extraOverrides,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
          orderedDiveIdsProvider.overrideWith((ref) async => ['a', 'b', 'c']),
        ],
        child: MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));
    return router;
  }

  testWidgets('the sections slide in with the header', (tester) async {
    final router = await pumpRouter(tester);
    // Load the dive once so the push below finds it ready, the way a tap
    // from the list does when the dive was opened before.
    final first = router.push('/dives/b');
    await tester.pumpAndSettle();
    router.pop();
    await tester.pumpAndSettle();
    await first;

    final pushed = router.push('/dives/b');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('#7'), findsOneWidget, reason: 'header card is up');
    expect(
      ModalRoute.of(tester.element(find.text('#7')))!.animation!.status,
      AnimationStatus.forward,
      reason: 'the page is still sliding in',
    );
    expect(
      find.text(notes),
      findsOneWidget,
      reason: 'sections are up while the page is still sliding in',
    );

    await tester.pumpAndSettle();
    expect(find.text('#7'), findsOneWidget);
    expect(find.text(notes), findsOneWidget);

    router.pop();
    await tester.pumpAndSettle();
    await pushed;
  });

  testWidgets('the sections start loading their data during the slide', (
    tester,
  ) async {
    final started = <String>[];
    final router = await pumpRouter(
      tester,
      extraOverrides: [
        surfaceIntervalProvider('b').overrideWith((ref) async {
          started.add('surface interval');
          return null;
        }),
        // Read by a section widget of its own, not by the page.
        incidentsForDiveProvider('b').overrideWith((ref) async {
          started.add('incidents');
          return const [];
        }),
      ],
    );

    final pushed = router.push('/dives/b');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text(notes), findsOneWidget);
    expect(
      started,
      unorderedEquals(['surface interval', 'incidents']),
      reason: 'loading started while the page was still sliding in',
    );

    await tester.pumpAndSettle();
    expect(find.text(notes), findsOneWidget);
    expect(started, hasLength(2), reason: 'each provider loaded once');

    router.pop();
    await tester.pumpAndSettle();
    await pushed;
  });

  testWidgets('a dive opened directly shows every section at once', (
    tester,
  ) async {
    await pumpRouter(tester, initialLocation: '/dives/b');
    await tester.pump();

    expect(find.text('#7'), findsOneWidget);
    expect(find.text(notes), findsOneWidget);
  });
}
