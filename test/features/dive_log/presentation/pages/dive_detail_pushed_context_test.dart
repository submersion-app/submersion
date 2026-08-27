import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Regression coverage for #764: drilling from a browse context (trip, buddy,
/// site) into a dive PUSHES /dives/:id; the page's desktop master-detail
/// redirect must not wipe that stack, or the browse context and back button
/// are lost.
void main() {
  const desktop = Size(1200, 800);

  Future<GoRouter> pumpWithRouter(
    WidgetTester tester, {
    required String initialLocation,
    required Size size,
    required List<String> locations,
  }) async {
    final dive = createTestDiveWithBottomTime(id: 'b');
    final overrides = await getBaseOverrides();

    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/trip',
          builder: (context, state) =>
              const Scaffold(body: Center(child: Text('TRIP PAGE'))),
        ),
        GoRoute(
          path: '/dives',
          builder: (context, state) {
            locations.add(state.uri.toString());
            return const Scaffold(body: Center(child: Text('DIVE LIST')));
          },
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (context, state) {
            locations.add(state.uri.toString());
            return DiveDetailPage(
              diveId: state.pathParameters['id']!,
              embedded: false,
            );
          },
        ),
      ],
    );

    final originalOnError = FlutterError.onError;
    FlutterError.onError = (d) {
      if (d.toString().contains('overflowed')) return;
      originalOnError?.call(d);
    };
    // Restore via tearDown so a throw from pumpWidget/pump below cannot leak
    // the override into subsequent tests.
    addTearDown(() => FlutterError.onError = originalOnError);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...overrides,
          diveProvider(dive.id).overrideWith((ref) async => dive),
          diveDataSourcesProvider(
            dive.id,
          ).overrideWith((ref) async => <DiveDataSource>[]),
          orderedDiveIdsProvider.overrideWith((ref) async => ['a', 'b', 'c']),
        ],
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return router;
  }

  testWidgets('pushed dive detail on desktop stays on the stack (#764)', (
    tester,
  ) async {
    final locations = <String>[];
    final router = await pumpWithRouter(
      tester,
      initialLocation: '/trip',
      size: desktop,
      locations: locations,
    );

    // push() completes only when the pushed route is popped; hold the future
    // and await it after the pop so it is never left dangling.
    final pushed = router.push('/dives/b');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      locations.last,
      '/dives/b',
      reason:
          'a pushed detail page must not self-redirect to the '
          'master-detail list and destroy the browse context',
    );
    expect(router.canPop(), isTrue);

    router.pop();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await pushed;
    expect(find.text('TRIP PAGE'), findsOneWidget);
  });

  testWidgets('root-level dive detail on desktop still redirects to '
      'master-detail', (tester) async {
    final locations = <String>[];
    await pumpWithRouter(
      tester,
      initialLocation: '/dives/b',
      size: desktop,
      locations: locations,
    );

    expect(
      locations.last,
      '/dives?selected=b',
      reason:
          'deep-linked standalone detail (nothing to pop) keeps the '
          'desktop master-detail redirect',
    );
  });
}
