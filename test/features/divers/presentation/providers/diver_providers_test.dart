import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

Diver _makeDiver({
  String id = '',
  String name = 'Test',
  bool isDefault = false,
}) {
  final now = DateTime.now();
  return Diver(
    id: id,
    name: name,
    isDefault: isDefault,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late SharedPreferences prefs;
  late DiverRepository repo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    repo = DiverRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  group('allDiversProvider', () {
    test('returns divers sorted by name from the repository', () async {
      await repo.createDiver(_makeDiver(name: 'Bob'));
      await repo.createDiver(_makeDiver(name: 'Alice'));

      final container = makeContainer();
      addTearDown(container.dispose);

      final divers = await container.read(allDiversProvider.future);
      expect(divers.map((d) => d.name), equals(['Alice', 'Bob']));
    });

    test('returns empty list when no divers exist', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      expect(await container.read(allDiversProvider.future), isEmpty);
    });
  });

  group('hasAnyDiversProvider', () {
    test('true when at least one diver exists', () async {
      await repo.createDiver(_makeDiver(name: 'One'));

      final container = makeContainer();
      addTearDown(container.dispose);

      expect(await container.read(hasAnyDiversProvider.future), isTrue);
    });

    test('false when no divers exist', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      expect(await container.read(hasAnyDiversProvider.future), isFalse);
    });
  });

  group('diverByIdProvider', () {
    test('returns the matching diver', () async {
      final d = await repo.createDiver(_makeDiver(name: 'Solo'));

      final container = makeContainer();
      addTearDown(container.dispose);

      final diver = await container.read(diverByIdProvider(d.id).future);
      expect(diver?.name, equals('Solo'));
    });

    test('returns null when no diver matches', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      expect(await container.read(diverByIdProvider('ghost').future), isNull);
    });
  });

  group('validatedCurrentDiverIdProvider', () {
    test(
      'falls back to default diver when current id does not exist',
      () async {
        final existing = await repo.createDiver(
          _makeDiver(name: 'Default', isDefault: true),
        );
        // Store a stale id
        await prefs.setString(currentDiverIdKey, 'ghost');

        final container = makeContainer();
        addTearDown(container.dispose);

        final resolved = await container.read(
          validatedCurrentDiverIdProvider.future,
        );
        expect(resolved, equals(existing.id));
      },
    );

    test('returns current id if it is valid', () async {
      final existing = await repo.createDiver(_makeDiver(name: 'Exists'));
      await prefs.setString(currentDiverIdKey, existing.id);

      final container = makeContainer();
      addTearDown(container.dispose);

      final resolved = await container.read(
        validatedCurrentDiverIdProvider.future,
      );
      expect(resolved, equals(existing.id));
    });

    test(
      'returns null when neither current nor default diver exists',
      () async {
        final container = makeContainer();
        addTearDown(container.dispose);

        expect(
          await container.read(validatedCurrentDiverIdProvider.future),
          isNull,
        );
      },
    );
  });

  group('currentDiverProvider', () {
    test('returns the current diver entity when set', () async {
      final d = await repo.createDiver(_makeDiver(name: 'Current'));
      await prefs.setString(currentDiverIdKey, d.id);

      final container = makeContainer();
      addTearDown(container.dispose);

      final current = await container.read(currentDiverProvider.future);
      expect(current?.name, equals('Current'));
    });

    test('falls back to default diver when current id is invalid', () async {
      final d = await repo.createDiver(
        _makeDiver(name: 'Fallback', isDefault: true),
      );
      await prefs.setString(currentDiverIdKey, 'stale');

      final container = makeContainer();
      addTearDown(container.dispose);

      // Let the async validation run and update the state.
      await Future<void>.delayed(Duration.zero);

      final current = await container.read(currentDiverProvider.future);
      expect(current?.id, equals(d.id));
    });
  });

  group('diverDiveCountProvider & diverTotalBottomTimeProvider', () {
    test('both return 0 for a diver with no dives', () async {
      final d = await repo.createDiver(_makeDiver(name: 'Empty'));

      final container = makeContainer();
      addTearDown(container.dispose);

      expect(
        await container.read(diverDiveCountProvider(d.id).future),
        equals(0),
      );
      expect(
        await container.read(diverTotalBottomTimeProvider(d.id).future),
        equals(0),
      );
    });
  });

  group('diverStatsProvider', () {
    test('combines count and bottom-time from repository', () async {
      final d = await repo.createDiver(_makeDiver(name: 'Stats'));

      final container = makeContainer();
      addTearDown(container.dispose);

      final stats = await container.read(diverStatsProvider(d.id).future);
      expect(stats.diveCount, equals(0));
      expect(stats.totalBottomTimeSeconds, equals(0));
    });
  });

  group('DiverStats.formattedBottomTime', () {
    test('formats minutes-only when under an hour', () {
      const s = DiverStats(diveCount: 0, totalBottomTimeSeconds: 1800);
      expect(s.formattedBottomTime, equals('30m'));
    });

    test('formats "Xh Ym" when at least an hour', () {
      const s = DiverStats(diveCount: 0, totalBottomTimeSeconds: 3725);
      expect(s.formattedBottomTime, equals('1h 2m'));
    });

    test('handles zero seconds', () {
      const s = DiverStats(diveCount: 0, totalBottomTimeSeconds: 0);
      expect(s.formattedBottomTime, equals('0m'));
    });
  });

  group('CurrentDiverIdNotifier', () {
    test(
      'setCurrentDiver updates state and persists to SharedPreferences',
      () async {
        final container = makeContainer();
        addTearDown(container.dispose);

        final notifier = container.read(currentDiverIdProvider.notifier);
        await notifier.setCurrentDiver('d-123');

        expect(container.read(currentDiverIdProvider), equals('d-123'));
        expect(prefs.getString(currentDiverIdKey), equals('d-123'));
      },
    );

    test('clearCurrentDiver nulls the state and clears prefs', () async {
      await prefs.setString(currentDiverIdKey, 'existing');

      final container = makeContainer();
      addTearDown(container.dispose);

      final notifier = container.read(currentDiverIdProvider.notifier);
      await notifier.clearCurrentDiver();

      expect(container.read(currentDiverIdProvider), isNull);
      expect(prefs.getString(currentDiverIdKey), isNull);
    });
  });

  group('DiverListNotifier', () {
    test('loads divers into AsyncValue.data on construction', () async {
      await repo.createDiver(_makeDiver(name: 'Alice'));

      final container = makeContainer();
      addTearDown(container.dispose);

      // Trigger construction/initial load
      final state0 = container.read(diverListNotifierProvider);
      expect(state0, isA<AsyncValue<List<Diver>>>());
      // Wait for the initial load to complete
      while (container.read(diverListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
      final state1 = container.read(diverListNotifierProvider);
      expect(
        state1.valueOrNull?.map((d) => d.name).toList(),
        equals(['Alice']),
      );
    });

    test('addDiver creates the diver and returns it', () async {
      final container = makeContainer();
      addTearDown(container.dispose);

      // Ensure initial load is complete
      while (container.read(diverListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }

      final notifier = container.read(diverListNotifierProvider.notifier);
      final newDiver = await notifier.addDiver(_makeDiver(name: 'Charlie'));
      expect(newDiver.name, equals('Charlie'));
      expect(newDiver.id, isNotEmpty);
    });

    test('setAsDefault delegates to repository', () async {
      final a = await repo.createDiver(_makeDiver(name: 'A'));
      final b = await repo.createDiver(_makeDiver(name: 'B'));

      final container = makeContainer();
      addTearDown(container.dispose);

      // Wait for init.
      while (container.read(diverListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }

      final notifier = container.read(diverListNotifierProvider.notifier);
      await notifier.setAsDefault(b.id);

      final divers = await repo.getAllDivers();
      final byId = {for (final d in divers) d.id: d};
      expect(byId[a.id]!.isDefault, isFalse);
      expect(byId[b.id]!.isDefault, isTrue);
    });

    test('deleteDiver returns a DeleteDiverResult and clears current selection '
        'when the deleted diver was current', () async {
      final a = await repo.createDiver(_makeDiver(name: 'A'));
      await repo.createDiver(_makeDiver(name: 'B'));
      await prefs.setString(currentDiverIdKey, a.id);

      final container = makeContainer();
      addTearDown(container.dispose);

      // Wait for init.
      while (container.read(diverListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }

      final result = await container
          .read(diverListNotifierProvider.notifier)
          .deleteDiver(a.id);
      expect(result.hasReassignments, isFalse);

      // Current diver id cleared once its diver was deleted.
      expect(container.read(currentDiverIdProvider), isNull);
    });

    test('updateDiver persists changes via notifier', () async {
      final d = await repo.createDiver(_makeDiver(name: 'Orig'));

      final container = makeContainer();
      addTearDown(container.dispose);

      while (container.read(diverListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }

      await container
          .read(diverListNotifierProvider.notifier)
          .updateDiver(d.copyWith(name: 'Renamed'));

      final read = await repo.getDiverById(d.id);
      expect(read?.name, equals('Renamed'));
    });
  });

  group('CurrentDiverIdNotifier settings-table fallback', () {
    test('resolves from Settings table when prefs is missing/stale', () async {
      // Seed the DB settings table with a valid active diver.
      final d = await repo.createDiver(_makeDiver(name: 'SettingsDiver'));
      await repo.setActiveDiverIdInSettings(d.id);

      final container = makeContainer();
      addTearDown(container.dispose);

      // The notifier constructor runs _validateAndSync asynchronously. Poll
      // up to 200ms for the resolved state to propagate.
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        if (container.read(currentDiverIdProvider) != null) break;
      }

      // The notifier should resolve to the id from the Settings table.
      expect(container.read(currentDiverIdProvider), equals(d.id));
    });
  });
}
