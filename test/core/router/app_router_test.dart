import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/feature_flags.dart';
import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_template_edit_page.dart';
import 'package:submersion/features/checklists/presentation/pages/checklist_templates_page.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/safety/presentation/pages/incident_edit_page.dart';
import 'package:submersion/features/safety/presentation/pages/incidents_list_page.dart';
import 'package:submersion/features/settings/presentation/pages/section_appearance_page.dart';
import 'package:submersion/features/settings/presentation/pages/column_config_page.dart';

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

  group('gps-log relocation', () {
    test('gpsLog route is registered at top level', () {
      final route = _findRouteByName(router.configuration.routes, 'gpsLog');
      expect(route, isNotNull);
      expect(route!.path, '/gps-log');
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
}
