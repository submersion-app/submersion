import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/list_view_mode.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_dive_profile_preview.dart';
import 'package:submersion/features/dashboard/presentation/widgets/recent_dives_card.dart';
import 'package:submersion/features/dive_log/presentation/widgets/dive_list_item.dart';
import 'package:submersion/shared/widgets/master_detail/master_detail_scaffold.dart';
import 'package:submersion/features/dive_log/presentation/pages/dive_list_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/widgets/compact_dive_list_tile.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

GoRouter _cardRouter() => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const Scaffold(body: RecentDivesCard()),
    ),
    GoRoute(path: '/dives', builder: (context, state) => const Scaffold()),
    GoRoute(path: '/dives/:id', builder: (context, state) => const Scaffold()),
    GoRoute(path: '/dives/new', builder: (context, state) => const Scaffold()),
  ],
);

void main() {
  group('RecentDivesCard bottomTime coverage', () {
    testWidgets('renders dive card with runtime/bottomTime fallback', (
      tester,
    ) async {
      final dives = [
        createTestDiveWithBottomTime(
          id: 'recent-1',
          diveNumber: 1,
          bottomTime: const Duration(minutes: 45),
          runtime: const Duration(minutes: 50),
          maxDepth: 25.0,
          waterTemp: 22.0,
        ),
      ];
      final overrides = await getBaseOverrides();

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                const Scaffold(body: RecentDivesCard()),
          ),
          GoRoute(
            path: '/dives',
            builder: (context, state) => const Scaffold(),
          ),
          GoRoute(
            path: '/dives/:id',
            builder: (context, state) => const Scaffold(),
          ),
          GoRoute(
            path: '/dives/new',
            builder: (context, state) => const Scaffold(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            divesProvider.overrideWith((ref) async => dives),
          ].cast(),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(RecentDivesCard), findsOneWidget);
    });
  });

  group('RecentDivesCard follows the dive list view mode (#506)', () {
    Future<void> pumpWithViewMode(
      WidgetTester tester,
      ListViewMode mode,
    ) async {
      final dives = [
        createTestDiveWithBottomTime(
          id: 'recent-1',
          diveNumber: 1,
          bottomTime: const Duration(minutes: 45),
          runtime: const Duration(minutes: 50),
          maxDepth: 25.0,
          waterTemp: 22.0,
        ),
      ];
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            recentDivesProvider.overrideWith((ref) async => dives),
            diveListViewModeProvider.overrideWith((ref) => mode),
          ].cast(),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: _cardRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('renders the compact tile when view mode is compact', (
      tester,
    ) async {
      await pumpWithViewMode(tester, ListViewMode.compact);

      expect(find.byType(CompactDiveListTile), findsOneWidget);
      expect(find.byType(DiveListTile), findsNothing);
    });

    testWidgets('renders the detailed tile when view mode is detailed', (
      tester,
    ) async {
      await pumpWithViewMode(tester, ListViewMode.detailed);

      expect(find.byType(DiveListTile), findsOneWidget);
      expect(find.byType(CompactDiveListTile), findsNothing);
    });
  });

  // On the Dives page the list is the fixed-width master pane of a split
  // view, so a dive card is kMasterPaneWidth across. The dashboard has no
  // split view, so the same shared DiveListItem used to be stretched by an
  // Expanded to two thirds of the window, and the identical card rendered at
  // two very different widths depending on which screen you were looking at.
  group('RecentDivesCard width', () {
    Future<void> pumpAtWidth(WidgetTester tester, double width) async {
      final dives = [
        createTestDiveWithBottomTime(
          id: 'recent-1',
          diveNumber: 1,
          bottomTime: const Duration(minutes: 45),
          runtime: const Duration(minutes: 50),
          maxDepth: 25.0,
          waterTemp: 22.0,
        ),
      ];
      final overrides = await getBaseOverrides();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ...overrides,
            recentDivesProvider.overrideWith((ref) async => dives),
            // Keep the preview off the database; the split itself is what
            // this group is about.
            latestDiveProfileProvider.overrideWith((ref) async => null),
          ].cast(),
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => Scaffold(
                    body: SizedBox(
                      width: width,
                      child: const RecentDivesCard(),
                    ),
                  ),
                ),
                GoRoute(
                  path: '/dives',
                  builder: (context, state) => const Scaffold(),
                ),
                GoRoute(
                  path: '/dives/:id',
                  builder: (context, state) => const Scaffold(),
                ),
                GoRoute(
                  path: '/dives/new',
                  builder: (context, state) => const Scaffold(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('pins dive cards to the list pane width when wide', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(2400, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpAtWidth(tester, 1600);

      expect(find.byType(RecentDiveProfilePreview), findsOneWidget);
      expect(
        tester.getSize(find.byType(DiveListItem).first).width,
        kMasterPaneWidth,
        reason: 'a recent dive card must match its width on the Dives page',
      );
    });

    testWidgets('stays a single full-width column when narrow', (tester) async {
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await pumpAtWidth(tester, 700);

      expect(find.byType(RecentDiveProfilePreview), findsNothing);
      expect(tester.getSize(find.byType(DiveListItem).first).width, 700);
    });
  });
}
