import 'dart:async' show TimeoutException;

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/database/database.dart' as db;
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/buddies/data/repositories/buddy_repository.dart';
import 'package:submersion/features/buddies/domain/entities/buddy.dart'
    as domain;
import 'package:submersion/features/buddies/presentation/providers/buddy_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

import '../../../../helpers/test_database.dart';

/// Reads the [buddyListNotifierProvider] state and waits until it is no longer
/// loading, returning the resolved list. Times out after 5 seconds.
Future<List<domain.Buddy>> _readBuddyList(ProviderContainer container) async {
  final deadline = DateTime.now().add(const Duration(seconds: 5));
  // Poll until the AsyncValue settles (loading -> data/error).
  while (DateTime.now().isBefore(deadline)) {
    final value = container.read(buddyListNotifierProvider);
    if (value is AsyncData<List<domain.Buddy>>) return value.value;
    if (value is AsyncError<List<domain.Buddy>>) throw value.error;
    // Still loading -- give the event loop a tick.
    await Future<void>.delayed(Duration.zero);
  }
  throw TimeoutException(
    'buddyListNotifierProvider did not settle within 5 seconds',
  );
}

void main() {
  late ProviderContainer container;
  late BuddyRepository repository;
  late db.AppDatabase database;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    await setUpTestDatabase();
    repository = BuddyRepository();
    database = DatabaseService.instance.database;
    container = ProviderContainer(
      overrides: [
        buddyRepositoryProvider.overrideWithValue(repository),
        sharedPreferencesProvider.overrideWithValue(prefs),
        validatedCurrentDiverIdProvider.overrideWith((ref) async => null),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await tearDownTestDatabase();
  });

  group('BuddyListNotifier - mergeBuddies', () {
    test('returns a snapshot and refreshes state', () async {
      final buddyA = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Alice',
          email: 'alice@example.com',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final buddyB = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Bob',
          phone: '555-0100',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await _insertDive(database, id: 'dive-mb-1', buddyId: buddyB.id);

      final notifier = container.read(buddyListNotifierProvider.notifier);

      // Wait for initial load
      await _readBuddyList(container);

      final mergedBuddy = buddyA.copyWith(
        name: 'Alice Merged',
        phone: '555-0100',
      );

      final snapshot = await notifier.mergeBuddies(mergedBuddy, [
        buddyA.id,
        buddyB.id,
      ]);

      // mergeBuddies returns a BuddyMergeSnapshot (not BuddyMergeResult),
      // so survivorId is found via originalSurvivor.id.
      expect(snapshot, isNotNull);
      expect(snapshot!.originalSurvivor.id, equals(buddyA.id));
      expect(snapshot.deletedBuddies.length, equals(1));
      expect(snapshot.deletedBuddies.first.id, equals(buddyB.id));

      // State should be refreshed and only contain the survivor
      final state = await _readBuddyList(container);
      final ids = state.map((b) => b.id).toSet();
      expect(ids, contains(buddyA.id));
      expect(ids, isNot(contains(buddyB.id)));

      // Survivor should have merged fields persisted to DB
      final survivor = await repository.getBuddyById(buddyA.id);
      expect(survivor, isNotNull);
      expect(survivor!.name, equals('Alice Merged'));
      expect(survivor.phone, equals('555-0100'));
    });

    test('with fewer than 2 IDs returns null without changes', () async {
      final buddy = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Solo',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final notifier = container.read(buddyListNotifierProvider.notifier);
      await _readBuddyList(container);

      final snapshot = await notifier.mergeBuddies(
        buddy.copyWith(name: 'Should Not Change'),
        [buddy.id],
      );

      expect(snapshot, isNull);

      final unchanged = await repository.getBuddyById(buddy.id);
      expect(unchanged, isNotNull);
      expect(unchanged!.name, equals('Solo'));
    });
  });

  group('BuddyListNotifier - undoMerge', () {
    test('restores state after merge', () async {
      final buddyA = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Undo A',
          email: 'a@test.com',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final buddyB = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Undo B',
          phone: '555-9999',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      await _insertDive(database, id: 'dive-undo-1', buddyId: buddyB.id);

      final notifier = container.read(buddyListNotifierProvider.notifier);
      await _readBuddyList(container);

      final snapshot = await notifier.mergeBuddies(
        buddyA.copyWith(name: 'Merged'),
        [buddyA.id, buddyB.id],
      );

      // Verify merged state: buddyB should be gone
      expect(await repository.getBuddyById(buddyB.id), isNull);

      // Undo the merge
      await notifier.undoMerge(snapshot!);

      // Both buddies should be restored in the DB
      final restoredA = await repository.getBuddyById(buddyA.id);
      final restoredB = await repository.getBuddyById(buddyB.id);
      expect(restoredA, isNotNull);
      expect(restoredA!.name, equals('Undo A'));
      expect(restoredA.email, equals('a@test.com'));
      expect(restoredB, isNotNull);
      expect(restoredB!.name, equals('Undo B'));

      // State should include both buddies again
      final state = await _readBuddyList(container);
      final ids = state.map((b) => b.id).toSet();
      expect(ids, contains(buddyA.id));
      expect(ids, contains(buddyB.id));

      // Dive re-linked to buddyB
      final diveBuddies = await repository.getBuddiesForDive('dive-undo-1');
      expect(diveBuddies.any((bwr) => bwr.buddy.id == buddyB.id), isTrue);
    });
  });

  group('BuddyListNotifier - bulkDeleteBuddies', () {
    test('removes buddies and refreshes state', () async {
      final buddyA = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Delete A',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final buddyB = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Delete B',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final buddyC = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Keep C',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final notifier = container.read(buddyListNotifierProvider.notifier);

      // Wait for initial state
      final initialState = await _readBuddyList(container);
      expect(initialState.length, equals(3));

      await notifier.bulkDeleteBuddies([buddyA.id, buddyB.id]);

      // Deleted buddies should not exist in the DB
      expect(await repository.getBuddyById(buddyA.id), isNull);
      expect(await repository.getBuddyById(buddyB.id), isNull);

      // Kept buddy should still exist
      expect(await repository.getBuddyById(buddyC.id), isNotNull);

      // State should be refreshed with only the kept buddy
      final updatedState = await _readBuddyList(container);
      final ids = updatedState.map((b) => b.id).toSet();
      expect(ids, isNot(contains(buddyA.id)));
      expect(ids, isNot(contains(buddyB.id)));
      expect(ids, contains(buddyC.id));
    });

    test('empty list is a no-op', () async {
      final buddy = await repository.createBuddy(
        domain.Buddy(
          id: '',
          name: 'Only',
          notes: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final notifier = container.read(buddyListNotifierProvider.notifier);
      await _readBuddyList(container);

      await notifier.bulkDeleteBuddies([]);

      expect(await repository.getBuddyById(buddy.id), isNotNull);
    });
  });
}

Future<void> _insertDive(
  db.AppDatabase database, {
  required String id,
  required String buddyId,
}) async {
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
  await database
      .into(database.diveBuddies)
      .insert(
        db.DiveBuddiesCompanion(
          id: Value('${id}_buddy'),
          diveId: Value(id),
          buddyId: Value(buddyId),
          role: Value(BuddyRole.buddy.name),
          createdAt: Value(now),
        ),
      );
}
