import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

/// Records calls instead of touching a real database.
class _RecordingNavTrackRepository extends NavTrackRepository {
  String? linkedRouteId;
  String? linkedDiveId;
  NavTrackLinkMode? linkMode;
  String? unlinkedId;
  String? primaryId;

  @override
  Future<void> link(
    String routeId,
    String diveId, {
    required NavTrackLinkMode linkMode,
  }) async {
    linkedRouteId = routeId;
    linkedDiveId = diveId;
    this.linkMode = linkMode;
  }

  @override
  Future<void> unlink(String routeId) async {
    unlinkedId = routeId;
  }

  @override
  Future<void> setPrimary(String routeId) async {
    primaryId = routeId;
  }
}

final _dive = Dive(
  id: 'dive-1',
  diveNumber: 1,
  dateTime: DateTime(2026, 8, 22),
);

NavTrack _route({String? diveId, bool isPrimary = true}) => NavTrack(
  id: 'r1',
  diveId: diveId,
  isPrimary: isPrimary,
  source: NavTrackSource.seacraftEnc,
  sourceRef: 'r1.csv',
  startTime: 1755856800000,
  endTime: 1755860400000,
  pointCount: 0,
  totalDistance: 1050,
  maxDepth: 38,
  createdAt: DateTime(2026, 8, 22),
  updatedAt: DateTime(2026, 8, 22),
);

Future<_RecordingNavTrackRepository> _pump(
  WidgetTester tester, {
  required List<NavTrack> linkedRoutes,
  List<NavTrack> unlinkedRoutes = const [],
  bool expanded = true,
  GoRouter? router,
}) async {
  // Pinned so the English finders below pass regardless of the host's
  // platform locale: without this, a supported non-English translation can
  // get selected instead and every finder in this file fails outside
  // English (mirrors nav_track_import_review_page_test.dart's own pin).
  tester.platformDispatcher.localesTestValue = const [
    Locale('de'),
    Locale('en'),
  ];
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);

  final overrides = await getBaseOverrides();
  final repository = _RecordingNavTrackRepository();
  final effectiveOverrides = [
    ...overrides,
    navTrackSectionExpandedProvider.overrideWith((ref) => expanded),
    navTracksForDiveProvider(
      _dive.id,
    ).overrideWith((ref) async => linkedRoutes),
    unlinkedNavTracksProvider.overrideWith((ref) async => unlinkedRoutes),
    navTrackRepositoryProvider.overrideWithValue(repository),
  ];
  if (router != null) {
    await tester.pumpWidget(
      ProviderScope(
        overrides: effectiveOverrides,
        child: MaterialApp.router(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    );
  } else {
    await tester.pumpWidget(
      ProviderScope(
        overrides: effectiveOverrides,
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: NavTrackSection(dive: _dive)),
        ),
      ),
    );
  }
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  testWidgets('empty state offers Link route and Import file', (tester) async {
    await _pump(tester, linkedRoutes: const [], unlinkedRoutes: [_route()]);

    expect(find.text('No route linked'), findsOneWidget);
    expect(find.byKey(const ValueKey('nav-track-link-button')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('nav-track-import-button')),
      findsOneWidget,
    );
  });

  testWidgets('empty state hides Link route when nothing is unlinked', (
    tester,
  ) async {
    await _pump(tester, linkedRoutes: const [], unlinkedRoutes: const []);

    expect(find.byKey(const ValueKey('nav-track-link-button')), findsNothing);
    expect(
      find.byKey(const ValueKey('nav-track-import-button')),
      findsOneWidget,
    );
  });

  testWidgets('populated state shows one row per linked route', (tester) async {
    await _pump(tester, linkedRoutes: [_route(diveId: _dive.id)]);

    expect(find.text('No route linked'), findsNothing);
    expect(find.byKey(const ValueKey('nav-track-row-r1')), findsOneWidget);
    expect(find.textContaining('primary'), findsOneWidget);
  });

  testWidgets(
    'shows the route\'s own stored distance and depth, not zero (proactive '
    'finding: navTracksForDiveProvider reads with includePoints: false, '
    'same as the routes-area list before item 9 was fixed -- recomputing '
    'NavTrackStats.of the empty points list silently zeroed the row)',
    (tester) async {
      await _pump(tester, linkedRoutes: [_route(diveId: _dive.id)]);

      expect(find.textContaining('1050'), findsOneWidget);
      expect(find.textContaining('38'), findsOneWidget);
    },
  );

  testWidgets('collapsed state renders no content', (tester) async {
    await _pump(
      tester,
      linkedRoutes: [_route(diveId: _dive.id)],
      expanded: false,
    );

    expect(find.byKey(const ValueKey('nav-track-row-r1')), findsNothing);
  });

  testWidgets('tapping "Link route" and choosing one links it to the dive', (
    tester,
  ) async {
    final repository = await _pump(
      tester,
      linkedRoutes: const [],
      unlinkedRoutes: [_route()],
    );

    await tester.tap(find.byKey(const ValueKey('nav-track-link-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('r1.csv'));
    await tester.pumpAndSettle();

    expect(repository.linkedRouteId, 'r1');
    expect(repository.linkedDiveId, _dive.id);
    expect(repository.linkMode, NavTrackLinkMode.manual);
  });

  group('row overflow menu', () {
    testWidgets('does not offer "Make primary" for the primary route', (
      tester,
    ) async {
      await _pump(tester, linkedRoutes: [_route(diveId: _dive.id)]);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();

      expect(find.text('Make primary'), findsNothing);
    });

    testWidgets('offers "Make primary" for a non-primary route, and calls '
        'setPrimary', (tester) async {
      final repository = await _pump(
        tester,
        linkedRoutes: [_route(diveId: _dive.id, isPrimary: false)],
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      expect(find.text('Make primary'), findsOneWidget);
      await tester.tap(find.text('Make primary'));
      await tester.pumpAndSettle();

      expect(repository.primaryId, 'r1');
    });

    testWidgets('"Unlink" calls unlink on the repository', (tester) async {
      final repository = await _pump(
        tester,
        linkedRoutes: [_route(diveId: _dive.id)],
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Unlink'));
      await tester.pumpAndSettle();

      expect(repository.unlinkedId, 'r1');
    });

    testWidgets('"Open route" pushes the route detail page', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                Scaffold(body: NavTrackSection(dive: _dive)),
          ),
          GoRoute(
            path: '/nav-routes/:id',
            builder: (context, state) =>
                const Scaffold(body: Text('ROUTE_DETAIL_PAGE')),
          ),
        ],
      );
      await _pump(
        tester,
        linkedRoutes: [_route(diveId: _dive.id)],
        router: router,
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open route'));
      await tester.pumpAndSettle();

      expect(find.text('ROUTE_DETAIL_PAGE'), findsOneWidget);
    });

    testWidgets('"Open 3D seascape" pushes the route seascape page', (
      tester,
    ) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                Scaffold(body: NavTrackSection(dive: _dive)),
          ),
          GoRoute(
            path: '/nav-routes/:id/3d',
            builder: (context, state) =>
                const Scaffold(body: Text('ROUTE_3D_PAGE')),
          ),
        ],
      );
      await _pump(
        tester,
        linkedRoutes: [_route(diveId: _dive.id)],
        router: router,
      );

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open 3D seascape'));
      await tester.pumpAndSettle();

      expect(find.text('ROUTE_3D_PAGE'), findsOneWidget);
    });
  });
}
