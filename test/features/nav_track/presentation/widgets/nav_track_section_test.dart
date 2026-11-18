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
import 'package:submersion/shared/widgets/record_editing/record_edit_controller.dart';

/// The card only reads (issue #4527): linking is changed in the open card,
/// so a write through here fails the test.
class _ReadOnlyNavTrackRepository extends NavTrackRepository {
  @override
  Future<void> unlink(String routeId, {String? onlyFromDiveId}) =>
      throw StateError('the card unlinked $routeId');

  @override
  Future<bool> setPrimary(String routeId, {String? onlyForDiveId}) =>
      throw StateError('the card made $routeId the primary');
}

final _dive = Dive(
  id: 'dive-1',
  diveNumber: 1,
  dateTime: DateTime(2026, 8, 22),
);

NavTrack _route({String? diveId, bool isPrimary = true, double? maxSpeed}) =>
    NavTrack(
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
      maxSpeed: maxSpeed,
      createdAt: DateTime(2026, 8, 22),
      updatedAt: DateTime(2026, 8, 22),
    );

Future<void> _pump(
  WidgetTester tester, {
  required List<NavTrack> linkedRoutes,
  bool expanded = true,
  GoRouter? router,
  List<Override> extraOverrides = const [],
  RecordEditController<Dive>? lockable,
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
  final repository = _ReadOnlyNavTrackRepository();
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
          home: Scaffold(
            body: lockable == null
                ? NavTrackSection(dive: _dive)
                : RecordEditScope<Dive>(
                    controller: lockable,
                    child: NavTrackSection(dive: _dive),
                  ),
          ),
        ),
      ),
    );
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('populated state shows one row per linked route', (tester) async {
    await _pump(tester, linkedRoutes: [_route(diveId: _dive.id)]);

    expect(find.text('No track linked'), findsNothing);
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

  testWidgets('shows max speed in m/min, not km/h -- the diving/DPV convention '
      '(Copilot review on PR #3637: this row still called formatSpeed after '
      'the detail page and 3D preview switched to formatTrackSpeed)', (
    tester,
  ) async {
    await _pump(
      tester,
      linkedRoutes: [_route(diveId: _dive.id, maxSpeed: 1.0)],
    );

    expect(find.textContaining('60.0 m/min'), findsOneWidget);
    expect(find.textContaining('km/h'), findsNothing);
  });

  testWidgets('collapsed state renders no content', (tester) async {
    await _pump(
      tester,
      linkedRoutes: [_route(diveId: _dive.id)],
      expanded: false,
    );

    expect(find.byKey(const ValueKey('nav-track-row-r1')), findsNothing);
  });

  group('row overflow menu', () {
    testWidgets('"Open track" pushes the route detail page', (tester) async {
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
      await tester.tap(find.text('Open track'));
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

  // Linking is changed in the open card (issue #4527): a route that is not
  // the primary still offers no Unlink or Make primary here.
  testWidgets('the row menu offers Open and 3D only', (tester) async {
    final controller = RecordEditController<Dive>(onSave: (_) async {});
    addTearDown(controller.dispose);
    await _pump(
      tester,
      linkedRoutes: [_route(diveId: _dive.id, isPrimary: false)],
      lockable: controller,
    );
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();

    expect(find.text('Open track'), findsOneWidget);
    expect(find.text('Unlink'), findsNothing);
    expect(find.text('Make primary'), findsNothing);
  });
}
