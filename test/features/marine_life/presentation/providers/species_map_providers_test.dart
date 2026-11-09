import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/marine_life/domain/entities/species_map_pins.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_prefs_providers.dart';
import 'package:submersion/features/marine_life/presentation/providers/species_map_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

AppDatabase get _db => DatabaseService.instance.database;
int get _now => DateTime.now().millisecondsSinceEpoch;

Future<void> _diver(String id) => _db
    .into(_db.divers)
    .insert(
      DiversCompanion(
        id: Value(id),
        name: Value(id),
        createdAt: Value(_now),
        updatedAt: Value(_now),
      ),
    );

Future<void> _site(String id, {String? diverId}) => _db
    .into(_db.diveSites)
    .insert(
      DiveSitesCompanion(
        id: Value(id),
        name: Value(id),
        latitude: const Value(1),
        longitude: const Value(2),
        diverId: Value(diverId),
        createdAt: Value(_now),
        updatedAt: Value(_now),
      ),
    );

Future<void> _dive(String id, String diverId, String siteId) => _db
    .into(_db.dives)
    .insert(
      DivesCompanion(
        id: Value(id),
        diveDateTime: Value(DateTime.utc(2024).millisecondsSinceEpoch),
        diverId: Value(diverId),
        siteId: Value(siteId),
        createdAt: Value(_now),
        updatedAt: Value(_now),
      ),
    );

Future<void> _species(String id) => _db
    .into(_db.species)
    .insert(
      SpeciesCompanion(
        id: Value(id),
        commonName: Value(id),
        category: const Value('fish'),
      ),
    );

Future<void> _sighting(String id, String diveId, String speciesId) => _db
    .into(_db.sightings)
    .insert(
      SightingsCompanion(
        id: Value(id),
        diveId: Value(diveId),
        speciesId: Value(speciesId),
      ),
    );

Future<T> _eventually<T>(
  Future<T> Function() read,
  bool Function(T value) until,
) async {
  late T value;
  for (var i = 0; i < 50; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
    value = await read();
    if (until(value)) break;
  }
  return value;
}

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('speciesMapPublicLayerProvider', () {
    test('defaults to off and persists', () async {
      final first = makeContainer();
      expect(first.read(speciesMapPublicLayerProvider), isFalse);

      await first.read(speciesMapPublicLayerProvider.notifier).set(true);

      expect(first.read(speciesMapPublicLayerProvider), isTrue);
      expect(makeContainer().read(speciesMapPublicLayerProvider), isTrue);
    });
  });

  group('speciesMapExpectedScopeProvider', () {
    test('defaults to mine and persists', () async {
      final first = makeContainer();
      expect(
        first.read(speciesMapExpectedScopeProvider),
        ExpectedSiteScope.mine,
      );

      await first
          .read(speciesMapExpectedScopeProvider.notifier)
          .set(ExpectedSiteScope.allVisible);

      expect(
        makeContainer().read(speciesMapExpectedScopeProvider),
        ExpectedSiteScope.allVisible,
      );
    });

    test('an unknown stored value reads as mine', () async {
      await prefs.setString('species_map.expected_scope', 'somethingNew');

      expect(
        makeContainer().read(speciesMapExpectedScopeProvider),
        ExpectedSiteScope.mine,
      );
    });
  });

  group('speciesMapSitePinsProvider', () {
    test('re-queries when the current diver changes', () async {
      await _diver('a');
      await _diver('b');
      await _site('sa', diverId: 'a');
      await _site('sb', diverId: 'b');
      await _species('fish');
      await _dive('da', 'a', 'sa');
      await _dive('db', 'b', 'sb');
      await _sighting('g1', 'da', 'fish');
      await _sighting('g2', 'db', 'fish');
      final container = makeContainer();
      await container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver('a');
      final sub = container.listen(speciesMapSitePinsProvider, (_, _) {});
      addTearDown(sub.close);

      final forA = await container.read(speciesMapSitePinsProvider.future);
      expect(forA.map((p) => p.siteId), ['sa']);

      await container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver('b');
      final forB = await _eventually(
        () => container.read(speciesMapSitePinsProvider.future),
        (v) => v.map((p) => p.siteId).contains('sb'),
      );
      expect(forB.map((p) => p.siteId), ['sb']);
    });

    test('refreshes on a sightings tick', () async {
      await _diver('a');
      await _site('sa', diverId: 'a');
      await _species('fish');
      await _dive('da', 'a', 'sa');
      final container = makeContainer();
      await container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver('a');
      final sub = container.listen(speciesMapSitePinsProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await container.read(speciesMapSitePinsProvider.future), isEmpty);

      await _sighting('g1', 'da', 'fish');

      final pins = await _eventually(
        () => container.read(speciesMapSitePinsProvider.future),
        (v) => v.isNotEmpty,
      );
      expect(pins.single.siteId, 'sa');
    });
  });

  group('speciesMapSpeciesPinsProvider', () {
    test('re-queries when the expected scope changes', () async {
      await _diver('a');
      await _diver('b');
      await _site('sb', diverId: 'b');
      await (_db.update(_db.diveSites)..where((t) => t.id.equals('sb'))).write(
        const DiveSitesCompanion(isShared: Value(true)),
      );
      await _species('fish');
      await _db
          .into(_db.siteSpecies)
          .insert(
            SiteSpeciesCompanion(
              id: const Value('ss1'),
              siteId: const Value('sb'),
              speciesId: const Value('fish'),
              createdAt: Value(_now),
            ),
          );
      final container = makeContainer();
      await container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver('a');
      final sub = container.listen(
        speciesMapSpeciesPinsProvider('fish'),
        (_, _) {},
      );
      addTearDown(sub.close);
      expect(
        await container.read(speciesMapSpeciesPinsProvider('fish').future),
        isEmpty,
      );

      await container
          .read(speciesMapExpectedScopeProvider.notifier)
          .set(ExpectedSiteScope.allVisible);

      final pins = await _eventually(
        () => container.read(speciesMapSpeciesPinsProvider('fish').future),
        (v) => v.isNotEmpty,
      );
      expect(pins.single.siteId, 'sb');
      expect(pins.single.kind, SpeciesPinKind.expected);
    });
  });
}
