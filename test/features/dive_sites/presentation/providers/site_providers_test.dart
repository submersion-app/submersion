import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';
import 'package:submersion/features/marine_life/data/repositories/species_repository.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late ProviderContainer container;
  late SiteRepository siteRepository;
  late SpeciesRepository speciesRepository;
  late db.AppDatabase database;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    siteRepository = SiteRepository();
    speciesRepository = SpeciesRepository();
    database = DatabaseService.instance.database;
    container = ProviderContainer(
      overrides: [
        siteRepositoryProvider.overrideWithValue(siteRepository),
        sharedPreferencesProvider.overrideWithValue(prefs),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  group('SiteListNotifier - Merge Operations', () {
    test(
      'mergeSites invalidates cached site and expected-species providers',
      () async {
        final site1 = await siteRepository.createSite(
          const DiveSite(id: 'site-1', name: 'Site A', description: 'Desc A'),
        );
        final site2 = await siteRepository.createSite(
          const DiveSite(id: 'site-2', name: 'Site B', country: 'Country B'),
        );
        final site3 = await siteRepository.createSite(
          const DiveSite(id: 'site-3', name: 'Site C', region: 'Region C'),
        );

        await _insertDive(database, id: 'dive-1', siteId: site2.id);
        await _insertDive(database, id: 'dive-2', siteId: site3.id);

        final turtle = await speciesRepository.createSpecies(
          commonName: 'Green Sea Turtle',
          category: SpeciesCategory.turtle,
        );
        final ray = await speciesRepository.createSpecies(
          commonName: 'Spotted Eagle Ray',
          category: SpeciesCategory.ray,
        );

        await speciesRepository.addExpectedSpecies(
          siteId: site1.id,
          speciesId: turtle.id,
        );
        await speciesRepository.addExpectedSpecies(
          siteId: site2.id,
          speciesId: ray.id,
        );

        final cachedSite2 = await container.read(siteProvider(site2.id).future);
        final cachedExpectedSpecies = await container.read(
          siteExpectedSpeciesProvider(site1.id).future,
        );

        expect(cachedSite2, isNotNull);
        expect(cachedExpectedSpecies.map((entry) => entry.speciesId).toSet(), {
          turtle.id,
        });

        final mergedSite = site1.copyWith(
          name: 'Merged Site',
          country: 'Country B',
          region: 'Region C',
        );

        await container.read(siteListNotifierProvider.notifier).mergeSites(
          mergedSite,
          [site1.id, site2.id, site3.id],
        );

        final refreshedSite1 = await container.read(
          siteProvider(site1.id).future,
        );
        final refreshedSite2 = await container.read(
          siteProvider(site2.id).future,
        );
        final refreshedExpectedSpecies = await container.read(
          siteExpectedSpeciesProvider(site1.id).future,
        );
        final diveList = await container.read(divesProvider.future);

        expect(refreshedSite1, isNotNull);
        expect(refreshedSite1!.name, equals('Merged Site'));
        expect(refreshedSite1.country, equals('Country B'));
        expect(refreshedSite1.region, equals('Region C'));
        expect(refreshedSite2, isNull);
        expect(
          refreshedExpectedSpecies.map((entry) => entry.speciesId).toSet(),
          equals({turtle.id, ray.id}),
        );
        expect(
          diveList.map((dive) => dive.site?.id).toSet(),
          equals({site1.id}),
        );
      },
    );

    test(
      'mergeSites with fewer than 2 IDs returns early without changes',
      () async {
        final site = await siteRepository.createSite(
          const DiveSite(id: 'solo', name: 'Solo Site'),
        );

        await container.read(siteListNotifierProvider.notifier).mergeSites(
          site.copyWith(name: 'Should Not Change'),
          ['solo'],
        );

        final result = await container.read(siteProvider('solo').future);
        expect(result, isNotNull);
        expect(result!.name, equals('Solo Site'));
      },
    );

    test('mergeSites deduplicates site IDs before merging', () async {
      final site1 = await siteRepository.createSite(
        const DiveSite(id: 'dd-1', name: 'First'),
      );
      final site2 = await siteRepository.createSite(
        const DiveSite(id: 'dd-2', name: 'Second'),
      );

      await container.read(siteListNotifierProvider.notifier).mergeSites(
        site1.copyWith(name: 'Merged'),
        [site1.id, site2.id, site2.id, site1.id],
      );

      final survivor = await container.read(siteProvider('dd-1').future);
      expect(survivor, isNotNull);
      expect(survivor!.name, equals('Merged'));
      expect(await container.read(siteProvider('dd-2').future), isNull);
    });

    test('undoMerge restores sites and invalidates providers', () async {
      final site1 = await siteRepository.createSite(
        const DiveSite(id: 'um-1', name: 'Undo A'),
      );
      final site2 = await siteRepository.createSite(
        const DiveSite(id: 'um-2', name: 'Undo B', country: 'Fiji'),
      );

      await _insertDive(database, id: 'um-dive', siteId: site2.id);

      final notifier = container.read(siteListNotifierProvider.notifier);
      final snapshot = await notifier.mergeSites(
        site1.copyWith(name: 'Merged'),
        [site1.id, site2.id],
      );

      // Verify merged state
      expect(await container.read(siteProvider('um-2').future), isNull);

      // Undo
      await notifier.undoMerge(snapshot!);

      // Verify restored
      final restored1 = await container.read(siteProvider('um-1').future);
      final restored2 = await container.read(siteProvider('um-2').future);
      expect(restored1, isNotNull);
      expect(restored1!.name, equals('Undo A'));
      expect(restored2, isNotNull);
      expect(restored2!.name, equals('Undo B'));
      expect(restored2.country, equals('Fiji'));

      // Verify dive re-linked
      final diveList = await container.read(divesProvider.future);
      final undoDive = diveList.where((d) => d.id == 'um-dive');
      expect(undoDive.first.site?.id, equals('um-2'));
    });
  });
}

Future<void> _insertDive(
  db.AppDatabase database, {
  required String id,
  required String siteId,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await database
      .into(database.dives)
      .insert(
        db.DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          siteId: Value(siteId),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}
