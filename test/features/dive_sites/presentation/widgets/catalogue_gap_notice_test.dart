import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_gap_field.dart';
import 'package:submersion/features/dive_sites/domain/catalogue_gaps/catalogue_pair.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_gap_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_gap_notice.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/mock_providers.dart';

CataloguePair _pair(String siteId) => CataloguePair(
  site: DiveSite(id: siteId, name: 'Site $siteId', catalogueId: 'r_$siteId'),
  record: CatalogueSite(id: 'r_$siteId', name: 'Site $siteId', source: 'osm'),
  kind: CataloguePairKind.linked,
  fields: const {CatalogueGapField.depth},
);

final _pairs = StateProvider<List<CataloguePair>>((ref) => const []);

void main() {
  late ProviderContainer container;
  late GoRouter router;

  Future<void> pump(
    WidgetTester tester, {
    required List<CataloguePair> pairs,
    Size size = const Size(390, 844),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentDiverIdProvider.overrideWith(
          (ref) => MockCurrentDiverIdNotifier(),
        ),
        _pairs.overrideWith((ref) => pairs),
        catalogueGapPairsProvider.overrideWith(
          (ref) async => ref.watch(_pairs),
        ),
      ],
    );
    addTearDown(container.dispose);
    router = GoRouter(
      initialLocation: '/sites',
      routes: [
        GoRoute(
          path: '/sites',
          builder: (_, _) => const Scaffold(
            body: Column(children: [CatalogueGapNotice(), Text('the list')]),
          ),
          routes: [
            GoRoute(
              path: 'catalogue-review',
              builder: (_, _) => const Scaffold(body: Text('review page')),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const text = 'Built-in details are available for your sites';

  testWidgets('says how many sites have details waiting', (tester) async {
    await pump(tester, pairs: [_pair('a'), _pair('b')]);

    expect(find.text('$text (2)'), findsOneWidget);
    expect(find.text('Review'), findsOneWidget);
  });

  testWidgets('takes no room when there is nothing to say', (tester) async {
    await pump(tester, pairs: const []);

    expect(find.textContaining(text), findsNothing);
    expect(tester.getSize(find.byType(CatalogueGapNotice)).height, 0);
  });

  testWidgets('Review opens the review list', (tester) async {
    await pump(tester, pairs: [_pair('a')]);

    await tester.tap(find.text('Review'));
    await tester.pumpAndSettle();

    expect(find.text('review page'), findsOneWidget);
  });

  testWidgets('dismissing hides it, and it stays away', (tester) async {
    await pump(tester, pairs: [_pair('a')]);

    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();

    expect(find.textContaining(text), findsNothing);
    expect(container.read(catalogueGapNoticeSeenProvider), {_pair('a').key});
  });

  testWidgets('it returns when a new pair appears', (tester) async {
    await pump(tester, pairs: [_pair('a')]);
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pumpAndSettle();

    container.read(_pairs.notifier).state = [_pair('a'), _pair('b')];
    await tester.pumpAndSettle();

    expect(find.text('$text (2)'), findsOneWidget);
  });

  testWidgets('a long translation wraps on a narrow phone', (tester) async {
    await pump(tester, pairs: [_pair('a')], size: const Size(320, 700));

    expect(tester.takeException(), isNull);
    expect(find.text('Review'), findsOneWidget);
  });
}
