import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/divers/data/repositories/diver_merge_repository.dart';
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

/// A [SharedPreferences] that holds its FIRST `setString` open until [release]
/// completes, then forwards it. Every later call forwards at once, so a write
/// issued while the first one is in flight lands BEFORE it: the ordering that
/// lets a validation write clobber a user's diver switch. [forwarded] records
/// every value that reached the real store, in order, so a test can wait for
/// the held write to land instead of racing it.
class _GatedPrefs implements SharedPreferences {
  _GatedPrefs(this._inner);

  final SharedPreferences _inner;
  final firstWriteStarted = Completer<void>();
  final release = Completer<void>();
  final forwarded = <String>[];
  bool _gateArmed = true;

  @override
  Future<bool> setString(String key, String value) async {
    if (_gateArmed) {
      _gateArmed = false;
      firstWriteStarted.complete();
      await release.future;
    }
    final ok = await _inner.setString(key, value);
    forwarded.add(value);
    return ok;
  }

  @override
  String? getString(String key) => _inner.getString(key);

  @override
  Future<bool> remove(String key) => _inner.remove(key);

  @override
  bool containsKey(String key) => _inner.containsKey(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Polls [condition] every 10ms for up to a second.
///
/// [CurrentDiverIdNotifier] validates asynchronously (in its constructor and
/// again on every divers-table tick), so tests wait for the state to settle
/// instead of racing it. A never-met condition simply returns, and the
/// caller's following expect reports the actual state.
Future<void> _pollUntil(bool Function() condition) async {
  for (var i = 0; i < 100; i++) {
    if (condition()) return;
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
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

    test(
      'auto-refreshes after a write to the divers table (sync scenario)',
      () async {
        final container = makeContainer();
        addTearDown(container.dispose);

        // An active listener keeps the provider alive, mirroring a widget that
        // watches the list; this is what keeps its table-change subscription open.
        final sub = container.listen(allDiversProvider, (_, _) {});
        addTearDown(sub.close);

        expect(await container.read(allDiversProvider.future), isEmpty);

        // A sync applies a remote diver straight to the DB, bypassing the list
        // notifier (no manual invalidate). The tableUpdates tick must invalidate
        // the provider so the UI reflects the new row.
        await repo.createDiver(_makeDiver(name: 'Synced Diver'));

        // Poll until the tick -> invalidateSelf -> rebuild settles.
        var names = <String>[];
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          names = (await container.read(
            allDiversProvider.future,
          )).map((d) => d.name).toList();
          if (names.contains('Synced Diver')) break;
        }

        expect(
          names,
          contains('Synced Diver'),
          reason:
              'allDiversProvider should auto-refresh after the table write '
              'without any manual invalidation',
        );
      },
    );
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

    test('clears a dangling id from state and prefs when no diver resolves '
        '(issue #1342)', () async {
      // The pref names a diver that no longer exists, the settings table
      // names nothing, and there is no diver to fall back to. Retaining the
      // id would scope every dive query to a diver that cannot exist.
      await prefs.setString(currentDiverIdKey, 'ghost');

      final container = makeContainer();
      addTearDown(container.dispose);

      // The synchronous seed exposes the raw pref before validation runs.
      expect(container.read(currentDiverIdProvider), equals('ghost'));

      await _pollUntil(() => container.read(currentDiverIdProvider) == null);

      expect(container.read(currentDiverIdProvider), isNull);
      expect(prefs.getString(currentDiverIdKey), isNull);
    });

    test(
      'replaces a dangling id with the default diver in every store',
      () async {
        final fallback = await repo.createDiver(
          _makeDiver(name: 'Default', isDefault: true),
        );
        await prefs.setString(currentDiverIdKey, 'ghost');

        final container = makeContainer();
        addTearDown(container.dispose);

        await _pollUntil(
          () => container.read(currentDiverIdProvider) == fallback.id,
        );

        expect(container.read(currentDiverIdProvider), equals(fallback.id));
        expect(prefs.getString(currentDiverIdKey), equals(fallback.id));
        expect(await repo.getActiveDiverIdFromSettings(), equals(fallback.id));
      },
    );

    test('revalidates when the active diver is deleted straight from the DB '
        '(sync-applied deletion)', () async {
      final survivor = await repo.createDiver(
        _makeDiver(name: 'Survivor', isDefault: true),
      );
      final active = await repo.createDiver(_makeDiver(name: 'Active'));
      await prefs.setString(currentDiverIdKey, active.id);

      final container = makeContainer();
      addTearDown(container.dispose);
      // An active listener mirrors any screen that watches the diver.
      final sub = container.listen(currentDiverIdProvider, (_, _) {});
      addTearDown(sub.close);

      await _pollUntil(
        () => container.read(currentDiverIdProvider) == active.id,
      );

      // No notifier call: the row disappears the way a sync tombstone
      // removes it, so only the divers-table tick can repair the id.
      await repo.deleteDiverWithReassignment(active.id);

      await _pollUntil(
        () => container.read(currentDiverIdProvider) == survivor.id,
      );

      expect(container.read(currentDiverIdProvider), equals(survivor.id));
      expect(prefs.getString(currentDiverIdKey), equals(survivor.id));
    });

    test('a diver switch made while the validation write is in flight wins in '
        'prefs as well as in state', () async {
      final fallback = await repo.createDiver(
        _makeDiver(name: 'Default', isDefault: true),
      );
      final chosen = await repo.createDiver(_makeDiver(name: 'Chosen'));
      await prefs.setString(currentDiverIdKey, 'ghost');
      final gated = _GatedPrefs(prefs);

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(gated)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(currentDiverIdProvider.notifier);

      // Validation resolves the default diver and starts persisting it; the
      // gate holds that write open.
      await gated.firstWriteStarted.future.timeout(const Duration(seconds: 2));
      expect(container.read(currentDiverIdProvider), equals('ghost'));

      // The user switches while that write is in flight. Their write goes
      // straight through, so the validation's write lands after it.
      await notifier.setCurrentDiver(chosen.id);
      expect(gated.forwarded, equals([chosen.id]));
      gated.release.complete();

      // Wait for the held write to land (it clobbers prefs) and for the
      // notifier's reconcile to put the chosen id back.
      await _pollUntil(
        () =>
            gated.forwarded.contains(fallback.id) &&
            prefs.getString(currentDiverIdKey) == chosen.id,
      );
      expect(gated.forwarded, contains(fallback.id));

      expect(container.read(currentDiverIdProvider), equals(chosen.id));
      expect(
        prefs.getString(currentDiverIdKey),
        equals(chosen.id),
        reason:
            'the validation write for ${fallback.id} landed after the '
            'switch and must not be what prefs keeps',
      );
    });

    test(
      'follows a merge to the keeper when the active diver was the duplicate',
      () async {
        // The keeper is neither default nor oldest, so only the merge's own
        // settings repoint can select it; the default fallback alone would
        // land on "Other" instead.
        await repo.createDiver(_makeDiver(name: 'Other', isDefault: true));
        final keeper = await repo.createDiver(_makeDiver(name: 'Alex'));
        final duplicate = await repo.createDiver(_makeDiver(name: 'Alex'));
        await prefs.setString(currentDiverIdKey, duplicate.id);
        await repo.setActiveDiverIdInSettings(duplicate.id);

        final container = makeContainer();
        addTearDown(container.dispose);
        final sub = container.listen(currentDiverIdProvider, (_, _) {});
        addTearDown(sub.close);
        await _pollUntil(
          () => container.read(currentDiverIdProvider) == duplicate.id,
        );

        await container
            .read(diverMergeRepositoryProvider)
            .mergeDivers(keeperId: keeper.id, duplicateId: duplicate.id);

        await _pollUntil(
          () => container.read(currentDiverIdProvider) == keeper.id,
        );

        expect(container.read(currentDiverIdProvider), equals(keeper.id));
        expect(prefs.getString(currentDiverIdKey), equals(keeper.id));
      },
    );
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

    test('silently reloads when a diver is written directly to the DB '
        '(sync scenario)', () async {
      final container = makeContainer();
      addTearDown(container.dispose);
      // Active listener keeps the notifier (and its divers-table subscription)
      // alive, mirroring the on-screen list.
      final sub = container.listen(diverListNotifierProvider, (_, _) {});
      addTearDown(sub.close);

      while (container.read(diverListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(container.read(diverListNotifierProvider).value, isEmpty);

      // A sync applies a remote diver straight to the DB (no addDiver call).
      // The watchDiversChanges tick must silently reload the list.
      await repo.createDiver(_makeDiver(name: 'Synced Diver'));

      var names = <String>[];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        names = (container.read(diverListNotifierProvider).value ?? [])
            .map((d) => d.name)
            .toList();
        if (names.contains('Synced Diver')) break;
      }

      expect(
        names,
        contains('Synced Diver'),
        reason:
            'DiverListNotifier should auto-refresh after a direct DB write '
            'without any manual refresh() call',
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

    test('deleteDiver returns a DeleteDiverResult and moves the selection to '
        'the surviving diver when the deleted diver was current', () async {
      final a = await repo.createDiver(_makeDiver(name: 'A'));
      final b = await repo.createDiver(_makeDiver(name: 'B'));
      await prefs.setString(currentDiverIdKey, a.id);

      final container = makeContainer();
      addTearDown(container.dispose);
      final sub = container.listen(currentDiverIdProvider, (_, _) {});
      addTearDown(sub.close);

      // Wait for init.
      while (container.read(diverListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }

      final result = await container
          .read(diverListNotifierProvider.notifier)
          .deleteDiver(a.id);
      expect(result.hasReassignments, isFalse);

      // The selection is not left dangling or null: deleteDiver re-resolves
      // before returning, so the survivor is current already (#1342).
      expect(container.read(currentDiverIdProvider), equals(b.id));
      expect(prefs.getString(currentDiverIdKey), equals(b.id));
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

  group('realignActiveDiverAfterDataReplace', () {
    test(
      'removes a dangling pref when nothing resolves (issue #1342)',
      () async {
        // A restore swapped the database file but SharedPreferences still
        // names a diver from the previous library, and the restored library
        // has no diver to fall back to. Leaving the pref in place would seed
        // the next launch with an id that scopes every dive query to nothing.
        await prefs.setString(currentDiverIdKey, 'ghost');

        await realignActiveDiverAfterDataReplace(prefs);

        expect(prefs.getString(currentDiverIdKey), isNull);
      },
    );

    test('replaces a dangling pref with the default diver', () async {
      final fallback = await repo.createDiver(
        _makeDiver(name: 'Default', isDefault: true),
      );
      await prefs.setString(currentDiverIdKey, 'ghost');

      await realignActiveDiverAfterDataReplace(prefs);

      expect(prefs.getString(currentDiverIdKey), equals(fallback.id));
    });

    test(
      'prefers the restored settings active diver over the default',
      () async {
        await repo.createDiver(_makeDiver(name: 'Default', isDefault: true));
        final restored = await repo.createDiver(_makeDiver(name: 'Restored'));
        await repo.setActiveDiverIdInSettings(restored.id);
        await prefs.setString(currentDiverIdKey, 'ghost');

        await realignActiveDiverAfterDataReplace(prefs);

        expect(prefs.getString(currentDiverIdKey), equals(restored.id));
      },
    );
  });

  group('diverMergeRepositoryProvider & duplicateDiverGroupsProvider', () {
    test('diverMergeRepositoryProvider exposes a repository instance', () {
      final container = makeContainer();
      addTearDown(container.dispose);

      expect(
        container.read(diverMergeRepositoryProvider),
        isA<DiverMergeRepository>(),
      );
    });

    test('duplicateDiverGroupsProvider groups same-named divers', () async {
      await repo.createDiver(_makeDiver(name: 'Dup Name'));
      await repo.createDiver(_makeDiver(name: 'Dup Name'));
      await repo.createDiver(_makeDiver(name: 'Unique'));

      final container = makeContainer();
      addTearDown(container.dispose);

      final groups = await container.read(duplicateDiverGroupsProvider.future);
      expect(groups, hasLength(1));
      expect(groups.first.displayName, equals('Dup Name'));
      expect(groups.first.duplicates, hasLength(1));
    });

    test(
      'duplicateDiverGroupsProvider is empty when all names are unique',
      () async {
        await repo.createDiver(_makeDiver(name: 'A'));
        await repo.createDiver(_makeDiver(name: 'B'));

        final container = makeContainer();
        addTearDown(container.dispose);

        expect(
          await container.read(duplicateDiverGroupsProvider.future),
          isEmpty,
        );
      },
    );
  });
}
