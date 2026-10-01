import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/pages/buddy_detail_page.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';
import '../../helpers/fake_buddy_list_notifier.dart';

/// Silences the RenderFlex overflow this page produces at phone widths while
/// still surfacing every other framework error.
///
/// `FlutterError.onError` is process-global and `testWidgets` installs its own
/// reporter on it, so the previous handler is captured and restored rather than
/// assuming `FlutterError.presentError`. The restore is registered with
/// `addTearDown` so it runs even when the test fails before reaching the end,
/// which would otherwise leak a swallowing handler into later tests.
void _ignoreOverflowErrors() {
  final previousOnError = FlutterError.onError;
  addTearDown(() => FlutterError.onError = previousOnError);
  FlutterError.onError = (details) {
    if (details.exception.toString().contains('overflowed')) return;
    previousOnError?.call(details);
  };
}

/// Silences only the overflows raised by a widget in [sourceFile], so an
/// overflow anywhere else on the page still fails the test.
///
/// Overflow reports name the error-causing widget's source location, which
/// is how the one known offender is told apart. The previous handler is
/// restored with `addTearDown`, as in [_ignoreOverflowErrors].
void _ignoreOverflowErrorsFrom(String sourceFile) {
  final previousOnError = FlutterError.onError;
  addTearDown(() => FlutterError.onError = previousOnError);
  FlutterError.onError = (details) {
    final report = details.toString();
    if (report.contains('overflowed') && report.contains(sourceFile)) return;
    previousOnError?.call(details);
  };
}

