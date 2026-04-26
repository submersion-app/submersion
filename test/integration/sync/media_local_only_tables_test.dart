// Regression test: Phase-1 local-only tables must not appear in the sync flow.
//
// The four tables below are per-device and must never be uploaded to the
// cloud sync file:
//   - media_subscription_state   (per-device polling state)
//   - connector_accounts         (per-device service connector accounts)
//   - network_credential_hosts   (per-device network credentials)
//   - media_fetch_diagnostics    (per-device fetch error tracking)
//
// Because the sync engine is opt-in (records only enter the sync queue via
// explicit markRecordPending calls), inserting rows directly into these
// tables without any repository write must leave the sync_records table
// empty.  This test guards against a future Phase 2/3/4 implementer
// accidentally adding markRecordPending calls for these tables before the
// corresponding opt-in decision has been reviewed.

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';

import '../../helpers/test_database.dart';

void main() {
  group('Phase-1 local-only tables do not sync', () {
    late SyncRepository syncRepo;

    setUp(() async {
      await setUpTestDatabase();
      syncRepo = SyncRepository();
    });

    tearDown(() {
      DatabaseService.instance.resetForTesting();
    });

    test(
      'inserting rows into local-only tables produces no pending sync records',
      () async {
        final db = DatabaseService.instance.database;

        // Seed a media_subscriptions row so the media_subscription_state FK
        // can be satisfied (media_subscriptions IS supposed to sync, but we
        // are only testing that the state table does not).
        await db.customStatement('''
          INSERT INTO media_subscriptions
            (id, manifest_url, format, poll_interval_seconds, is_active,
             created_at, updated_at)
          VALUES
            ('sub-1', 'https://example.com/feed', 'rss', 86400, 1, 0, 0)
        ''');

        // media_subscription_state — per-device polling state (NOT synced).
        await db.customStatement('''
          INSERT INTO media_subscription_state (subscription_id, last_polled_at)
          VALUES ('sub-1', 0)
        ''');

        // connector_accounts — per-device connector credentials (NOT synced).
        await db.customStatement('''
          INSERT INTO connector_accounts
            (id, connector_type, display_name, credentials_ref, added_at)
          VALUES
            ('acc-1', 'immich', 'My Immich', 'cred-ref-1', 0)
        ''');

        // network_credential_hosts — per-device network credentials (NOT synced).
        await db.customStatement('''
          INSERT INTO network_credential_hosts
            (id, hostname, auth_type, credentials_ref, added_at)
          VALUES
            ('host-1', 'example.com', 'basic', 'cred-ref-2', 0)
        ''');

        // media_fetch_diagnostics references media(id) via FK.
        // Seed a minimal media row first so the FK is satisfied.
        await db.customStatement('''
          INSERT INTO media
            (id, file_path, source_type, created_at, updated_at)
          VALUES
            ('media-1', '/tmp/test.jpg', 'localFile', 0, 0)
        ''');

        // media_fetch_diagnostics — per-device fetch error tracking (NOT synced).
        await db.customStatement('''
          INSERT INTO media_fetch_diagnostics (media_item_id, error_count)
          VALUES ('media-1', 1)
        ''');

        // The sync queue must be completely empty — no markRecordPending was
        // called, so none of the rows above should appear.
        final pending = await syncRepo.getPendingRecords();
        expect(
          pending,
          isEmpty,
          reason:
              'Direct inserts into local-only tables must not create sync records',
        );

        // Belt-and-suspenders: confirm none of the four table names appear as
        // entityType values even if the above assertion somehow passes with a
        // non-empty list.
        final pendingTypes = pending.map((r) => r.entityType).toSet();
        expect(pendingTypes, isNot(contains('media_subscription_state')));
        expect(pendingTypes, isNot(contains('connector_accounts')));
        expect(pendingTypes, isNot(contains('network_credential_hosts')));
        expect(pendingTypes, isNot(contains('media_fetch_diagnostics')));
      },
    );
  });
}
