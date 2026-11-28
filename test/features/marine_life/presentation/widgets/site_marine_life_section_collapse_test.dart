import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/widgets/site_marine_life_section.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import 'site_marine_life_section_harness.dart';

/// A long Spotted, Expected or Recorded nearby list on the site's Marine
/// life card collapses to 12 species with Show all (issue #5128).
void main() {
  final l = AppLocalizationsEn();

  group('a long section collapses', () {
    testWidgets('to 12 species, with Show all and Show fewer', (tester) async {
      await pumpCard(tester, expected: expectedFish(20));

      expect(find.text('Fish 11'), findsOneWidget);
      expect(find.text('Fish 12'), findsNothing);
      final showAll = find.text(l.marineLife_speciesDetail_showAll(20));
      expect(showAll, findsOneWidget);

      await tester.ensureVisible(showAll);
      await tester.tap(showAll);
      await tester.pumpAndSettle();
      expect(find.text('Fish 19'), findsOneWidget);

      final showFewer = find.text(l.marineLife_speciesDetail_showFewer);
      await tester.ensureVisible(showFewer);
      await tester.tap(showFewer);
      await tester.pumpAndSettle();
      expect(find.text('Fish 12'), findsNothing);
      expect(find.text(l.marineLife_speciesDetail_showAll(20)), findsOneWidget);
    });

    testWidgets('not at all when it holds 12 or fewer', (tester) async {
      await pumpCard(tester, expected: expectedFish(12));

      expect(find.text('Fish 11'), findsOneWidget);
      expect(find.text(l.marineLife_speciesDetail_showAll(12)), findsNothing);
    });

    testWidgets('Spotted and Expected each on their own', (tester) async {
      await pumpCard(
        tester,
        spotted: [
          for (var i = 0; i < 14; i++)
            spottedSummary('s$i', 'Seen $i', SpeciesCategory.fish),
        ],
        expected: expectedFish(16),
      );

      expect(find.text(l.marineLife_speciesDetail_showAll(14)), findsOneWidget);
      expect(find.text(l.marineLife_speciesDetail_showAll(16)), findsOneWidget);

      final showAll = find.text(l.marineLife_speciesDetail_showAll(14));
      await tester.ensureVisible(showAll);
      await tester.tap(showAll);
      await tester.pumpAndSettle();
      expect(find.text('Seen 13 (1)'), findsOneWidget);
      expect(find.text('Fish 15'), findsNothing);
    });

    testWidgets('dropping a category the limit leaves out entirely', (
      tester,
    ) async {
      await pumpCard(
        tester,
        expected: [
          ...expectedFish(12),
          expectedEntry('t1', 'Hawksbill Turtle', SpeciesCategory.turtle),
        ],
      );

      expect(find.text(SpeciesCategory.turtle.localizedName(l)), findsNothing);
      final showAll = find.text(l.marineLife_speciesDetail_showAll(13));
      await tester.ensureVisible(showAll);
      await tester.tap(showAll);
      await tester.pumpAndSettle();
      expect(
        find.text(SpeciesCategory.turtle.localizedName(l)),
        findsOneWidget,
      );
      expect(find.text('Hawksbill Turtle'), findsOneWidget);
    });

    testWidgets('in the order the chips are drawn, grouped', (tester) async {
      // Listed fish, turtle, fish: drawn as all the fish, then the turtle.
      // The first 12 drawn are fish, so Show all adds the turtle after
      // them rather than slotting it in among those already shown.
      await pumpCard(
        tester,
        expected: [
          ...expectedFish(11),
          expectedEntry('t1', 'Hawksbill Turtle', SpeciesCategory.turtle),
          expectedEntry('f11', 'Fish 11', SpeciesCategory.fish),
          expectedEntry('f12', 'Fish 12', SpeciesCategory.fish),
        ],
      );

      expect(find.text('Fish 11'), findsOneWidget);
      expect(find.text('Hawksbill Turtle'), findsNothing);
    });

    testWidgets('Show fewer at the foot of a long list keeps it in view', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpCard(tester, expected: expectedFish(120), below: 3000);

      final showAll = find.text(l.marineLife_speciesDetail_showAll(120));
      await tester.ensureVisible(showAll);
      await tester.tap(showAll);
      await tester.pumpAndSettle();
      final showFewer = find.text(l.marineLife_speciesDetail_showFewer);
      await tester.ensureVisible(showFewer);
      await tester.pumpAndSettle();
      await tester.tap(showFewer);
      await tester.pumpAndSettle();

      final toggle = tester.getRect(
        find.text(l.marineLife_speciesDetail_showAll(120)),
      );
      expect(toggle.top, greaterThanOrEqualTo(0));
      expect(toggle.bottom, lessThanOrEqualTo(600));
    });

    testWidgets('again once it has shrunk to 12 or fewer and grown back', (
      tester,
    ) async {
      final expected = ValueNotifier(expectedFish(20));
      addTearDown(expected.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
            siteSpottedSpeciesProvider(
              'site-1',
            ).overrideWith((ref) async => const []),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ValueListenableBuilder<List<SiteSpeciesEntry>>(
                  valueListenable: expected,
                  builder: (_, species, _) =>
                      SiteMarineLifeSection(siteId: 'site-1', species: species),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final showAll = find.text(l.marineLife_speciesDetail_showAll(20));
      await tester.ensureVisible(showAll);
      await tester.tap(showAll);
      await tester.pumpAndSettle();

      expected.value = expectedFish(10);
      await tester.pumpAndSettle();
      expected.value = expectedFish(20);
      await tester.pumpAndSettle();

      expect(find.text('Fish 19'), findsNothing);
      expect(find.text(l.marineLife_speciesDetail_showAll(20)), findsOneWidget);
    });

    testWidgets('Recorded nearby: Show fewer at its foot keeps it in view', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpCard(
        tester,
        nearby: NearbySpecies(
          matched: const [],
          unmatchedNames: [for (var i = 0; i < 80; i++) 'Genus species$i'],
        ),
        below: 3000,
      );

      final showAll = find.text(l.reef_species_showAll(80));
      await tester.ensureVisible(showAll);
      await tester.tap(showAll);
      await tester.pumpAndSettle();
      final showFewer = find.text(l.reef_species_showFewer);
      await tester.ensureVisible(showFewer);
      await tester.pumpAndSettle();
      await tester.tap(showFewer);
      await tester.pumpAndSettle();

      final toggle = tester.getRect(find.text(l.reef_species_showAll(80)));
      expect(toggle.top, greaterThanOrEqualTo(0));
      expect(toggle.bottom, lessThanOrEqualTo(600));
    });

    testWidgets('with every toggle at the same edge, right-to-left too', (
      tester,
    ) async {
      await pumpCard(
        tester,
        locale: const Locale('he'),
        expected: expectedFish(14),
        nearby: NearbySpecies(
          matched: const [],
          unmatchedNames: [for (var i = 0; i < 20; i++) 'Genus species$i'],
        ),
      );

      final toggles = tester
          .widgetList<TextButton>(find.byType(TextButton))
          .map((b) => tester.getRect(find.byWidget(b)))
          .toList();
      expect(toggles, hasLength(2));
      expect(toggles.first.left, toggles.last.left);
    });

    testWidgets('again when another site opens in the same card', (
      tester,
    ) async {
      final siteId = ValueNotifier('site-1');
      addTearDown(siteId.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
            for (final id in ['site-1', 'site-2'])
              siteSpottedSpeciesProvider(
                id,
              ).overrideWith((ref) async => const []),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ValueListenableBuilder<String>(
                  valueListenable: siteId,
                  builder: (_, id, _) => SiteMarineLifeSection(
                    siteId: id,
                    species: expectedFish(20),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final showAll = find.text(l.marineLife_speciesDetail_showAll(20));
      await tester.ensureVisible(showAll);
      await tester.tap(showAll);
      await tester.pumpAndSettle();
      expect(find.text('Fish 19'), findsOneWidget);

      siteId.value = 'site-2';
      await tester.pumpAndSettle();
      expect(find.text('Fish 19'), findsNothing);
      expect(find.text(l.marineLife_speciesDetail_showAll(20)), findsOneWidget);
    });
  });
}
