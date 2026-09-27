import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/presentation/pages/species_detail_page.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/insights/presentation/providers/insights_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_app.dart';

const _species = Species(
  id: 'sp_whale_shark',
  commonName: 'Whale Shark',
  category: SpeciesCategory.shark,
  isBuiltIn: true,
);

/// Issue #1930: the species insights query rethrows a failure instead of
/// answering with empty statistics. The page must say so, not drop the
/// section as if there were nothing to show.
void main() {
  testWidgets('a failed statistics query says so', (tester) async {
    final overrides = await getBaseOverrides();
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          ...overrides,
          speciesProvider(_species.id).overrideWith((ref) async => _species),
          speciesInsightsProvider(
            _species.id,
          ).overrideWith((ref) async => throw StateError('query failed')),
          speciesSightingsProvider(
            _species.id,
          ).overrideWith((ref) async => const []),
        ],
        child: SpeciesDetailPage(speciesId: _species.id),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load sighting statistics'), findsOneWidget);
    expect(find.text('No sightings recorded yet'), findsNothing);
  });
}
