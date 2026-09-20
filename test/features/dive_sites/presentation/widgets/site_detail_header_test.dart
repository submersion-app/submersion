import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/site_detail_header.dart';
import 'package:submersion/features/site_types/domain/entities/site_type_entity.dart';
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
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          siteTypesForSiteProvider(site.id).overrideWith((_) async => types),
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
    expect(find.text('4.0'), findsOneWidget);
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
}
