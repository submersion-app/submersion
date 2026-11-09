import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';

import '../../../../helpers/test_database.dart';

const _siteId = 'site-1';

Future<void> _insertSiteAndDives() async {
  final db = DatabaseService.instance.database;
  final now = DateTime(2026).millisecondsSinceEpoch;
  await db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion.insert(
          id: _siteId,
          name: 'Blue Corner',
          createdAt: now,
          updatedAt: now,
        ),
      );
  for (final id in ['d1', 'd2']) {
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            siteId: const Value(_siteId),
            diveDateTime: Value(now),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }
}

/// The dive editor's suggestion chips (issue #4383) read other dives'
/// sightings at the site and the site's expected list, and must follow
/// writes to either without a manual invalidate.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() async {
    await setUpTestDatabase();
    container = ProviderContainer();
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  test(
    'reads other dives sightings and the expected list, and follows writes',
    () async {
      await _insertSiteAndDives();
      final repository = container.read(speciesRepositoryProvider);
      final shark = await repository.createSpecies(
        commonName: 'Test Shark',
        category: SpeciesCategory.shark,
      );
      final turtle = await repository.createSpecies(
        commonName: 'Test Turtle',
        category: SpeciesCategory.turtle,
      );
      await repository.addSighting(diveId: 'd1', speciesId: shark.id);
      // d2 is the dive being edited: its own sighting must not count.
      await repository.addSighting(diveId: 'd2', speciesId: turtle.id);

      const key = (siteId: _siteId, excludeDiveId: 'd2');
      final sub = container.listen(
        siteSpeciesSuggestionSourcesProvider(key),
        (_, _) {},
      );
      addTearDown(sub.close);

      final first = await container.read(
        siteSpeciesSuggestionSourcesProvider(key).future,
      );
      expect(first.spotted.map((s) => s.speciesId), [shark.id]);
      expect(first.expected, isEmpty);

      await repository.addSighting(diveId: 'd1', speciesId: turtle.id);
      await repository.addExpectedSpecies(siteId: _siteId, speciesId: shark.id);
      await Future<void>.delayed(Duration.zero);

      final refreshed = await container.read(
        siteSpeciesSuggestionSourcesProvider(key).future,
      );
      expect(refreshed.spotted.map((s) => s.speciesId).toSet(), {
        shark.id,
        turtle.id,
      }, reason: 'a new sighting on another dive must refresh the suggestions');
      expect(refreshed.expected.map((e) => e.speciesId), [
        shark.id,
      ], reason: 'a write to the expected list must refresh the suggestions');
    },
  );
}