void main() {
  group('BuddyDetailPage desktop redirect', () {
    final buddy = Buddy(
      id: 'buddy-1',
      name: 'Jane Doe',
      notes: '',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    testWidgets(
      'redirects to master-detail on desktop when not in table mode',
      (tester) async {
        tester.view.devicePixelRatio = 1.0;
        tester.view.physicalSize = const Size(1200, 800);
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final overrides = await getBaseOverrides();

        final router = GoRouter(
          initialLocation: '/buddies/buddy-1',
          routes: [
            GoRoute(
              path: '/buddies',
              builder: (context, state) =>
                  const Scaffold(body: Text('BUDDY_LIST_PAGE')),
            ),
            GoRoute(
              path: '/buddies/:id',
              builder: (context, state) =>
                  BuddyDetailPage(buddyId: state.pathParameters['id']!),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              ...overrides,
              buddyListViewModeProvider.overrideWith(
                (ref) => ListViewMode.detailed,
              ),
              buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
              buddyStatsProvider(
                buddy.id,
              ).overrideWith((ref) async => const BuddyStats(totalDives: 0)),
              diveIdsForBuddyProvider(
                buddy.id,
              ).overrideWith((ref) async => <String>[]),
              divesForBuddyProvider(buddy.id).overrideWith((ref) async => []),
            ].cast(),
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(find.text('BUDDY_LIST_PAGE'), findsOneWidget);
      },
    );

    testWidgets('does not redirect on desktop in table mode', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await getBaseOverrides();

      final router = GoRouter(
        initialLocation: '/buddies/buddy-1',
        routes: [
          GoRoute(
            path: '/buddies',
            builder: (context, state) =>
                const Scaffold(body: Text('BUDDY_LIST_PAGE')),
          ),
          GoRoute(
            path: '/buddies/:id',
            builder: (context, state) =>
                BuddyDetailPage(buddyId: state.pathParameters['id']!),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            buddyListViewModeProvider.overrideWith((ref) => ListViewMode.table),
            buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
            buddyStatsProvider(
              buddy.id,
            ).overrideWith((ref) async => const BuddyStats(totalDives: 0)),
            diveIdsForBuddyProvider(
              buddy.id,
            ).overrideWith((ref) async => <String>[]),
            divesForBuddyProvider(buddy.id).overrideWith((ref) async => []),
          ].cast(),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('BUDDY_LIST_PAGE'), findsNothing);
    });

    testWidgets('Open in Connections pushes the ego deep link', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1200, 800);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final overrides = await getBaseOverrides();

      final router = GoRouter(
        initialLocation: '/buddies/buddy-1',
        routes: [
          GoRoute(
            path: '/buddies',
            builder: (context, state) =>
                const Scaffold(body: Text('BUDDY_LIST_PAGE')),
          ),
          GoRoute(
            path: '/buddies/:id',
            builder: (context, state) =>
                BuddyDetailPage(buddyId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: '/insights/connections',
            builder: (context, state) =>
                Scaffold(body: Text('CONNECTIONS ${state.uri.query}')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            buddyListViewModeProvider.overrideWith((ref) => ListViewMode.table),
            buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
            buddyStatsProvider(
              buddy.id,
            ).overrideWith((ref) async => const BuddyStats(totalDives: 0)),
            diveIdsForBuddyProvider(
              buddy.id,
            ).overrideWith((ref) async => <String>[]),
            divesForBuddyProvider(buddy.id).overrideWith((ref) async => []),
          ].cast(),
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open in Connections'));
      await tester.pumpAndSettle();
      expect(
        find.text('CONNECTIONS mode=around&focus=buddy:buddy-1'),
        findsOneWidget,
      );
    });
  });

  group('BuddyDetailPage bottomTime coverage', () {
    testWidgets('displays dive bottomTime in buddy dive history', (
      tester,
    ) async {
      final buddy = Buddy(
        id: 'buddy-1',
        name: 'Jane Doe',
        notes: '',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final dives = [
        createTestDiveWithBottomTime(
          id: 'buddy-dive-1',
          diveNumber: 1,
          bottomTime: const Duration(minutes: 45),
          maxDepth: 25.0,
        ),
      ];

      final overrides = await getBaseOverrides();

      // Use mobile size to avoid master-detail layout
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Installed before the first frame: an overflow thrown during
      // pumpWidget would otherwise escape the handler.
      _ignoreOverflowErrors();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
            buddyStatsProvider(
              buddy.id,
            ).overrideWith((ref) async => const BuddyStats(totalDives: 1)),
            diveIdsForBuddyProvider(
              buddy.id,
            ).overrideWith((ref) async => ['buddy-dive-1']),
            divesForBuddyProvider(buddy.id).overrideWith((ref) async => dives),
          ].cast(),
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BuddyDetailPage(buddyId: buddy.id, embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should show bottomTime formatted as minutes in dive history
      expect(find.text('45min'), findsOneWidget);
    });
  });

  // Issue #982: the shared-dives list formatted dates with DateFormat.MMMd(),
  // so a list spanning several years rendered ambiguous labels like "Mar 28".
  group('BuddyDetailPage shared dive dates (#982)', () {
    testWidgets('renders the year alongside the dive date', (tester) async {
      final previousLocale = Intl.defaultLocale;
      Intl.defaultLocale = 'en';
      addTearDown(() => Intl.defaultLocale = previousLocale);

      final buddy = Buddy(
        id: 'buddy-1',
        name: 'Jane Doe',
        notes: '',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      // createTestDiveWithBottomTime dives are dated 2026-03-28.
      final dives = [
        createTestDiveWithBottomTime(id: 'buddy-dive-1', diveNumber: 1),
      ];

      final overrides = await getBaseOverrides();

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Installed before the first frame: an overflow thrown during
      // pumpWidget would otherwise escape the handler.
      _ignoreOverflowErrors();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
            buddyStatsProvider(
              buddy.id,
            ).overrideWith((ref) async => const BuddyStats(totalDives: 1)),
            diveIdsForBuddyProvider(
              buddy.id,
            ).overrideWith((ref) async => ['buddy-dive-1']),
            divesForBuddyProvider(buddy.id).overrideWith((ref) async => dives),
          ].cast(),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BuddyDetailPage(buddyId: buddy.id, embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(DateFormat.yMMMd().format(dives.first.dateTime)),
        findsOneWidget,
      );
      expect(
        find.text(DateFormat.MMMd().format(dives.first.dateTime)),
        findsNothing,
      );
    });
  });

  // The shared-dives card appended a literal "m" to the stored meter value,
  // so an imperial diver saw a metric number labelled as meters.
  group('BuddyDetailPage shared dive depth units', () {
    testWidgets('shows max depth in the active diver\'s depth unit', (
      tester,
    ) async {
      final buddy = Buddy(
        id: 'buddy-1',
        name: 'Jane Doe',
        notes: '',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final dives = [
        createTestDiveWithBottomTime(
          id: 'buddy-dive-1',
          diveNumber: 1,
          maxDepth: 25.0,
        ),
      ];

      final overrides = await getBaseOverrides(
        settingsNotifier: MockSettingsNotifier(
          const AppSettings(depthUnit: DepthUnit.feet),
        ),
      );

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Installed before the first frame: an overflow thrown during
      // pumpWidget would otherwise escape the handler.
      _ignoreOverflowErrors();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
            buddyStatsProvider(
              buddy.id,
            ).overrideWith((ref) async => const BuddyStats(totalDives: 1)),
            diveIdsForBuddyProvider(
              buddy.id,
            ).overrideWith((ref) async => ['buddy-dive-1']),
            divesForBuddyProvider(buddy.id).overrideWith((ref) async => dives),
          ].cast(),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BuddyDetailPage(buddyId: buddy.id, embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 25 m x 3.28084 = 82.021 ft.
      expect(find.text('82.0ft'), findsOneWidget);
      expect(find.text('25.0m'), findsNothing);
    });
  });

  group('BuddyDetailPage favorite star (issue #1336)', () {
    final buddy = Buddy(
      id: 'buddy-1',
      name: 'Jane Doe',
      notes: '',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    Future<List<Override>> pageOverrides() async => [
      ...await getBaseOverrides(),
      buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
      buddyStatsProvider(
        buddy.id,
      ).overrideWith((ref) async => const BuddyStats(totalDives: 0)),
      diveIdsForBuddyProvider(buddy.id).overrideWith((ref) async => []),
      divesForBuddyProvider(buddy.id).overrideWith((ref) async => []),
    ];

    testWidgets('shows a star in the embedded header, toggling it', (
      tester,
    ) async {
      final notifier = FakeBuddyListNotifier();
      _ignoreOverflowErrors();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await pageOverrides(),
            buddyListNotifierProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BuddyDetailPage(buddyId: buddy.id, embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_border), findsOneWidget);

      await tester.tap(find.byIcon(Icons.star_border));
      await tester.pumpAndSettle();

      expect(notifier.toggledFavoriteIds, ['buddy-1']);
    });

    testWidgets('shows a star in the app bar of the standalone page', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final notifier = FakeBuddyListNotifier();
      _ignoreOverflowErrors();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await pageOverrides(),
            buddyListNotifierProvider.overrideWith((ref) => notifier),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BuddyDetailPage(buddyId: buddy.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star_border), findsOneWidget);

      await tester.tap(find.byIcon(Icons.star_border));
      await tester.pumpAndSettle();

      expect(notifier.toggledFavoriteIds, ['buddy-1']);
    });

    testWidgets('shows a filled star for an already-favorite buddy', (
      tester,
    ) async {
      final favoriteBuddy = buddy.copyWith(isFavorite: true);
      _ignoreOverflowErrors();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...await getBaseOverrides(),
            buddyByIdProvider(
              buddy.id,
            ).overrideWith((ref) async => favoriteBuddy),
            buddyStatsProvider(
              buddy.id,
            ).overrideWith((ref) async => const BuddyStats(totalDives: 0)),
            diveIdsForBuddyProvider(buddy.id).overrideWith((ref) async => []),
            divesForBuddyProvider(buddy.id).overrideWith((ref) async => []),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BuddyDetailPage(buddyId: buddy.id, embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.star), findsOneWidget);
      expect(find.byIcon(Icons.star_border), findsNothing);
    });
  });

  group('BuddyDetailPage dive statistics', () {
    testWidgets('shows the first and last shared dive dates', (tester) async {
      final buddy = Buddy(
        id: 'buddy-1',
        name: 'Jane Doe',
        notes: '',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
            buddyStatsProvider(buddy.id).overrideWith(
              (ref) async => BuddyStats(
                totalDives: 12,
                firstDive: DateTime(2023, 3, 4),
                lastDive: DateTime(2026, 8, 20),
              ),
            ),
            diveIdsForBuddyProvider(buddy.id).overrideWith((ref) async => []),
            divesForBuddyProvider(buddy.id).overrideWith((ref) async => []),
          ].cast(),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BuddyDetailPage(buddyId: buddy.id, embedded: true),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Each stat reads as one "label: value" row; the dates follow the
      // diver's date format, so only the label is pinned here.
      Finder row(String prefix) => find.byWidgetPredicate(
        (w) => w is Semantics && (w.properties.label ?? '').startsWith(prefix),
      );
      expect(row('Dives Together: 12'), findsOneWidget);
      expect(row('First Dive: '), findsOneWidget);
      expect(row('Last Dive: '), findsOneWidget);
    });
  });

  group('BuddyDetailPage stat rows on a phone-width screen', () {
    // A long favourite-site name took the row's width and squeezed the
    // label onto several lines or overflowed the row, as the certification
    // detail rows did (issue #2695).
    const longSite = 'Blue Corner Wall and Drift, Palau Southern Reefs';

    testWidgets('a long site name wraps without squeezing its label', (
      tester,
    ) async {
      final buddy = Buddy(
        id: 'buddy-1',
        name: 'Jane Doe',
        notes: '',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(375, 812);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // The Shared Dives header still overflows under the wide test font;
      // only that is silenced, so an overflowing stat row fails the test.
      _ignoreOverflowErrorsFrom('buddy_shared_dives_section.dart');
      final overrides = await getBaseOverrides();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            buddyByIdProvider(buddy.id).overrideWith((ref) async => buddy),
            buddyStatsProvider(buddy.id).overrideWith(
              (ref) async =>
                  const BuddyStats(totalDives: 3, favoriteSite: longSite),
            ),
            diveIdsForBuddyProvider(buddy.id).overrideWith((ref) async => []),
            divesForBuddyProvider(buddy.id).overrideWith((ref) async => []),
          ].cast(),
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BuddyDetailPage(buddyId: buddy.id),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // A single-line label in the same card is the unit of height.
      final oneLine = tester.getSize(find.text('Dives Together')).height;
      final label = find.text('Favorite Site');
      final value = find.text(longSite);

      // The test font draws "Favorite Site" about twice as wide as a real
      // one, beyond the 40% share a label keeps beside a long value, so it
      // wraps once here (one line in the app). Before the fix it was squeezed
      // to one letter per line, twelve lines tall.
      expect(tester.getSize(label).height, lessThanOrEqualTo(oneLine * 2));
      expect(tester.getSize(value).height, greaterThan(oneLine));
      // The wrapped value keeps clear of the label rather than crowding it.
      expect(
        tester.getTopLeft(value).dx,
        greaterThan(tester.getTopRight(label).dx),
      );
      // And it stays inside its card instead of running off the edge.
      final card = find.ancestor(of: value, matching: find.byType(Card));
      expect(
        tester.getTopRight(value).dx,
        lessThanOrEqualTo(tester.getTopRight(card).dx),
      );
    });
  });
}
