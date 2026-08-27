import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/sort_options.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/models/sort_state.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';

import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart';
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;
import 'package:submersion/features/dive_roles/domain/entities/dive_role.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/divers/domain/entities/diver.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

Buddy _makeBuddy({
  String id = '',
  String name = 'Test Buddy',
  String? diverId,
}) {
  final now = DateTime(2024);
  return Buddy(
    id: id,
    name: name,
    diverId: diverId,
    createdAt: now,
    updatedAt: now,
  );
}

BuddyWithDiveCount _withCount(
  String name, {
  int diveCount = 0,
  bool isFavorite = false,
}) {
  return BuddyWithDiveCount(
    buddy: _makeBuddy(id: name, name: name).copyWith(isFavorite: isFavorite),
    diveCount: diveCount,
  );
}

/// Inserts a dive row directly into the `dives` table, mirroring a sync apply
/// that writes rows without going through any list notifier. This fires the
/// `dives` table-change tick that count-aware providers subscribe to.
Future<void> _insertDive(db.AppDatabase database, {required String id}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await database
      .into(database.dives)
      .insert(
        db.DivesCompanion(
          id: Value(id),
          diveDateTime: Value(now),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

/// Like [_insertDive] but with a caller-chosen dive date, for ordering tests.
Future<void> _insertDiveAt(
  db.AppDatabase database, {
  required String id,
  required DateTime diveDateTime,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  await database
      .into(database.dives)
      .insert(
        db.DivesCompanion(
          id: Value(id),
          diveDateTime: Value(diveDateTime.millisecondsSinceEpoch),
          createdAt: Value(now),
          updatedAt: Value(now),
        ),
      );
}

void main() {
  late SharedPreferences prefs;
  late BuddyRepository buddyRepo;
  late DiverRepository diverRepo;
  late db.AppDatabase database;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    buddyRepo = BuddyRepository();
    diverRepo = DiverRepository();
    database = DatabaseService.instance.database;
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  ProviderContainer makeContainer() {
    return ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
  }

  Future<Diver> seedCurrentDiver() async {
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

  group('allBuddiesProvider', () {
    test('auto-refreshes after a buddy is written directly to the DB '
        '(sync scenario)', () async {
      final diver = await seedCurrentDiver();

      final container = makeContainer();
      addTearDown(container.dispose);

      // An active listener keeps the provider (and its buddies table-change
      // subscription) alive, mirroring a widget that watches the list.
      final sub = container.listen(allBuddiesProvider, (_, _) {});
      addTearDown(sub.close);

      expect(await container.read(allBuddiesProvider.future), isEmpty);

      // A sync applies a remote buddy straight to the DB (no notifier
      // mutation). The watchBuddiesChanges tick must invalidate the provider
      // so the new row surfaces.
      await buddyRepo.createBuddy(
        _makeBuddy(name: 'Synced Buddy', diverId: diver.id),
      );

      var names = <String>[];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        names = (await container.read(
          allBuddiesProvider.future,
        )).map((b) => b.name).toList();
        if (names.contains('Synced Buddy')) break;
      }

      expect(
        names,
        contains('Synced Buddy'),
        reason:
            'allBuddiesProvider should auto-refresh after a direct table '
            'write without any manual invalidation',
      );
    });
  });

  group('allBuddiesWithDiveCountProvider', () {
    test(
      'auto-refreshes on both buddies and dives table writes (sync scenario)',
      () async {
        final diver = await seedCurrentDiver();

        final container = makeContainer();
        addTearDown(container.dispose);

        // Keep the provider alive so both its buddies and dives table-change
        // subscriptions stay open.
        final sub = container.listen(
          allBuddiesWithDiveCountProvider,
          (_, _) {},
        );
        addTearDown(sub.close);

        expect(
          await container.read(allBuddiesWithDiveCountProvider.future),
          isEmpty,
        );

        // Buddies-table tick: a synced buddy applied straight to the DB.
        await buddyRepo.createBuddy(
          _makeBuddy(name: 'Counted Buddy', diverId: diver.id),
        );

        // Dives-table tick: a synced dive applied straight to the DB exercises
        // the separate dives subscription that also invalidates this provider.
        await _insertDive(database, id: 'count-dive-1');

        var names = <String>[];
        for (var i = 0; i < 50; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          names = (await container.read(
            allBuddiesWithDiveCountProvider.future,
          )).map((b) => b.buddy.name).toList();
          if (names.contains('Counted Buddy')) break;
        }

        expect(
          names,
          contains('Counted Buddy'),
          reason:
              'allBuddiesWithDiveCountProvider should auto-refresh after '
              'direct buddies/dives table writes',
        );
      },
    );
  });

  group('BuddyListNotifier', () {
    test('silently reloads the list when a buddy is written directly to the '
        'DB (sync scenario)', () async {
      final diver = await seedCurrentDiver();

      final container = makeContainer();
      addTearDown(container.dispose);

      // Active listener keeps the notifier (and its table-change subscription)
      // alive, mirroring the on-screen buddy list.
      final sub = container.listen(buddyListNotifierProvider, (_, _) {});
      addTearDown(sub.close);

      while (container.read(buddyListNotifierProvider).isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(container.read(buddyListNotifierProvider).value, isEmpty);

      // A sync applies a remote buddy straight to the DB (no addBuddy call).
      // The watchBuddiesChanges tick must trigger _silentReloadBuddies.
      await buddyRepo.createBuddy(
        _makeBuddy(name: 'Silent Buddy', diverId: diver.id),
      );

      var names = <String>[];
      for (var i = 0; i < 50; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        names = (container.read(buddyListNotifierProvider).value ?? [])
            .map((b) => b.name)
            .toList();
        if (names.contains('Silent Buddy')) break;
      }

      expect(
        names,
        contains('Silent Buddy'),
        reason:
            'BuddyListNotifier should silently reload after a direct DB write '
            'without any manual refresh() call',
      );
    });

    test('toggleFavorite flips the flag and refreshes the list', () async {
      final diver = await seedCurrentDiver();
      final buddy = await buddyRepo.createBuddy(
        _makeBuddy(name: 'Fave Buddy', diverId: diver.id),
      );

      final container = makeContainer();
      addTearDown(container.dispose);

      await container
          .read(buddyListNotifierProvider.notifier)
          .toggleFavorite(buddy.id);

      final updated = await buddyRepo.getBuddyById(buddy.id);
      expect(updated!.isFavorite, isTrue);
    });
  });

  group('applyBuddyWithDiveCountSorting (issue #638)', () {
    test('sorts by dive count descending by default', () {
      final buddies = [
        _withCount('Low', diveCount: 1),
        _withCount('High', diveCount: 10),
        _withCount('Mid', diveCount: 5),
      ];

      final sorted = applyBuddyWithDiveCountSorting(
        buddies,
        const SortState(
          field: BuddySortField.diveCount,
          direction: SortDirection.descending,
        ),
      );

      expect(sorted.map((b) => b.buddy.name), ['High', 'Mid', 'Low']);
    });

    test('dive count ascending reverses the order', () {
      final buddies = [
        _withCount('Low', diveCount: 1),
        _withCount('High', diveCount: 10),
        _withCount('Mid', diveCount: 5),
      ];

      final sorted = applyBuddyWithDiveCountSorting(
        buddies,
        const SortState(
          field: BuddySortField.diveCount,
          direction: SortDirection.ascending,
        ),
      );

      expect(sorted.map((b) => b.buddy.name), ['Low', 'Mid', 'High']);
    });

    test('name sort is alphabetical regardless of dive count', () {
      final buddies = [
        _withCount('Charlie', diveCount: 99),
        _withCount('Alice', diveCount: 0),
        _withCount('Bob', diveCount: 50),
      ];

      final sorted = applyBuddyWithDiveCountSorting(
        buddies,
        const SortState(
          field: BuddySortField.name,
          direction: SortDirection.descending,
        ),
      );

      expect(sorted.map((b) => b.buddy.name), ['Alice', 'Bob', 'Charlie']);
    });

    test('does not mutate the input list', () {
      final buddies = [
        _withCount('Low', diveCount: 1),
        _withCount('High', diveCount: 10),
      ];
      final original = List.of(buddies);

      applyBuddyWithDiveCountSorting(
        buddies,
        const SortState(
          field: BuddySortField.diveCount,
          direction: SortDirection.descending,
        ),
      );

      expect(buddies, original);
    });
  });

  group('buddyPickerSortProvider (issue #638)', () {
    test('defaults to dive count descending, not alphabetical', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final sort = container.read(buddyPickerSortProvider);

      expect(sort.field, BuddySortField.diveCount);
      expect(sort.direction, SortDirection.descending);
    });
  });

  // Issue #982: the buddy detail page's shared-dives preview showed an
  // arbitrary five dives because the ids arrived in `dive_buddies.created_at`
  // order (when the link was written) and only the surviving five were sorted
  // by dive date. A dive from a previous year outranked the newest one.
  // The provider re-sorts a list the repository has already ordered, so a
  // provider-level test cannot tell a faithful comparator from a sloppy one.
  // These exercise the comparator directly instead.
  group('compareSharedDivesForPreview (#982)', () {
    domain.Dive diveWith({required String id, int? diveNumber}) => domain.Dive(
      id: id,
      diveNumber: diveNumber,
      dateTime: DateTime(2026, 3, 28),
    );

    List<String> sorted(List<domain.Dive> dives) =>
        (dives.toList()..sort(compareSharedDivesForPreview))
            .map((d) => d.id)
            .toList();

    test('places a null dive number last, behind zero and negatives', () {
      // SQLite sorts NULL below every value, so DESC puts it last. Coalescing
      // null to 0 would rank it above -1 and tie it with a real 0.
      final dives = [
        diveWith(id: 'null', diveNumber: null),
        diveWith(id: 'negative', diveNumber: -1),
        diveWith(id: 'zero', diveNumber: 0),
        diveWith(id: 'three', diveNumber: 3),
      ];

      expect(sorted(dives), equals(['three', 'zero', 'negative', 'null']));
    });

    test('falls back to id when dive numbers are both null', () {
      final dives = [
        diveWith(id: 'zzz', diveNumber: null),
        diveWith(id: 'aaa', diveNumber: null),
      ];

      expect(sorted(dives), equals(['aaa', 'zzz']));
    });
  });

  group('divesForBuddyProvider ordering (#982)', () {
    test('previews the five newest dives, newest first', () async {
      final diver = await seedCurrentDiver();
      final buddy = await buddyRepo.createBuddy(
        _makeBuddy(name: 'Dive Partner', diverId: diver.id),
      );

      // Six dives. The link timestamps are written in the exact reverse of the
      // dive order, so an implementation that truncates before sorting keeps
      // the five OLDEST dives.
      final diveIds = ['d1', 'd2', 'd3', 'd4', 'd5', 'd6'];
      for (var i = 0; i < diveIds.length; i++) {
        await _insertDiveAt(
          database,
          id: diveIds[i],
          diveDateTime: DateTime(2020 + i, 6, 1),
        );
        await buddyRepo.addBuddyToDive(diveIds[i], buddy.id, DiveRole.buddyId);
        await database.customStatement(
          'UPDATE dive_buddies SET created_at = ? '
          'WHERE dive_id = ? AND buddy_id = ?',
          [diveIds.length - i, diveIds[i], buddy.id],
        );
      }

      final container = makeContainer();
      addTearDown(container.dispose);

      final dives = await container.read(
        divesForBuddyProvider(buddy.id).future,
      );

      expect(
        dives.map((d) => d.id).toList(),
        equals(['d6', 'd5', 'd4', 'd3', 'd2']),
        reason:
            'the preview must take the five newest dives, not the first five '
            'buddy links',
      );
    });
  });
}
