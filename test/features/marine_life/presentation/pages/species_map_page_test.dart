import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/marine_life/data/services/gbif_species_map_service.dart';
import 'package:submersion/features/marine_life/domain/entities/seen_species.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/entities/species_map_pins.dart';
import 'package:submersion/features/marine_life/presentation/pages/species_map_page.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_prefs_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/species_map_legend.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/species_map_list_pane.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/species_map_site_card.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/species_map_species_site_card.dart';
import 'package:submersion/shared/providers/map_list_selection_provider.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _manta = Species(
  id: 'manta',
  commonName: 'Reef Manta Ray',
  scientificName: 'Mobula alfredi',
  category: SpeciesCategory.ray,
);
const _turtle = Species(
  id: 'turtle',
  commonName: 'Hawksbill',
  category: SpeciesCategory.turtle,
);

final _seen = [
  SeenSpecies(
    species: _manta,
    totalSightings: 9,
    diveCount: 5,
    siteCount: 2,
    firstSeen: DateTime.utc(2024),
    lastSeen: DateTime.utc(2025),
  ),
];

const _sitePins = [
  SiteSpeciesPin(
    siteId: 's1',
    siteName: 'Blue Corner',
    latitude: 7.1,
    longitude: 134.2,
    speciesCount: 3,
    sightingCount: 20,
  ),
];

const _mantaPins = [
  SpeciesSitePin(
    siteId: 's2',
    siteName: 'Manta Point',
    latitude: -8.8,
    longitude: 115.5,
    kind: SpeciesPinKind.logged,
    sightingCount: 6,
  ),
  SpeciesSitePin(
    siteId: 's3',
    siteName: 'Crystal Bay',
    latitude: -8.7,
    longitude: 115.4,
    kind: SpeciesPinKind.expected,
    sightingCount: 0,
  ),
];

