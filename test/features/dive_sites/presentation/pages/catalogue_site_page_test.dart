import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/core/utils/coordinates/coordinate_format.dart';
import 'package:submersion/features/dive_sites/domain/entities/catalogue_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_catalogue_answers.dart';
import 'package:submersion/features/dive_sites/domain/entities/site_with_dive_count.dart';
import 'package:submersion/features/dive_sites/presentation/pages/catalogue_site_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_catalogue_providers.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_page/catalogue_about_card.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_page/catalogue_location_card.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_page/catalogue_nearby_card.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_page/catalogue_site_map_strip.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/catalogue_page/catalogue_source_card.dart';
import 'package:submersion/features/reef/presentation/widgets/reef_section.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/tides/presentation/widgets/tide_section.dart';

import 'catalogue_site_page_harness.dart';

const _addAction = ValueKey('catalogueAddAction');
const _addButton = ValueKey('catalogueAddButton');
const _yourSiteHere = ValueKey('catalogueYourSiteHere');
const _stripGlyph = ValueKey('catalogueStripGlyph');

void main() {
  group('a record with full details', () {
    testWidgets('shows every card', (tester) async {
      await pumpCataloguePage(tester, id: saltPier.id);

      expect(find.byType(CatalogueSiteMapStrip), findsOneWidget);
      // The name, in the app bar and as the page's heading.
      expect(find.text('Salt Pier'), findsNWidgets(2));
      expect(
        find.text('Kralendijk, Bonaire Island, Bonaire, Caribbean Netherlands'),
        findsOneWidget,
      );
      expect(
        find.text('Built-in dive site · Not in your sites'),
        findsOneWidget,
      );

      expect(find.byType(CatalogueAboutCard), findsOneWidget);
      expect(find.text('Reef'), findsOneWidget);
      expect(find.text('Shore'), findsOneWidget);
      expect(find.text('5m–15m'), findsOneWidget);
      expect(find.text('Pillars covered in sponges.'), findsOneWidget);

      expect(find.byType(CatalogueHazardsCard), findsOneWidget);
      expect(find.text('Boat traffic at the pier'), findsOneWidget);

      expect(find.byType(CatalogueLocationCard), findsOneWidget);
      expect(find.text('Caribbean Sea'), findsOneWidget);

      expect(find.byType(TideSection), findsOneWidget);
      expect(find.byType(ReefSection), findsOneWidget);
      expect(find.byType(CatalogueNearbyCard), findsOneWidget);

      expect(find.byType(CatalogueSourceCard), findsOneWidget);
      expect(find.text('OpenStreetMap'), findsOneWidget);
      expect(find.text('Credit: OpenStreetMap contributors'), findsOneWidget);
      expect(find.text('Licence: ODbL-1.0'), findsOneWidget);
      expect(find.byKey(const ValueKey('catalogueSourceLink')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('catalogueWebsiteLink')),
        findsOneWidget,
      );
      // A dive site record is not a charted position.
      expect(find.textContaining('not a dive guide'), findsNothing);

      expect(find.byKey(_addAction), findsOneWidget);
      expect(find.byKey(_addButton), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('its glyph on the strip is the dive site pin', (tester) async {
      await pumpCataloguePage(tester, id: saltPier.id);

      expect(
        tester.widget<Icon>(find.byKey(_stripGlyph)).icon,
        Icons.location_on_outlined,
      );
    });

    testWidgets('depths, distances and coordinates follow the diver\'s '
        'settings', (tester) async {
      await pumpCataloguePage(
        tester,
        id: saltPier.id,
        settings: const AppSettings(
          depthUnit: DepthUnit.feet,
          distanceUnit: DistanceUnit.miles,
          coordinateFormat: CoordinateFormat.degreesDecimalMinutes,
        ),
      );

      expect(find.text('16ft–49ft'), findsOneWidget);
      // Bari Reef is about 9 km north: listed in miles.
      expect(find.textContaining(' mi'), findsOneWidget);
      expect(find.textContaining(' km'), findsNothing);
      // Degrees and decimal minutes, not the decimal degrees of the default.
      expect(find.textContaining('12.08'), findsNothing);
      expect(find.textContaining("12°"), findsOneWidget);
    });

    testWidgets('the coordinates can be copied, and no other row can', (
      tester,
    ) async {
      // A clipboard that takes what it is given, put back afterwards: the
      // platform channel is the whole isolate's.
      final copied = <String>[];
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await pumpCataloguePage(tester, id: saltPier.id);

      // One copy button on the page: the coordinates row's.
      final copy = find.byTooltip('Copy');
      expect(copy, findsOneWidget);
      await tester.ensureVisible(copy);
      await tester.tap(copy);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(copied.single, contains('12.08'));
      expect(find.text('Copied to clipboard'), findsOneWidget);
    });
  });

  testWidgets('a record that is only a name and a position shows no empty '
      'cards', (tester) async {
    await pumpCataloguePage(tester, id: thin.id, records: const [thin]);

    expect(find.byType(CatalogueSiteMapStrip), findsOneWidget);
    expect(find.text('Built-in dive site · Not in your sites'), findsOneWidget);
    expect(find.byType(CatalogueAboutCard), findsNothing);
    expect(find.byType(CatalogueHazardsCard), findsNothing);
    expect(find.byType(CatalogueNearbyCard), findsNothing);
    // What a position alone gives.
    expect(find.byType(CatalogueLocationCard), findsOneWidget);
    expect(find.byType(TideSection), findsOneWidget);
    expect(find.byType(ReefSection), findsOneWidget);
    expect(find.byType(CatalogueSourceCard), findsOneWidget);
    // No website, and no record page: the source's name still stands.
    expect(find.byKey(const ValueKey('catalogueWebsiteLink')), findsNothing);
    expect(find.byKey(const ValueKey('catalogueSourceLink')), findsNothing);
  });

  testWidgets('a record whose only detail is a type this version cannot '
      'name has no About card, not an empty one', (tester) async {
    const future = CatalogueSite(
      id: 'future',
      name: 'Somewhere',
      location: GeoPoint(1, 1),
      typeIds: ['a_type_from_a_later_catalogue'],
      source: 'osm',
    );
    await pumpCataloguePage(tester, id: future.id, records: const [future]);

    expect(find.byType(CatalogueAboutCard), findsNothing);
    expect(find.text('About'), findsNothing);
  });

  testWidgets('a record with no known source and no links has no Source '
      'card, and no gap where it would be', (tester) async {
    const orphan = CatalogueSite(
      id: 'orphan',
      name: 'Orphan',
      location: GeoPoint(1, 1),
      source: 'a_source_the_catalogue_does_not_list',
    );
    await pumpCataloguePage(tester, id: orphan.id, records: const [orphan]);

    expect(find.byType(CatalogueSourceCard), findsNothing);
    // The Add button follows the card above it at the page's one gap.
    final reef = tester.getRect(find.byType(ReefSection));
    final add = tester.getRect(find.byKey(_addButton));
    expect(add.top - reef.bottom, closeTo(12, 0.5));
  });

  testWidgets('a fresh-water record has no tides, and says it is fresh '
      'water', (tester) async {
    const quarry = CatalogueSite(
      id: 'quarry',
      name: 'Dutch Springs',
      location: GeoPoint(40.68, -75.35),
      waterType: WaterType.fresh,
      source: 'osm',
    );
    await pumpCataloguePage(tester, id: quarry.id, records: const [quarry]);

    expect(find.byType(TideSection), findsNothing);
    expect(find.byType(ReefSection), findsOneWidget);
    expect(find.byType(CatalogueAboutCard), findsOneWidget);
    expect(find.text('Fresh Water'), findsOneWidget);
  });

  testWidgets('a charted wreck says so, wears the anchor, and is not a '
      'dive guide', (tester) async {
    await pumpCataloguePage(tester, id: tabarka.id);

    expect(find.text('Charted wreck · Not in your sites'), findsOneWidget);
    expect(tester.widget<Icon>(find.byKey(_stripGlyph)).icon, Icons.anchor);
    expect(
      find.text('A charted position, not a dive guide. Not for navigation.'),
      findsOneWidget,
    );
    expect(
      find.text('UK Hydrographic Office Wrecks and Obstructions'),
      findsOneWidget,
    );
    expect(find.text('Credit: UK Hydrographic Office'), findsOneWidget);
  });

  testWidgets('a source link that is the licence address, or a data file, '
      'is left out', (tester) async {
    const sameAsLicence = CatalogueSite(
      id: 'same',
      name: 'Same',
      location: GeoPoint(1, 1),
      source: 'osm',
      sourceRef: 'https://www.openstreetmap.org/copyright',
    );
    await pumpCataloguePage(
      tester,
      id: sameAsLicence.id,
      records: const [sameAsLicence],
    );

    expect(find.byKey(const ValueKey('catalogueSourceLink')), findsNothing);
    // The licence itself is still a link.
    expect(find.byKey(const ValueKey('catalogueLicenceLink')), findsOneWidget);
  });

  testWidgets('a record without coordinates shows its header and source '
      'and nothing that needs a position', (tester) async {
    const nowhere = CatalogueSite(
      id: 'nowhere',
      name: 'Blue Hole',
      country: 'Egypt',
      source: 'osm',
    );
    await pumpCataloguePage(tester, id: nowhere.id, records: const [nowhere]);

    expect(find.text('Blue Hole'), findsNWidgets(2));
    expect(find.byType(CatalogueSiteMapStrip), findsNothing);
    expect(find.byType(TideSection), findsNothing);
    expect(find.byType(ReefSection), findsNothing);
    expect(find.byType(CatalogueNearbyCard), findsNothing);
    expect(find.byType(CatalogueSourceCard), findsOneWidget);
    // Its country is still a row.
    expect(find.byType(CatalogueLocationCard), findsOneWidget);
    expect(find.byKey(_addButton), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an id the catalogue does not hold says the site is no '
      'longer available, with nothing to add', (tester) async {
    await pumpCataloguePage(tester, id: 'gone');

    expect(
      find.text('This built-in site is no longer available'),
      findsOneWidget,
    );
    expect(find.byKey(_addAction), findsNothing);
    expect(find.byKey(_addButton), findsNothing);
  });

  group('a record that is the diver\'s own', () {
    testWidgets('opens their site\'s page, not the built-in one', (
      tester,
    ) async {
      await pumpCataloguePage(
        tester,
        id: saltPier.id,
        mine: [own('mine', catalogueId: saltPier.id)],
      );

      expect(find.text(ownPageText('mine')), findsOneWidget);
      expect(find.byType(CatalogueSitePage), findsNothing);
    });

    testWidgets('also when a merge folded it into another site', (
      tester,
    ) async {
      await pumpCataloguePage(
        tester,
        id: saltPier.id,
        mine: [
          SiteWithDiveCount(
            site: DiveSite(
              id: 'survivor',
              name: 'Survivor',
              catalogueId: 'another',
              catalogueAnswers: SiteCatalogueAnswers(also: {saltPier.id}),
            ),
            diveCount: 0,
          ),
        ],
      );

      expect(find.text(ownPageText('survivor')), findsOneWidget);
    });

    testWidgets('never draws the record on the way', (tester) async {
      await pumpCataloguePage(
        tester,
        id: saltPier.id,
        mine: [own('mine', catalogueId: saltPier.id)],
        settled: false,
      );

      // Frame by frame, from the first one to the diver's own page: the
      // built-in page's content is in none of them.
      for (var frame = 0; frame < 16; frame++) {
        expect(
          find.text('Pillars covered in sponges.'),
          findsNothing,
          reason: 'frame $frame',
        );
        expect(find.byKey(_addButton), findsNothing, reason: 'frame $frame');
        await tester.pump(const Duration(milliseconds: 60));
      }
      expect(find.text(ownPageText('mine')), findsOneWidget);
    });

    testWidgets('with something open over the page (a sheet, a dialog) it '
        'waits for that to close before it moves on', (tester) async {
      final container = await pumpCataloguePage(
        tester,
        id: saltPier.id,
        fromHome: true,
      );
      // Over the page, not instead of it: the page stays visible beneath,
      // and keeps hearing about the diver's sites.
      unawaited(
        showDialog<void>(
          context: tester.element(find.byType(CatalogueSitePage)),
          builder: (_) => const AlertDialog(content: Text('a dialog')),
        ),
      );
      await settle(tester);
      expect(find.text('a dialog'), findsOneWidget);

      container.read(mineProvider.notifier).state = [
        own('synced', catalogueId: saltPier.id),
      ];
      await settle(tester);

      // Nothing is replaced under what the diver is looking at.
      expect(find.text('a dialog'), findsOneWidget);
      expect(find.text(ownPageText('synced')), findsNothing);

      Navigator.of(tester.element(find.text('a dialog'))).pop();
      await settle(tester);
      expect(find.text(ownPageText('synced')), findsOneWidget);
    });

    testWidgets('a page that is covered by another leaves that one alone, '
        'and moves on only when the diver comes back to it', (tester) async {
      final container = await pumpCataloguePage(
        tester,
        id: saltPier.id,
        fromHome: true,
      );
      // The diver goes on from the built-in page to something else.
      GoRouter.of(
        tester.element(find.byType(CatalogueSitePage)),
      ).push(otherPath);
      await settle(tester);
      expect(find.text(otherText), findsOneWidget);

      // Meanwhile the record becomes theirs (a sync, another screen).
      container.read(mineProvider.notifier).state = [
        own('synced', catalogueId: saltPier.id),
      ];
      await settle(tester);

      // The page on top is not the built-in page's to replace.
      expect(find.text(otherText), findsOneWidget);
      expect(find.text(ownPageText('synced')), findsNothing);

      // Back on the built-in page, it hands over to the diver's own site.
      await tester.pageBack();
      await settle(tester);
      expect(find.text(ownPageText('synced')), findsOneWidget);

      await tester.pageBack();
      await settle(tester);
      expect(find.text(homeText), findsOneWidget);
    });

    testWidgets('and when it becomes theirs while the page is open, the '
        'page moves on', (tester) async {
      final container = await pumpCataloguePage(
        tester,
        id: saltPier.id,
        fromHome: true,
      );
      expect(find.byKey(_addButton), findsOneWidget);

      // Added on the map behind this page, or by a sync.
      container.read(mineProvider.notifier).state = [
        own('synced', catalogueId: saltPier.id),
      ];
      await settle(tester);

      expect(find.text(ownPageText('synced')), findsOneWidget);
      expect(find.byType(CatalogueSitePage), findsNothing);

      // Back returns to where the page was opened from, not to it.
      await tester.pageBack();
      await settle(tester);
      expect(find.text(homeText), findsOneWidget);
      expect(find.byType(CatalogueSitePage), findsNothing);
    });
  });

  testWidgets('the page shows the record when the diver\'s sites cannot '
      'be read, where it would otherwise wait for ever', (tester) async {
    await pumpCataloguePage(
      tester,
      id: saltPier.id,
      sitesError: StateError('database is busy'),
    );

    expect(find.text('Pillars covered in sponges.'), findsOneWidget);
    expect(find.byKey(_addButton), findsOneWidget);
  });

  group('tides', () {
    testWidgets('a position with no tide data has no Tides card: a lake '
        'the catalogue has no water type for', (tester) async {
      const lake = CatalogueSite(
        id: 'lake',
        name: 'Hemmoor',
        location: GeoPoint(53.69, 9.13),
        country: 'Germany',
        source: 'osm',
      );
      await pumpCataloguePage(
        tester,
        id: lake.id,
        records: const [lake],
        tideData: false,
      );

      expect(find.byType(TideSection), findsNothing);
      expect(find.text('Tides'), findsNothing);
      // The cards around where it would be keep the page's one gap.
      final location = tester.getRect(find.byType(CatalogueLocationCard));
      final reef = tester.getRect(find.byType(ReefSection));
      expect(reef.top - location.bottom, closeTo(12, 0.5));
    });

    testWidgets('while that is still being found out the card holds its '
        'place', (tester) async {
      await pumpCataloguePage(tester, id: saltPier.id);

      expect(find.byType(TideSection), findsOneWidget);
    });
  });

  group('while the catalogue is being imported', () {
    testWidgets('a record it does not hold yet is waited for, not called '
        'unavailable', (tester) async {
      final container = await pumpCataloguePage(
        tester,
        id: 'not_imported_yet',
        importing: true,
      );

      expect(
        find.text('This built-in site is no longer available'),
        findsNothing,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // The import ends without the record: now it is unavailable.
      container.read(siteCatalogueImportingProvider.notifier).state = false;
      await settle(tester);
      expect(
        find.text('This built-in site is no longer available'),
        findsOneWidget,
      );
    });
  });

  testWidgets('a record read again while the page is open stays on screen', (
    tester,
  ) async {
    final container = await pumpCataloguePage(tester, id: saltPier.id);
    expect(find.text('Pillars covered in sponges.'), findsOneWidget);

    // An import that lands: every catalogue read is made again.
    container.read(siteCatalogueRevisionProvider.notifier).state++;
    await tester.pump();

    // In the frame where the re-read is under way, the page is still the
    // page, not a progress indicator in its place.
    expect(find.text('Pillars covered in sponges.'), findsOneWidget);
    expect(find.byKey(_addButton), findsOneWidget);
    await settle(tester);
    expect(find.text('Pillars covered in sponges.'), findsOneWidget);
  });

  group('your site here', () {
    testWidgets('names the diver\'s unlinked site that sits on the record, '
        'and opens it', (tester) async {
      await pumpCataloguePage(
        tester,
        id: tabarka.id,
        mine: [
          // About 40 m north of the wreck.
          own(
            'hand_made',
            name: 'Tabarka',
            location: const GeoPoint(58.90036, -3.1),
          ),
        ],
      );

      expect(
        find.text('Your site "Tabarka" is 40 m from here'),
        findsOneWidget,
      );
      // Adding is still offered: the diver decides whether it is the same.
      expect(find.byKey(_addButton), findsOneWidget);

      await tester.tap(find.byKey(_yourSiteHere));
      await settle(tester);

      expect(find.text(ownPageText('hand_made')), findsOneWidget);
    });

    testWidgets('is absent when no site of the diver\'s is that close', (
      tester,
    ) async {
      await pumpCataloguePage(
        tester,
        id: tabarka.id,
        mine: [own('far', location: const GeoPoint(58.95, -3.1))],
      );

      expect(find.byKey(_yourSiteHere), findsNothing);
    });
  });

  group('nearby', () {
    const neighbourSite = CatalogueSite(
      id: 'inganess',
      name: 'Inganess Bay',
      location: GeoPoint(58.96, -3.1),
      source: 'osm',
    );
    const neighbourWreck = CatalogueSite(
      id: 'karlsruhe',
      name: 'SMS Karlsruhe',
      location: GeoPoint(58.91, -3.1),
      source: 'ukho',
      kind: CatalogueKind.register,
    );

    testWidgets('lists the diver\'s sites, then built-in dive sites before '
        'wrecks, each with its distance', (tester) async {
      await pumpCataloguePage(
        tester,
        id: tabarka.id,
        records: const [tabarka, neighbourWreck, neighbourSite],
        mine: [
          own(
            'barriers',
            name: 'Churchill Barriers',
            location: const GeoPoint(58.89, -3.1),
            dives: 3,
          ),
        ],
      );

      expect(find.text('Your sites'), findsOneWidget);
      expect(find.text('Churchill Barriers · 3 dives'), findsOneWidget);
      expect(find.text('Built-in sites'), findsOneWidget);

      final site = tester.getTopLeft(find.text('Inganess Bay')).dy;
      final wreck = tester.getTopLeft(find.text('SMS Karlsruhe')).dy;
      // The dive site is listed first although the wreck is nearer.
      expect(site, lessThan(wreck));
      expect(find.text('1.1 km'), findsNWidgets(2));
      expect(find.text('6.7 km'), findsOneWidget);
      // Each built-in row wears the glyph its pin has.
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('catalogueNearbyRecord_karlsruhe')),
          matching: find.byIcon(Icons.anchor),
        ),
        findsOneWidget,
      );
    });

    testWidgets('a built-in row opens that record\'s own page', (tester) async {
      await pumpCataloguePage(
        tester,
        id: tabarka.id,
        records: const [tabarka, neighbourSite],
      );

      final row = find.byKey(const ValueKey('catalogueNearbyRecord_inganess'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await settle(tester);

      expect(
        find.text('Built-in dive site · Not in your sites'),
        findsOneWidget,
      );
      expect(find.text('Inganess Bay'), findsWidgets);
    });

    testWidgets('one of the diver\'s rows opens their own site\'s page', (
      tester,
    ) async {
      await pumpCataloguePage(
        tester,
        id: tabarka.id,
        records: const [tabarka],
        mine: [own('barriers', location: const GeoPoint(58.89, -3.1))],
      );

      final row = find.byKey(const ValueKey('catalogueNearbyOwn_barriers'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await settle(tester);

      expect(find.text(ownPageText('barriers')), findsOneWidget);
    });
  });

  testWidgets('what can be tapped on the page is tall enough to hit: the '
      'nearby rows, the line for a site of yours, and the licence link', (
    tester,
  ) async {
    await pumpCataloguePage(
      tester,
      id: tabarka.id,
      mine: [
        own(
          'hand_made',
          name: 'Tabarka',
          location: const GeoPoint(58.90036, -3.1),
        ),
        own('barriers', location: const GeoPoint(58.89, -3.1)),
      ],
      records: const [
        tabarka,
        CatalogueSite(
          id: 'inganess',
          name: 'Inganess Bay',
          location: GeoPoint(58.96, -3.1),
          source: 'osm',
        ),
      ],
    );

    for (final key in const [
      ValueKey('catalogueYourSiteHere'),
      ValueKey('catalogueNearbyOwn_barriers'),
      ValueKey('catalogueNearbyRecord_inganess'),
      ValueKey('catalogueLicenceLink'),
    ]) {
      expect(
        tester.getSize(find.byKey(key)).height,
        greaterThanOrEqualTo(kMinInteractiveDimension),
        reason: '$key',
      );
    }
  });

  testWidgets('the strip opens a map of the same position that can be '
      'moved', (tester) async {
    await pumpCataloguePage(tester, id: tabarka.id);

    await tester.tap(find.byKey(const ValueKey('catalogueMapFullscreen')));
    await settle(tester);

    // The page beneath is still built, so the glyph is now on two maps.
    expect(find.byKey(_stripGlyph, skipOffstage: false), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  group('layout', () {
    testWidgets('on a wide window the content is held to a centred column', (
      tester,
    ) async {
      await pumpCataloguePage(
        tester,
        id: saltPier.id,
        size: const Size(1400, 900),
      );

      final strip = tester.getRect(find.byType(CatalogueSiteMapStrip));
      expect(strip.width, lessThanOrEqualTo(kCatalogueSitePageMaxWidth));
      expect(strip.center.dx, closeTo(700, 1));
      final button = tester.getRect(find.byKey(_addButton));
      expect(button.width, lessThanOrEqualTo(kCatalogueSitePageMaxWidth));
    });

    testWidgets('on a phone the content fills the width', (tester) async {
      await pumpCataloguePage(tester, id: saltPier.id);

      final strip = tester.getRect(find.byType(CatalogueSiteMapStrip));
      expect(strip.width, greaterThan(360));
    });

    testWidgets('a narrow phone in a long language does not overflow', (
      tester,
    ) async {
      await pumpCataloguePage(
        tester,
        id: tabarka.id,
        size: const Size(320, 900),
        locale: const Locale('de'),
        mine: [
          own(
            'hand_made',
            name: 'Ein sehr langer Name eines Tauchplatzes',
            location: const GeoPoint(58.90036, -3.1),
          ),
        ],
      );

      expect(find.textContaining('Verzeichnetes Wrack'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
