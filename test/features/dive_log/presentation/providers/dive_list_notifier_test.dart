import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/database.dart' hide Dive, Diver;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';

import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

Dive _makeDive({String id = '', String? diverId, String notes = 'Test Dive'}) {
  return Dive(id: id, diverId: diverId, dateTime: DateTime.now(), notes: notes);
}

void main() {
  late SharedPreferences prefs;
  late DiveRepository diveRepo;
  late DiverRepository diverRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    diveRepo = DiveRepository();
    diverRepo = DiverRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  /// Creates a default diver and pins it as the current diver in prefs so the
  /// diver-scoped dive providers/notifiers read it synchronously at construction.
  Future<Diver> setUpCurrentDiver() async {
    final diver = await diverRepo.createDiver(
      Diver(
        id: '',
        name: 'D',
        isDefault: true,
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      ),
    );
    await prefs.setString(currentDiverIdKey, diver.id);
    return diver;
  }

  group('DiveListNotifier auto-refresh', () {
    test('auto-refreshes the list when a dive is written directly to the DB '
        '(sync scenario)', () async {
      final diver = await setUpCurrentDiver();

      final container = makeContainer();
      addTearDown(container.dispose);
      // Active listener keeps the notifier (and its dives-table subscription)
      // alive, mirroring the on-screen list.
      final sub = container.listen(diveListNotifierProvider, (_, _) {});
      addTearDown(sub.close);

      while (container.read(diveListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(container.read(diveListNotifierProvider).value, isEmpty);

      // A sync applies a remote dive straight to the DB (no notifier mutation
      // call). The watchDivesChanges tick must silently reload the list.
      await diveRepo.createDive(
        _makeDive(diverId: diver.id, notes: 'Synced Dive'),
      );

      var notes = <String>[];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        notes = (container.read(diveListNotifierProvider).value ?? [])
            .map((d) => d.notes)
            .toList();
        if (notes.contains('Synced Dive')) break;
      }

      expect(
        notes,
        contains('Synced Dive'),
        reason:
            'DiveListNotifier should auto-refresh after a direct DB write '
            'without any manual refresh() call',
      );
    });
  });

  // A dives tick costs what changed rather than the whole logbook (#3815).
  group('DiveListNotifier incremental refresh', () {
    late Diver diver;
    late ProviderContainer container;
    late List<List<Dive>> emitted;

    Future<void> settle() =>
        Future<void>.delayed(DiveRepository.changeTickDebounce * 2);

    /// For what a tick must bring: a fixed wait can land before the reload
    /// does when the test isolate stalls.
    Future<void> until(bool Function() done) async {
      for (var i = 0; i < 300 && !done(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    }

    Dive listed(String id) => container
        .read(diveListNotifierProvider)
        .value!
        .firstWhere((dive) => dive.id == id);

    Future<void> openList() async {
      container = makeContainer();
      addTearDown(container.dispose);
      emitted = [];
      final sub = container.listen(diveListNotifierProvider, (_, next) {
        if (next.value case final dives?) emitted.add(dives);
      });
      addTearDown(sub.close);
      while (container.read(diveListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
      emitted.clear();
    }

    setUp(() async {
      diver = await setUpCurrentDiver();
      await diveRepo.createDive(
        _makeDive(id: 'a', diverId: diver.id, notes: 'A'),
      );
      await diveRepo.createDive(
        _makeDive(id: 'b', diverId: diver.id, notes: 'B'),
      );
    });

    test('keeps the dives a tick did not change', () async {
      await openList();
      final untouched = listed('b');

      final db = DatabaseService.instance.database;
      await (db.update(db.dives)..where((t) => t.id.equals('a'))).write(
        const DivesCompanion(notes: Value('Edited')),
      );
      await until(() => listed('a').notes == 'Edited');

      expect(listed('a').notes, 'Edited');
      expect(listed('b'), same(untouched));
    });

    test('a tick that changed nothing the list holds stays silent', () async {
      await openList();

      final db = DatabaseService.instance.database;
      await (db.update(db.dives)..where((t) => t.id.equals('a'))).write(
        const DivesCompanion(notes: Value('A')),
      );
      await settle();

      expect(emitted, isEmpty);
    });

    test('a save through the notifier reloads once, not again on its '
        'tick', () async {
      await openList();

      await container
          .read(diveListNotifierProvider.notifier)
          .setFavorite('a', true);
      final afterSave = container.read(diveListNotifierProvider).value;
      await settle();

      expect(container.read(diveListNotifierProvider).value, same(afterSave));
      expect(listed('a').isFavorite, isTrue);
    });

    // What a dive embeds can change with no write to its own row: a sync pull
    // of a tank never restamps the parent (#1769), and the next dives tick
    // has to pick it up as the whole-list reload always did.
    test('a dives tick refreshes a child written to another dive', () async {
      await openList();

      final db = DatabaseService.instance.database;
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: 'synced-tank', diveId: 'b'));
      await (db.update(db.dives)..where((t) => t.id.equals('a'))).write(
        const DivesCompanion(notes: Value('Edited')),
      );
      await until(() => listed('b').tanks.isNotEmpty);

      expect(listed('b').tanks.map((t) => t.id), ['synced-tank']);
    });

    test('a site rename reaches every dive on the next dives tick', () async {
      final db = DatabaseService.instance.database;
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion.insert(
              id: 'site',
              name: 'Old name',
              createdAt: 0,
              updatedAt: 0,
            ),
          );
      await (db.update(db.dives)..where((t) => t.id.equals('b'))).write(
        const DivesCompanion(siteId: Value('site')),
      );
      await openList();

      await (db.update(db.diveSites)..where((t) => t.id.equals('site'))).write(
        const DiveSitesCompanion(name: Value('New name')),
      );
      await (db.update(db.dives)..where((t) => t.id.equals('a'))).write(
        const DivesCompanion(notes: Value('Edited')),
      );
      await until(() => listed('b').site?.name == 'New name');

      expect(listed('b').site?.name, 'New name');
    });

    test('a child write alone keeps the list as it is', () async {
      await openList();

      final db = DatabaseService.instance.database;
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: 'synced-tank', diveId: 'b'));
      await settle();

      expect(emitted, isEmpty);
    });

    test('a diver switch discards a refresh already in flight', () async {
      final other = await diverRepo.createDiver(
        Diver(
          id: '',
          name: 'Other',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );
      await diveRepo.createDive(
        _makeDive(id: 'theirs', diverId: other.id, notes: 'Theirs'),
      );
      await openList();

      await (DatabaseService.instance.database.update(
        DatabaseService.instance.database.dives,
      )..where((t) => t.id.equals('a'))).write(
        const DivesCompanion(notes: Value('Edited')),
      );
      await Future<void>.delayed(DiveRepository.changeTickDebounce);
      await container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver(other.id);
      await settle();

      expect(container.read(diveListNotifierProvider).value?.map((d) => d.id), [
        'theirs',
      ]);
    });
  });

  group('PaginatedDiveListNotifier auto-refresh', () {
    test('silently reloads the first page when a dive is written directly to '
        'the DB (sync scenario)', () async {
      final diver = await setUpCurrentDiver();

      final container = makeContainer();
      addTearDown(container.dispose);
      // Active listener keeps the notifier (and its dives-table subscription)
      // alive, mirroring the on-screen paginated list.
      final sub = container.listen(paginatedDiveListProvider, (_, _) {});
      addTearDown(sub.close);

      while (container.read(paginatedDiveListProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(container.read(paginatedDiveListProvider).value?.dives, isEmpty);

      // Remote dive applied straight to the DB; _silentReloadLoadedPages must
      // refresh the first page in place.
      await diveRepo.createDive(
        _makeDive(diverId: diver.id, notes: 'Synced Summary'),
      );

      var count = 0;
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        final state = container.read(paginatedDiveListProvider).value;
        count = state?.dives.length ?? 0;
        if (count >= 1) break;
      }

      expect(
        count,
        greaterThanOrEqualTo(1),
        reason:
            'PaginatedDiveListNotifier should reload its first page after a '
            'direct DB write without any manual refresh() call',
      );
    });
  });

  group('divesProvider auto-refresh', () {
    test(
      'self-invalidates after a write to the dives table (sync scenario)',
      () async {
        final diver = await setUpCurrentDiver();

        final container = makeContainer();
        addTearDown(container.dispose);
        // Active listener keeps the FutureProvider (and its table-change
        // subscription) alive, mirroring a widget watching the list.
        final sub = container.listen(divesProvider, (_, _) {});
        addTearDown(sub.close);

        expect(await container.read(divesProvider.future), isEmpty);

        // A sync applies a remote dive straight to the DB. The tableUpdates tick
        // must invalidate the provider so the next read reflects the new row.
        await diveRepo.createDive(
          _makeDive(diverId: diver.id, notes: 'Synced FP Dive'),
        );

        var notes = <String>[];
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          notes = (await container.read(
            divesProvider.future,
          )).map((d) => d.notes).toList();
          if (notes.contains('Synced FP Dive')) break;
        }

        expect(
          notes,
          contains('Synced FP Dive'),
          reason:
              'divesProvider should auto-refresh after the table write without '
              'any manual invalidation',
        );
      },
    );

    test('keeps the dives a tick did not change', () async {
      final diver = await setUpCurrentDiver();
      await diveRepo.createDive(
        _makeDive(id: 'a', diverId: diver.id, notes: 'A'),
      );
      await diveRepo.createDive(
        _makeDive(id: 'b', diverId: diver.id, notes: 'B'),
      );
      final container = makeContainer();
      addTearDown(container.dispose);
      final sub = container.listen(divesProvider, (_, _) {});
      addTearDown(sub.close);
      final before = await container.read(divesProvider.future);
      final untouched = before.firstWhere((dive) => dive.id == 'b');

      final db = DatabaseService.instance.database;
      await (db.update(db.dives)..where((t) => t.id.equals('a'))).write(
        const DivesCompanion(notes: Value('Edited')),
      );
      await Future<void>.delayed(DiveRepository.changeTickDebounce * 2);

      final after = await container.read(divesProvider.future);
      expect(after.firstWhere((dive) => dive.id == 'a').notes, 'Edited');
      expect(after.firstWhere((dive) => dive.id == 'b'), same(untouched));
    });

    test('an unchanged tick keeps the list itself', () async {
      final diver = await setUpCurrentDiver();
      await diveRepo.createDive(
        _makeDive(id: 'a', diverId: diver.id, notes: 'A'),
      );
      final container = makeContainer();
      addTearDown(container.dispose);
      final sub = container.listen(divesProvider, (_, _) {});
      addTearDown(sub.close);
      final before = await container.read(divesProvider.future);

      final db = DatabaseService.instance.database;
      await (db.update(db.dives)..where((t) => t.id.equals('a'))).write(
        const DivesCompanion(notes: Value('A')),
      );
      await Future<void>.delayed(DiveRepository.changeTickDebounce * 2);

      expect(await container.read(divesProvider.future), same(before));
    });

    test('a child write reaches the next read', () async {
      final diver = await setUpCurrentDiver();
      await diveRepo.createDive(
        _makeDive(id: 'a', diverId: diver.id, notes: 'A'),
      );
      final container = makeContainer();
      addTearDown(container.dispose);
      final sub = container.listen(divesProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(divesProvider.future);

      final db = DatabaseService.instance.database;
      await db
          .into(db.diveTanks)
          .insert(DiveTanksCompanion.insert(id: 'tank', diveId: 'a'));
      container.invalidate(divesProvider);

      final after = await container.read(divesProvider.future);
      expect(after.single.tanks.map((tank) => tank.id), ['tank']);
    });

    test('a diver switch reads the new diver', () async {
      final diver = await setUpCurrentDiver();
      final other = await diverRepo.createDiver(
        Diver(
          id: '',
          name: 'Other',
          createdAt: DateTime(2024),
          updatedAt: DateTime(2024),
        ),
      );
      await diveRepo.createDive(
        _makeDive(id: 'mine', diverId: diver.id, notes: 'Mine'),
      );
      await diveRepo.createDive(
        _makeDive(id: 'theirs', diverId: other.id, notes: 'Theirs'),
      );
      final container = makeContainer();
      addTearDown(container.dispose);
      final sub = container.listen(divesProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(divesProvider.future);

      await container
          .read(currentDiverIdProvider.notifier)
          .setCurrentDiver(other.id);

      final after = await container.read(divesProvider.future);
      expect(after.map((dive) => dive.id), ['theirs']);
    });
  });
}
