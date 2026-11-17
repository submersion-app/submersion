import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/edit_sections/sightings_editor.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/edit_sighting_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/species_picker_sheet.dart';
import 'package:submersion/features/dive_log/presentation/widgets/site_species_suggestion_chips.dart';
import 'package:submersion/features/marine_life/domain/entities/sighting_abundance.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/site_species_suggestions.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../../helpers/mock_providers.dart';

/// The sightings editor the dive form, bulk edit and the Sightings card
/// share (issue #4527, plan 6).
void main() {
  const turtle = Sighting(
    id: 's1',
    diveId: 'd1',
    speciesId: 'turtle',
    speciesName: 'Green turtle',
    speciesCategory: SpeciesCategory.turtle,
    count: 2,
  );
  const ray = Sighting(
    id: 's2',
    diveId: 'd1',
    speciesId: 'ray',
    speciesName: 'Eagle ray',
    speciesCategory: SpeciesCategory.ray,
  );

  late List<List<Sighting>> changes;
  setUp(() => changes = []);

  Future<void> pump(
    WidgetTester tester, {
    List<Sighting> sightings = const [turtle, ray],
    String? siteId,
  }) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: await getBaseOverrides(),
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: SightingsEditor(
                diveId: 'd1',
                sightings: sightings,
                onChanged: changes.add,
                siteId: siteId,
                siteName: siteId == null ? null : 'House reef',
                excludeDiveId: 'd1',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('rows show each sighting; remove calls back without it', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('Green turtle'), findsOneWidget);
    expect(find.text('Eagle ray'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove sighting').first);
    expect(changes.single.map((s) => s.id), ['s2']);
  });

  testWidgets('Add opens the species picker and calls back with the new '
      'sighting', (tester) async {
    await pump(tester, sightings: const []);
    await tester.tap(find.text('Add'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final sheet = tester.widget<SpeciesPickerSheet>(
      find.byType(SpeciesPickerSheet),
    );
    sheet.onSpeciesSelected(
      const Species(
        id: 'manta',
        commonName: 'Manta',
        category: SpeciesCategory.ray,
      ),
      (abundance: SightingAbundance.seen, count: 1),
      'Cleaning station',
    );
    await tester.pump();

    final added = changes.single.single;
    expect(added.speciesId, 'manta');
    expect(added.diveId, 'd1');
    expect(added.notes, 'Cleaning station');
    expect(added.id, isNotEmpty);
  });

  testWidgets('a tap opens the edit sheet; delete there removes it', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Eagle ray'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    tester.widget<EditSightingSheet>(find.byType(EditSightingSheet)).onDelete();
    await tester.pump();
    expect(changes.single.map((s) => s.id), ['s1']);
  });

  testWidgets('with a site, suggestions show and add a Seen sighting; with '
      'none, nothing', (tester) async {
    await pump(tester);
    expect(find.byType(SiteSpeciesSuggestionChips), findsNothing);

    await pump(tester, siteId: 'site');
    final chips = tester.widget<SiteSpeciesSuggestionChips>(
      find.byType(SiteSpeciesSuggestionChips),
    );
    expect(chips.loggedSpeciesIds, {'turtle', 'ray'});
    chips.onAdd(
      const SiteSpeciesSuggestion(
        speciesId: 'octopus',
        speciesName: 'Octopus',
        category: SpeciesCategory.other,
        diveCount: 3,
        animalCount: 4,
      ),
    );
    await tester.pump();
    final added = changes.single.last;
    expect(added.speciesId, 'octopus');
    expect(added.abundance, SightingAbundance.seen);
  });
}
