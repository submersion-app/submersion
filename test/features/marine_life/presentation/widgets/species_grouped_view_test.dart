import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/species_grouping.dart';
import 'package:submersion/features/marine_life/presentation/widgets/seen_species_tile.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_card.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_grouped_view.dart';

import '../../domain/species_test_entries.dart';
import 'species_picture_test_support.dart';

final _grouper = seenEntry('Grouper');
final _snapper = seenEntry('Snapper');
final _manta = seenEntry('Manta', category: SpeciesCategory.ray);

Future<void> _pump(
  WidgetTester tester,
  List<SpeciesGroup> groups, {
  required SpeciesGroupBy by,
  bool grid = true,
  ValueChanged<SpeciesCategory>? onSeeAll,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpPictures(
    tester,
    SpeciesGroupedView(
      groups: groups,
      by: by,
      grid: grid,
      pictures: const {},
      rarityOf: (_) => null,
      onOpen: (_) {},
      onSeeAllCategory: onSeeAll ?? (_) {},
    ),
  );
}

void main() {
  testWidgets('none shows every species as a card', (tester) async {
    await _pump(tester, [
      SpeciesGroup(key: 'all', entries: [_grouper, _snapper]),
    ], by: SpeciesGroupBy.none);
    expect(find.byType(SpeciesCard), findsNWidgets(2));
  });

  testWidgets('shelves per category with See all', (tester) async {
    SpeciesCategory? opened;
    await _pump(
      tester,
      groupSeenSpecies([
        _grouper,
        _snapper,
        _manta,
      ], by: SpeciesGroupBy.category),
      by: SpeciesGroupBy.category,
      onSeeAll: (c) => opened = c,
    );
    expect(find.text('Fish · 2 species'), findsOneWidget);
    expect(find.text('Ray · 1 species'), findsOneWidget);
    await tester.tap(find.text('See all').first);
    expect(opened, SpeciesCategory.fish);
  });

  testWidgets('trip sections include No trip and collapse', (tester) async {
    final places = SpeciesPlaces(
      tripsBySpecies: {
        'Grouper': [
          SpeciesPlace(id: 't1', name: 'Bonaire', sortDate: DateTime.utc(2025)),
        ],
        'Snapper': const [SpeciesPlace(id: null, name: '')],
      },
      sitesBySpecies: const {},
      firstTripBySpecies: const {'Grouper': 't1'},
      firstSiteBySpecies: const {},
    );
    await _pump(
      tester,
      groupSeenSpecies(
        [_grouper, _snapper],
        by: SpeciesGroupBy.trip,
        places: places,
      ),
      by: SpeciesGroupBy.trip,
    );
    expect(find.text('Bonaire'), findsOneWidget);
    expect(find.text('No trip'), findsOneWidget);
    expect(find.text('First seen here'), findsOneWidget);
    expect(find.byType(SpeciesCard), findsNWidgets(2));

    await tester.tap(find.text('Bonaire'));
    await tester.pumpAndSettle();
    expect(find.byType(SpeciesCard), findsOneWidget);
  });

  testWidgets('list mode renders tiles', (tester) async {
    await _pump(
      tester,
      [
        SpeciesGroup(key: 'all', entries: [_grouper]),
      ],
      by: SpeciesGroupBy.none,
      grid: false,
    );
    expect(find.byType(SeenSpeciesTile), findsOneWidget);
    expect(find.byType(SpeciesCard), findsNothing);
  });
}
