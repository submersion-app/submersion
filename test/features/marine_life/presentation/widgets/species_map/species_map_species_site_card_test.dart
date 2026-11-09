import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/domain/entities/species_map_pins.dart';
import 'package:submersion/features/marine_life/domain/entities/species_sighting_record.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/species_map_species_site_card.dart';

import 'species_map_harness.dart';

SpeciesSightingRecord _record(String id, String siteId, int number) =>
    SpeciesSightingRecord(
      sightingId: 's-$id',
      diveId: id,
      diveNumber: number,
      diveDateTime: DateTime.utc(2024, 3, number),
      siteId: siteId,
      siteName: siteId,
      maxDepthMeters: null,
      count: 2,
      notes: '',
    );

Future<void> _pump(WidgetTester tester, SpeciesSitePin pin) async {
  await tester.pumpWidget(
    await speciesMapHarness(
      overrides: [
        speciesSightingsProvider('manta').overrideWith(
          (ref) async => [
            _record('d1', 'site-1', 11),
            _record('d2', 'site-2', 12),
            _record('d3', 'site-1', 13),
          ],
        ),
      ],
      child: SpeciesMapSpeciesSiteCard(
        pin: pin,
        speciesId: 'manta',
        onClose: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets("a logged pin lists only that site's sightings", (tester) async {
    await _pump(
      tester,
      const SpeciesSitePin(
        siteId: 'site-1',
        siteName: 'Manta Point',
        latitude: 1,
        longitude: 2,
        kind: SpeciesPinKind.logged,
        sightingCount: 4,
      ),
    );

    expect(find.text('Manta Point'), findsOneWidget);
    expect(find.textContaining('dive 11'), findsOneWidget);
    expect(find.textContaining('dive 13'), findsOneWidget);
    expect(find.textContaining('dive 12'), findsNothing);
  });

  testWidgets('tapping a sighting opens its dive', (tester) async {
    await _pump(
      tester,
      const SpeciesSitePin(
        siteId: 'site-1',
        siteName: 'Manta Point',
        latitude: 1,
        longitude: 2,
        kind: SpeciesPinKind.logged,
        sightingCount: 4,
      ),
    );

    await tester.tap(find.textContaining('dive 11'));
    await tester.pumpAndSettle();

    expect(find.text('page:/dives/d1'), findsOneWidget);
  });

  testWidgets('an expected pin says expected here', (tester) async {
    await _pump(
      tester,
      const SpeciesSitePin(
        siteId: 'site-9',
        siteName: 'Crystal Bay',
        latitude: 1,
        longitude: 2,
        kind: SpeciesPinKind.expected,
        sightingCount: 0,
      ),
    );

    expect(find.text('Crystal Bay'), findsOneWidget);
    expect(find.text('Expected here, not logged yet'), findsOneWidget);
  });
}
