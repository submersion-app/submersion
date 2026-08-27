import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/providers/provider.dart';

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

      // Remote dive applied straight to the DB; _silentReloadFirstPage must
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
  });
}
