import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/milestone_providers.dart';
import 'package:submersion/features/dashboard/presentation/providers/media_ribbon_providers.dart';
import 'package:submersion/features/dashboard/presentation/widgets/milestones_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/on_this_day_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/media_ribbon_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/quick_actions_card.dart';
import 'package:submersion/features/dashboard/presentation/widgets/year_in_review_card.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/pages/photo_viewer_page.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/statistics/data/repositories/statistics_repository.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

final _t0 = DateTime(2026, 1, 1);

/// Records where a tap navigated.
class NavSpy extends NavigatorObserver {
  String? location;

  /// Routes pushed imperatively onto the root navigator (go_router's own
  /// route pushes arrive here too, so callers match on route type).
  final List<Route<dynamic>> pushedRoutes = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRoutes.add(route);
  }
}

Future<NavSpy> pumpCard(
  WidgetTester tester,
  Widget card, {
  List<Override> overrides = const [],
}) async {
  final base = await getBaseOverrides();
  final spy = NavSpy();
  Widget stub(String path) => Builder(
    builder: (context) {
      spy.location = path;
      return const Scaffold();
    },
  );
  final router = GoRouter(
    observers: [spy],
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => Scaffold(body: SingleChildScrollView(child: card)),
      ),
      for (final path in const [
        '/dives/new',
        '/planning/dive-planner',
        '/statistics',
        '/gps-log',
        '/settings/diver-profile/emergency-card',
      ])
        GoRoute(path: path, builder: (_, _) => stub(path)),
      GoRoute(
        path: '/dives/:id',
        builder: (_, state) {
          spy.location = '/dives/${state.pathParameters['id']}';
          return const Scaffold();
        },
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [...base, ...overrides].cast(),
      child: MaterialApp.router(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return spy;
}

void main() {
  group('MilestonesCard', () {
    testWidgets('hidden when there is nothing to look forward to', (
      tester,
    ) async {
      await pumpCard(
        tester,
        const MilestonesCard(),
        overrides: [
          milestonesProvider.overrideWith(
            (ref) async => const DashboardMilestones(
              nextMilestone: null,
              divesRemaining: null,
              anniversaries: [],
            ),
          ),
        ],
      );
      expect(find.text('Milestones'), findsNothing);
    });

    testWidgets('renders the next dive milestone and anniversaries', (
      tester,
    ) async {
      await pumpCard(
        tester,
        const MilestonesCard(),
        overrides: [
          milestonesProvider.overrideWith(
            (ref) async => DashboardMilestones(
              nextMilestone: 250,
              divesRemaining: 3,
              anniversaries: [
                CertAnniversary(
                  certName: 'Open Water',
                  years: 10,
                  date: DateTime(2026, 8, 10),
                ),
              ],
            ),
          ),
        ],
      );
      expect(find.text('Milestones'), findsOneWidget);
      expect(find.text('3 dives to #250'), findsOneWidget);
      expect(find.text('Open Water: 10 years in August'), findsOneWidget);
    });
  });

  group('OnThisDayCard', () {
    testWidgets('hidden without prior-year dives', (tester) async {
      await pumpCard(
        tester,
        const OnThisDayCard(),
        overrides: [onThisDayProvider.overrideWith((ref) async => <Dive>[])],
      );
      expect(find.text('On this day'), findsNothing);
    });

    testWidgets('lists prior dives and opens one on tap', (tester) async {
      final spy = await pumpCard(
        tester,
        const OnThisDayCard(),
        overrides: [
          onThisDayProvider.overrideWith(
            (ref) async => [
              Dive(
                id: 'd-2023',
                dateTime: DateTime(2023, 7, 24, 10),
                entryTime: DateTime(2023, 7, 24, 10),
                maxDepth: 31,
                bottomTime: const Duration(minutes: 48),
                site: const DiveSite(id: 's1', name: 'Blue Hole'),
              ),
            ],
          ),
        ],
      );
      expect(find.text('On this day'), findsOneWidget);
      expect(find.text('2023 - Blue Hole'), findsOneWidget);
      expect(find.textContaining('48 min'), findsOneWidget);

      await tester.tap(find.text('2023 - Blue Hole'));
      await tester.pumpAndSettle();
      expect(spy.location, '/dives/d-2023');
    });

    testWidgets('falls back to the dive name when there is no site', (
      tester,
    ) async {
      await pumpCard(
        tester,
        const OnThisDayCard(),
        overrides: [
          onThisDayProvider.overrideWith(
            (ref) async => [
              Dive(
                id: 'd-2022',
                dateTime: DateTime(2022, 7, 24, 10),
                entryTime: DateTime(2022, 7, 24, 10),
                name: 'Shore checkout',
              ),
            ],
          ),
        ],
      );
      expect(find.text('2022 - Shore checkout'), findsOneWidget);
    });
  });

  group('YearInReviewCard', () {
    testWidgets('hidden when there is no year data', (tester) async {
      await pumpCard(
        tester,
        const YearInReviewCard(),
        overrides: [yearInReviewProvider.overrideWith((ref) async => null)],
      );
      expect(find.text('This year'), findsNothing);
    });

    testWidgets('compares against last year', (tester) async {
      await pumpCard(
        tester,
        const YearInReviewCard(),
        overrides: [
          yearInReviewProvider.overrideWith(
            (ref) async => const YearInReview(
              year: 2026,
              current: YearStats(
                diveCount: 34,
                totalSeconds: 147600,
                maxDepth: 48,
              ),
              previous: YearStats(diveCount: 28, totalSeconds: 100800),
            ),
          ),
        ],
      );
      expect(find.text('This year'), findsOneWidget);
      expect(find.text('34 dives (vs 28 last year)'), findsOneWidget);
      expect(find.text('41 hours underwater'), findsOneWidget);
      expect(find.textContaining('Deepest:'), findsOneWidget);
    });

    testWidgets('hours just under 10 render as whole hours, not "10.0"', (
      tester,
    ) async {
      // 9.96h: fails a naive `< 10` test but rounds to 10.0 at one decimal.
      await pumpCard(
        tester,
        const YearInReviewCard(),
        overrides: [
          yearInReviewProvider.overrideWith(
            (ref) async => const YearInReview(
              year: 2026,
              current: YearStats(diveCount: 5, totalSeconds: 35856),
              previous: YearStats(diveCount: 3, totalSeconds: 10800),
            ),
          ),
        ],
      );
      expect(find.text('10 hours underwater'), findsOneWidget);
      expect(find.text('10.0 hours underwater'), findsNothing);
    });

    testWidgets('omits depth and hours rows when the year is empty', (
      tester,
    ) async {
      await pumpCard(
        tester,
        const YearInReviewCard(),
        overrides: [
          yearInReviewProvider.overrideWith(
            (ref) async => const YearInReview(
              year: 2026,
              current: YearStats(diveCount: 0, totalSeconds: 0),
              previous: YearStats(diveCount: 12, totalSeconds: 36000),
            ),
          ),
        ],
      );
      expect(find.text('0 dives (vs 12 last year)'), findsOneWidget);
      expect(find.textContaining('hours underwater'), findsNothing);
      expect(find.textContaining('Deepest:'), findsNothing);
    });
  });

  group('MediaRibbonCard', () {
    testWidgets('hidden without media', (tester) async {
      await pumpCard(
        tester,
        const MediaRibbonCard(),
        overrides: [
          recentMediaProvider.overrideWith((ref) async => <MediaItem>[]),
        ],
      );
      expect(find.text('Recent media'), findsNothing);
    });

    // A video thumbnail is a still frame, so the badge is the only thing
    // distinguishing it from a photo in the ribbon.
    testWidgets('badges videos but not photos', (tester) async {
      MediaItem entry(String id, MediaType type) => MediaItem(
        id: id,
        mediaType: type,
        sourceType: MediaSourceType.platformGallery,
        filePath: '/tmp/$id',
        diveId: 'd1',
        takenAt: _t0,
        createdAt: _t0,
        updatedAt: _t0,
      );

      await pumpCard(
        tester,
        const MediaRibbonCard(),
        overrides: [
          recentMediaProvider.overrideWith(
            (ref) async => [
              entry('v1', MediaType.video),
              entry('p1', MediaType.photo),
              entry('v2', MediaType.video),
            ],
          ),
        ],
      );

      expect(find.byIcon(Icons.play_arrow), findsNWidgets(2));
    });

    testWidgets('renders a tile per item', (tester) async {
      await pumpCard(
        tester,
        const MediaRibbonCard(),
        overrides: [
          recentMediaProvider.overrideWith(
            (ref) async => [
              MediaItem(
                id: 'p1',
                mediaType: MediaType.photo,
                sourceType: MediaSourceType.platformGallery,
                filePath: '/tmp/p1.jpg',
                diveId: 'd1',
                takenAt: _t0,
                createdAt: _t0,
                updatedAt: _t0,
              ),
              MediaItem(
                id: 'p2',
                mediaType: MediaType.photo,
                sourceType: MediaSourceType.platformGallery,
                filePath: '/tmp/p2.jpg',
                diveId: 'd2',
                takenAt: _t0,
                createdAt: _t0,
                updatedAt: _t0,
              ),
            ],
          ),
        ],
      );
      expect(find.text('Recent media'), findsOneWidget);
      expect(find.byType(ClipRRect), findsNWidgets(2));
    });

    testWidgets('tapping a photo opens the photo viewer, not the dive', (
      tester,
    ) async {
      final spy = await pumpCard(
        tester,
        const MediaRibbonCard(),
        overrides: [
          recentMediaProvider.overrideWith(
            (ref) async => [
              MediaItem(
                id: 'p1',
                mediaType: MediaType.photo,
                sourceType: MediaSourceType.platformGallery,
                filePath: '/tmp/p1.jpg',
                diveId: 'd1',
                takenAt: _t0,
                createdAt: _t0,
                updatedAt: _t0,
              ),
            ],
          ),
          // The viewer resolves its own gallery from the dive; an empty list
          // short-circuits its build before it reaches the profile providers,
          // so this stays a navigation test rather than a viewer test.
          mediaForDiveProvider('d1').overrideWith((ref) async => <MediaItem>[]),
          diveProvider('d1').overrideWith((ref) async => null),
        ],
      );

      await tester.tap(find.byType(ClipRRect).first);
      await tester.pumpAndSettle();

      expect(find.byType(PhotoViewerPage), findsOneWidget);
      expect(spy.location, isNull);
    });
  });

  group('QuickActionsCard', () {
    // Tab-level actions still use go(); sub-page actions use push() so the
    // Android system back button can pop them (#647). Either way each case
    // gets its own pump rather than popping back.
    for (final (label, destination) in const [
      ('Plan Dive', '/planning/dive-planner'),
      ('Statistics', '/statistics'),
      ('GPS Logger', '/gps-log'),
      ('Emergency card', '/settings/diver-profile/emergency-card'),
    ]) {
      testWidgets('$label opens $destination', (tester) async {
        final spy = await pumpCard(tester, const QuickActionsCard());
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(spy.location, destination);
      });
    }

    testWidgets('log dive opens the add-dive sheet', (tester) async {
      await pumpCard(tester, const QuickActionsCard());
      await tester.tap(find.text('Log Dive'));
      await tester.pumpAndSettle();
      // The sheet replaces nothing; it presents options over the card.
      expect(find.byType(QuickActionsCard), findsOneWidget);
    });

    testWidgets('log dive manually pushes the new-dive page', (tester) async {
      final spy = await pumpCard(tester, const QuickActionsCard());
      await tester.tap(find.text('Log Dive'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Log Dive Manually'));
      await tester.pumpAndSettle();

      expect(spy.location, '/dives/new');
    });
  });
}
