import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/marine_life/presentation/providers/seen_species_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

Future<void> _insertDive({required String id, required DateTime at}) async {
  final db = DatabaseService.instance.database;
  final now = DateTime.now().millisecondsSinceEpoch;
  await db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(at.millisecondsSinceEpoch),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

Future<void> _insertSpecies({required String id, required String name}) async {
  final db = DatabaseService.instance.database;
  await db
      .into(db.species)
      .insert(
        SpeciesCompanion(
          id: Value(id),
          commonName: Value(name),
          category: Value(SpeciesCategory.fish.name),
        ),
      );
}

Future<void> _insertSighting({
  required String id,
  required String diveId,
  required String speciesId,
}) async {
  final db = DatabaseService.instance.database;
  await db
      .into(db.sightings)
      .insert(
        SightingsCompanion(
          id: Value(id),
          diveId: Value(diveId),
          speciesId: Value(speciesId),
        ),
      );
}

/// Polls [read] until [until] holds or ~500 ms pass. Table ticks are
/// delivered asynchronously, so a single read right after a write can race
/// the invalidation.
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

  group('seenSpeciesProvider', () {
    test('lists a species once a sighting is added (sightings tick)', () async {
      final container = makeContainer();
      final sub = container.listen(seenSpeciesProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await container.read(seenSpeciesProvider.future), isEmpty);

      await _insertDive(id: 'd1', at: DateTime(2024, 1, 10));
      await _insertSpecies(id: 'c1', name: 'Grouper');
      await _insertSighting(id: 'sg1', diveId: 'd1', speciesId: 'c1');

      final entries = await _eventually(
        () => container.read(seenSpeciesProvider.future),
        (v) => v.isNotEmpty,
      );
      expect(entries.single.species.id, 'c1');
      expect(entries.single.lastSeen, DateTime(2024, 1, 10));
    });

    test('refreshes when the dive date changes (dives tick)', () async {
      await _insertDive(id: 'd1', at: DateTime(2024, 1, 10));
      await _insertSpecies(id: 'c1', name: 'Grouper');
      await _insertSighting(id: 'sg1', diveId: 'd1', speciesId: 'c1');
      final container = makeContainer();
      final sub = container.listen(seenSpeciesProvider, (_, _) {});
      addTearDown(sub.close);
      expect(
        (await container.read(seenSpeciesProvider.future)).single.lastSeen,
        DateTime(2024, 1, 10),
      );

      final db = DatabaseService.instance.database;
      await (db.update(db.dives)..where((d) => d.id.equals('d1'))).write(
        DivesCompanion(
          diveDateTime: Value(DateTime(2024, 6, 1).millisecondsSinceEpoch),
        ),
      );

      final entries = await _eventually(
        () => container.read(seenSpeciesProvider.future),
        (v) => v.single.lastSeen == DateTime(2024, 6, 1),
      );
      expect(entries.single.lastSeen, DateTime(2024, 6, 1));
    });

    test('drops a species when its only dive is deleted', () async {
      await _insertDive(id: 'd1', at: DateTime(2024, 1, 10));
      await _insertSpecies(id: 'c1', name: 'Grouper');
      await _insertSighting(id: 'sg1', diveId: 'd1', speciesId: 'c1');
      final container = makeContainer();
      final sub = container.listen(seenSpeciesProvider, (_, _) {});
      addTearDown(sub.close);
      expect(await container.read(seenSpeciesProvider.future), hasLength(1));

      final db = DatabaseService.instance.database;
      await (db.delete(db.dives)..where((d) => d.id.equals('d1'))).go();

      final entries = await _eventually(
        () => container.read(seenSpeciesProvider.future),
        (v) => v.isEmpty,
      );
      expect(entries, isEmpty);
    });

    test('picks up a renamed species (species tick)', () async {
      await _insertDive(id: 'd1', at: DateTime(2024, 1, 10));
      await _insertSpecies(id: 'c1', name: 'Grouper');
      await _insertSighting(id: 'sg1', diveId: 'd1', speciesId: 'c1');
      final container = makeContainer();
      final sub = container.listen(seenSpeciesProvider, (_, _) {});
      addTearDown(sub.close);
      expect(
        (await container.read(
          seenSpeciesProvider.future,
        )).single.species.commonName,
        'Grouper',
      );

      final db = DatabaseService.instance.database;
      await (db.update(db.species)..where((s) => s.id.equals('c1'))).write(
        const SpeciesCompanion(commonName: Value('Nassau Grouper')),
      );

      final entries = await _eventually(
        () => container.read(seenSpeciesProvider.future),
        (v) => v.single.species.commonName == 'Nassau Grouper',
      );
      expect(entries.single.species.commonName, 'Nassau Grouper');
    });
  });

  group('speciesSightingsProvider', () {
    test(
      'lists sightings for the species and refreshes on a new one',
      () async {
        await _insertDive(id: 'd1', at: DateTime(2024, 1, 10));
        await _insertDive(id: 'd2', at: DateTime(2024, 2, 10));
        await _insertSpecies(id: 'c1', name: 'Grouper');
        await _insertSighting(id: 'sg1', diveId: 'd1', speciesId: 'c1');
        final container = makeContainer();
        final sub = container.listen(speciesSightingsProvider('c1'), (_, _) {});
        addTearDown(sub.close);
        expect(
          (await container.read(
            speciesSightingsProvider('c1').future,
          )).map((r) => r.diveId).toList(),
          ['d1'],
        );

        await _insertSighting(id: 'sg2', diveId: 'd2', speciesId: 'c1');

        final records = await _eventually(
          () => container.read(speciesSightingsProvider('c1').future),
          (v) => v.length == 2,
        );
        expect(records.map((r) => r.diveId).toList(), ['d2', 'd1']);
      },
    );
  });
}
