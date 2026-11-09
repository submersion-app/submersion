import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/species_map_legend.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

void main() {
  testWidgets('species mode names sightings and expected, not public', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: const SpeciesMapLegend(speciesMode: true, publicOn: false),
      ),
    );

    expect(find.text('My sightings'), findsOneWidget);
    expect(find.text('Expected, not logged'), findsOneWidget);
    expect(find.text('Public records'), findsNothing);
    expect(find.text('Species logged at a site'), findsNothing);
  });

  testWidgets('species mode with public on adds public records', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: const SpeciesMapLegend(speciesMode: true, publicOn: true),
      ),
    );

    expect(find.text('Public records'), findsOneWidget);
  });

  testWidgets('places mode names species logged at a site only', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: const SpeciesMapLegend(speciesMode: false, publicOn: true),
      ),
    );

    expect(find.text('Species logged at a site'), findsOneWidget);
    expect(find.text('My sightings'), findsNothing);
    // Places mode draws no public tiles, so the legend does not name them.
    expect(find.text('Public records'), findsNothing);
    // But the site cards show GBIF records, so GBIF is still credited.
    expect(find.text('Records: GBIF.org'), findsOneWidget);
  });

  testWidgets('no GBIF credit while the public layer is off', (tester) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: const SpeciesMapLegend(speciesMode: true, publicOn: false),
      ),
    );

    expect(find.text('Records: GBIF.org'), findsNothing);
  });
}
