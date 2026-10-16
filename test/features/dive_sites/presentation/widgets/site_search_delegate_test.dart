import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/features/dive_sites/domain/constants/site_field.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_list_content.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/shared/models/entity_card_view_config.dart';
import 'package:submersion/shared/providers/entity_card_config_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _config = EntityCardViewConfig<SiteField>(
  slots: [
    EntityCardSlotConfig(slotId: 'title', field: SiteField.siteName),
    EntityCardSlotConfig(slotId: 'subtitle', field: SiteField.location),
    EntityCardSlotConfig(slotId: 'stat1', field: SiteField.depthRange),
    EntityCardSlotConfig(slotId: 'stat2', field: SiteField.diveCount),
  ],
);

const _site = DiveSite(
  id: 's1',
  name: 'Österreich - Fernsteinsee',
  country: 'Österreich',
  region: 'Tirol',
);

Future<List<dynamic>> _overrides({required int diveCount}) async => [
  ...await getBaseOverrides(),
  siteDetailedCardConfigProvider.overrideWith(
    (ref) => EntityCardConfigNotifier<SiteField>(
      defaultConfig: _config,
      fieldFromName: SiteFieldAdapter.instance.fieldFromName,
    ),
  ),
  showMapBackgroundOnSiteCardsProvider.overrideWithValue(false),
  // Both search providers answer, so the test pins which one the delegate is
  // actually reading rather than merely whether it renders a tile.
  siteSearchProvider.overrideWith((ref, query) async => [_site]),
  siteSearchWithDiveCountProvider.overrideWith(
    (ref, query) async => [
      SiteWithDiveCount(site: _site, diveCount: diveCount),
    ],
  ),
];

void main() {
  /// Opens the site search from a routed page, as the site list does.
  Future<void> openRouted(WidgetTester tester, {int diveCount = 4}) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Consumer(
              builder: (context, ref, _) => ElevatedButton(
                onPressed: () => showSearch(
                  context: context,
                  delegate: SiteSearchDelegate(ref),
                ),
                child: const Text('open search'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/sites/:id',
          builder: (context, state) => Scaffold(
            appBar: AppBar(),
            body: Text('detail ${state.pathParameters['id']}'),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      testAppRouter(
        router: router,
        locale: const Locale('en'),
        overrides: await _overrides(diveCount: diveCount),
      ),
    );
    await tester.tap(find.text('open search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'öste');
    // Clear the DebouncedSearchResults debounce before settling.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
  }

  // Issue #3377: the results fabricated `SiteWithDiveCount(diveCount: 0)`, so
  // every hit claimed the site had no dives.
  testWidgets('search results show the site real dive count', (tester) async {
    await openRouted(tester, diveCount: 4);

    expect(find.text('Österreich - Fernsteinsee'), findsOneWidget);
    expect(find.text('4 dives'), findsOneWidget);
  });

  // Issue #3377: a tapped result closed the search before opening the site,
  // so back from the site landed on the full list, not the results.
  testWidgets('back from an opened result returns to the search results', (
    tester,
  ) async {
    await openRouted(tester);

    await tester.tap(find.text('Österreich - Fernsteinsee'));
    await tester.pumpAndSettle();
    expect(find.text('detail s1'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('Österreich - Fernsteinsee'), findsOneWidget);
    expect(find.text('open search'), findsNothing);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller?.text, 'öste');
  });
}
