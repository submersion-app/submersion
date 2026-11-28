import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/species_display.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_color.dart';
import 'package:submersion/features/marine_life/presentation/utils/species_category_icon.dart';
import 'package:submersion/features/marine_life/presentation/widgets/site_marine_life_section.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

import 'site_marine_life_section_harness.dart';

/// The site page's Marine life card shows the site's species only: the lock
/// is the one way to change them (issue #4527, phase 2, plan 7). Its three
/// sections read as sections, each category beside its chips (issue #5128).
void main() {
  final l = AppLocalizationsEn();

  testWidgets('a species recorded nearby opens its page and adds nothing', (
    tester,
  ) async {
    final repository = await pumpCard(tester);

    expect(find.byTooltip(l.reef_species_addToExpected), findsNothing);
    await tester.tap(find.text('Whale Shark'));
    await tester.pumpAndSettle();

    expect(find.text('SPECIES sp_whale_shark'), findsOneWidget);
    expect(repository.added, isEmpty);
  });

  testWidgets('the card has no pencil of its own for the expected species', (
    tester,
  ) async {
    await pumpCard(tester);

    expect(
      find.descendant(
        of: find.byType(SiteMarineLifeSection),
        matching: find.byIcon(Icons.edit),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'the three section titles share one style, above the category labels',
    (tester) async {
      await pumpCard(
        tester,
        spotted: [spottedSummary('a', 'Blue Tang', SpeciesCategory.fish)],
        expected: [expectedEntry('b', 'Tarpon', SpeciesCategory.fish)],
      );

      final context = tester.element(find.byType(SiteMarineLifeSection));
      final onSurface = Theme.of(context).colorScheme.onSurface;
      final spotted = renderedStyle(
        tester,
        l.marineLife_siteSection_spottedHere,
      );
      final expectedTitle = renderedStyle(
        tester,
        l.marineLife_siteSection_expectedSpecies,
      );
      final nearby = renderedStyle(tester, l.reef_species_recordedNearby);
      final category = renderedStyle(
        tester,
        SpeciesCategory.fish.localizedName(l),
      );

      for (final title in [spotted, expectedTitle, nearby]) {
        expect(title.fontSize, spotted.fontSize);
        expect(title.fontWeight, spotted.fontWeight);
        expect(title.color, onSurface);
      }
      expect(spotted.fontSize, greaterThan(category.fontSize!));
      // One casing too, as the page's other sub-section titles have it.
      for (final title in [
        l.marineLife_siteSection_spottedHere,
        l.marineLife_siteSection_expectedSpecies,
        l.reef_species_recordedNearby,
      ]) {
        expect(title, title[0] + title.substring(1).toLowerCase());
      }
      // Each title is a heading for assistive tech too, its count read
      // with it rather than as a bare number after it.
      expect(
        tester.getSemantics(find.text(l.marineLife_siteSection_spottedHere)),
        matchesSemantics(
          label: '${l.marineLife_siteSection_spottedHere}\n1',
          isHeader: true,
        ),
      );
    },
  );

  testWidgets('each section title counts the species under it', (tester) async {
    await pumpCard(
      tester,
      spotted: [
        spottedSummary('a', 'Blue Tang', SpeciesCategory.fish, count: 4),
        spottedSummary('b', 'Trumpetfish', SpeciesCategory.fish),
        spottedSummary('c', 'Green Sea Turtle', SpeciesCategory.turtle),
      ],
      expected: [
        expectedEntry('d', 'Tarpon', SpeciesCategory.fish),
        expectedEntry('e', 'Hawksbill Turtle', SpeciesCategory.turtle),
      ],
    );

    expect(
      find.descendant(
        of: tierHeader(l.marineLife_siteSection_spottedHere),
        matching: find.text('3'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tierHeader(l.marineLife_siteSection_expectedSpecies),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tierHeader(l.reef_species_recordedNearby),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a spotted chip is announced once, with its count in words', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpCard(
      tester,
      spotted: [
        spottedSummary('a', 'Blue Tang', SpeciesCategory.fish, count: 4),
      ],
    );

    expect(
      find.bySemanticsLabel(
        l.marineLife_siteSection_spottedCountSemantics('Blue Tang', 4),
      ),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Blue Tang (4)'), findsNothing);
    handle.dispose();
  });

  testWidgets('a section that fails to load counts nothing', (tester) async {
    // A refresh that fails keeps the last species in the value it reports,
    // under the error the section shows.
    final failing = StateProvider((ref) => false);
    final container = ProviderContainer(
      overrides: [
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
        siteSpottedSpeciesProvider('site-1').overrideWith((ref) async {
          if (ref.watch(failing)) throw StateError('offline');
          return [
            spottedSummary('a', 'Blue Tang', SpeciesCategory.fish),
            spottedSummary('b', 'Tarpon', SpeciesCategory.fish),
          ];
        }),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SiteMarineLifeSection(siteId: 'site-1', species: []),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: tierHeader(l.marineLife_siteSection_spottedHere),
        matching: find.text('2'),
      ),
      findsOneWidget,
    );

    container.read(failing.notifier).state = true;
    await tester.pumpAndSettle();

    expect(
      find.text(l.marineLife_siteSection_errorLoadingSightings),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: tierHeader(l.marineLife_siteSection_spottedHere),
        matching: find.text('2'),
      ),
      findsNothing,
    );
  });

  testWidgets('an empty section counts nothing', (tester) async {
    await pumpCard(tester);

    expect(
      find.descendant(
        of: tierHeader(l.marineLife_siteSection_spottedHere),
        matching: find.text('0'),
      ),
      findsNothing,
    );
    expect(find.text(l.marineLife_siteSection_noSpotted), findsOneWidget);
  });

  testWidgets('a divider separates each section from the next', (tester) async {
    await pumpCard(tester);

    expect(
      find.descendant(
        of: find.byType(SiteMarineLifeSection),
        matching: find.byType(Divider),
      ),
      findsNWidgets(2),
    );
  });

  testWidgets('no divider is left for a nearby tier that draws nothing', (
    tester,
  ) async {
    await pumpCard(tester, nearby: null);

    expect(find.text(l.reef_species_recordedNearby), findsNothing);
    expect(
      find.descendant(
        of: find.byType(SiteMarineLifeSection),
        matching: find.byType(Divider),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a category label sits beside its chips, on their first line', (
    tester,
  ) async {
    await pumpCard(
      tester,
      spotted: [
        spottedSummary('a', 'Blue Tang', SpeciesCategory.fish),
        spottedSummary('b', 'Trumpetfish', SpeciesCategory.fish),
        spottedSummary('c', 'Green Sea Turtle', SpeciesCategory.turtle),
      ],
    );

    final fishLabel = tester.getRect(
      find.text(SpeciesCategory.fish.localizedName(l)),
    );
    final turtleLabel = tester.getRect(
      find.text(SpeciesCategory.turtle.localizedName(l)),
    );
    final blueTang = chipRect(tester, 'Blue Tang (1)');
    final turtle = chipRect(tester, 'Green Sea Turtle (1)');

    // Beside: the label ends before its chips start.
    expect(fishLabel.right, lessThanOrEqualTo(blueTang.left));
    expect(turtleLabel.right, lessThanOrEqualTo(turtle.left));
    // On the first line: the label is level with its first chip, so a
    // category of one species takes one line, not two.
    expect(fishLabel.center.dy, closeTo(blueTang.center.dy, 4));
    expect(turtleLabel.center.dy, closeTo(turtle.center.dy, 4));
    expect(turtle.top, greaterThanOrEqualTo(blueTang.bottom));
    // Both categories' chips start in one column.
    expect(turtle.left, blueTang.left);
  });

  testWidgets('a category reads in one colour wherever the card shows it', (
    tester,
  ) async {
    await pumpCard(
      tester,
      spotted: [
        spottedSummary(
          'x',
          'Caribbean Reef Squid',
          SpeciesCategory.invertebrate,
        ),
      ],
      nearby: const NearbySpecies(
        matched: [
          MatchedNearbySpecies(speciesId: 'sp_octopus', occurrenceCount: 3),
        ],
        unmatchedNames: [],
      ),
      catalog: const [octopus],
    );

    final icons = tester
        .widgetList<Icon>(
          find.byIcon(iconForSpeciesCategory(SpeciesCategory.invertebrate)),
        )
        .toList();
    expect(icons, hasLength(2));
    final brightness = Theme.of(
      tester.element(find.byType(SiteMarineLifeSection)),
    ).brightness;
    for (final icon in icons) {
      expect(
        icon.color,
        colorForSpeciesCategory(SpeciesCategory.invertebrate, brightness),
      );
    }
  });

  testWidgets('a long list on a narrow phone lays out without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpCard(
      tester,
      spotted: [
        for (var i = 0; i < 40; i++)
          spottedSummary(
            's$i',
            'Long-named Reef Species Number $i',
            SpeciesCategory.values[i % SpeciesCategory.values.length],
            count: i + 1,
          ),
      ],
      expected: [
        for (var i = 0; i < 15; i++)
          expectedEntry(
            'e$i',
            'Expected Species $i',
            SpeciesCategory.values[i % SpeciesCategory.values.length],
          ),
      ],
    );

    expect(tester.takeException(), isNull);
    // Names too wide to sit beside the chips in a third of this card go
    // above them instead, whole, leaving the chips the card's full width.
    expect(
      find.descendant(
        of: find.byType(SiteMarineLifeSection),
        matching: find.byType(Table),
      ),
      findsNothing,
    );
    // The collapsed lists leave some categories out.
    final shownNames = SpeciesCategory.values
        .map((category) => category.localizedName(l))
        .where((name) => find.text(name).evaluate().isNotEmpty)
        .toList();
    expect(shownNames, isNotEmpty);
    for (final name in shownNames) {
      expect(isOneLine(tester, name), isTrue);
    }
  });

  testWidgets('every section starts its chips in one column', (tester) async {
    // Spotted has only a short category name, Expected a long one: the
    // chips still line up down the card.
    await pumpCard(
      tester,
      spotted: [spottedSummary('a', 'Blue Tang', SpeciesCategory.fish)],
      expected: [
        expectedEntry(
          'b',
          'Caribbean Reef Squid',
          SpeciesCategory.invertebrate,
        ),
      ],
    );

    expect(
      chipRect(tester, 'Blue Tang (1)').left,
      chipRect(tester, 'Caribbean Reef Squid').left,
    );
  });

  testWidgets('a long name on a narrow phone wraps and keeps its count', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const name = 'Caribbean Reef Squid With A Very Long Name (12)';

    await pumpCard(
      tester,
      spotted: [
        spottedSummary(
          'a',
          'Caribbean Reef Squid With A Very Long Name',
          SpeciesCategory.invertebrate,
          count: 12,
        ),
      ],
    );

    final paragraph = tester.renderObject<RenderParagraph>(find.text(name));
    // Not faded out at the chip's edge, which is how a chip cuts a label,
    // but wrapped onto a second line.
    expect(paragraph.debugHasOverflowShader, isFalse);
    expect(
      paragraph.size.height,
      greaterThan(paragraph.getMinIntrinsicHeight(double.infinity)),
    );
    expect(tester.takeException(), isNull);
  });
}
