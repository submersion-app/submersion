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
  String? unlinkedId;
  String? primaryId;

  @override
  Future<void> unlink(String routeId, {String? onlyFromDiveId}) async {
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
  bool expanded = true,
  GoRouter? router,
  List<Override> extraOverrides = const [],
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
    navTrackRepositoryProvider.overrideWithValue(repository),
    ...extraOverrides,
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
            path: '/tracks/underwater/:id',
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

    testWidgets('tapping the route row opens its detail page', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) =>
                Scaffold(body: NavTrackSection(dive: _dive)),
          ),
          GoRoute(
            path: '/tracks/underwater/:id',
            builder: (context, state) => Scaffold(
              body: Text('ROUTE_DETAIL ${state.pathParameters['id']}'),
            ),
          ),
        ],
      );
      final route = _route(diveId: _dive.id);
      await _pump(tester, linkedRoutes: [route], router: router);

      await tester.tap(find.byType(ListTile).first);
      await tester.pumpAndSettle();

      expect(find.text('ROUTE_DETAIL ${route.id}'), findsOneWidget);
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
            path: '/tracks/underwater/:id/3d',
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