/// Lets a camera move finish. The cluster layer hides its markers while it
/// animates to a new zoom, so a pin is only findable once that settles.
/// Avoids pumpAndSettle: the tile layer animates indefinitely.
Future<void> _settleMap(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Finder _pin(String label) => find
    .byWidgetPredicate((w) => w is Semantics && w.properties.label == label)
    .hitTestable();

Future<void> _pump(
  WidgetTester tester, {
  String? initialSpeciesId,
  Size size = const Size(1400, 900),
  bool publicOn = false,
  int unplaced = 0,
  int? taxonKey,
  List<SpeciesSitePin> mantaPins = _mantaPins,
  List<SpeciesSitePin> turtlePins = const [],
  Object? taxonKeyError,
  bool tileFailed = false,
  GbifSpeciesMapService? service,
  Duration catalogDelay = Duration.zero,
  bool sitePinsFail = false,
  String? leftOpenSiteId,
  bool unplacedFails = false,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final base = await getBaseOverrides();
  if (publicOn) {
    await (await SharedPreferences.getInstance()).setBool(
      kSpeciesMapPublicLayerKey,
      true,
    );
  }
  final router = GoRouter(
    initialLocation: initialSpeciesId == null
        ? '/species/map'
        : '/species/map?species=$initialSpeciesId',
    routes: [
      GoRoute(
        path: '/species/map',
        builder: (context, state) => SpeciesMapPage(
          initialSpeciesId: state.uri.queryParameters['species'],
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    testAppRouter(
      router: router,
      locale: const Locale('en'),
      overrides: [
        ...base,
        allSpeciesProvider.overrideWith((ref) async {
          if (catalogDelay > Duration.zero) {
            await Future<void>.delayed(catalogDelay);
          }
          return [_manta, _turtle];
        }),
        seenSpeciesProvider.overrideWith((ref) async => _seen),
        speciesMapSitePinsProvider.overrideWith(
          (ref) async => sitePinsFail ? throw StateError('db') : _sitePins,
        ),
        speciesMapSpeciesPinsProvider(
          'no-such-species',
        ).overrideWith((ref) async => const []),
        speciesMapUnplacedCountProvider(
          'no-such-species',
        ).overrideWith((ref) async => 0),
        speciesMapSpeciesPinsProvider(
          'manta',
        ).overrideWith((ref) async => mantaPins),
        speciesMapSpeciesPinsProvider(
          'turtle',
        ).overrideWith((ref) async => turtlePins),
        speciesMapUnplacedCountProvider('manta').overrideWith(
          (ref) async => unplacedFails ? throw StateError('db') : unplaced,
        ),
        speciesMapUnplacedCountProvider(
          'turtle',
        ).overrideWith((ref) async => 0),
        speciesMapUnplacedCountProvider(
          null,
        ).overrideWith((ref) async => unplaced),
        if (service != null)
          gbifSpeciesMapServiceProvider.overrideWithValue(service)
        else ...[
          speciesGbifTaxonKeyProvider('manta').overrideWith(
            (ref) async =>
                taxonKeyError != null ? throw taxonKeyError : taxonKey,
          ),
          speciesGbifTaxonKeyProvider(
            'turtle',
          ).overrideWith((ref) async => taxonKey),
        ],
        speciesMapPublicTilesFailedProvider(
          'manta',
        ).overrideWith((ref) => tileFailed),
        // A card left open on an earlier visit: the selection outlives the
        // page.
        if (leftOpenSiteId != null)
          mapListSelectionProvider('speciesMap').overrideWith(
            (ref) => MapListSelectionNotifier()..select(leftOpenSiteId),
          ),
      ],
    ),
  );
  await tester.pump();
  await _settleMap(tester);
}

void main() {
  testWidgets('places mode shows one marker per site pin', (tester) async {
    await _pump(tester);

    expect(_pin('Blue Corner, 3 species'), findsOneWidget);
    expect(_pin('Manta Point, 6 sightings'), findsNothing);
  });

  for (final size in const [Size(1400, 900), Size(400, 800)]) {
    testWidgets(
      'an open site card leaves the legend and its GBIF credit in view '
      'at ${size.width.toInt()} wide',
      (tester) async {
        await _pump(tester, size: size, publicOn: true, unplaced: 2);

        await tester.tap(_pin('Blue Corner, 3 species'));
        await _settleMap(tester);

        final card = tester.getRect(find.byType(SpeciesMapSiteCard));
        final legend = tester.getRect(find.byType(SpeciesMapLegend));
        expect(legend.overlaps(card), isFalse);
        expect(find.text('Records: GBIF.org').hitTestable(), findsOneWidget);
      },
    );
  }

  testWidgets('?species= seeds species mode with logged and expected pins', (
    tester,
  ) async {
    await _pump(tester, initialSpeciesId: 'manta');

    expect(_pin('Manta Point, 6 sightings'), findsOneWidget);
    expect(_pin('Crystal Bay, expected'), findsOneWidget);
    expect(_pin('Blue Corner, 3 species'), findsNothing);
  });

  testWidgets('a new ?species= on the open page switches to that species', (
    tester,
  ) async {
    await _pump(tester);
    expect(_pin('Blue Corner, 3 species'), findsOneWidget);

    GoRouter.of(
      tester.element(find.byType(SpeciesMapPage)),
    ).go('/species/map?species=manta');
    await _settleMap(tester);

    expect(_pin('Manta Point, 6 sightings'), findsOneWidget);
  });

  testWidgets('a species link opens with no card from an earlier visit', (
    tester,
  ) async {
    await _pump(tester, initialSpeciesId: 'manta', leftOpenSiteId: 's2');

    expect(find.byType(SpeciesMapSpeciesSiteCard), findsNothing);
  });

  testWidgets('a selection whose pin is gone is let go, not kept for later', (
    tester,
  ) async {
    // A site whose sightings went, or an expected pin the scope no longer
    // draws: its card must not come back on its own if the pin returns.
    await _pump(tester, leftOpenSiteId: 'gone');

    final container = ProviderScope.containerOf(
      tester.element(find.byType(SpeciesMapPage)),
    );
    expect(
      container.read(mapListSelectionProvider('speciesMap')).selectedId,
      isNull,
    );
  });

  testWidgets('an unknown ?species= id opens places mode', (tester) async {
    await _pump(tester, initialSpeciesId: 'no-such-species');

    expect(_pin('Blue Corner, 3 species'), findsOneWidget);
  });

  testWidgets('picking a species in the list switches mode, and back', (
    tester,
  ) async {
    await _pump(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(SpeciesMapListPane),
        matching: find.text('Reef Manta Ray'),
      ),
    );
    await _settleMap(tester);
    expect(_pin('Manta Point, 6 sightings'), findsOneWidget);

    await tester.tap(find.text('All sites'));
    await _settleMap(tester);
    expect(_pin('Blue Corner, 3 species'), findsOneWidget);
  });

  testWidgets('no unplaced line when every sighting is placed', (tester) async {
    await _pump(tester, initialSpeciesId: 'manta');

    expect(find.textContaining('without a mapped site'), findsNothing);
  });

  testWidgets('the unplaced line counts sightings without a mapped site', (
    tester,
  ) async {
    await _pump(tester, initialSpeciesId: 'manta', unplaced: 2);

    expect(
      find.text('2 sightings are on dives without a mapped site'),
      findsOneWidget,
    );
  });

  testWidgets('a failed unplaced count says so instead of nothing', (
    tester,
  ) async {
    await _pump(tester, initialSpeciesId: 'manta', unplacedFails: true);

    expect(find.text('Could not load the species map.'), findsOneWidget);
  });

  testWidgets('public on with no taxon key explains there are no records', (
    tester,
  ) async {
    await _pump(tester, initialSpeciesId: 'manta', publicOn: true);

    expect(
      find.textContaining('No public records can be shown'),
      findsOneWidget,
    );
    // The diver's own pins still draw.
    expect(_pin('Manta Point, 6 sightings'), findsOneWidget);
  });

  testWidgets('public on and GBIF unreachable says records did not load', (
    tester,
  ) async {
    await _pump(
      tester,
      initialSpeciesId: 'manta',
      publicOn: true,
      taxonKeyError: const GbifUnavailableException('offline'),
    );

    expect(find.text('Public records could not be loaded.'), findsOneWidget);
    expect(find.textContaining('No public records can be shown'), findsNothing);
  });

  testWidgets('a failed public tile says records did not load', (tester) async {
    await _pump(
      tester,
      initialSpeciesId: 'manta',
      publicOn: true,
      taxonKey: 9241141,
      tileFailed: true,
    );

    expect(find.text('Public records could not be loaded.'), findsOneWidget);
  });

  testWidgets('panning clears the note so it reflects the tiles now in view', (
    tester,
  ) async {
    // No taxon key, so no tile can fail again during the test.
    await _pump(
      tester,
      initialSpeciesId: 'manta',
      publicOn: true,
      tileFailed: true,
    );
    expect(find.text('Public records could not be loaded.'), findsOneWidget);

    await tester.drag(find.byType(FlutterMap), const Offset(-200, 0));
    await _settleMap(tester);

    expect(find.text('Public records could not be loaded.'), findsNothing);
  });

  testWidgets('with the public layer off the page sends nothing to GBIF', (
    tester,
  ) async {
    final service = _CountingService();
    await _pump(tester, initialSpeciesId: 'manta', service: service);

    expect(service.calls, 0);
  });

  testWidgets('an unknown id frames the places pins once the catalog loads', (
    tester,
  ) async {
    await _pump(
      tester,
      initialSpeciesId: 'no-such-species',
      catalogDelay: const Duration(milliseconds: 300),
    );

    expect(_pin('Blue Corner, 3 species'), findsOneWidget);
  });

  testWidgets('a failed read shows an error with a retry', (tester) async {
    await _pump(tester, sitePinsFail: true);

    expect(find.text('Could not load the species map.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  });

  testWidgets('public on with a key shows no note and credits GBIF', (
    tester,
  ) async {
    await _pump(
      tester,
      initialSpeciesId: 'manta',
      publicOn: true,
      taxonKey: 9241141,
    );

    expect(find.textContaining('No public records can be shown'), findsNothing);
    expect(find.text('Records: GBIF.org'), findsOneWidget);
  });

  testWidgets('no pins with public off suggests turning on public records', (
    tester,
  ) async {
    await _pump(tester, initialSpeciesId: 'turtle');

    expect(
      find.textContaining('Turn on public records to see where others have'),
      findsOneWidget,
    );
  });

  testWidgets('on a phone the picker opens from the app bar', (tester) async {
    await _pump(tester, size: const Size(400, 800));
    expect(find.byType(SpeciesMapListPane), findsNothing);

    await tester.tap(find.byTooltip('Pick a species'));
    await _settleMap(tester);
    expect(find.byType(SpeciesMapListPane), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(SpeciesMapListPane),
        matching: find.text('Reef Manta Ray'),
      ),
    );
    await _settleMap(tester);
    expect(find.byType(SpeciesMapListPane), findsNothing);
    expect(_pin('Manta Point, 6 sightings'), findsOneWidget);
  });
}

class _CountingService extends GbifSpeciesMapService {
  int calls = 0;

  @override
  Future<int?> resolveTaxonKey({
    required String speciesId,
    String? scientificName,
  }) async {
    calls++;
    return 1;
  }
}
