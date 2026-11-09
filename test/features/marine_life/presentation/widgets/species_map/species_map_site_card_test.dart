import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/entities/species_map_pins.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_prefs_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/species_map_site_card.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/reef/domain/entities/reef_data_status.dart';
import 'package:submersion/features/reef/presentation/providers/reef_providers.dart';
import 'package:submersion/features/reef/presentation/widgets/nearby_species_tier.dart';

import 'species_map_harness.dart';

const _pin = SiteSpeciesPin(
  siteId: 'site-1',
  siteName: 'Blue Corner',
  latitude: 7.13,
  longitude: 134.22,
  speciesCount: 2,
  sightingCount: 5,
);

const _catalog = [
  Species(
    id: 'shark',
    commonName: 'Grey Reef Shark',
    category: SpeciesCategory.shark,
  ),
  Species(
    id: 'wrasse',
    commonName: 'Napoleon Wrasse',
    category: SpeciesCategory.fish,
  ),
  Species(
    id: 'turtle',
    commonName: 'Hawksbill',
    category: SpeciesCategory.turtle,
  ),
];

SiteSpeciesEntry _entry(String speciesId, String name) => SiteSpeciesEntry(
  id: 'e-$speciesId',
  siteId: 'site-1',
  speciesId: speciesId,
  speciesName: name,
  category: SpeciesCategory.fish,
  createdAt: DateTime(2026),
);

Future<void> _pump(
  WidgetTester tester, {
  bool publicOn = false,
  List<SiteSpeciesEntry> expected = const [],
  Future<List<LoggedSpeciesAtSite>>? logged,
  Future<List<Species>>? catalog,
  bool expectedFails = false,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    await speciesMapHarness(
      prefs: {kSpeciesMapPublicLayerKey: publicOn},
      overrides: [
        allSpeciesProvider.overrideWith(
          (ref) => catalog ?? Future.value(_catalog),
        ),
        speciesMapLoggedAtSiteProvider('site-1').overrideWith(
          (ref) =>
              logged ??
              Future.value(const [
                LoggedSpeciesAtSite(speciesId: 'shark', sightingCount: 14),
                LoggedSpeciesAtSite(speciesId: 'wrasse', sightingCount: 9),
              ]),
        ),
        siteExpectedSpeciesProvider('site-1').overrideWith(
          (ref) async => expectedFails ? throw StateError('db') : expected,
        ),
        reefNearbySpeciesProvider(const GeoPoint(7.13, 134.22)).overrideWith(
          (ref) async => const ReefPart<NearbySpecies>.ok(
            NearbySpecies(
              matched: [
                MatchedNearbySpecies(speciesId: 'turtle', occurrenceCount: 3),
              ],
              unmatchedNames: [],
            ),
          ),
        ),
      ],
      child: SpeciesMapSiteCard(pin: _pin, onClose: () {}),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  testWidgets('lists logged species most seen first, with counts', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.text('Blue Corner'), findsOneWidget);
    final shark = tester.getTopLeft(find.textContaining('Grey Reef Shark'));
    final wrasse = tester.getTopLeft(find.textContaining('Napoleon Wrasse'));
    expect(shark.dy < wrasse.dy || shark.dx < wrasse.dx, isTrue);
    expect(find.textContaining('14'), findsOneWidget);
  });

  testWidgets('species seen equally often are listed by name', (tester) async {
    // The read breaks ties by species id, which means nothing on screen.
    await _pump(
      tester,
      logged: Future.value(const [
        LoggedSpeciesAtSite(speciesId: 'wrasse', sightingCount: 3),
        LoggedSpeciesAtSite(speciesId: 'shark', sightingCount: 3),
      ]),
    );

    final shark = tester.getTopLeft(find.textContaining('Grey Reef Shark'));
    final wrasse = tester.getTopLeft(find.textContaining('Napoleon Wrasse'));
    expect(shark.dy, wrasse.dy);
    expect(shark.dx, lessThan(wrasse.dx));
  });

  testWidgets('lists expected species not yet logged, omitting logged ones', (
    tester,
  ) async {
    await _pump(
      tester,
      expected: [
        _entry('shark', 'Grey Reef Shark'),
        _entry('turtle', 'Hawksbill'),
      ],
    );

    expect(find.text('Expected, not logged yet'), findsOneWidget);
    expect(find.textContaining('Hawksbill'), findsOneWidget);
    expect(find.textContaining('Grey Reef Shark'), findsOneWidget);
  });

  testWidgets('shows the nearby tier only with the public layer on', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byType(NearbySpeciesTier), findsNothing);

    await _pump(tester, publicOn: true);
    expect(find.byType(NearbySpeciesTier), findsOneWidget);
  });

  testWidgets('tapping a species opens its page', (tester) async {
    await _pump(tester);

    await tester.tap(find.textContaining('Napoleon Wrasse'));
    await tester.pumpAndSettle();

    expect(find.text('page:/species/wrasse'), findsOneWidget);
  });

  testWidgets('tapping the site name opens the site', (tester) async {
    await _pump(tester);

    await tester.tap(find.byTooltip('Open site'));
    await tester.pumpAndSettle();

    expect(find.text('page:/sites/site-1'), findsOneWidget);
  });

  testWidgets('shows progress, not "nothing logged", while loading', (
    tester,
  ) async {
    await _pump(
      tester,
      logged: Completer<List<LoggedSpeciesAtSite>>().future,
      settle: false,
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Nothing logged here yet'), findsNothing);
  });

  testWidgets('shows progress while the catalog that names them loads', (
    tester,
  ) async {
    await _pump(
      tester,
      catalog: Completer<List<Species>>().future,
      settle: false,
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Nothing logged here yet'), findsNothing);
  });

  testWidgets('a failed expected read says so, keeping the logged list', (
    tester,
  ) async {
    await _pump(tester, expectedFails: true);

    expect(find.textContaining('Grey Reef Shark'), findsOneWidget);
    expect(find.text('Could not load the species map.'), findsOneWidget);
  });
}
