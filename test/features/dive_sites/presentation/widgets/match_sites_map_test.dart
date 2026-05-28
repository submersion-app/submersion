import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_sites/data/services/site_matching_service.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/widgets/match_sites_map.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/mock_providers.dart';

void main() {
  testWidgets('renders dive + candidate markers and reports taps', (
    tester,
  ) async {
    String? tapped;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // MatchSitesMap reads the map-tile style from settingsProvider.
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MatchSitesMap(
              divePoint: const GeoPoint(0, 0),
              candidates: const [
                MatchCandidateView(
                  id: 's1',
                  name: 'Blue Hole',
                  isExisting: true,
                  distanceMeters: 40,
                  location: GeoPoint(0, 0.0003),
                ),
              ],
              selectedCandidateId: null,
              onSelectCandidate: (id) => tapped = id,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.my_location), findsOneWidget);
    expect(find.byIcon(Icons.place), findsOneWidget);

    await tester.tap(find.byIcon(Icons.place));
    expect(tapped, 's1');
  });

  testWidgets('renders only the dive pin when there are no candidates', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsProvider.overrideWith((ref) => MockSettingsNotifier()),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: MatchSitesMap(
              divePoint: const GeoPoint(0, 0),
              candidates: const [],
              selectedCandidateId: null,
              onSelectCandidate: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.my_location), findsOneWidget);
    expect(find.byIcon(Icons.place), findsNothing);
  });
}
