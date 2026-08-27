import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

Future<void> _insertTestDive({required String id}) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

void main() {
  late SharedPreferences prefs;
  late SpeciesRepository speciesRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    speciesRepo = SpeciesRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  group('allSpeciesProvider', () {
    test('auto-refreshes after a species is written directly to the DB '
        '(sync scenario)', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      // An active listener keeps the provider (and its species table-change
      // subscription) alive, mirroring a widget that watches the list.
      final sub = container.listen(allSpeciesProvider, (_, _) {});
      addTearDown(sub.close);

      expect(await container.read(allSpeciesProvider.future), isEmpty);

      // A sync applies a remote species straight to the DB (species are not
      // diver-scoped). The watchSpeciesChanges tick must invalidate the
      // provider so the new row surfaces.
      await speciesRepo.createSpecies(
        commonName: 'Synced Grouper',
        category: SpeciesCategory.fish,
      );

      var names = <String>[];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        names = (await container.read(
          allSpeciesProvider.future,
        )).map((s) => s.commonName).toList();
        if (names.contains('Synced Grouper')) break;
      }

      expect(
        names,
        contains('Synced Grouper'),
        reason:
            'allSpeciesProvider should auto-refresh after a direct table '
            'write without any manual invalidation',
      );
    });
  });

  group('speciesSightingCountsProvider', () {
    test('auto-refreshes after a sighting is written directly to the DB '
        '(sync scenario)', () async {
      final species = await speciesRepo.createSpecies(
        commonName: 'Counted Grouper',
        category: SpeciesCategory.fish,
      );
      await _insertTestDive(id: 'counted-dive');

      final container = makeContainer();
      addTearDown(container.dispose);
      final sub = container.listen(speciesSightingCountsProvider, (_, _) {});
      addTearDown(sub.close);

      expect(
        await container.read(speciesSightingCountsProvider.future),
        isEmpty,
      );

      await speciesRepo.addSighting(
        diveId: 'counted-dive',
        speciesId: species.id,
      );

      var counts = <String, int>{};
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        counts = await container.read(speciesSightingCountsProvider.future);
        if (counts[species.id] == 1) break;
      }

      expect(
        counts,
        {species.id: 1},
        reason:
            'speciesSightingCountsProvider should refresh after a sightings '
            'table write without manual invalidation',
      );
    });
  });

  group('speciesListNotifierProvider', () {
    test('reloads the list when a species is written directly to the DB '
        '(sync scenario)', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      // The notifier is autoDispose, so an active listener is required to keep
      // it (and its table-change subscription) alive, mirroring the species
      // management page.
      final sub = container.listen(speciesListNotifierProvider, (_, _) {});
      addTearDown(sub.close);

      while (container.read(speciesListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(container.read(speciesListNotifierProvider).value, isEmpty);

      // A sync applies a remote species straight to the DB (no addSpecies
      // call). The watchSpeciesChanges tick must trigger _loadSpecies, which
      // updates in place without a loading flash.
      await speciesRepo.createSpecies(
        commonName: 'Reloaded Wrasse',
        category: SpeciesCategory.fish,
      );

      var names = <String>[];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        names = (container.read(speciesListNotifierProvider).value ?? [])
            .map((s) => s.commonName)
            .toList();
        if (names.contains('Reloaded Wrasse')) break;
      }

      expect(
        names,
        contains('Reloaded Wrasse'),
        reason:
            'SpeciesListNotifier should reload after a direct DB write '
            'without any manual reload call',
      );
    });
  });
}
