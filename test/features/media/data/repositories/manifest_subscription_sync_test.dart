import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ManifestSubscriptionRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = ManifestSubscriptionRepository();
  });

  tearDown(() => tearDownTestDatabase());

  Future<int> pendingCount(String id) async {
    final rows = await db
        .customSelect(
          "SELECT id FROM sync_records "
          "WHERE id = 'mediaSubscriptions_$id'",
        )
        .get();
    return rows.length;
  }

  test('createSubscription marks the row pending and stamps an HLC', () async {
    final sub = await repo.createSubscription(
      manifestUrl: 'https://example.com/feed.xml',
      format: ManifestFormat.atom,
    );
    expect(await pendingCount(sub.id), 1);

    final hlc = await db
        .customSelect(
          "SELECT hlc FROM media_subscriptions WHERE id = '${sub.id}'",
        )
        .getSingle();
    expect(hlc.data['hlc'], isNotNull);
  });

  test('setActive and updateUrlAndDisplayName mark pending', () async {
    final sub = await repo.createSubscription(
      manifestUrl: 'https://example.com/feed.xml',
      format: ManifestFormat.atom,
    );
    await repo.setActive(sub.id, false);
    await repo.updateUrlAndDisplayName(
      sub.id,
      manifestUrl: 'https://example.com/feed2.xml',
      displayName: 'Renamed',
    );
    expect(await pendingCount(sub.id), 1, reason: 'pending row is reused');
  });

  test('deleteById logs a tombstone', () async {
    final sub = await repo.createSubscription(
      manifestUrl: 'https://example.com/feed.xml',
      format: ManifestFormat.atom,
    );
    await repo.deleteById(sub.id);

    final tombstones = await db
        .customSelect(
          "SELECT record_id FROM deletion_log "
          "WHERE entity_type = 'mediaSubscriptions' "
          "AND record_id = '${sub.id}'",
        )
        .get();
    expect(tombstones, hasLength(1));
  });

  test(
    'a pre-v108 subscription (NULL hlc) still exports incrementally',
    () async {
      await db.customStatement(
        "INSERT INTO media_subscriptions "
        "(id, manifest_url, format, created_at, updated_at) "
        "VALUES ('legacy-1', 'https://x/legacy.xml', 'atom', 1, 1)",
      );

      final payload = await SyncDataSerializer().exportChangeset(
        deviceId: 'dev-test',
        hlcWatermark: 'zzz-any-cursor',
        deletions: const [],
      );
      expect(
        payload.data.mediaSubscriptions.map((r) => r['id']),
        contains('legacy-1'),
        reason: 'unstamped legacy rows must not be invisible to increments',
      );
    },
  );

  test('poll bookkeeping does NOT mark the subscription pending', () async {
    final sub = await repo.createSubscription(
      manifestUrl: 'https://example.com/feed.xml',
      format: ManifestFormat.atom,
    );
    await db.customStatement(
      "DELETE FROM sync_records WHERE id = 'mediaSubscriptions_${sub.id}'",
    );

    await repo.recordPollSuccess(
      sub.id,
      pollIntervalSeconds: 3600,
      etag: 'e1',
      lastModified: null,
      now: DateTime.now().toUtc(),
    );
    expect(
      await pendingCount(sub.id),
      0,
      reason: 'per-device poll state must not churn sync',
    );
  });
}
