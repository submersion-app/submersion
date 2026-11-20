import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/reef/domain/entities/nearby_species.dart';
import 'package:submersion/features/species_id/presentation/providers/recorded_nearby_providers.dart';
import 'package:submersion/features/species_id/presentation/widgets/recorded_nearby_line.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

/// The "Recorded nearby" marker's own layout (issue #4668).
void main() {
  Future<double> markerHeightIn(WidgetTester tester, double width) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recordedNearbyListProvider.overrideWith(
            (ref, request) async => const NearbySpecies(speciesKeys: {1}),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: width,
                child: const RecordedNearbyLine(
                  request: (diveId: 'd1', photo: null),
                  gbifKeys: {1},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return tester.getSize(find.text('Recorded nearby')).height;
  }

  testWidgets('in a narrow column it stays one line', (tester) async {
    // Longer translations (Portuguese, Italian, Dutch) are wider than a
    // phone's name column; a second line would push the row's buttons down
    // as the list arrives.
    final wide = await markerHeightIn(tester, 600);
    final narrow = await markerHeightIn(tester, 60);
    expect(narrow, wide);
  });
}
