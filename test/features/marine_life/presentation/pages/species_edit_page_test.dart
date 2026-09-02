import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/data/services/species_lookup_service.dart';
import 'package:submersion/features/marine_life/domain/entities/species.dart';
import 'package:submersion/features/marine_life/domain/entities/species_lookup.dart';
import 'package:submersion/features/marine_life/presentation/pages/species_edit_page.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_lookup_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';

import '../../../../helpers/test_app.dart';

class _FakeLookup implements SpeciesLookupService {
  @override
  Future<List<SpeciesLookupHit>> search(
    String query, {
    required String locale,
  }) async => const [
    SpeciesLookupHit(
      taxonId: 52188,
      scientificName: 'Rhincodon typus',
      rank: 'species',
      rankLevel: 10,
      commonName: 'Whale Shark',
      observationCount: 5,
    ),
  ];

  @override
  Future<SpeciesLookupResult> resolve(
    int taxonId, {
    required String locale,
  }) async => const SpeciesLookupResult(
    taxonId: 52188,
    commonName: 'Whale Shark',
    scientificName: 'Rhincodon typus',
    category: SpeciesCategory.shark,
    taxonomyClass: 'Chondrichthyes',
  );
}

/// Records what the editor writes, and can hold a write open across a frame,
/// which is when Riverpod disposes an autoDispose provider nothing listens to.
class _FakeSpeciesRepository extends Fake implements SpeciesRepository {
  _FakeSpeciesRepository(this._stored);

  final List<Species> _stored;
  final _changes = StreamController<void>.broadcast();
  final List<Species> updated = [];
  final List<String> created = [];

  /// Completed by the test to release the in-flight write.
  Completer<void>? gate;

  /// Drops the row on the next read, standing in for a sync that deleted the
  /// species from another device while the editor was open.
  bool deleteOnNextRead = false;

  @override
  Stream<void> watchSpeciesChanges() => _changes.stream;

  @override
  Future<List<Species>> getAllSpecies() async => List.of(_stored);

  @override
  Future<Species?> getSpeciesById(String id) async {
    if (deleteOnNextRead) {
      _stored.removeWhere((s) => s.id == id);
      deleteOnNextRead = false;
      return null;
    }
    return _stored.where((s) => s.id == id).firstOrNull;
  }

  @override
  Future<void> updateSpecies(Species species) async {
    await gate?.future;
    updated.add(species);
  }

  @override
  Future<Species> createSpecies({
    required String commonName,
    String? scientificName,
    required SpeciesCategory category,
    String? taxonomyClass,
    String? description,
  }) async {
    await gate?.future;
    created.add(commonName);
    return Species(
      id: 'new-1',
      commonName: commonName,
      scientificName: scientificName,
      category: category,
      taxonomyClass: taxonomyClass,
      description: description,
    );
  }

  void dispose() => _changes.close();
}

void main() {
  testWidgets('a lookup fills name, scientific name, category and class', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testApp(
        locale: const Locale('en'),
        overrides: [
          speciesLookupServiceProvider.overrideWithValue(_FakeLookup()),
          speciesLookupLocaleProvider.overrideWithValue('en'),
        ],
        child: const SpeciesEditPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'whale');
    await tester.tap(find.text('Look up online'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Look up'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Whale Shark'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextFormField, 'Whale Shark'), findsOneWidget);
    expect(
      find.widgetWithText(TextFormField, 'Rhincodon typus'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextFormField, 'Chondrichthyes'),
      findsOneWidget,
    );
    expect(find.text('Shark'), findsOneWidget);
  });

  group('saving', () {
    const existing = Species(
      id: 's1',
      commonName: 'Map Puffer',
      scientificName: 'Arothron mappa',
      category: SpeciesCategory.fish,
      taxonomyClass: 'Actinopterygii',
      description: 'Large pale pufferfish.',
      photoPath: '/photos/map-puffer.jpg',
    );

    late _FakeSpeciesRepository repository;

    setUp(() => repository = _FakeSpeciesRepository([existing]));
    tearDown(() => repository.dispose());

    /// Mirrors the real route shape: the editor sits on its own route above
    /// the species page, so nothing on screen watches
    /// speciesListNotifierProvider while the save runs.
    Widget host({bool editing = true}) => testAppRouter(
      overrides: [speciesRepositoryProvider.overrideWithValue(repository)],
      locale: const Locale('en'),
      router: GoRouter(
        initialLocation: editing ? '/species/edit' : '/species/new',
        routes: [
          GoRoute(
            path: '/species',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('species list'))),
            routes: [
              GoRoute(
                path: 'new',
                builder: (context, state) => const SpeciesEditPage(),
              ),
              GoRoute(
                path: 'edit',
                builder: (context, state) =>
                    const SpeciesEditPage(speciesId: 's1'),
              ),
            ],
          ),
        ],
      ),
    );

    testWidgets('an edit saves while nothing listens to the species list', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).first,
        'Map Pufferfish',
      );
      repository.gate = Completer<void>();
      await tester.tap(find.text('Save'));
      // End the frame so Riverpod disposes anything unlistened before the
      // write returns.
      await tester.pump();
      repository.gate!.complete();
      await tester.pumpAndSettle();

      expect(repository.updated.single.commonName, 'Map Pufferfish');
      expect(find.textContaining('Error saving species'), findsNothing);
      expect(find.text('species list'), findsOneWidget);
    });

    testWidgets('a new species saves while nothing listens to the list', (
      tester,
    ) async {
      await tester.pumpWidget(host(editing: false));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Map Puffer');
      repository.gate = Completer<void>();
      await tester.tap(find.text('Save'));
      await tester.pump();
      repository.gate!.complete();
      await tester.pumpAndSettle();

      expect(repository.created, ['Map Puffer']);
      expect(find.textContaining('Error saving species'), findsNothing);
      expect(find.text('species list'), findsOneWidget);
    });

    testWidgets('clearing the optional fields blanks them on the row', (
      tester,
    ) async {
      await tester.pumpWidget(host());
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(1), '');
      await tester.enterText(fields.at(2), '');
      await tester.enterText(fields.at(3), '');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      final saved = repository.updated.single;
      expect(saved.scientificName, isNull);
      expect(saved.taxonomyClass, isNull);
      expect(saved.description, isNull);
      // Fields the editor does not show survive the write.
      expect(saved.id, 's1');
      expect(saved.photoPath, '/photos/map-puffer.jpg');
    });

    testWidgets(
      'reports a species deleted under the editor instead of a save',
      (tester) async {
        await tester.pumpWidget(host());
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextFormField).first,
          'Map Pufferfish',
        );
        repository.deleteOnNextRead = true;
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(repository.updated, isEmpty);
        expect(find.text('This species no longer exists.'), findsOneWidget);
        expect(find.textContaining('updated'), findsNothing);
        // The editor stays put so the diver does not lose what they typed.
        expect(find.text('species list'), findsNothing);
      },
    );
  });
}
