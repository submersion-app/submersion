import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/pages/site_merge_page.dart';
import 'package:submersion/shared/widgets/forms/form_section.dart';
import 'package:submersion/shared/widgets/shared_items/item_sharing_field.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';
import 'package:submersion/l10n/arb/app_localizations_en.dart';

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
      home: SiteMergePage(siteIds: siteIds),
    ),
  );
}

/// The merge page (issue #4527, phase 2, plan 7): each field shows the
/// first site's meaningful value and cycles through the others'.
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

  // The sites being merged are the duplicates the merge resolves, not a
  // similar site to warn about (seen in the manual test).
  testWidgets('the name hint never names a site the merge takes in', (
    tester,
  ) async {
    await siteRepository.createSite(
      const DiveSite(id: 'hole-1', name: 'Blue Hole Lighthouse Reef'),
    );
    await siteRepository.createSite(
      const DiveSite(id: 'hole-2', name: 'Blue Hole Lighthouse Reef (copy)'),
    );

    await tester.pumpWidget(
      _buildMergePageHarness(
        prefs: prefs,
        siteRepository: siteRepository,
        siteIds: const ['hole-1', 'hole-2'],
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        AppLocalizationsEn().diveSites_similarSite_warning(
          'Blue Hole Lighthouse Reef (copy)',
        ),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'merge mode cycles difficulty when sites have different difficulties',
    (tester) async {
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
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
        matching: find.byType(FormSection),
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

  testWidgets('merge mode cycles water type when sites differ', (tester) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final site1 = await siteRepository.createSite(
      const DiveSite(id: 'wt-m1', name: 'Salt Site', waterType: WaterType.salt),
    );
    final site2 = await siteRepository.createSite(
      const DiveSite(
        id: 'wt-m2',
        name: 'Fresh Site',
        waterType: WaterType.fresh,
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
    await tester.scrollUntilVisible(
      find.text('Water Type'),
      100,
      scrollable: find.byType(Scrollable).first,
    );

    // Salt Water (site1, the first non-empty candidate) selected initially.
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Salt Water'))
          .selected,
      isTrue,
    );

    // Only water type differs, so exactly one cycle button sits in Dive Info.
    final waterTypeSection = find.ancestor(
      of: find.text('Water Type'),
      matching: find.byType(FormSection),
    );
    final cycleButton = find.descendant(
      of: waterTypeSection,
      matching: find.byIcon(Icons.sync_alt),
    );
    expect(cycleButton, findsOneWidget);

    await tester.tap(cycleButton);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Fresh Water'))
          .selected,
      isTrue,
    );
  });

  testWidgets('merge mode cycles rating when sites have different ratings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
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
      matching: find.byType(FormSection),
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
      tester.view.physicalSize = const Size(900, 3600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
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

      // Scroll down to make the Location section's rows visible
      await tester.scrollUntilVisible(
        find.text('Latitude'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Find the Location section
      final gpsSection = find.ancestor(
        of: find.text('Latitude'),
        matching: find.byType(FormSection),
      );
      final gpsCycleButton = find.descendant(
        of: gpsSection,
        matching: find.byIcon(Icons.sync_alt),
      );
      expect(gpsCycleButton, findsOneWidget);

      // Verify initial coordinates (site1). The coordinate fields render at a
      // fixed six decimal places whatever precision the site was stored with.
      expect(find.text('17.288000'), findsOneWidget);
      expect(find.text('-87.812000'), findsOneWidget);

      await tester.tap(gpsCycleButton);
      await tester.pumpAndSettle();

      // After cycling, should show site2 coordinates
      expect(find.text('-8.409000'), findsOneWidget);
      expect(find.text('115.189000'), findsOneWidget);
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

  /// The cycle button inside the FormSection that owns [rowLabel].
  Finder cycleButtonFor(String rowLabel) => find.descendant(
    of: find.ancestor(
      of: find.text(rowLabel),
      matching: find.byType(FormSection),
    ),
    matching: find.byIcon(Icons.sync_alt),
  );

  testWidgets('merge mode cycles entry method when sites differ', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final site1 = await siteRepository.createSite(
      const DiveSite(
        id: 'em-1',
        name: 'Boat Site',
        entryMethods: [EntryMethod.boat],
      ),
    );
    final site2 = await siteRepository.createSite(
      const DiveSite(
        id: 'em-2',
        name: 'Boat Site',
        entryMethods: [EntryMethod.shore],
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
    await tester.scrollUntilVisible(
      find.text('Entry Method'),
      100,
      scrollable: find.byType(Scrollable).first,
    );

    // site1, the first non-empty candidate, wins initially.
    expect(find.text('Boat'), findsOneWidget);

    // Only entry method differs, so exactly one cycle button sits in the
    // Access & safety section.
    final cycleButton = cycleButtonFor('Entry Method');
    expect(cycleButton, findsOneWidget);

    await tester.tap(cycleButton);
    await tester.pumpAndSettle();

    expect(find.text('Shore'), findsOneWidget);
    expect(find.text('Boat'), findsNothing);
  });

  testWidgets('merge mode cycles exit method independently', (tester) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final site1 = await siteRepository.createSite(
      const DiveSite(
        id: 'xm-1',
        name: 'Wall',
        exitMethods: [EntryMethod.ladder],
      ),
    );
    final site2 = await siteRepository.createSite(
      const DiveSite(
        id: 'xm-2',
        name: 'Wall',
        exitMethods: [EntryMethod.platform],
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
    await tester.scrollUntilVisible(
      find.text('Exit Method'),
      100,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Ladder'), findsOneWidget);

    await tester.tap(cycleButtonFor('Exit Method'));
    await tester.pumpAndSettle();

    expect(find.text('Platform'), findsOneWidget);
    expect(find.text('Ladder'), findsNothing);
  });

  testWidgets('no cycle button when both sites agree on entry method', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final site1 = await siteRepository.createSite(
      const DiveSite(
        id: 'ag-1',
        name: 'Pier',
        entryMethods: [EntryMethod.jetty],
      ),
    );
    final site2 = await siteRepository.createSite(
      const DiveSite(
        id: 'ag-2',
        name: 'Pier',
        entryMethods: [EntryMethod.jetty],
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
    await tester.scrollUntilVisible(
      find.text('Entry Method'),
      100,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Jetty/Dock'), findsOneWidget);
    expect(cycleButtonFor('Entry Method'), findsNothing);
  });

  testWidgets('merge mode cycles whole entry lists (#2054)', (tester) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final site1 = await siteRepository.createSite(
      const DiveSite(
        id: 'ml-1',
        name: 'Wall',
        entryMethods: [EntryMethod.giantStride],
      ),
    );
    final site2 = await siteRepository.createSite(
      const DiveSite(
        id: 'ml-2',
        name: 'Wall',
        entryMethods: [EntryMethod.backRoll, EntryMethod.giantStride],
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
    await tester.scrollUntilVisible(
      find.text('Entry Method'),
      100,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Giant Stride'), findsOneWidget);
    await tester.tap(cycleButtonFor('Entry Method'));
    await tester.pumpAndSettle();
    expect(find.text('Back Roll, Giant Stride'), findsOneWidget);
  });

  testWidgets('equal lists give one candidate and no cycle button', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 3600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final id in ['eq-1', 'eq-2']) {
      await siteRepository.createSite(
        DiveSite(
          id: id,
          name: 'Wall',
          entryMethods: const [EntryMethod.backRoll, EntryMethod.giantStride],
        ),
      );
    }

    await tester.pumpWidget(
      _buildMergePageHarness(
        prefs: prefs,
        siteRepository: siteRepository,
        siteIds: const ['eq-1', 'eq-2'],
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Entry Method'),
      100,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Back Roll, Giant Stride'), findsOneWidget);
    expect(cycleButtonFor('Entry Method'), findsNothing);
  });

  group('merge mode share toggle', () {
    // A merge keeps each site's sharing (issue #2151): the page offers no
    // picker. That a shared survivor stays shared is pinned by what a merge
    // stores (site_merge_page_save_test.dart).
    testWidgets('offers no sharing picker for a shared survivor', (
      tester,
    ) async {
      // Seed two sites into the test database. The first is shared.
      final repo = SiteRepository();
      final primarySite = await repo.createSite(
        const DiveSite(
          id: 'site-primary',
          name: 'Primary Site',
          isShared: true,
        ),
      );
      await repo.createSite(
        const DiveSite(
          id: 'site-secondary',
          name: 'Secondary Site',
          isShared: false,
        ),
      );

      await tester.pumpWidget(
        _buildMergePageHarness(
          prefs: prefs,
          siteRepository: siteRepository,
          siteIds: [primarySite.id, 'site-secondary'],
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(SharingTile), findsNothing);
    });

    testWidgets('initializes city/island/bodyOfWater from a merge candidate', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(900, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      // Primary has no locality; secondary carries the values that must not be
      // silently dropped during a merge.
      final repo = SiteRepository();
      final primarySite = await repo.createSite(
        const DiveSite(id: 'merge-primary', name: 'Primary'),
      );
      await repo.createSite(
        const DiveSite(
          id: 'merge-secondary',
          name: 'Secondary',
          city: 'Cebu City',
          island: 'Malapascua',
          bodyOfWater: 'Visayan Sea',
        ),
      );

      await tester.pumpWidget(
        _buildMergePageHarness(
          prefs: prefs,
          siteRepository: siteRepository,
          siteIds: [primarySite.id, 'merge-secondary'],
        ),
      );
      await tester.pumpAndSettle();

      // The merge picks the first meaningful value, so the locality fields are
      // populated from the secondary site rather than left empty.
      expect(
        find.widgetWithText(TextFormField, 'Cebu City'),
        findsOneWidget,
        reason: 'city must be initialized from the merge candidate',
      );
      expect(find.widgetWithText(TextFormField, 'Malapascua'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Visayan Sea'), findsOneWidget);
    });
  });
}
