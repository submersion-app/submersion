import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/insights/domain/entities/species_insights.dart';
import 'package:submersion/features/marine_life/domain/species_rarity.dart';
import 'package:submersion/features/marine_life/presentation/widgets/species_facts_row.dart';

import 'species_picture_test_support.dart';

void main() {
  testWidgets('shows dives, sites, dates and the badge', (tester) async {
    await pumpPictures(
      tester,
      SpeciesFactsRow(
        insights: SpeciesInsights(
          totalSightings: 5,
          diveCount: 5,
          siteCount: 3,
          firstSeen: DateTime.utc(2024, 1, 10),
          lastSeen: DateTime.utc(2026, 5, 7),
        ),
        rarity: SpeciesRarity.notSeenLately,
      ),
    );
    expect(find.text('5'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('2024'), findsOneWidget);
    expect(find.textContaining('2026'), findsOneWidget);
    expect(find.text('Not seen lately'), findsOneWidget);
  });

  testWidgets('a species with no sightings says so', (tester) async {
    await pumpPictures(
      tester,
      const SpeciesFactsRow(insights: SpeciesInsights.empty),
    );
    expect(find.text('No sightings recorded yet'), findsOneWidget);
  });
}
