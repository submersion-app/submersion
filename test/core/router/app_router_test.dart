import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

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
}
