import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/presentation/widgets/pickers/species_picker_sheet.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/data/services/species_lookup_service.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_lookup_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

const _hit = SpeciesLookupHit(
  taxonId: 52188,
  scientificName: 'Rhincodon typus',
  rank: 'species',
  rankLevel: 10,
  commonName: 'Whale Shark',
  observationCount: 5,
);

const _resolved = SpeciesLookupResult(
  taxonId: 52188,
  commonName: 'Whale Shark',
  scientificName: 'Rhincodon typus',
  category: SpeciesCategory.shark,
  taxonomyClass: 'Chondrichthyes',
);

class _FakeLookup implements SpeciesLookupService {
  @override
  Future<List<SpeciesLookupHit>> search(
    String query, {
    required String locale,
  }) async => const [_hit];

  @override
  Future<SpeciesLookupResult> resolve(
    int taxonId, {
    required String locale,
  }) async => _resolved;
}

/// Records creations; `existing` is what a scientific-name lookup returns.
class _RecordingRepository extends Fake implements SpeciesRepository {
  _RecordingRepository({this.existing});

  final Species? existing;
  final List<Map<String, Object?>> created = [];
  int nameOnlyCreations = 0;

  @override
  Future<Species?> findSpeciesByScientificName(String scientificName) async =>
      existing;

  @override
  Future<Species> createSpecies({
    required String commonName,
    String? scientificName,
    required SpeciesCategory category,
    String? taxonomyClass,
    String? description,
  }) async {
    created.add({
      'commonName': commonName,
      'scientificName': scientificName,
      'category': category,
      'taxonomyClass': taxonomyClass,
    });
    return Species(
      id: 'new-1',
      commonName: commonName,
      scientificName: scientificName,
      category: category,
      taxonomyClass: taxonomyClass,
    );
  }

  @override
  Future<Species> getOrCreateSpecies({
    required String commonName,
    String? scientificName,
    required SpeciesCategory category,
  }) async {
    nameOnlyCreations += 1;
    return Species(id: 'plain-1', commonName: commonName, category: category);
  }
}

const _lookupFooter = ValueKey('species_picker_lookup_online');

/// A catalog that answers "sail" locally, so the lookup footer is exercised
/// on the path the empty state never reaches.
const _catalog = [
  Species(
    id: 'sp_sailfin_blenny',
    commonName: 'Sailfin Blenny',
    scientificName: 'Emblemaria pandionis',
    category: SpeciesCategory.fish,
    isBuiltIn: true,
  ),
  Species(
    id: 'sp_sailfin_tang',
    commonName: 'Sailfin Tang',
    scientificName: 'Zebrasoma veliferum',
    category: SpeciesCategory.fish,
    isBuiltIn: true,
  ),
];

