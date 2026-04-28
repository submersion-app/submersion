// Adapted from plan `docs/superpowers/plans/2026-04-28-media-source-extension-phase3b.md`
// Task 8. Test-helper deviations applied vs. plan code:
//
// - Plan uses `AppDatabase.forTesting(NativeDatabase.memory())`; the codebase
//   exposes only `AppDatabase(NativeDatabase.memory())`. The shared
//   `setUpTestDatabase()` / `tearDownTestDatabase()` helpers wrap the
//   `DatabaseService.instance.setTestDatabase(...)` / `resetForTesting()`
//   round-trip the plan was reaching for via the (non-existent)
//   `setDatabaseForTesting` calls.
//
// All other test intent (round-trip, listActiveDue, recordPollFailure cap,
// setActive, deleteById) is preserved verbatim.
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late ManifestSubscriptionRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    repo = ManifestSubscriptionRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('create + getById round-trips', () async {
    final created = await repo.createSubscription(
      manifestUrl: 'https://example.com/m.json',
      format: ManifestFormat.json,
      displayName: 'Eric',
      pollIntervalSeconds: 3600,
    );
    final fetched = await repo.getById(created.id);
    expect(fetched, isNotNull);
    expect(fetched!.manifestUrl, 'https://example.com/m.json');
    expect(fetched.format, ManifestFormat.json);
    expect(fetched.pollIntervalSeconds, 3600);
    expect(fetched.isActive, isTrue);
    expect(fetched.lastPolledAt, isNull);
    expect(fetched.nextPollAt, isNull);
  });

  test(
    'listActiveDue returns subscriptions whose nextPollAt is null or past',
    () async {
      final now = DateTime.utc(2024, 4, 12, 14, 0);
      final newSub = await repo.createSubscription(
        manifestUrl: 'https://x/m.json',
        format: ManifestFormat.json,
      );
      // Fresh subscription has nextPollAt = null -> should be due.
      final due1 = await repo.listActiveDue(now);
      expect(due1.map((s) => s.id), contains(newSub.id));

      // After a successful poll with 1 h interval, it's not due 30 m later.
      await repo.recordPollSuccess(
        newSub.id,
        pollIntervalSeconds: 3600,
        etag: '"abc"',
        lastModified: null,
        now: now,
      );
      final due2 = await repo.listActiveDue(
        now.add(const Duration(minutes: 30)),
      );
      expect(due2.map((s) => s.id), isNot(contains(newSub.id)));

      // 90 m later it's due again.
      final due3 = await repo.listActiveDue(
        now.add(const Duration(minutes: 90)),
      );
      expect(due3.map((s) => s.id), contains(newSub.id));
    },
  );

  test(
    'recordPollFailure sets nextPollAt with exponential backoff cap',
    () async {
      final now = DateTime.utc(2024, 4, 12, 14, 0);
      final sub = await repo.createSubscription(
        manifestUrl: 'https://x/m.json',
        format: ManifestFormat.json,
      );
      // 12 h * 2 = 24 h; cap at 24 h.
      await repo.recordPollFailure(
        sub.id,
        pollIntervalSeconds: 12 * 3600,
        error: 'boom',
        now: now,
      );
      final fetched = await repo.getById(sub.id);
      final delta = fetched!.nextPollAt!.difference(now);
      expect(delta, const Duration(hours: 24));
      expect(fetched.lastError, 'boom');
    },
  );

  test('setActive toggles flag', () async {
    final sub = await repo.createSubscription(
      manifestUrl: 'https://x/m.json',
      format: ManifestFormat.json,
    );
    await repo.setActive(sub.id, false);
    expect((await repo.getById(sub.id))!.isActive, isFalse);
  });

  test('deleteById removes both rows', () async {
    final sub = await repo.createSubscription(
      manifestUrl: 'https://x/m.json',
      format: ManifestFormat.json,
    );
    await repo.deleteById(sub.id);
    expect(await repo.getById(sub.id), isNull);
  });
}
