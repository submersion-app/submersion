import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_detail_ui_providers.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/data/services/nav_track_import_service.dart';
import 'package:submersion/features/nav_track/data/services/parsers/parsed_nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_segmenter.dart';
import 'package:submersion/features/nav_track/domain/nav_track_stats.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_import_review_page.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_import_flow_providers.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/presentation/providers/nav_track_providers.dart';
import 'package:submersion/features/nav_track/presentation/widgets/nav_track_section.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_file_picker_platform.dart';
import '../../../../helpers/mock_providers.dart';

/// Records calls instead of touching a real database.
class _RecordingNavTrackRepository extends NavTrackRepository {
  String? linkedRouteId;
  String? linkedDiveId;
  NavTrackLinkMode? linkMode;
  String? unlinkedId;
  String? primaryId;

  @override
  Future<bool> link(
    String routeId,
    String diveId, {
    required NavTrackLinkMode linkMode,
  }) async {
    linkedRouteId = routeId;
    linkedDiveId = diveId;
    this.linkMode = linkMode;
    return true;
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

/// Parses nothing: hands back a fixed preview, so the import button's flow
/// can be followed past the file picker without a real Seacraft ENC file.
class _PreparedImportService implements NavTrackImportService {
  int prepareCount = 0;

  @override
  Future<NavTrackImportPreview> prepare(
    Uint8List bytes, {
    String? fileName,
  }) async {
    prepareCount++;
    const points = [
      NavTrackPoint(
        timestamp: 1755856800,
        north: 0,
        east: 0,
        depth: 5,
        distance: 0,
        speed: 0.3,
      ),
      NavTrackPoint(
        timestamp: 1755857400,
        north: 40,
        east: 0,
        depth: 5,
        distance: 40,
        speed: 0.3,
      ),
    ];
    return NavTrackImportPreview(
      parsed: const ParsedNavTrack(points: points),
      stats: NavTrackStats.of(points),
      segmentation: NavTrackSegmenter.classify(points),
      candidateDives: const [],
      duplicateOfRouteId: null,
      sourceRef: fileName ?? '',
    );
  }

  @override
  Future<String> commit({
    required ParsedNavTrack parsed,
    required String sourceRef,
    Dive? dive,
    String? siteId,
    String? name,
    String? deviceName,
    String? equipmentId,
    String? replacingRouteId,
  }) async => throw UnimplementedError();
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
    unlinkedNavTracksProvider.overrideWith((ref) async => unlinkedRoutes),
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

  testWidgets(
    'importing a file opens the review page with the preview it already '
    'parsed and this dive pre-selected',
    (tester) async {
      final original = FilePickerPlatform.instance;
      addTearDown(() => FilePickerPlatform.instance = original);
      FilePickerPlatform.instance = MockFilePickerPlatform()
        ..pickFilesResult = [
          FakePlatformFile.contentUri(
            Uri.parse('content://picked/005.DAT.csv'),
            name: '005.DAT.csv',
            bytes: Uint8List.fromList([1]),
          ),
        ];
      final service = _PreparedImportService();
      await _pump(
        tester,
        linkedRoutes: const [],
        extraOverrides: [
          navTrackImportServiceProvider.overrideWithValue(service),
        ],
      );

      await tester.tap(find.byKey(const ValueKey('nav-track-import-button')));
      await tester.pumpAndSettle();

      final review = tester.widget<NavTrackImportReviewPage>(
        find.byType(NavTrackImportReviewPage),
      );
      expect(review.fileName, '005.DAT.csv');
      expect(review.preview, isNotNull);
      expect(review.preselectedDiveId, _dive.id);
      expect(service.prepareCount, 1);
    },
  );
}