Future<void> _pump(
  WidgetTester tester, {
  required _RecordingRepository repository,
  List<Species> catalog = const [],
}) async {
  tester.view.physicalSize = const Size(900, 1800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  List<Species> matching(String query) => catalog
      .where(
        (s) => s.commonName.toLowerCase().contains(query.trim().toLowerCase()),
      )
      .toList();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allSpeciesProvider.overrideWith((ref) async => catalog),
        speciesByCategoryProvider.overrideWith(
          (ref, category) async =>
              catalog.where((s) => s.category == category).toList(),
        ),
        speciesSearchProvider.overrideWith(
          (ref, query) async => matching(query),
        ),
        speciesRepositoryProvider.overrideWithValue(repository),
        speciesLookupServiceProvider.overrideWithValue(_FakeLookup()),
        speciesLookupLocaleProvider.overrideWithValue('en'),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SpeciesPickerSheet(
            scrollController: ScrollController(),
            onSpeciesSelected: (_, _, _) {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps the sheet into a short fixed box, the way DraggableScrollableSheet
/// does at its minimum size. Kept wide on purpose: the test font draws every
/// glyph as wide as the font size, so a narrow surface overflows the title
/// row for reasons that have nothing to do with the height under test.
Future<void> _pumpConstrained(
  WidgetTester tester, {
  required double height,
}) async {
  tester.view.physicalSize = Size(900, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allSpeciesProvider.overrideWith((ref) async => _catalog),
        speciesByCategoryProvider.overrideWith(
          (ref, category) async => const [],
        ),
        speciesSearchProvider.overrideWith((ref, query) async => const []),
        speciesRepositoryProvider.overrideWithValue(_RecordingRepository()),
        speciesLookupServiceProvider.overrideWithValue(_FakeLookup()),
        speciesLookupLocaleProvider.overrideWithValue('en'),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: SizedBox(
              height: height,
              width: 900,
              child: SpeciesPickerSheet(
                scrollController: ScrollController(),
                onSpeciesSelected: (_, _, _) {},
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Pumps the sheet bottom-anchored under a home-indicator-sized inset, the
/// way both hosts present it: showModalBottomSheet without useSafeArea.
Future<void> _pumpWithBottomInset(
  WidgetTester tester, {
  required double inset,
}) async {
  tester.view.physicalSize = const Size(900, 800);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allSpeciesProvider.overrideWith((ref) async => _catalog),
        speciesByCategoryProvider.overrideWith(
          (ref, category) async => const [],
        ),
        speciesSearchProvider.overrideWith((ref, query) async => const []),
        speciesRepositoryProvider.overrideWithValue(_RecordingRepository()),
        speciesLookupServiceProvider.overrideWithValue(_FakeLookup()),
        speciesLookupLocaleProvider.overrideWithValue('en'),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          // The override sits inside the body so it is the sheet's nearest
          // MediaQuery, whatever the Scaffold did with the real padding.
          body: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(padding: EdgeInsets.only(bottom: inset)),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: SizedBox(
                  height: 560,
                  width: 900,
                  child: SpeciesPickerSheet(
                    scrollController: ScrollController(),
                    onSpeciesSelected: (_, _, _) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _typeAndAdd(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'whale');
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('whale').last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a lookup result creates the species with its fields and '
      'opens the sighting dialog', (tester) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository: repository);

    await _typeAndAdd(tester);
    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Whale Shark'));
    await tester.pumpAndSettle();

    expect(repository.created.single['scientificName'], 'Rhincodon typus');
    expect(repository.created.single['category'], SpeciesCategory.shark);
    expect(repository.created.single['taxonomyClass'], 'Chondrichthyes');
    expect(repository.nameOnlyCreations, 0);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('an existing species with that scientific name is reused', (
    tester,
  ) async {
    const existing = Species(
      id: 'sp_whale_shark',
      commonName: 'Whale Shark',
      scientificName: 'Rhincodon typus',
      category: SpeciesCategory.shark,
      isBuiltIn: true,
    );
    final repository = _RecordingRepository(existing: existing);
    await _pump(tester, repository: repository);

    await _typeAndAdd(tester);
    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Whale Shark'));
    await tester.pumpAndSettle();

    expect(repository.created, isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('Create without lookup keeps the name-only path', (tester) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository: repository);

    await _typeAndAdd(tester);
    await tester.tap(find.text('Create without lookup'));
    await tester.pumpAndSettle();

    expect(repository.nameOnlyCreations, 1);
    expect(repository.created, isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('the online lookup is offered even when the catalog matches '
      'the query', (tester) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository: repository, catalog: _catalog);

    // The empty state's "Add ..." button is the pre-existing door and it is
    // shut here, because the catalog answered the search.
    await tester.enterText(find.byType(TextField).first, 'sail');
    await tester.pumpAndSettle();
    expect(find.text('Sailfin Blenny'), findsOneWidget);
    expect(find.textContaining('Add "'), findsNothing);

    expect(find.byKey(_lookupFooter), findsOneWidget);
  });

  testWidgets('the online lookup is offered before anything is typed', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository: repository, catalog: _catalog);

    expect(find.byKey(_lookupFooter), findsOneWidget);
  });

  testWidgets('the footer carries the current query into the lookup and '
      'creates the chosen species', (tester) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository: repository, catalog: _catalog);

    await tester.enterText(find.byType(TextField).first, 'whale');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_lookupFooter));
    await tester.pumpAndSettle();

    // The sheet opens pre-filled, so the diver does not retype the name.
    expect(find.text('Look up a species'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).last).controller?.text,
      'whale',
    );

    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Whale Shark'));
    await tester.pumpAndSettle();

    expect(repository.created.single['scientificName'], 'Rhincodon typus');
    expect(repository.nameOnlyCreations, 0);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('browsing the lookup with an empty query offers no '
      'create-without escape and creates nothing when dismissed', (
    tester,
  ) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository: repository, catalog: _catalog);

    await tester.tap(find.byKey(_lookupFooter));
    await tester.pumpAndSettle();
    expect(find.text('Look up a species'), findsOneWidget);

    // With no name to fall back on, "Create without lookup" would mint a
    // nameless species, so it must not be offered at all.
    expect(find.text('Create without lookup'), findsNothing);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(find.text('Look up a species'), findsNothing);
    expect(repository.created, isEmpty);
    expect(repository.nameOnlyCreations, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('dismissing the lookup opened from the footer with a query '
      'creates nothing', (tester) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository: repository, catalog: _catalog);

    await tester.enterText(find.byType(TextField).first, 'whale');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_lookupFooter));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();

    expect(repository.created, isEmpty);
    expect(repository.nameOnlyCreations, 0);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('Create without lookup from the footer keeps the name-only '
      'path', (tester) async {
    final repository = _RecordingRepository();
    await _pump(tester, repository: repository, catalog: _catalog);

    await tester.enterText(find.byType(TextField).first, 'whale');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_lookupFooter));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create without lookup'));
    await tester.pumpAndSettle();

    expect(repository.nameOnlyCreations, 1);
    expect(repository.created, isEmpty);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('the footer survives a short sheet, since it sits below the '
      'scrolling list rather than inside it', (tester) async {
    await _pumpConstrained(tester, height: 320);

    expect(tester.takeException(), isNull);
    expect(find.byKey(_lookupFooter), findsOneWidget);
    // Off-screen would still be "found", so check it can actually be hit.
    final box = tester.getRect(find.byKey(_lookupFooter));
    expect(box.bottom, lessThanOrEqualTo(320));
    expect(box.height, greaterThan(0));
    // The list is the part that gives, not the footer.
    expect(find.byType(ListView), findsWidgets);
  });

  testWidgets('the footer clears the bottom inset, since neither host passes '
      'useSafeArea', (tester) async {
    const inset = 34.0;
    await _pumpWithBottomInset(tester, inset: inset);

    final footer = tester.getRect(find.byKey(_lookupFooter));
    // The sheet is bottom-anchored, so its own bottom edge is the screen
    // edge; the button has to stop short of the home indicator.
    expect(footer.bottom, lessThanOrEqualTo(800 - inset));
    expect(footer.height, greaterThan(0));
  });
}
