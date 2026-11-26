import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/marine_life/domain/entities/species_crop.dart';
import 'package:submersion/features/marine_life/domain/species_rarity.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_card.dart';

import '../../domain/species_test_entries.dart';
import 'species_picture_test_support.dart';

void main() {
  testWidgets('shows the name, dive count and rarity badge', (tester) async {
    var tapped = false;
    await pumpPictures(
      tester,
      SizedBox(
        width: 170,
        height: 220,
        child: SpeciesCard(
          entry: seenEntry('Grouper', dives: 4),
          picture: const NoPicture(),
          rarity: SpeciesRarity.newSpecies,
          onTap: () => tapped = true,
        ),
      ),
    );
    expect(find.text('Grouper'), findsOneWidget);
    expect(find.text('4 dives'), findsOneWidget);
    expect(find.text('New'), findsOneWidget);
    await tester.tap(find.byType(SpeciesCard));
    expect(tapped, isTrue);
  });

  testWidgets('first seen here shows its marker', (tester) async {
    await pumpPictures(
      tester,
      SizedBox(
        width: 170,
        height: 220,
        child: SpeciesCard(
          entry: seenEntry('Grouper'),
          picture: const NoPicture(),
          firstSeenHere: true,
        ),
      ),
    );
    expect(find.text('First seen here'), findsOneWidget);
  });

  testWidgets('long names ellipsize at 2 lines', (tester) async {
    final name = 'Very ' * 18;
    await pumpPictures(
      tester,
      SizedBox(
        width: 160,
        height: 220,
        child: SpeciesCard(
          entry: seenEntry(name),
          picture: const NoPicture(),
          rarity: SpeciesRarity.notSeenLately,
        ),
      ),
    );
    final text = tester.widget<Text>(find.text(name));
    expect(text.maxLines, 2);
    expect(text.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('first seen here keeps the dive count', (tester) async {
    await pumpPictures(
      tester,
      SizedBox(
        width: 170,
        height: 260,
        child: SpeciesCard(
          entry: seenEntry('Grouper', dives: 4),
          picture: const NoPicture(),
          firstSeenHere: true,
        ),
      ),
    );
    expect(find.text('4 dives'), findsOneWidget);
    expect(find.text('First seen here'), findsOneWidget);
  });

  testWidgets('fits its grid cell at text scale 1.3 with a long name', (
    tester,
  ) async {
    const scaler = TextScaler.linear(1.3);
    await pumpPictures(
      tester,
      MediaQuery(
        data: const MediaQueryData(textScaler: scaler),
        child: SizedBox(
          width: 160,
          height: speciesCardHeight(160, scaler, withMarker: true),
          child: SpeciesCard(
            entry: seenEntry('Very ' * 18, dives: 12),
            picture: const NoPicture(),
            rarity: SpeciesRarity.notSeenLately,
            firstSeenHere: true,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  test('the marker line is reserved only when it can show', () {
    const scaler = TextScaler.noScaling;
    expect(
      speciesCardHeight(160, scaler, withMarker: true),
      greaterThan(speciesCardHeight(160, scaler)),
    );
  });
}
