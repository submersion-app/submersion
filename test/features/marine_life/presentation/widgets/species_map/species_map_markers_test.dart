import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/domain/entities/species_map_pins.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_map/species_map_markers.dart';

import '../../../../../helpers/l10n_test_helpers.dart';

BoxDecoration _circle(WidgetTester tester, Finder marker) {
  final box = tester.widget<Container>(
    find.descendant(of: marker, matching: find.byType(Container)).first,
  );
  return box.decoration! as BoxDecoration;
}

void main() {
  group('siteSpeciesMarkerSize', () {
    test('starts at 32 and grows with the species count', () {
      expect(siteSpeciesMarkerSize(1), 32);
      expect(siteSpeciesMarkerSize(2), greaterThan(32));
      expect(siteSpeciesMarkerSize(4), greaterThan(siteSpeciesMarkerSize(2)));
    });

    test('caps at 52', () {
      expect(siteSpeciesMarkerSize(500), 52);
    });

    test('treats zero or less as one', () {
      expect(siteSpeciesMarkerSize(0), 32);
    });
  });

  testWidgets('site marker shows the species count', (tester) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: const Center(
          child: SiteSpeciesMarker(speciesCount: 23, selected: false),
        ),
      ),
    );

    expect(find.text('23'), findsOneWidget);
  });

  testWidgets('logged marker shows its count on a filled circle', (
    tester,
  ) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: const Center(
          child: LoggedSpeciesMarker(sightingCount: 6, selected: false),
        ),
      ),
    );

    expect(find.text('6'), findsOneWidget);
    final context = tester.element(find.byType(LoggedSpeciesMarker));
    expect(
      _circle(tester, find.byType(LoggedSpeciesMarker)).color,
      Theme.of(context).colorScheme.primary,
    );
  });

  testWidgets('expected marker is hollow', (tester) async {
    await tester.pumpWidget(
      localizedMaterialApp(
        home: const Center(child: ExpectedSpeciesMarker(selected: false)),
      ),
    );

    final context = tester.element(find.byType(ExpectedSpeciesMarker));
    final scheme = Theme.of(context).colorScheme;
    final decoration = _circle(tester, find.byType(ExpectedSpeciesMarker));
    expect(decoration.color, scheme.surface);
    expect((decoration.border! as Border).top.color, scheme.primary);
    expect((decoration.border! as Border).top.width, 2);
  });

  group('species pin clusters', () {
    Marker pin(SpeciesPinKind kind) => Marker(
      key: speciesPinMarkerKey(kind, 's'),
      point: const LatLng(0, 0),
      child: const SizedBox(),
    );

    testWidgets('a cluster of expected pins only is hollow', (tester) async {
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Center(
            child: SpeciesMapClusterMarker(
              markers: [
                pin(SpeciesPinKind.expected),
                pin(SpeciesPinKind.expected),
              ],
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(SpeciesMapClusterMarker));
      final decoration = _circle(tester, find.byType(SpeciesMapClusterMarker));
      expect(decoration.color, Theme.of(context).colorScheme.surface);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('a cluster holding a logged pin is filled', (tester) async {
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Center(
            child: SpeciesMapClusterMarker(
              markers: [
                pin(SpeciesPinKind.expected),
                pin(SpeciesPinKind.logged),
              ],
            ),
          ),
        ),
      );

      final context = tester.element(find.byType(SpeciesMapClusterMarker));
      final decoration = _circle(tester, find.byType(SpeciesMapClusterMarker));
      expect(decoration.color, isNot(Theme.of(context).colorScheme.surface));
    });

    testWidgets('a screen reader hears how many sites, not a bare number', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Center(
            child: SpeciesMapClusterMarker(
              markers: [
                pin(SpeciesPinKind.logged),
                pin(SpeciesPinKind.expected),
                pin(SpeciesPinKind.logged),
              ],
            ),
          ),
        ),
      );

      expect(find.bySemanticsLabel('3 sites'), findsOneWidget);
      expect(find.bySemanticsLabel('3'), findsNothing);
      semantics.dispose();
    });
  });
}
