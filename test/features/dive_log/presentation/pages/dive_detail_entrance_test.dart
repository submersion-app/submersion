import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_analysis_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/safety/presentation/providers/incident_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Issue #3489: building every section in the opening frames of the push
/// made the slide into Dive Details stutter on a phone. The header card
/// slides in with the page, the sections' data starts loading during the
/// slide, and the sections themselves follow once the page has all but
/// slid in.
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

  testWidgets('the header slides in; the sections follow the slide', (
    tester,
  ) async {
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
      find.text(notes, skipOffstage: false),
      findsNothing,
      reason: 'sections wait for the slide to finish',
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
        weeklyOtuProvider('b').overrideWith((ref) async {
          started.add('weekly OTU');
          return 0;
        }),
        surfaceIntervalProvider('b').overrideWith((ref) async {
          started.add('surface interval');
          return null;
        }),
        hasGasSwitchesProvider('b').overrideWith((ref) async {
          started.add('gas switches');
          return false;
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

    expect(find.text(notes, skipOffstage: false), findsNothing);
    expect(
      started,
      unorderedEquals([
        'weekly OTU',
        'surface interval',
        'gas switches',
        'incidents',
      ]),
      reason: 'loading started while the page was still sliding in',
    );

    await tester.pumpAndSettle();
    expect(find.text(notes), findsOneWidget);
    expect(started, hasLength(4), reason: 'the sections reuse what loaded');

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
