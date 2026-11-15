import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_withdrawal.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_detail_header.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
import 'package:submersion/shared/widgets/country_flag.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  SiteTypeEntity builtIn(String id) => SiteTypeEntity(
    id: id,
    name: id,
    isBuiltIn: true,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Future<void> pumpHeader(
    WidgetTester tester,
    DiveSite site, {
    List<SiteTypeEntity> types = const [],
    double? width,
    bool flags = true,
    CatalogueSite? catalogueSite,
    CatalogueSource? catalogueSource,
    CatalogueWithdrawal? withdrawal,
    Future<CatalogueWithdrawal?>? withdrawalFuture,
    Future<CatalogueSite?>? catalogueSiteFuture,
    List<String>? withdrawalsAsked,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          siteTypesForSiteProvider(site.id).overrideWith((_) async => types),
          showCountryFlagsProvider.overrideWithValue(flags),
          catalogueSiteProvider.overrideWith(
            (ref, id) => catalogueSiteFuture ?? Future.value(catalogueSite),
          ),
          catalogueSourceProvider.overrideWith(
            (ref, key) async => catalogueSource,
          ),
          catalogueWithdrawalProvider.overrideWith((ref, id) {
            withdrawalsAsked?.add(id);
            return withdrawalFuture ?? Future.value(withdrawal);
          }),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: width == null
                ? SiteDetailHeader(site: site)
                : SizedBox(
                    width: width,
                    child: SiteDetailHeader(site: site),
                  ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const bare = DiveSite(id: 'site-1', name: 'Blue Hole');

  testWidgets('the name reads in the page headline style', (tester) async {
    await pumpHeader(tester, bare);

    final name = tester.widget<Text>(find.text('Blue Hole'));
    final headline = Theme.of(
      tester.element(find.text('Blue Hole')),
    ).textTheme.headlineSmall;
    expect(name.style?.fontSize, headline?.fontSize);
  });

  testWidgets('a rated site shows its stars and the value', (tester) async {
    await pumpHeader(tester, bare.copyWith(rating: 4));

    expect(find.byIcon(Icons.star), findsNWidgets(4));
    expect(find.byIcon(Icons.star_border), findsOneWidget);
    // A whole-star rating reads like a dive's, not "4.0" (#4573).
    expect(find.text('4'), findsOneWidget);
    expect(find.text('4.0'), findsNothing);
  });

  testWidgets('a fraction of a star counts the way the Rating card does', (
    tester,
  ) async {
    // The Rating card fills a star for any part of one (index < rating), so
    // an imported 4.4 reads as five there. The summary must not contradict
    // the card it summarizes.
    await pumpHeader(tester, bare.copyWith(rating: 4.4));

    expect(find.byIcon(Icons.star), findsNWidgets(5));
    expect(find.byIcon(Icons.star_border), findsNothing);
  });

  testWidgets('the rating gives way instead of overflowing when squeezed', (
    tester,
  ) async {
    // Narrower than any pane the app lays out, so the stars and the value
    // cannot all sit on one line: the row has to wrap rather than paint an
    // overflow stripe. Guards the fixed-size star icons against a future
    // layout, or a large text scale, that leaves them less room.
    await pumpHeader(tester, bare.copyWith(rating: 4), width: 150);

    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.star), findsNWidgets(4));
  });

  testWidgets('an unrated site shows no stars at all', (tester) async {
    await pumpHeader(tester, bare);

    expect(find.byIcon(Icons.star), findsNothing);
    expect(find.byIcon(Icons.star_border), findsNothing);
  });

  testWidgets('the location line reads locality, region and country', (
    tester,
  ) async {
    await pumpHeader(
      tester,
      bare.copyWith(city: 'Dahab', region: 'South Sinai', country: 'Egypt'),
    );

    expect(find.text('Dahab · South Sinai, Egypt'), findsOneWidget);
  });

  testWidgets('a site with no location shows no location line', (tester) async {
    await pumpHeader(tester, bare);

    expect(find.byIcon(Icons.location_on_outlined), findsNothing);
  });

  group('country flag (issue #4426)', () {
    testWidgets('a stored code shows its flag for unread text', (tester) async {
      await pumpHeader(
        tester,
        bare.copyWith(region: 'Jeju', country: 'Korea', countryCode: 'KR'),
      );

      expect(tester.widget<CountryFlag>(find.byType(CountryFlag)).code, 'KR');
    });

    final egypt = bare.copyWith(
      city: 'Dahab',
      region: 'South Sinai',
      country: 'Egypt',
    );

    testWidgets('the flag takes the place of the pin', (tester) async {
      await pumpHeader(tester, egypt);

      expect(tester.widget<CountryFlag>(find.byType(CountryFlag)).code, 'EG');
      expect(find.byIcon(Icons.location_on_outlined), findsNothing);
      expect(find.text('Dahab · South Sinai, Egypt'), findsOneWidget);
    });

    testWidgets('the pin comes back when flags are off', (tester) async {
      await pumpHeader(tester, egypt, flags: false);

      expect(find.byType(CountryFlag), findsNothing);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    });

    testWidgets('the pin stays for a country it cannot name', (tester) async {
      await pumpHeader(tester, egypt.copyWith(country: 'Atlantis'));

      expect(find.byType(CountryFlag), findsNothing);
      expect(find.byIcon(Icons.location_on_outlined), findsOneWidget);
    });
  });

  testWidgets('chips name the site types, difficulty and water type', (
    tester,
  ) async {
    await pumpHeader(
      tester,
      bare.copyWith(
        difficulty: SiteDifficulty.intermediate,
        waterType: WaterType.salt,
      ),
      types: [builtIn('wreck')],
    );

    expect(find.text('Wreck'), findsOneWidget);
    expect(find.text('Intermediate'), findsOneWidget);
    expect(find.text('Salt Water'), findsOneWidget);
  });

  testWidgets('a site type built-in reads its translated name', (tester) async {
    await pumpHeader(tester, bare, types: [builtIn('wreck')]);

    // Stored under its English slug name, shown through the l10n lookup.
    expect(find.text('wreck'), findsNothing);
    expect(find.text('Wreck'), findsOneWidget);
  });

  testWidgets('a site with nothing to classify it shows no chips', (
    tester,
  ) async {
    await pumpHeader(tester, bare);

    expect(find.byType(Chip), findsNothing);
  });
  group('a site adopted from the built-in catalogue', () {
    const osm = CatalogueSource(
      key: 'osm',
      name: 'OpenStreetMap',
      licence: 'ODbL-1.0',
      credit: 'OpenStreetMap contributors',
    );
    const adopted = DiveSite(
      id: 's1',
      name: 'Salt Pier',
      catalogueId: 'osm_node_1',
    );

    testWidgets('credits where it came from', (tester) async {
      await pumpHeader(
        tester,
        adopted,
        catalogueSite: const CatalogueSite(
          id: 'osm_node_1',
          name: 'Salt Pier',
          source: 'osm',
        ),
        catalogueSource: osm,
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'From the built-in site catalogue. Source: OpenStreetMap '
          'contributors',
        ),
        findsOneWidget,
      );
      expect(find.text('Website'), findsNothing);
    });

    testWidgets('links the website the catalogue holds', (tester) async {
      await pumpHeader(
        tester,
        adopted,
        catalogueSite: const CatalogueSite(
          id: 'osm_node_1',
          name: 'Salt Pier',
          website: 'https://example.org/salt-pier',
          source: 'osm',
        ),
        catalogueSource: osm,
      );
      await tester.pumpAndSettle();

      expect(find.text('Website'), findsOneWidget);
    });

    testWidgets('does not link a website that is not a web address', (
      tester,
    ) async {
      await pumpHeader(
        tester,
        adopted,
        catalogueSite: const CatalogueSite(
          id: 'osm_node_1',
          name: 'Salt Pier',
          website: 'intent://scan/#Intent;scheme=zxing;end',
          source: 'osm',
        ),
        catalogueSource: osm,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('built-in site catalogue'), findsOneWidget);
      expect(find.text('Website'), findsNothing);
    });

    group('a withdrawn record', () {
      CatalogueWithdrawal withdrawn(
        CatalogueWithdrawalReason reason, {
        String? replacedBy,
      }) => CatalogueWithdrawal(
        id: 'osm_node_1',
        reason: reason,
        date: '2026-12-02',
        replacedBy: replacedBy,
      );

      for (final (reason, text) in [
        (
          CatalogueWithdrawalReason.position,
          'Built-in record withdrawn: its position was wrong.',
        ),
        (
          CatalogueWithdrawalReason.notASite,
          'Built-in record withdrawn: it is not a dive site.',
        ),
        (
          CatalogueWithdrawalReason.duplicate,
          'Built-in record withdrawn: it listed a site twice.',
        ),
        (CatalogueWithdrawalReason.other, 'Built-in record withdrawn.'),
      ]) {
        testWidgets('says why: ${reason.name}', (tester) async {
          await pumpHeader(tester, adopted, withdrawal: withdrawn(reason));

          expect(find.text(text), findsOneWidget);
          expect(find.text('See the corrected record'), findsNothing);
          expect(find.textContaining('built-in site catalogue'), findsNothing);
        });
      }

      testWidgets('offers the corrected record when there is one', (
        tester,
      ) async {
        await pumpHeader(
          tester,
          adopted,
          withdrawal: withdrawn(
            CatalogueWithdrawalReason.position,
            replacedBy: 'research_my_south_point_2',
          ),
        );

        expect(find.text('See the corrected record'), findsOneWidget);
      });

      testWidgets('the corrected record opens its built-in page', (
        tester,
      ) async {
        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) =>
                  const Scaffold(body: SiteDetailHeader(site: adopted)),
            ),
            GoRoute(
              path: '/sites/catalogue/:id',
              builder: (context, state) =>
                  Text('page ${state.pathParameters['id']}'),
            ),
          ],
        );
        addTearDown(router.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              siteTypesForSiteProvider(
                adopted.id,
              ).overrideWith((_) async => const []),
              showCountryFlagsProvider.overrideWithValue(true),
              catalogueSiteProvider.overrideWith((ref, id) async => null),
              catalogueSourceProvider.overrideWith((ref, key) async => null),
              catalogueWithdrawalProvider.overrideWith(
                (ref, id) async => withdrawn(
                  CatalogueWithdrawalReason.position,
                  // Not path-safe: the link keeps it one path segment.
                  replacedBy: 'research_my_x/2',
                ),
              ),
            ],
            child: MaterialApp.router(
              locale: const Locale('en'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('See the corrected record'));
        await tester.pumpAndSettle();

        expect(find.text('page research_my_x/2'), findsOneWidget);
      });

      testWidgets('a record still in the catalogue shows its credit, not a '
          'withdrawal', (tester) async {
        await pumpHeader(
          tester,
          adopted,
          catalogueSite: const CatalogueSite(
            id: 'osm_node_1',
            name: 'Salt Pier',
            source: 'osm',
          ),
          catalogueSource: osm,
          withdrawal: withdrawn(CatalogueWithdrawalReason.position),
        );

        expect(find.textContaining('built-in site catalogue'), findsOneWidget);
        expect(find.textContaining('withdrawn'), findsNothing);
      });

      testWidgets('nothing shows, and nothing throws, while the catalogue is '
          'still loading', (tester) async {
        await pumpHeader(
          tester,
          adopted,
          withdrawalFuture: Completer<CatalogueWithdrawal?>().future,
        );

        expect(tester.takeException(), isNull);
        expect(find.textContaining('withdrawn'), findsNothing);
      });
    });

    testWidgets('does not ask for a withdrawal while the record is still '
        'loading', (tester) async {
      final asked = <String>[];
      await pumpHeader(
        tester,
        adopted,
        catalogueSiteFuture: Completer<CatalogueSite?>().future,
        withdrawalsAsked: asked,
      );
      await tester.pump();

      expect(asked, isEmpty);
    });

    testWidgets('shows nothing once the catalogue dropped the record', (
      tester,
    ) async {
      await pumpHeader(tester, adopted, catalogueSource: osm);
      await tester.pumpAndSettle();

      expect(find.textContaining('built-in site catalogue'), findsNothing);
      expect(find.text('Website'), findsNothing);
    });

    testWidgets('a site made by hand has no credit', (tester) async {
      await pumpHeader(
        tester,
        const DiveSite(id: 's2', name: 'My Reef'),
        catalogueSite: const CatalogueSite(
          id: 'osm_node_1',
          name: 'Salt Pier',
          source: 'osm',
        ),
        catalogueSource: osm,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('built-in site catalogue'), findsNothing);
    });
  });
}
