import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// Finds a [GoRoute] by name in a route tree recursively.
GoRoute? _named(List<RouteBase> routes, String name) {
  for (final route in routes) {
    if (route is GoRoute && route.name == name) return route;
    final found = _named(route.routes, name);
    if (found != null) return found;
  }
  return null;
}

void main() {
  late ProviderContainer container;
  late GoRouter router;

  setUp(() {
    container = ProviderContainer(
      overrides: [hasAnyDiversProvider.overrideWith((ref) async => true)],
    );
    router = container.read(appRouterProvider);
  });

  tearDown(() => container.dispose());

  test('a built-in record\'s page is a route under /sites', () {
    final sites = _named(router.configuration.routes, 'sites')!;
    final page = sites.routes.whereType<GoRoute>().singleWhere(
      (route) => route.name == 'catalogueSite',
    );

    expect(page.path, 'catalogue/:catalogueId');
  });

  test('it is matched before a site id, which "catalogue" would '
      'otherwise be read as', () {
    final sites = _named(router.configuration.routes, 'sites')!;
    final children = sites.routes.whereType<GoRoute>().toList();
    final page = children.indexWhere((r) => r.name == 'catalogueSite');
    final siteDetail = children.indexWhere((r) => r.name == 'siteDetail');

    expect(page, isNonNegative);
    expect(page, lessThan(siteDetail));
  });

  test('its location resolves to the page and carries the record id', () {
    final matches = router.configuration.findMatch(
      Uri.parse('/sites/catalogue/osm_node_663869401'),
    );

    expect(matches.pathParameters['catalogueId'], 'osm_node_663869401');
    expect(matches.last.route.name, 'catalogueSite');
  });
}
