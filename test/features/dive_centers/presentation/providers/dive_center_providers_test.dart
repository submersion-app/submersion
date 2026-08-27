import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_centers/data/repositories/dive_center_repository.dart';
import 'package:submersion/features/dive_centers/domain/entities/dive_center.dart';
import 'package:submersion/features/dive_centers/presentation/providers/dive_center_providers.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

DiveCenter _makeCenter({
  String id = '',
  String name = 'Test Center',
  String? diverId,
}) {
  final now = DateTime.now();
  return DiveCenter(
    id: id,
    diverId: diverId,
    name: name,
    createdAt: now,
    updatedAt: now,
  );
}

Dive _makeDive({String id = '', required DiveCenter center}) {
  return Dive(id: id, dateTime: DateTime(2024, 1, 1, 10), diveCenter: center);
}

/// Fake repository whose [getAllDiveCenters] always throws, used to exercise
/// the providers' error path.
class _ThrowingDiveCenterRepository extends DiveCenterRepository {
  @override
  Future<List<DiveCenter>> getAllDiveCenters({String? diverId}) async {
    throw StateError('boom');
  }
}

void main() {
  late SharedPreferences prefs;
  late DiveCenterRepository centerRepo;
  late DiverRepository diverRepo;
  late DiveRepository diveRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    centerRepo = DiveCenterRepository();
    diverRepo = DiverRepository();
    diveRepo = DiveRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  /// Creates the current default diver. Dive centers are diver-scoped, so a
  /// valid current diver is required for the scoped queries to return rows.
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

  group('allDiveCentersProvider auto-refresh', () {
    test('auto-refreshes after a dive center is written directly to the DB '
        '(sync scenario)', () async {
      final diver = await setUpCurrentDiver();

      final container = makeContainer();
      addTearDown(container.dispose);
      // An active listener keeps the provider (and its dive_centers
      // table-change subscription) alive, mirroring a widget watching the
      // list.
      final sub = container.listen(allDiveCentersProvider, (_, _) {});
      addTearDown(sub.close);

      expect(await container.read(allDiveCentersProvider.future), isEmpty);

      // A sync applies a remote dive center straight to the DB, bypassing the
      // list notifier (no manual invalidate). The watchDiveCentersChanges
      // tick must invalidateSelf so the provider reflects the new row.
      await centerRepo.createDiveCenter(
        _makeCenter(name: 'Synced Center', diverId: diver.id),
      );

      var names = <String>[];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        names = (await container.read(
          allDiveCentersProvider.future,
        )).map((c) => c.name).toList();
        if (names.contains('Synced Center')) break;
      }

      expect(
        names,
        contains('Synced Center'),
        reason:
            'allDiveCentersProvider should auto-refresh after the table '
            'write without any manual invalidation',
      );
    });

    test('surfaces an AsyncError when the repository throws', () async {
      await setUpCurrentDiver();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          diveCenterRepositoryProvider.overrideWithValue(
            _ThrowingDiveCenterRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final result = container.read(allDiveCentersProvider);
      // Drive the future to completion and assert it rejects.
      await expectLater(
        container.read(allDiveCentersProvider.future),
        throwsA(isA<StateError>()),
      );
      expect(container.read(allDiveCentersProvider), isA<AsyncError>());
      // Initial read is loading before the throw propagates.
      expect(result, isA<AsyncLoading>());
    });
  });

  group('diveCenterDiveCountProvider auto-refresh', () {
    test('recomputes the count when a dive is written for the center '
        '(sync scenario)', () async {
      final diver = await setUpCurrentDiver();
      final center = await centerRepo.createDiveCenter(
        _makeCenter(name: 'Counted', diverId: diver.id),
      );

      final container = makeContainer();
      addTearDown(container.dispose);
      // An active listener keeps the family provider (and its dives
      // table-change subscription) alive.
      final sub = container.listen(
        diveCenterDiveCountProvider(center.id),
        (_, _) {},
      );
      addTearDown(sub.close);

      expect(
        await container.read(diveCenterDiveCountProvider(center.id).future),
        equals(0),
      );

      // A sync writes a dive linked to this center straight to the DB. The
      // watchDivesChanges tick must invalidateSelf so the per-row count
      // refreshes.
      await diveRepo.createDive(_makeDive(center: center));

      var count = 0;
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        count = await container.read(
          diveCenterDiveCountProvider(center.id).future,
        );
        if (count > 0) break;
      }

      expect(
        count,
        equals(1),
        reason:
            'diveCenterDiveCountProvider should auto-refresh after a dive is '
            'written for the center without any manual invalidation',
      );
    });
  });

  group('diveCenterListNotifierProvider silent reload', () {
    test(
      'auto-refreshes the list when a dive center is written directly to the '
      'DB (sync scenario)',
      () async {
        final diver = await setUpCurrentDiver();

        final container = makeContainer();
        addTearDown(container.dispose);
        // An active listener keeps the notifier (and its dive_centers
        // table-change subscription) alive, mirroring the on-screen list.
        final sub = container.listen(diveCenterListNotifierProvider, (_, _) {});
        addTearDown(sub.close);

        while (container.read(diveCenterListNotifierProvider).isLoading) {
          await Future<void>.delayed(Duration.zero);
        }
        expect(container.read(diveCenterListNotifierProvider).value, isEmpty);

        // A sync applies a remote dive center straight to the DB (no notifier
        // mutation call). The watchDiveCentersChanges tick must trigger
        // _silentReload, which refreshes in place without flipping to loading.
        await centerRepo.createDiveCenter(
          _makeCenter(name: 'Silently Synced', diverId: diver.id),
        );

        var names = <String>[];
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          names = (container.read(diveCenterListNotifierProvider).value ?? [])
              .map((c) => c.name)
              .toList();
          if (names.contains('Silently Synced')) break;
        }

        expect(
          names,
          contains('Silently Synced'),
          reason:
              'DiveCenterListNotifier should silently reload after a direct DB '
              'write without any manual refresh() call',
        );
      },
    );

    test('surfaces an AsyncError when the repository throws on load', () async {
      await setUpCurrentDiver();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          diveCenterRepositoryProvider.overrideWithValue(
            _ThrowingDiveCenterRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // The notifier's initial load calls getAllDiveCenters, which throws and
      // is caught into AsyncValue.error.
      AsyncValue<List<DiveCenter>> state = container.read(
        diveCenterListNotifierProvider,
      );
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        state = container.read(diveCenterListNotifierProvider);
        if (state is AsyncError) break;
      }

      expect(state, isA<AsyncError>());
    });
  });
}
