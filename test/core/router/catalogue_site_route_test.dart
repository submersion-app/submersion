import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/features/dive_sites/presentation/catalogue_site_display.dart';
import 'package:submersion/features/dive_sites/presentation/pages/catalogue_site_page.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_import_page.dart';
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

  test('an id that is not path-safe comes back as it went in', () {
    const id = 'researched/blue hole?v=2#a';

    final matches = router.configuration.findMatch(
      Uri.parse(catalogueSitePath(id)),
    );

    expect(matches.last.route.name, 'catalogueSite');
    expect(matches.pathParameters['catalogueId'], id);
  });

  group('the route builders', () {
    Future<BuildContext> aContext(WidgetTester tester) async {
      late BuildContext captured;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              captured = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      return captured;
    }

    Widget build(
      BuildContext context,
      String name,
      String location, {
      required String fullPath,
      Map<String, String> pathParameters = const {},
    }) => _named(router.configuration.routes, name)!.builder!(
      context,
      GoRouterState(
        router.configuration,
        uri: Uri.parse(location),
        matchedLocation: Uri.parse(location).path,
        fullPath: fullPath,
        pathParameters: pathParameters,
        pageKey: ValueKey(location),
      ),
    );

    testWidgets('catalogueSite builds the page for the record in the path', (
      tester,
    ) async {
      final context = await aContext(tester);

      final page =
          build(
                context,
                'catalogueSite',
                '/sites/catalogue/ukho_1',
                fullPath: '/sites/catalogue/:catalogueId',
                pathParameters: const {'catalogueId': 'ukho_1'},
              )
              as CatalogueSitePage;

      expect(page.catalogueId, 'ukho_1');
    });

    testWidgets('importSite hands the page the search in the URL', (
      tester,
    ) async {
      final context = await aContext(tester);
      SiteImportPage at(String location) =>
          build(context, 'importSite', location, fullPath: '/sites/import')
              as SiteImportPage;

      // As the Sites search row writes it.
      final handedOver = Uri(
        path: '/sites/import',
        queryParameters: {'q': 'blue hole'},
      ).toString();
      expect(at(handedOver).initialQuery, 'blue hole');
      expect(at('/sites/import').initialQuery, isNull);
    });
  });
}
