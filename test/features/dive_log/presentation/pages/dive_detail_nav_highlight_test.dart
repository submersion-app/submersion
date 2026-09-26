import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/highlight_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Stepping to an adjacent dive with the previous/next controls must move the
/// list highlight along with it. The list highlights both the `?selected=`
/// dive and [highlightedDiveIdProvider], so a highlight left on the dive the
/// user first clicked kept that row lit while the pane showed another.
void main() {
  const desktop = Size(1200, 800);
  const phone = Size(400, 800);

  Future<void> pumpDetail(
    WidgetTester tester, {
    required String initialLocation,
    required Size size,
    required bool embedded,
    required List<String> locations,
  }) async {
    final overrides = await getBaseOverrides();
    final dives = {
      for (final id in ['a', 'b', 'c'])
        id: createTestDiveWithBottomTime(id: id),
    };

    Widget detail(String id) =>
        DiveDetailPage(key: ValueKey(id), diveId: id, embedded: embedded);

    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/dives',
          builder: (context, state) {
            locations.add(state.uri.toString());
            final selected = state.uri.queryParameters['selected'];
            return Scaffold(
              body: selected == null
                  ? const Text('DIVE LIST')
                  : detail(selected),
            );
          },
        ),
        GoRoute(
          path: '/dives/:id',
          builder: (context, state) {
            locations.add(state.uri.toString());
            return detail(state.pathParameters['id']!);
          },
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
          for (final dive in dives.values) ...[
            diveProvider(dive.id).overrideWith((ref) async => dive),
            diveDataSourcesProvider(
              dive.id,
            ).overrideWith((ref) async => <DiveDataSource>[]),
          ],
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
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(DiveDetailPage)));

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.byIcon(Icons.chevron_right).first);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('embedded next moves the list highlight to the new dive', (
    tester,
  ) async {
    final locations = <String>[];
    await pumpDetail(
      tester,
      initialLocation: '/dives?selected=b',
      size: desktop,
      embedded: true,
      locations: locations,
    );
    // A list tap highlights the row it opens.
    containerOf(tester).read(highlightedDiveIdProvider.notifier).state = 'b';
    await tester.pump();

    await tapNext(tester);

    expect(locations.last, '/dives?selected=c');
    expect(
      containerOf(tester).read(highlightedDiveIdProvider),
      'c',
      reason: 'the dive stepped away from must not stay highlighted',
    );
  });

  testWidgets('standalone next moves the list highlight to the new dive', (
    tester,
  ) async {
    final locations = <String>[];
    await pumpDetail(
      tester,
      initialLocation: '/dives/b',
      size: phone,
      embedded: false,
      locations: locations,
    );
    containerOf(tester).read(highlightedDiveIdProvider.notifier).state = 'b';
    await tester.pump();

    await tapNext(tester);

    expect(locations.last, '/dives/c');
    expect(
      containerOf(tester).read(highlightedDiveIdProvider),
      'c',
      reason: 'returning to the list must highlight the dive last viewed',
    );
  });
}
