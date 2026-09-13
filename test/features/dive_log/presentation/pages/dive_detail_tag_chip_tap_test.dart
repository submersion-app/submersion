import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/dive_data_source.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_detail_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// A tag chip on the dive detail page opens the dive list filtered to that
/// tag (#1833).
void main() {
  final nightDive = Tag(
    id: 'tag-night',
    name: 'Night Dive',
    colorHex: '#EF4444',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
  final wreck = Tag(
    id: 'tag-wreck',
    name: 'Wreck',
    colorHex: '#3B82F6',
    createdAt: DateTime(2024),
    updatedAt: DateTime(2024),
  );
  final dive = Dive(
    id: 'dive-1',
    diveNumber: 1,
    dateTime: DateTime(2023, 1, 1),
    tags: [nightDive, wreck],
  );

  /// Pumps the detail page under a router with a stub dive list and returns
  /// the router, so a test can read where a tap took it.
  Future<GoRouter> pumpDetail(
    WidgetTester tester, {
    required bool embedded,
    required Size size,
    DiveFilterState initialFilter = const DiveFilterState(),
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
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
          builder: (context, state) =>
              DiveDetailPage(diveId: dive.id, embedded: embedded),
        ),
        GoRoute(
          path: '/dives',
          builder: (context, state) =>
              const Scaffold(body: Text('DIVES_LIST_PAGE')),
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
          diveFilterProvider.overrideWith((ref) => initialFilter),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    return router;
  }

  Future<void> tapChip(WidgetTester tester, String name) async {
    final chip = find.text(name);
    await tester.scrollUntilVisible(
      chip,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(chip);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  DiveFilterState filterAt(WidgetTester tester) {
    final container = ProviderScope.containerOf(
      tester.element(find.text('DIVES_LIST_PAGE')),
    );
    return container.read(diveFilterProvider);
  }

  testWidgets('tapping a tag chip opens the dive list filtered to that tag', (
    tester,
  ) async {
    final router = await pumpDetail(
      tester,
      embedded: false,
      size: const Size(700, 1000),
    );

    await tapChip(tester, 'Wreck');

    expect(find.text('DIVES_LIST_PAGE'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/dives');
    expect(filterAt(tester).tagIds, ['tag-wreck']);
  });

  testWidgets('the tag filter replaces the filter the diver had before', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      embedded: false,
      size: const Size(700, 1000),
      initialFilter: const DiveFilterState(
        siteId: 'site-1',
        tagIds: ['tag-other'],
        minDepth: 30,
      ),
    );

    await tapChip(tester, 'Night Dive');

    final filter = filterAt(tester);
    expect(filter.tagIds, ['tag-night']);
    expect(filter.siteId, isNull);
    expect(filter.minDepth, isNull);
  });

  testWidgets('a chip in the master-detail pane also opens the tag dives', (
    tester,
  ) async {
    await pumpDetail(tester, embedded: true, size: const Size(1200, 900));

    await tapChip(tester, 'Night Dive');

    expect(find.text('DIVES_LIST_PAGE'), findsOneWidget);
    expect(filterAt(tester).tagIds, ['tag-night']);
  });

  testWidgets('each chip says what tapping it does', (tester) async {
    await pumpDetail(tester, embedded: false, size: const Size(700, 1000));
    await tester.scrollUntilVisible(
      find.text('Wreck'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.byTooltip('Show dives tagged "Wreck"'), findsOneWidget);
    expect(find.byTooltip('Show dives tagged "Night Dive"'), findsOneWidget);
  });
}
