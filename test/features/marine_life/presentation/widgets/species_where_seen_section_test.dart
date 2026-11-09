import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/domain/entities/species_map_pins.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_prefs_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/gbif_occurrence_layer.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_where_seen_section.dart';

import 'species_map/species_map_harness.dart';

SpeciesSitePin _logged(String id, String name, int count, double lat) =>
    SpeciesSitePin(
      siteId: id,
      siteName: name,
      latitude: lat,
      longitude: 115,
      kind: SpeciesPinKind.logged,
      sightingCount: count,
    );

final _pins = [
  _logged('a', 'Batu Bolong', 1, -8.0),
  _logged('b', 'Manta Point', 6, -8.5),
  _logged('c', 'Crystal Bay', 2, -8.7),
  _logged('d', 'Toyapakeh', 1, -8.6),
  const SpeciesSitePin(
    siteId: 'e',
    siteName: 'Sakenan',
    latitude: -8.4,
    longitude: 115.3,
    kind: SpeciesPinKind.expected,
    sightingCount: 0,
  ),
];

Future<void> _pump(
  WidgetTester tester,
  List<SpeciesSitePin> pins, {
  bool publicOn = false,
  bool fail = false,
}) async {
  await tester.pumpWidget(
    await speciesMapHarness(
      prefs: {kSpeciesMapPublicLayerKey: publicOn},
      overrides: [
        speciesMapSpeciesPinsProvider(
          'manta',
        ).overrideWith((ref) async => fail ? throw StateError('db') : pins),
      ],
      child: const SingleChildScrollView(
        child: SpeciesWhereSeenSection(speciesId: 'manta'),
      ),
    ),
  );
  // Avoid pumpAndSettle: the tile layer animates indefinitely.
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('a locked map and the top three sites by count', (tester) async {
    await _pump(tester, _pins);

    expect(find.text('Where seen'), findsOneWidget);
    final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
    expect(map.options.interactionOptions.flags, InteractiveFlag.none);
    expect(
      find.text('Manta Point (6), Crystal Bay (2), Batu Bolong (1)'),
      findsOneWidget,
    );
  });

  testWidgets('with no pins shows the empty line and the open button', (
    tester,
  ) async {
    await _pump(tester, const []);

    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Not logged at a mapped site yet.'), findsOneWidget);
    expect(find.text('Open full map'), findsOneWidget);
  });

  testWidgets('open full map goes to the species map for this species', (
    tester,
  ) async {
    await _pump(tester, _pins);

    await tester.tap(find.text('Open full map'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('page:/species/map?species=manta'), findsOneWidget);
  });

  testWidgets('never draws the public layer, even when it is on', (
    tester,
  ) async {
    await _pump(tester, _pins, publicOn: true);

    expect(find.byType(GbifOccurrenceLayer), findsNothing);
    expect(find.byType(TileLayer), findsOneWidget);
  });

  testWidgets('a failed read says so instead of "not logged"', (tester) async {
    await _pump(tester, const [], fail: true);

    expect(find.text('Could not load the species map.'), findsOneWidget);
    expect(find.text('Not logged at a mapped site yet.'), findsNothing);
  });
}
