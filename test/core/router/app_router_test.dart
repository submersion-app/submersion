import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/features/gps_log/presentation/pages/gps_track_detail_page.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_align_page.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_detail_page.dart';
import 'package:submersion/features/nav_track/presentation/pages/nav_track_seascape_page.dart';
import 'package:submersion/features/tracks/domain/track_kind.dart';
import 'package:submersion/features/tracks/presentation/pages/tracks_map_page.dart';
import 'package:submersion/features/tracks/presentation/pages/tracks_page.dart';
import 'package:submersion/core/router/track_locations.dart';
import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/features/connections/presentation/connections_links.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_template_edit_page.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_templates_page.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_search_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/planner/presentation/pages/plan_canvas_page.dart';
import 'package:submersion/features/marine_life/presentation/pages/species_page.dart';
import 'package:submersion/features/safety/presentation/pages/incident_edit_page.dart';
import 'package:submersion/features/safety/presentation/pages/incidents_list_page.dart';
import 'package:submersion/features/safety/presentation/pages/no_fly_page.dart';
import 'package:submersion/features/settings/presentation/pages/section_appearance_page.dart';
import 'package:submersion/features/settings/presentation/pages/settings_page.dart';
import 'package:submersion/features/settings/presentation/pages/site_detail_sections_page.dart';
import 'package:submersion/features/settings/presentation/widgets/unrecognized_backups_notice.dart';
import 'package:submersion/features/settings/presentation/pages/column_config_page.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// Finds a [GoRoute] by name in a route tree recursively.
GoRoute? _findRouteByName(List<RouteBase> routes, String name) {
  for (final route in routes) {
    if (route is GoRoute && route.name == name) return route;
    if (route is GoRoute) {
      final found = _findRouteByName(route.routes, name);
      if (found != null) return found;
    }
    if (route is ShellRoute) {
      final found = _findRouteByName(route.routes, name);
      if (found != null) return found;
    }
  }
  return null;
}

/// Finds a [GoRoute] by its own path segment in a route tree recursively.
GoRoute? _findRouteByPath(List<RouteBase> routes, String path) {
  for (final route in routes) {
    if (route is GoRoute) {
      if (route.path == path) return route;
      final found = _findRouteByPath(route.routes, path);
      if (found != null) return found;
    }
    if (route is ShellRoute) {
      final found = _findRouteByPath(route.routes, path);
      if (found != null) return found;
    }
  }
  return null;
}

/// Collects all named [GoRoute]s from a route tree recursively.
Set<String> _collectRouteNames(List<RouteBase> routes) {
  final names = <String>{};
  for (final route in routes) {
    if (route is GoRoute && route.name != null) {
      names.add(route.name!);
    }
    if (route is GoRoute) {
      names.addAll(_collectRouteNames(route.routes));
    }
    if (route is ShellRoute) {
      names.addAll(_collectRouteNames(route.routes));
    }
  }
  return names;
}

/// Collects all paths from [GoRoute]s recursively.
Set<String> _collectRoutePaths(List<RouteBase> routes) {
  final paths = <String>{};
  for (final route in routes) {
    if (route is GoRoute) {
      paths.add(route.path);
      paths.addAll(_collectRoutePaths(route.routes));
    }
    if (route is ShellRoute) {
      paths.addAll(_collectRoutePaths(route.routes));
    }
  }
  return paths;
}

/// Route paths in declaration order, which [_collectRoutePaths] discards.
List<String> _orderedRoutePaths(List<RouteBase> routes) => [
  for (final route in routes) ...[
    if (route is GoRoute) route.path,
    ..._orderedRoutePaths(route.routes),
  ],
];

/// The location a named route resolves to, assembled from its ancestors.
///
/// A nested GoRoute stores only its own segment, so a widget that pushes a
/// hand-written absolute path can drift from the tree without any test
/// noticing until the push fails at runtime.
String? _locationOfRoute(
  List<RouteBase> routes,
  String name, [
  String prefix = '',
]) {
  for (final route in routes) {
    if (route is GoRoute) {
      final here = route.path.startsWith('/')
          ? route.path
          : '${prefix == '/' ? '' : prefix}/${route.path}';
      if (route.name == name) return here;
      final found = _locationOfRoute(route.routes, name, here);
      if (found != null) return found;
    }
    if (route is ShellRoute) {
      final found = _locationOfRoute(route.routes, name, prefix);
      if (found != null) return found;
    }
  }
  return null;
}

