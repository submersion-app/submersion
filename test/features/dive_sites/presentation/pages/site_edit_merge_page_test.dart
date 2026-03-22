import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_edit_page.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

import '../../../../helpers/test_database.dart';

Widget _buildMergePageHarness({
  required SharedPreferences prefs,
  required SiteRepository siteRepository,
  required List<String> siteIds,
}) {
  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      siteRepositoryProvider.overrideWithValue(siteRepository),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SiteEditPage(mergeSiteIds: siteIds),
    ),
  );
}

void main() {
  late SharedPreferences prefs;
  late SiteRepository siteRepository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    siteRepository = SiteRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  testWidgets('merge mode initializes with first non-empty values and cycles', (
    tester,
  ) async {
    final site1 = await siteRepository.createSite(
      const DiveSite(id: 'site-1', name: 'Siet'),
    );
    final site2 = await siteRepository.createSite(
      const DiveSite(
        id: 'site-2',
        name: 'Site',
        country: 'Belize',
        region: 'Turneffe',
      ),
    );

    await tester.pumpWidget(
      _buildMergePageHarness(
        prefs: prefs,
        siteRepository: siteRepository,
        siteIds: [site1.id, site2.id],
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Merge Sites'), findsOneWidget);

    final nameField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(nameField.controller!.text, equals('Siet'));

    await tester.tap(find.byIcon(Icons.sync_alt).first);
    await tester.pumpAndSettle();

    final updatedNameField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(updatedNameField.controller!.text, equals('Site'));
    expect(find.textContaining('From Site'), findsWidgets);
  });

  testWidgets(
    'merge mode cycles difficulty when sites have different difficulties',
    (tester) async {
      final site1 = await siteRepository.createSite(
        const DiveSite(
          id: 'diff-1',
          name: 'Easy Reef',
          difficulty: SiteDifficulty.beginner,
        ),
      );
      final site2 = await siteRepository.createSite(
        const DiveSite(
          id: 'diff-2',
          name: 'Hard Reef',
          difficulty: SiteDifficulty.advanced,
        ),
      );

      await tester.pumpWidget(
        _buildMergePageHarness(
          prefs: prefs,
          siteRepository: siteRepository,
          siteIds: [site1.id, site2.id],
        ),
      );
      await tester.pumpAndSettle();

      // Beginner chip should be selected initially
      final beginnerChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Beginner'),
      );
      expect(beginnerChip.selected, isTrue);

      // Find the sync_alt icon in the difficulty section (it's in a Card)
      // The difficulty section has a sync_alt icon for cycling
      final difficultySection = find.ancestor(
        of: find.text('Difficulty Level'),
        matching: find.byType(Card),
      );
      final difficultyCycleButton = find.descendant(
        of: difficultySection,
        matching: find.byIcon(Icons.sync_alt),
      );
      expect(difficultyCycleButton, findsOneWidget);

      await tester.tap(difficultyCycleButton);
      await tester.pumpAndSettle();

      final advancedChip = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Advanced'),
      );
      expect(advancedChip.selected, isTrue);
    },
  );

  testWidgets('merge mode cycles rating when sites have different ratings', (
    tester,
  ) async {
    final site1 = await siteRepository.createSite(
      const DiveSite(id: 'rate-1', name: 'OK Site', rating: 2.0),
    );
    final site2 = await siteRepository.createSite(
      const DiveSite(id: 'rate-2', name: 'Great Site', rating: 5.0),
    );

    await tester.pumpWidget(
      _buildMergePageHarness(
        prefs: prefs,
        siteRepository: siteRepository,
        siteIds: [site1.id, site2.id],
      ),
    );
    await tester.pumpAndSettle();

    // Scroll down to make the Rating section visible
    await tester.scrollUntilVisible(
      find.text('Rating'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    // Initially rating = 2 (from site1): 2 filled stars, 3 empty
    expect(find.byIcon(Icons.star), findsNWidgets(2));
    expect(find.byIcon(Icons.star_border), findsNWidgets(3));

    // Cycle rating
    final ratingSection = find.ancestor(
      of: find.text('Rating'),
      matching: find.byType(Card),
    );
    final ratingCycleButton = find.descendant(
      of: ratingSection,
      matching: find.byIcon(Icons.sync_alt),
    );
    expect(ratingCycleButton, findsOneWidget);

    await tester.tap(ratingCycleButton);
    await tester.pumpAndSettle();

    // Now rating = 5 (from site2): 5 filled stars, 0 empty
    expect(find.byIcon(Icons.star), findsNWidgets(5));
    expect(find.byIcon(Icons.star_border), findsNothing);
  });

  testWidgets(
    'merge mode cycles GPS coordinates when sites have different locations',
    (tester) async {
      final site1 = await siteRepository.createSite(
        const DiveSite(
          id: 'gps-1',
          name: 'North Site',
          location: GeoPoint(17.288, -87.812),
        ),
      );
      final site2 = await siteRepository.createSite(
        const DiveSite(
          id: 'gps-2',
          name: 'South Site',
          location: GeoPoint(-8.409, 115.189),
        ),
      );

      await tester.pumpWidget(
        _buildMergePageHarness(
          prefs: prefs,
          siteRepository: siteRepository,
          siteIds: [site1.id, site2.id],
        ),
      );
      await tester.pumpAndSettle();

      // Scroll down to make the GPS section visible
      await tester.scrollUntilVisible(
        find.text('GPS Coordinates'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Find the GPS section
      final gpsSection = find.ancestor(
        of: find.text('GPS Coordinates'),
        matching: find.byType(Card),
      );
      final gpsCycleButton = find.descendant(
        of: gpsSection,
        matching: find.byIcon(Icons.sync_alt),
      );
      expect(gpsCycleButton, findsOneWidget);

      // Verify initial coordinates (site1)
      expect(find.text('17.288'), findsOneWidget);
      expect(find.text('-87.812'), findsOneWidget);

      await tester.tap(gpsCycleButton);
      await tester.pumpAndSettle();

      // After cycling, should show site2 coordinates
      expect(find.text('-8.409'), findsOneWidget);
      expect(find.text('115.189'), findsOneWidget);
    },
  );

  testWidgets(
    'merge mode with three sites cycles country field through all candidates',
    (tester) async {
      final site1 = await siteRepository.createSite(
        const DiveSite(id: 'c-1', name: 'Site 1', country: 'Mexico'),
      );
      final site2 = await siteRepository.createSite(
        const DiveSite(id: 'c-2', name: 'Site 2', country: 'Belize'),
      );
      final site3 = await siteRepository.createSite(
        const DiveSite(id: 'c-3', name: 'Site 3', country: 'Honduras'),
      );

      await tester.pumpWidget(
        _buildMergePageHarness(
          prefs: prefs,
          siteRepository: siteRepository,
          siteIds: [site1.id, site2.id, site3.id],
        ),
      );
      await tester.pumpAndSettle();

      // Find the country TextFormField (3rd TextFormField: name, desc, country)
      final textFields = find.byType(TextFormField);
      final countryField = tester.widget<TextFormField>(textFields.at(2));
      expect(countryField.controller!.text, equals('Mexico'));

      // sync_alt icons only appear for fields with >1 distinct candidate.
      // name: 3 distinct -> icon at(0)
      // description: all empty -> no icon
      // country: 3 distinct -> icon at(1)
      final allSyncIcons = find.byIcon(Icons.sync_alt);

      await tester.tap(allSyncIcons.at(1));
      await tester.pumpAndSettle();

      final field2 = tester.widget<TextFormField>(textFields.at(2));
      expect(field2.controller!.text, equals('Belize'));

      // Cycle again
      await tester.tap(allSyncIcons.at(1));
      await tester.pumpAndSettle();

      final field3 = tester.widget<TextFormField>(textFields.at(2));
      expect(field3.controller!.text, equals('Honduras'));

      // Cycle wraps back to first
      await tester.tap(allSyncIcons.at(1));
      await tester.pumpAndSettle();

      final field4 = tester.widget<TextFormField>(textFields.at(2));
      expect(field4.controller!.text, equals('Mexico'));
    },
  );

  testWidgets('merge mode skips duplicate field values in candidates', (
    tester,
  ) async {
    final site1 = await siteRepository.createSite(
      const DiveSite(id: 'dup-1', name: 'Same Name', country: 'Mexico'),
    );
    final site2 = await siteRepository.createSite(
      const DiveSite(id: 'dup-2', name: 'Same Name', country: 'Mexico'),
    );
    final site3 = await siteRepository.createSite(
      const DiveSite(id: 'dup-3', name: 'Different', country: 'Belize'),
    );

    await tester.pumpWidget(
      _buildMergePageHarness(
        prefs: prefs,
        siteRepository: siteRepository,
        siteIds: [site1.id, site2.id, site3.id],
      ),
    );
    await tester.pumpAndSettle();

    // Name should start with 'Same Name'
    final nameField = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(nameField.controller!.text, equals('Same Name'));

    // Cycle name - should go to 'Different' (skipping the duplicate)
    await tester.tap(find.byIcon(Icons.sync_alt).first);
    await tester.pumpAndSettle();

    final updated = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(updated.controller!.text, equals('Different'));

    // Cycle again - wraps back to 'Same Name' (only 2 distinct candidates)
    await tester.tap(find.byIcon(Icons.sync_alt).first);
    await tester.pumpAndSettle();

    final wrapped = tester.widget<TextFormField>(
      find.byType(TextFormField).first,
    );
    expect(wrapped.controller!.text, equals('Same Name'));
  });

  testWidgets('merge mode selects first meaningful value for fields', (
    tester,
  ) async {
    // Site 1 has no country, site 2 has country - should prefer site 2
    final site1 = await siteRepository.createSite(
      const DiveSite(id: 'pref-1', name: 'No Country Site'),
    );
    final site2 = await siteRepository.createSite(
      const DiveSite(id: 'pref-2', name: 'Has Country', country: 'Thailand'),
    );

    await tester.pumpWidget(
      _buildMergePageHarness(
        prefs: prefs,
        siteRepository: siteRepository,
        siteIds: [site1.id, site2.id],
      ),
    );
    await tester.pumpAndSettle();

    // Country field should be initialized to 'Thailand' (first meaningful)
    final textFields = find.byType(TextFormField);
    final countryField = tester.widget<TextFormField>(textFields.at(2));
    expect(countryField.controller!.text, equals('Thailand'));
  });
}
