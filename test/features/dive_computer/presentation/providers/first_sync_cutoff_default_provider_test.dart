import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_computer/presentation/providers/download_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';

/// Regression coverage for the first-sync cutoff caching bug.
///
/// Before this fix, `firstSyncCutoffDefaultProvider` was a plain
/// `FutureProvider`, which caches its first resolved value for the app's
/// lifetime. The reported failure sequence: an empty log resolves the
/// default to `null` on the first connect attempt; the user cancels; they
/// then import a logbook file, populating the log; on the next reconnect,
/// the still-cached `null` means the first-sync cutoff prompt never
/// reappears -- until the app is restarted.
///
/// The fix makes the provider `autoDispose`. `DcAdapterDownloadStep` (the
/// only watcher) only watches it while the cutoff prompt could apply, and
/// only for as long as it stays mounted -- so tearing the provider down once
/// its last listener unmounts carries no mid-session refetch risk, and the
/// next watch always re-fetches instead of replaying a stale value.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  Future<void> insertDiver(String diverId) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.divers)
        .insert(
          DiversCompanion(
            id: Value(diverId),
            name: const Value('Test Diver'),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  Future<void> insertDive(
    String diveId,
    String diverId,
    DateTime dateTime,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(diveId),
            diveDateTime: Value(dateTime.millisecondsSinceEpoch),
            diverId: Value(diverId),
            createdAt: Value(now),
            updatedAt: Value(now),
          ),
        );
  }

  test('refetches after the last listener unmounts, instead of caching the '
      'first resolved value for the app lifetime', () async {
    await insertDiver('diver-1');

    final diverIdNotifier = MockCurrentDiverIdNotifier();
    await diverIdNotifier.setCurrentDiver('diver-1');
    final container = ProviderContainer(
      overrides: [
        currentDiverIdProvider.overrideWith((ref) => diverIdNotifier),
      ],
    );
    addTearDown(container.dispose);

    // First watch, empty log: resolves to null. Simulates the first
    // connect attempt from the reported sequence.
    final sub1 = container.listen(
      firstSyncCutoffDefaultProvider,
      (previous, next) {},
    );
    final firstResult = await container.read(
      firstSyncCutoffDefaultProvider.future,
    );
    expect(firstResult, isNull);

    // Drop the listener -- simulates cancelling out of the download step.
    // With autoDispose this tears the provider (and its cached value)
    // down once the disposal timer fires.
    sub1.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    // Simulate a file import populating the log in between, per the
    // reported sequence (empty log -> connect -> cancel -> import file ->
    // reconnect).
    await insertDive('dive-1', 'diver-1', DateTime.utc(2026, 5, 1));

    // Re-watching (the reconnect) must re-fetch from the database rather
    // than replay the stale cached null.
    final sub2 = container.listen(
      firstSyncCutoffDefaultProvider,
      (previous, next) {},
    );
    addTearDown(sub2.close);
    final secondResult = await container.read(
      firstSyncCutoffDefaultProvider.future,
    );

    expect(
      secondResult,
      DateTime.utc(2026, 5, 1),
      reason:
          'A plain (non-autoDispose) FutureProvider would still be '
          'serving the stale cached null here, leaving the reconnect '
          'with no cutoff prompt until app restart.',
    );
  });
}