void main() {
  late GoRouter router;
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer(
      overrides: [hasAnyDiversProvider.overrideWith((ref) async => true)],
    );
    router = container.read(appRouterProvider);
  });

  tearDown(() {
    container.dispose();
  });

  group('tracks area', () {
    test('every tracks page is a top-level sibling of /tracks', () {
      // go_router builds one page per matched segment and /tracks has its
      // own pageBuilder, so a nested detail would stack the landing page
      // under it: two Back presses from a dive's track link.
      final routes = router.configuration.routes;
      final tracks = _findRouteByName(routes, 'tracks');
      expect(tracks?.path, kTracksLocation);
      expect(tracks!.routes, isEmpty);
      for (final (name, path) in const [
        ('tracksMap', '/tracks/map'),
        ('gpsTrackDetail', '/tracks/gps/:id'),
        ('underwaterTrackDetail', '/tracks/underwater/:id'),
        ('underwaterTrackAlign', '/tracks/underwater/:id/align'),
        ('underwaterTrackSeascape', '/tracks/underwater/:id/3d'),
      ]) {
        expect(_findRouteByName(routes, name)?.path, path, reason: name);
      }
    });

    test('the location helpers match the route table', () {
      final config = router.configuration;
      for (final (location, fullPath) in [
        (kTracksMapLocation, '/tracks/map'),
        (gpsTrackLocation('abc'), '/tracks/gps/:id'),
        (underwaterTrackLocation('abc'), '/tracks/underwater/:id'),
        (underwaterTrackAlignLocation('abc'), '/tracks/underwater/:id/align'),
        (underwaterTrackSeascapeLocation('abc'), '/tracks/underwater/:id/3d'),
      ]) {
        expect(
          config.findMatch(Uri.parse(location)).fullPath,
          fullPath,
          reason: location,
        );
      }
    });

    test('static paths are declared before parameterised siblings', () {
      // ':id' matches any single segment, so a static sibling declared after
      // it would never match.
      final paths = _orderedRoutePaths(router.configuration.routes);
      expect(
        paths.indexOf('/tracks/map'),
        lessThan(paths.indexOf('/tracks/gps/:id')),
      );
      expect(paths.indexOf('/gps-log/map'), isNot(-1));
      expect(
        paths.indexOf('/gps-log/map'),
        lessThan(paths.indexOf('/gps-log/:id')),
      );
    });

    testWidgets('each tracks route builds its page with the path id', (
      tester,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      GoRouterState stateFor(
        String fullPath,
        String location, [
        Map<String, String> params = const {},
      ]) => GoRouterState(
        router.configuration,
        uri: Uri.parse(location),
        matchedLocation: Uri.parse(location).path,
        fullPath: fullPath,
        pathParameters: params,
        pageKey: ValueKey(location),
      );
      final routes = router.configuration.routes;
      Widget build(String name, GoRouterState state) =>
          _findRouteByName(routes, name)!.builder!(capturedContext, state);

      final landing = _findRouteByName(routes, 'tracks')!.pageBuilder!(
        capturedContext,
        stateFor('/tracks', '/tracks?kind=underwater'),
      );
      expect(landing, isA<NoTransitionPage<void>>());
      final tracksPage =
          (landing as NoTransitionPage<void>).child as TracksPage;
      expect(tracksPage.initialKind, TrackKindFilter.underwater);

      expect(
        build('tracksMap', stateFor('/tracks/map', '/tracks/map')),
        isA<TracksMapPage>(),
      );
      final gps =
          build(
                'gpsTrackDetail',
                stateFor('/tracks/gps/:id', '/tracks/gps/g1', {'id': 'g1'}),
              )
              as GpsTrackDetailPage;
      expect(gps.trackId, 'g1');
      final detail =
          build(
                'underwaterTrackDetail',
                stateFor('/tracks/underwater/:id', '/tracks/underwater/u1', {
                  'id': 'u1',
                }),
              )
              as NavTrackDetailPage;
      expect(detail.trackId, 'u1');
      final align =
          build(
                'underwaterTrackAlign',
                stateFor(
                  '/tracks/underwater/:id/align',
                  '/tracks/underwater/u1/align',
                  {'id': 'u1'},
                ),
              )
              as NavTrackAlignPage;
      expect(align.routeId, 'u1');
      final seascape =
          build(
                'underwaterTrackSeascape',
                stateFor(
                  '/tracks/underwater/:id/3d',
                  '/tracks/underwater/u1/3d',
                  {'id': 'u1'},
                ),
              )
              as NavTrackSeascapePage;
      expect(seascape.trackId, 'u1');
    });

    testWidgets('old GPS log and underwater route locations redirect into '
        '/tracks', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      Future<String?> redirect(
        String path,
        String location, [
        Map<String, String> params = const {},
      ]) async {
        final route = _findRouteByPath(router.configuration.routes, path);
        expect(route?.redirect, isNotNull, reason: path);
        return route!.redirect!(
          capturedContext,
          GoRouterState(
            router.configuration,
            uri: Uri.parse(location),
            matchedLocation: location,
            fullPath: path,
            pathParameters: params,
            pageKey: ValueKey(location),
          ),
        );
      }

      expect(await redirect('/gps-log', '/gps-log'), '/tracks');
      expect(await redirect('/gps-log/map', '/gps-log/map'), '/tracks/map');
      expect(
        await redirect('/gps-log/:id', '/gps-log/abc', {'id': 'abc'}),
        '/tracks/gps/abc',
      );
      expect(
        await redirect('/nav-routes', '/nav-routes'),
        '/tracks?kind=underwater',
      );
      expect(
        await redirect('/nav-routes/:id', '/nav-routes/r1', {'id': 'r1'}),
        '/tracks/underwater/r1',
      );
      expect(
        await redirect('/nav-routes/:id/align', '/nav-routes/r1/align', {
          'id': 'r1',
        }),
        '/tracks/underwater/r1/align',
      );
      expect(
        await redirect('/nav-routes/:id/3d', '/nav-routes/r1/3d', {'id': 'r1'}),
        '/tracks/underwater/r1/3d',
      );
      expect(await redirect('gps-logger', '/planning/gps-logger'), '/tracks');
    });

    test('old planning gps-logger path is a redirect', () {
      GoRoute? findByPath(List<RouteBase> routes) {
        for (final route in routes) {
          if (route is GoRoute) {
            if (route.path == 'gps-logger') return route;
            final found = findByPath(route.routes);
            if (found != null) return found;
          }
          if (route is ShellRoute) {
            final found = findByPath(route.routes);
            if (found != null) return found;
          }
        }
        return null;
      }

      final route = findByPath(router.configuration.routes);
      expect(route, isNotNull);
      expect(route!.redirect, isNotNull);
      expect(route.builder, isNull);
    });
  });

  group('app_router route configuration', () {
    test('connections lives under Insights and accepts query params', () {
      final routes = router.configuration.routes;
      expect(_findRouteByName(routes, 'connections'), isNotNull);
      expect(_locationOfRoute(routes, 'connections'), kConnectionsLocation);
      final match = router.configuration.findMatch(
        Uri.parse('/insights/connections?mode=around&focus=buddy:abc'),
      );
      expect(match.fullPath, '/insights/connections');
    });

    test('the cylinder passport nests under equipment detail', () {
      final names = _collectRouteNames(router.configuration.routes);
      expect(names, contains('equipmentPassport'));
      expect(
        _locationOfRoute(router.configuration.routes, 'equipmentPassport'),
        '/equipment/:equipmentId/passport',
      );
    });

    test('contains universalImport route', () {
      final names = _collectRouteNames(router.configuration.routes);
      expect(names, contains('universalImport'));
    });

    test('contains wearableImport route', () {
      final names = _collectRouteNames(router.configuration.routes);
      expect(names, contains('wearableImport'));
    });

    test('contains discoverDevice route', () {
      final names = _collectRouteNames(router.configuration.routes);
      expect(names, contains('discoverDevice'));
    });

    test('contains computerDownload route', () {
      final names = _collectRouteNames(router.configuration.routes);
      expect(names, contains('computerDownload'));
    });

    test('contains diveComputers route', () {
      final names = _collectRouteNames(router.configuration.routes);
      expect(names, contains('diveComputers'));
    });

    test('contains computerDetail route', () {
      final names = _collectRouteNames(router.configuration.routes);
      expect(names, contains('computerDetail'));
    });

    test('does not contain removed fitImport route', () {
      final names = _collectRouteNames(router.configuration.routes);
      expect(names, isNot(contains('fitImport')));
    });

    test('does not contain removed uddfImport route', () {
      final names = _collectRouteNames(router.configuration.routes);
      expect(names, isNot(contains('uddfImport')));
    });

    test('does not contain removed healthkitImport route', () {
      final names = _collectRouteNames(router.configuration.routes);
      expect(names, isNot(contains('healthkitImport')));
    });

    test('import-wizard path exists under /transfer', () {
      final paths = _collectRoutePaths(router.configuration.routes);
      expect(paths, contains('import-wizard'));
    });

    test('wearable-import path exists under /settings', () {
      final paths = _collectRoutePaths(router.configuration.routes);
      expect(paths, contains('wearable-import'));
    });

    test('discover path exists under dive computers', () {
      final paths = _collectRoutePaths(router.configuration.routes);
      expect(paths, contains('discover'));
    });

    test('download path exists under computer detail', () {
      final paths = _collectRoutePaths(router.configuration.routes);
      expect(paths, contains('download'));
    });

    test('transfer route still exists', () {
      final names = _collectRouteNames(router.configuration.routes);
      expect(names, contains('transfer'));
    });

    test('universalImport is the only import child route under transfer', () {
      GoRoute? transferRoute;
      for (final route in router.configuration.routes) {
        if (route is ShellRoute) {
          for (final child in route.routes) {
            if (child is GoRoute && child.name == 'transfer') {
              transferRoute = child;
              break;
            }
          }
        }
      }
      expect(transferRoute, isNotNull, reason: 'transfer route should exist');

      final childNames = _collectRouteNames(transferRoute!.routes);
      expect(childNames, contains('universalImport'));
      // The old fitImport and uddfImport should not be children of transfer
      expect(childNames, isNot(contains('fitImport')));
      expect(childNames, isNot(contains('uddfImport')));
    });

    test(':computerId path has download as a nested route', () {
      // Walk the tree to find diveComputers > :computerId > download
      GoRoute? computersRoute;
      for (final route in router.configuration.routes) {
        if (route is ShellRoute) {
          for (final child in route.routes) {
            if (child is GoRoute && child.name == 'diveComputers') {
              computersRoute = child;
              break;
            }
          }
        }
      }
      expect(computersRoute, isNotNull);

      // Find :computerId child
      final computerDetailRoute =
          computersRoute!.routes.firstWhere(
                (r) => r is GoRoute && r.path == ':computerId',
              )
              as GoRoute;
      expect(computerDetailRoute.name, equals('computerDetail'));

      // Find download child
      final downloadRoute =
          computerDetailRoute.routes.firstWhere(
                (r) => r is GoRoute && r.name == 'computerDownload',
              )
              as GoRoute;
      expect(downloadRoute.path, equals('download'));
    });

    test('a scanned foreign tag has its own route, not an equipment id', () {
      final match = router.configuration.findMatch(
        Uri.parse('/equipment/tag?t=x'),
      );
      expect(match.isError, isFalse);
      expect(match.last.route.name, 'foreignPassport');
    });
  });

  group('appearance section routes', () {
    test('all 8 appearance section routes exist', () {
      final names = _collectRouteNames(router.configuration.routes);
      expect(names, contains('appearanceDives'));
      expect(names, contains('appearanceSites'));
      expect(names, contains('appearanceBuddies'));
      expect(names, contains('appearanceTrips'));
      expect(names, contains('appearanceEquipment'));
      expect(names, contains('appearanceDiveCenters'));
      expect(names, contains('appearanceCertifications'));
      expect(names, contains('appearanceCourses'));
    });

    test('columnConfig route exists under appearance', () {
      final names = _collectRouteNames(router.configuration.routes);
      expect(names, contains('columnConfig'));
    });

    test('appearance section routes have correct paths', () {
      final paths = _collectRoutePaths(router.configuration.routes);
      expect(paths, contains('dives'));
      expect(paths, contains('sites'));
      expect(paths, contains('buddies'));
      expect(paths, contains('trips'));
      expect(paths, contains('equipment'));
      expect(paths, contains('dive-centers'));
      expect(paths, contains('certifications'));
      expect(paths, contains('courses'));
      expect(paths, contains('column-config'));
    });

    test('appearance section routes have non-null builders', () {
      for (final name in [
        'appearanceDives',
        'appearanceSites',
        'appearanceBuddies',
        'appearanceTrips',
        'appearanceEquipment',
        'appearanceDiveCenters',
        'appearanceCertifications',
        'appearanceCourses',
        'columnConfig',
      ]) {
        final route = _findRouteByName(router.configuration.routes, name);
        expect(route, isNotNull, reason: 'Route "$name" should exist');
        expect(
          route!.builder,
          isNotNull,
          reason: 'Route "$name" should have a builder',
        );
      }
    });

    testWidgets('appearance section builders return correct widget types', (
      tester,
    ) async {
      // Build a minimal widget tree to get a valid BuildContext,
      // then invoke each route builder to verify it returns the expected
      // widget type. This covers the builder lambdas in app_router.dart.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));

      final context = tester.element(find.byType(SizedBox));
      final config = router.configuration;

      // Section appearance routes
      for (final entry in <String, String>{
        'appearanceDives': 'dives',
        'appearanceSites': 'sites',
        'appearanceBuddies': 'buddies',
        'appearanceTrips': 'trips',
        'appearanceEquipment': 'equipment',
        'appearanceDiveCenters': 'diveCenters',
        'appearanceCertifications': 'certifications',
        'appearanceCourses': 'courses',
      }.entries) {
        final route = _findRouteByName(config.routes, entry.key);
        expect(route, isNotNull, reason: '${entry.key} should exist');

        final state = GoRouterState(
          config,
          uri: Uri.parse('/settings/appearance/${entry.value}'),
          matchedLocation: '/settings/appearance/${entry.value}',
          fullPath: '/settings/appearance/${entry.value}',
          pathParameters: const {},
          pageKey: ValueKey('/settings/appearance/${entry.value}'),
        );

        final widget = route!.builder!(context, state);
        expect(
          widget,
          isA<SectionAppearancePage>(),
          reason: '${entry.key} builder should return SectionAppearancePage',
        );
      }

      // Column config route
      final columnRoute = _findRouteByName(config.routes, 'columnConfig');
      expect(columnRoute, isNotNull);
      final columnState = GoRouterState(
        config,
        uri: Uri.parse('/settings/appearance/column-config?section=dives'),
        matchedLocation: '/settings/appearance/column-config',
        fullPath: '/settings/appearance/column-config',
        pathParameters: const {},
        pageKey: const ValueKey('/settings/appearance/column-config'),
      );
      final columnWidget = columnRoute!.builder!(context, columnState);
      expect(columnWidget, isA<ColumnConfigPage>());
    });
  });

  group('app_router media routes', () {
    test('contains mediaSources route', () {
      final names = _collectRouteNames(router.configuration.routes);
      expect(names, contains('mediaSources'));
    });

    test('mediaSources route path is /settings/media-sources', () {
      final paths = _collectRoutePaths(router.configuration.routes);
      expect(paths, contains('media-sources'));
    });

    testWidgets('mediaSources route builder returns MediaSourcesPage', (
      tester,
    ) async {
      final config = router.configuration;
      final route = _findRouteByName(config.routes, 'mediaSources');
      expect(route, isNotNull);

      // Capture a real BuildContext so we can invoke the builder.
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final state = GoRouterState(
        config,
        uri: Uri.parse('/settings/media-sources'),
        matchedLocation: '/settings/media-sources',
        fullPath: '/settings/media-sources',
        pathParameters: const {},
        pageKey: const ValueKey('/settings/media-sources'),
      );
      final widget = route!.builder!(capturedContext, state);
      // Use a String comparison so this test does not need to import the
      // MediaSourcesPage class (avoids over-coupling the router test).
      expect(widget.runtimeType.toString(), 'MediaSourcesPage');
    });

    test('cloudSync route path is /settings/cloud-sync', () {
      final paths = _collectRoutePaths(router.configuration.routes);
      expect(paths, contains('cloud-sync'));
    });

    testWidgets('cloudSync route builder returns CloudSyncPage', (
      tester,
    ) async {
      final config = router.configuration;
      final route = _findRouteByName(config.routes, 'cloudSync');
      expect(route, isNotNull);

      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final state = GoRouterState(
        config,
        uri: Uri.parse('/settings/cloud-sync'),
        matchedLocation: '/settings/cloud-sync',
        fullPath: '/settings/cloud-sync',
        pathParameters: const {},
        pageKey: const ValueKey('/settings/cloud-sync'),
      );
      final widget = route!.builder!(capturedContext, state);
      expect(widget.runtimeType.toString(), 'CloudSyncPage');
    });
  });

  group('app_router checklist templates routes', () {
    testWidgets(
      'newChecklistTemplate and editChecklistTemplate builders return '
      'ChecklistTemplateEditPage with the expected templateId',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final context = tester.element(find.byType(SizedBox));
        final config = router.configuration;

        final listRoute = _findRouteByName(config.routes, 'checklistTemplates');
        expect(listRoute, isNotNull);
        final listState = GoRouterState(
          config,
          uri: Uri.parse('/checklist-templates'),
          matchedLocation: '/checklist-templates',
          fullPath: '/checklist-templates',
          pathParameters: const {},
          pageKey: const ValueKey('/checklist-templates'),
        );
        expect(
          listRoute!.builder!(context, listState),
          isA<ChecklistTemplatesPage>(),
        );

        final newRoute = _findRouteByName(
          config.routes,
          'newChecklistTemplate',
        );
        expect(newRoute, isNotNull);
        final newState = GoRouterState(
          config,
          uri: Uri.parse('/checklist-templates/new'),
          matchedLocation: '/checklist-templates/new',
          fullPath: '/checklist-templates/new',
          pathParameters: const {},
          pageKey: const ValueKey('/checklist-templates/new'),
        );
        final newWidget =
            newRoute!.builder!(context, newState) as ChecklistTemplateEditPage;
        expect(newWidget.templateId, isNull);

        final editRoute = _findRouteByName(
          config.routes,
          'editChecklistTemplate',
        );
        expect(editRoute, isNotNull);
        final editState = GoRouterState(
          config,
          uri: Uri.parse('/checklist-templates/tpl-1/edit'),
          matchedLocation: '/checklist-templates/tpl-1/edit',
          fullPath: '/checklist-templates/tpl-1/edit',
          pathParameters: const {'templateId': 'tpl-1'},
          pageKey: const ValueKey('/checklist-templates/tpl-1/edit'),
        );
        final editWidget =
            editRoute!.builder!(context, editState)
                as ChecklistTemplateEditPage;
        expect(editWidget.templateId, 'tpl-1');
      },
    );
  });

  group('app_router near-miss incident routes', () {
    testWidgets(
      'incidents, incidentNew, and incidentEdit builders return the right '
      'pages and thread through the dive/incident ids',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final context = tester.element(find.byType(SizedBox));
        final config = router.configuration;

        final listRoute = _findRouteByName(config.routes, 'incidents');
        expect(listRoute, isNotNull);
        expect(listRoute!.path, '/incidents');
        final listState = GoRouterState(
          config,
          uri: Uri.parse('/incidents'),
          matchedLocation: '/incidents',
          fullPath: '/incidents',
          pathParameters: const {},
          pageKey: const ValueKey('/incidents'),
        );
        expect(
          listRoute.builder!(context, listState),
          isA<IncidentsListPage>(),
        );

        // A new incident prefilled from a dive carries the diveId query param.
        final newRoute = _findRouteByName(config.routes, 'incidentNew');
        expect(newRoute, isNotNull);
        final newState = GoRouterState(
          config,
          uri: Uri.parse('/incidents/new?diveId=dive-9'),
          matchedLocation: '/incidents/new',
          fullPath: '/incidents/new',
          pathParameters: const {},
          pageKey: const ValueKey('/incidents/new'),
        );
        final newWidget =
            newRoute!.builder!(context, newState) as IncidentEditPage;
        expect(newWidget.incidentId, isNull);
        expect(newWidget.diveId, 'dive-9');

        // Editing an existing incident threads the path param through.
        final editRoute = _findRouteByName(config.routes, 'incidentEdit');
        expect(editRoute, isNotNull);
        final editState = GoRouterState(
          config,
          uri: Uri.parse('/incidents/inc-1'),
          matchedLocation: '/incidents/inc-1',
          fullPath: '/incidents/:incidentId',
          pathParameters: const {'incidentId': 'inc-1'},
          pageKey: const ValueKey('/incidents/inc-1'),
        );
        final editWidget =
            editRoute!.builder!(context, editState) as IncidentEditPage;
        expect(editWidget.incidentId, 'inc-1');
        expect(editWidget.diveId, isNull);
      },
    );
  });

  group('dive planner back-navigation (editPlan not nested)', () {
    // Regression: opening a saved plan navigated to
    // /planning/dive-planner/:planId, which was declared as a CHILD of the
    // 'dive-planner' route. go_router builds one page per matched route
    // segment, so the stack became [PlanningPage, PlanCanvasPage(),
    // PlanCanvasPage(planId)] -- two canvas pages. Both read the same shared
    // divePlanNotifierProvider, so the first Back press only revealed the
    // identical parent canvas, forcing a second press. The fix makes editPlan
    // a SIBLING of divePlanner (path 'dive-planner/:planId') so exactly one
    // canvas page is built.

    test('editPlan is a sibling of divePlanner, not a nested child', () {
      final planning = _findRouteByName(
        router.configuration.routes,
        'planning',
      );
      expect(planning, isNotNull);

      // editPlan lives directly under /planning (sibling of divePlanner).
      final editPlan = planning!.routes.whereType<GoRoute>().firstWhere(
        (r) => r.name == 'editPlan',
        orElse: () =>
            throw StateError('editPlan not a direct child of planning'),
      );
      expect(editPlan.path, 'dive-planner/:planId');

      // The divePlanner subtree must NOT contain the plan-id route anymore.
      final divePlanner = _findRouteByName(
        router.configuration.routes,
        'divePlanner',
      );
      expect(divePlanner, isNotNull);
      final nestedNames = _collectRouteNames(divePlanner!.routes);
      expect(nestedNames, isNot(contains('editPlan')));
      final nestedPaths = _collectRoutePaths(divePlanner.routes);
      expect(nestedPaths, isNot(contains(':planId')));
    });

    test('opening a saved plan matches only editPlan (single canvas page)', () {
      final match = router.configuration.findMatch(
        Uri.parse('/planning/dive-planner/plan-123'),
      );
      expect(match.fullPath, '/planning/dive-planner/:planId');
    });

    test('static sub-routes still win over the :planId sibling', () {
      // Precedence guard: 'compare' / 'chart' remain children of divePlanner
      // and must resolve before the dynamic sibling.
      expect(
        router.configuration
            .findMatch(Uri.parse('/planning/dive-planner/compare?ids=a,b'))
            .fullPath,
        '/planning/dive-planner/compare',
      );
      expect(
        router.configuration
            .findMatch(Uri.parse('/planning/dive-planner/chart'))
            .fullPath,
        '/planning/dive-planner/chart',
      );
    });

    test('no-fly is a direct child of /planning (matches the hub tile)', () {
      // Regression: the "Flying after diving" hub tile navigates to
      // '/planning/no-fly'. The route used to live under 'dive-planner'
      // (so its real path was '/planning/dive-planner/no-fly'), leaving the
      // tile's target unmatched and throwing "no routes for location".
      expect(
        router.configuration.findMatch(Uri.parse('/planning/no-fly')).fullPath,
        '/planning/no-fly',
      );

      final noFly = _findRouteByName(router.configuration.routes, 'noFly');
      expect(noFly, isNotNull);
      final divePlanner = _findRouteByName(
        router.configuration.routes,
        'divePlanner',
      );
      expect(divePlanner, isNotNull);
      final nestedNames = _collectRouteNames(divePlanner!.routes);
      expect(nestedNames, isNot(contains('noFly')));
    });

    testWidgets('noFly route builds the NoFlyPage', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox));

      final noFly = _findRouteByName(router.configuration.routes, 'noFly');
      expect(noFly, isNotNull);
      final state = GoRouterState(
        router.configuration,
        uri: Uri.parse('/planning/no-fly'),
        matchedLocation: '/planning/no-fly',
        fullPath: '/planning/no-fly',
        pathParameters: const {},
        pageKey: const ValueKey('/planning/no-fly'),
      );
      expect(noFly!.builder!(context, state), isA<NoFlyPage>());
    });

    testWidgets(
      'editPlan builder threads planId; divePlanner builds a new plan',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: SizedBox()));
        final context = tester.element(find.byType(SizedBox));
        final config = router.configuration;

        final editPlan = _findRouteByName(config.routes, 'editPlan');
        final editState = GoRouterState(
          config,
          uri: Uri.parse('/planning/dive-planner/plan-123'),
          matchedLocation: '/planning/dive-planner/plan-123',
          fullPath: '/planning/dive-planner/:planId',
          pathParameters: const {'planId': 'plan-123'},
          pageKey: const ValueKey('/planning/dive-planner/plan-123'),
        );
        final editWidget =
            editPlan!.builder!(context, editState) as PlanCanvasPage;
        expect(editWidget.planId, 'plan-123');

        final divePlanner = _findRouteByName(config.routes, 'divePlanner');
        final newState = GoRouterState(
          config,
          uri: Uri.parse('/planning/dive-planner'),
          matchedLocation: '/planning/dive-planner',
          fullPath: '/planning/dive-planner',
          pathParameters: const {},
          pageKey: const ValueKey('/planning/dive-planner'),
        );
        final newWidget =
            divePlanner!.builder!(context, newState) as PlanCanvasPage;
        expect(newWidget.planId, isNull);
      },
    );
  });

  // The GaugeStrip widget test navigates through a stub router, so a chip
  // pointing at a path that does not exist in the real app would still pass
  // there. These assert the destinations resolve against the real config.
  group('home gauge-strip chip destinations resolve', () {
    const destinations = <String>[
      '/equipment',
      '/equipment/new',
      // Gear chips and urgent-banner lines deep-link to one item (issue #816).
      '/equipment/e1',
      '/settings/diver-profile/insurance',
      '/planning/no-fly',
      '/dives',
      '/certifications',
      '/trips',
      '/pre-dive-sessions/session-7',
      '/courses/c1',
      '/settings/media-storage/transfers',
      '/settings/backup',
      '/settings/cloud-sync',
      '/dives/quality',
    ];

    for (final destination in destinations) {
      test('$destination matches a route', () {
        final match = router.configuration.findMatch(Uri.parse(destination));
        expect(
          match.isError,
          isFalse,
          reason: '$destination does not resolve to any route',
        );
      });
    }
  });

  group('app_router initialLocation', () {
    test('initial location is /dashboard', () {
      expect(
        router.configuration.routes.any(
          (r) => r is GoRoute && r.path == '/dashboard',
        ),
        isFalse,
        reason: '/dashboard is nested under ShellRoute, not a top-level path',
      );
      // The GoRouter initialLocation is /dashboard
      // which is resolved via the shell route
    });
  });

  group('newBuddy route escapes to the root navigator', () {
    // Regression: bulk-editing dives opens "Add buddies" via showDialog
    // (useRootNavigator: true by default), then BuddyPicker opens a
    // showModalBottomSheet (which resolves to that same root navigator,
    // since its default useRootNavigator: false picks the nearest
    // navigator ancestor -- the dialog's). Tapping "Add New Buddy" pushes
    // 'newBuddy', which -- absent a parentNavigatorKey -- mounts on the
    // ShellRoute's nested navigator instead. That nested navigator's
    // overlay paints underneath the root navigator's, so the new-buddy
    // screen renders hidden behind the still-open dialog and bottom sheet
    // until both are dismissed. See buddy_picker_navigation_render_test.dart
    // for the full render-level reproduction, including confirmation that
    // the dialog/sheet correctly reappear (with state intact) once the
    // new-buddy page is popped -- pushing onto the root navigator does not
    // evict them, it only elides their (harmless, Flutter-standard)
    // rendering while a fully opaque route covers them.
    test('newBuddy has parentNavigatorKey set to the root navigator', () {
      final route = _findRouteByName(router.configuration.routes, 'newBuddy');
      expect(route, isNotNull);
      expect(
        route!.parentNavigatorKey,
        same(rootNavigatorKey),
        reason:
            'Without this, "Add New Buddy" pushed from the bulk-edit '
            'dialog renders underneath it instead of in the foreground.',
      );
    });
  });

  group('manageServiceTypes route escapes to the root navigator', () {
    // Regression: the Add/Edit Service Record dialog opens via showDialog
    // (useRootNavigator: true by default) and its "Manage Service Types"
    // link pushes 'manageServiceTypes'. Absent a parentNavigatorKey, that
    // page mounts on the ShellRoute's nested navigator, which paints under
    // the root navigator's overlay, so the page opened hidden behind the
    // still-open dialog. See service_record_dialog_manage_types_nav_test.dart
    // for the render-level round trip.
    test('manageServiceTypes has parentNavigatorKey set to the root '
        'navigator', () {
      final route = _findRouteByName(
        router.configuration.routes,
        'manageServiceTypes',
      );
      expect(route, isNotNull);
      expect(
        route!.parentNavigatorKey,
        same(rootNavigatorKey),
        reason:
            'Without this, "Manage Service Types" pushed from the service '
            'record dialog renders underneath it instead of in the '
            'foreground.',
      );
    });
  });

  group('app_router lightroom route (pending Adobe review)', () {
    test('lightroom route stays defined so navigation degrades gracefully', () {
      // The route is intentionally kept (not removed) while the UI is hidden so
      // deep links and PendingSetupService's '/settings/lightroom' target
      // redirect instead of hitting an unknown-route error screen.
      final route = _findRouteByName(router.configuration.routes, 'lightroom');
      expect(route, isNotNull);
      expect(route!.path, 'lightroom');
      expect(route.redirect, isNotNull);
    });

    testWidgets('redirects to media sources when lightroomUiEnabled is false, '
        'and passes through when true', (tester) async {
      final config = router.configuration;
      final route = _findRouteByName(config.routes, 'lightroom');
      expect(route, isNotNull);

      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final state = GoRouterState(
        config,
        uri: Uri.parse('/settings/lightroom'),
        matchedLocation: '/settings/lightroom',
        fullPath: '/settings/lightroom',
        pathParameters: const {},
        pageKey: const ValueKey('/settings/lightroom'),
      );

      addTearDown(() => lightroomUiEnabled = false);

      lightroomUiEnabled = false;
      expect(
        await route!.redirect!(capturedContext, state),
        '/settings/media-sources',
      );

      lightroomUiEnabled = true;
      expect(await route.redirect!(capturedContext, state), isNull);
    });
  });

  group('settings sections are pushed as animated child routes', () {
    // Settings sub-sections used to navigate two different ways. Sections
    // with a dedicated route (Appearance -> /settings/appearance) push a
    // child GoRoute, which go_router wraps in a platform-adaptive
    // MaterialPage, so they slide in. Sections without one (About, Units,
    // Data, ...) pushed '/settings?selected=<id>', which re-matches the
    // '/settings' route itself -- a bottom-nav tab root whose pageBuilder
    // returns a NoTransitionPage. Correct for switching tabs, but it made
    // those sections snap into place with no animation.
    //
    // The fix gives them a real child route. It deliberately does not make
    // '/settings' itself animate when '?selected=' is present: the desktop
    // master-detail pane navigates with go() (a stable pageKey), so swapping
    // the page type under the same key would fail Page.canUpdate's
    // runtimeType check and slide the whole split view on every click.
    test('equipment condition settings live under the safety route', () {
      // Equipment condition is reached from Settings > Safety, not from the
      // settings root, so its route nests under /settings/safety.
      expect(
        router.namedLocation('equipmentConditionSettings'),
        '/settings/safety/equipment-condition',
      );
    });

    testWidgets('the equipment condition route builds its settings page', (
      tester,
    ) async {
      final config = router.configuration;
      final route = _findRouteByName(
        config.routes,
        'equipmentConditionSettings',
      );
      expect(route, isNotNull);

      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final state = GoRouterState(
        config,
        uri: Uri.parse('/settings/safety/equipment-condition'),
        matchedLocation: '/settings/safety/equipment-condition',
        fullPath: '/settings/safety/equipment-condition',
        pathParameters: const {},
        pageKey: const ValueKey('/settings/safety/equipment-condition'),
      );
      final widget = route!.builder!(capturedContext, state);
      expect(widget.runtimeType.toString(), 'EquipmentConditionSettingsPage');
    });

    test('a section child route exists under /settings', () {
      final route = _findRouteByName(
        router.configuration.routes,
        'settingsSection',
      );
      expect(route, isNotNull);
      expect(route!.path, 'section/:sectionId');
    });

    test('the section route uses builder, so go_router animates it', () {
      final route = _findRouteByName(
        router.configuration.routes,
        'settingsSection',
      );
      expect(route, isNotNull);
      expect(
        route!.builder,
        isNotNull,
        reason:
            'builder lets go_router pick the platform-adaptive MaterialPage, '
            'which is what makes /settings/appearance slide in.',
      );
      expect(
        route.pageBuilder,
        isNull,
        reason:
            'a custom pageBuilder here would risk reintroducing the '
            'NoTransitionPage that suppressed the animation.',
      );
    });

    testWidgets('the section route redirects ids that have a page of their '
        'own', (tester) async {
      // SettingsSectionDetailPage supplies a Scaffold and an AppBar, so a
      // deep link to /settings/section/safety would stack a second app bar
      // on top of SafetySettingsPage's. Fixing only the list tile leaves the
      // URL reachable; the route itself has to normalize it.
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final route = _findRouteByName(
        router.configuration.routes,
        'settingsSection',
      );
      expect(route, isNotNull);
      expect(route!.redirect, isNotNull);

      Future<String?> redirectFor(String sectionId) async {
        return route.redirect!(
          capturedContext,
          GoRouterState(
            router.configuration,
            uri: Uri.parse('/settings/section/$sectionId'),
            matchedLocation: '/settings/section/$sectionId',
            fullPath: '/settings/section/:sectionId',
            pathParameters: {'sectionId': sectionId},
            pageKey: ValueKey('/settings/section/$sectionId'),
          ),
        );
      }

      // Sections whose content is its own Scaffold with its own AppBar.
      expect(await redirectFor('safety'), '/settings/safety');
      expect(await redirectFor('debug'), '/settings/debug-logs');
      expect(await redirectFor('profile'), '/settings/diver-profile');
      // Has a dedicated page too, so the route stays canonical.
      expect(await redirectFor('appearance'), '/settings/appearance');

      // Genuine section content belongs in the wrapper and must not redirect.
      expect(await redirectFor('about'), isNull);
      expect(await redirectFor('units'), isNull);
      expect(
        await redirectFor('security'),
        isNull,
        reason:
            'SecuritySettingsPage returns plain content and relies on the '
            "wrapper's Scaffold for its snackbars",
      );
    });

    testWidgets('the section route passes its path parameter through', (
      tester,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final route = _findRouteByName(
        router.configuration.routes,
        'settingsSection',
      );
      expect(route, isNotNull);

      final widget = route!.builder!(
        capturedContext,
        GoRouterState(
          router.configuration,
          uri: Uri.parse('/settings/section/about'),
          matchedLocation: '/settings/section/about',
          fullPath: '/settings/section/:sectionId',
          pathParameters: const {'sectionId': 'about'},
          pageKey: const ValueKey('/settings/section/about'),
        ),
      );

      expect(widget, isA<SettingsSectionDetailPage>());
      expect((widget as SettingsSectionDetailPage).sectionId, 'about');
    });

    testWidgets('the settings tab root itself still has no transition', (
      tester,
    ) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final route = _findRouteByName(router.configuration.routes, 'settings');
      expect(route, isNotNull);
      expect(route!.pageBuilder, isNotNull);

      final page = route.pageBuilder!(
        capturedContext,
        GoRouterState(
          router.configuration,
          uri: Uri.parse('/settings'),
          matchedLocation: '/settings',
          fullPath: '/settings',
          pathParameters: const {},
          pageKey: const ValueKey('/settings'),
        ),
      );

      expect(
        page,
        isA<NoTransitionPage<dynamic>>(),
        reason:
            '/settings is a bottom-nav destination; switching tabs must not '
            'animate, matching every other tab root.',
      );
    });
  });

  group('explore route', () {
    test('is registered under the dive list', () {
      final route = _findRouteByName(router.configuration.routes, 'explore');
      expect(route, isNotNull);
      expect(route!.path, 'explore');
    });
  });

  // #2773: Advanced Search became the Refine panel; an old link or a
  // bookmark lands on the dive list with its search row open, including on
  // a cold start, when the redirect runs while the tree builds.
  group('diveSearch route redirects to the dive list', () {
    for (final location in ['/dives/search', '/dives/search?section=query']) {
      testWidgets('a cold start at $location opens the search row', (
        tester,
      ) async {
        final route = _findRouteByName(
          router.configuration.routes,
          'diveSearch',
        )!;
        expect(route.redirect, same(redirectRetiredDiveSearch));
        final coldStart = GoRouter(
          initialLocation: location,
          routes: [
            GoRoute(
              path: '/dives',
              builder: (context, _) => Consumer(
                builder: (context, ref, _) =>
                    Text('open=${ref.watch(diveSearchBarOpenProvider)}'),
              ),
              routes: [
                GoRoute(path: 'search', redirect: redirectRetiredDiveSearch),
              ],
            ),
          ],
        );
        addTearDown(coldStart.dispose);
        await tester.pumpWidget(
          ProviderScope(child: MaterialApp.router(routerConfig: coldStart)),
        );
        await tester.pumpAndSettle();
        expect(find.text('open=true'), findsOneWidget);
      });
    }
  });
  group('species routes', () {
    test('the Species page is registered at /species', () {
      final route = _findRouteByName(router.configuration.routes, 'species');
      expect(route, isNotNull);
      expect(route!.path, '/species');
    });

    test('the catalog manager is the manage child, declared before the '
        'species id parameter', () {
      final species = _findRouteByName(router.configuration.routes, 'species');
      final paths = _orderedRoutePaths(species!.routes);
      expect(paths, contains('manage'));
      expect(paths.indexOf('manage'), lessThan(paths.indexOf(':speciesId')));

      final manage = _findRouteByName(species.routes, 'speciesManage');
      expect(manage, isNotNull);
      expect(manage!.path, 'manage');
    });

    test('the species route lives inside the nav shell', () {
      final shells = router.configuration.routes.whereType<ShellRoute>();
      expect(shells, isNotEmpty);
      expect(
        shells.any(
          (shell) => _findRouteByName(shell.routes, 'species') != null,
        ),
        isTrue,
        reason:
            'Species is a nav destination, so its page must render inside '
            'MainScaffold rather than replacing the rail and bottom bar.',
      );
    });

    testWidgets('the species route has no transition', (tester) async {
      late BuildContext capturedContext;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Builder(
            builder: (context) {
              capturedContext = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      final route = _findRouteByName(router.configuration.routes, 'species');
      expect(route, isNotNull);
      expect(route!.pageBuilder, isNotNull);

      final page = route.pageBuilder!(
        capturedContext,
        GoRouterState(
          router.configuration,
          uri: Uri.parse('/species'),
          matchedLocation: '/species',
          fullPath: '/species',
          pathParameters: const {},
          pageKey: const ValueKey('/species'),
        ),
      );

      expect(
        page,
        isA<NoTransitionPage<dynamic>>(),
        reason:
            '/species is a nav destination reached with go, so switching to '
            'it must not animate the way a pushed page does.',
      );
      expect((page as NoTransitionPage).child, isA<SpeciesPage>());
    });
  });

  group('storage usage', () {
    test('the unrecognized backups page is reachable at the pushed path', () {
      // UnrecognizedBackupsNotice pushes an absolute location. Nothing else
      // ties that string to the route tree, so a rename on either side is a
      // runtime "no routes for location" and nothing before that.
      expect(
        _locationOfRoute(router.configuration.routes, 'unrecognizedBackups'),
        UnrecognizedBackupsNotice.routeLocation,
      );
    });
  });

  group('site detail sections route', () {
    test('resolves to the path the Sites appearance row pushes', () {
      expect(
        _locationOfRoute(router.configuration.routes, 'siteDetailSections'),
        '/settings/site-detail-sections',
      );
    });

    testWidgets('builds the site detail sections page', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final context = tester.element(find.byType(SizedBox));
      final config = router.configuration;
      final route = _findRouteByName(config.routes, 'siteDetailSections');
      expect(route, isNotNull);

      const location = '/settings/site-detail-sections';
      final state = GoRouterState(
        config,
        uri: Uri.parse(location),
        matchedLocation: location,
        fullPath: location,
        pathParameters: const {},
        pageKey: const ValueKey(location),
      );
      expect(route!.builder!(context, state), isA<SiteDetailSectionsPage>());
    });
  });
}
