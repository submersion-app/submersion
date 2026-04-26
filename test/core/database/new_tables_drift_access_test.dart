// Exercises the Drift typed API for tables added in v72 so the `lib/core/
// database/database.dart` column getters and table classes are reached at
// runtime — without that, the table-class declarations (e.g. `class
// MediaSubscriptions extends Table { TextColumn get id => ...; }`) stay at
// 0 hits in the lcov report even though the schema works in production.

import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  test('media_subscriptions accepts insert + select via typed API', () async {
    await db
        .into(db.mediaSubscriptions)
        .insert(
          MediaSubscriptionsCompanion.insert(
            id: 'sub-1',
            manifestUrl: 'https://example.com/feed.atom',
            format: 'atom',
            displayName: const Value('Example Feed'),
            credentialsHostId: const Value('host-1'),
            createdAt: 1,
            updatedAt: 1,
          ),
        );

    final rows = await db.select(db.mediaSubscriptions).get();
    expect(rows, hasLength(1));
    expect(rows.first.manifestUrl, 'https://example.com/feed.atom');
    expect(rows.first.format, 'atom');
    expect(rows.first.pollIntervalSeconds, 86400); // default
    expect(rows.first.isActive, isTrue); // default
  });

  test(
    'media_subscription_state accepts insert + select via typed API',
    () async {
      await db
          .into(db.mediaSubscriptions)
          .insert(
            MediaSubscriptionsCompanion.insert(
              id: 'sub-2',
              manifestUrl: 'https://example.com/feed',
              format: 'rss',
              createdAt: 0,
              updatedAt: 0,
            ),
          );

      await db
          .into(db.mediaSubscriptionState)
          .insert(
            MediaSubscriptionStateCompanion.insert(
              subscriptionId: 'sub-2',
              lastPolledAt: const Value(100),
              nextPollAt: const Value(86500),
              lastEtag: const Value('"deadbeef"'),
              lastModified: const Value('Wed, 21 Oct 2026 07:28:00 GMT'),
              lastError: const Value('connection refused'),
              lastErrorAt: const Value(50),
            ),
          );

      final rows = await db.select(db.mediaSubscriptionState).get();
      expect(rows, hasLength(1));
      expect(rows.first.subscriptionId, 'sub-2');
      expect(rows.first.lastEtag, '"deadbeef"');
    },
  );

  test('connector_accounts accepts insert + select via typed API', () async {
    await db
        .into(db.connectorAccounts)
        .insert(
          ConnectorAccountsCompanion.insert(
            id: 'acc-1',
            connectorType: 'immich',
            displayName: 'My Immich',
            baseUrl: const Value('https://photos.example.com'),
            accountIdentifier: const Value('user@example.com'),
            credentialsRef: 'cred-ref-1',
            addedAt: 0,
            lastUsedAt: const Value(100),
          ),
        );

    final rows = await db.select(db.connectorAccounts).get();
    expect(rows, hasLength(1));
    expect(rows.first.connectorType, 'immich');
    expect(rows.first.baseUrl, 'https://photos.example.com');
  });

  test(
    'network_credential_hosts accepts insert + select via typed API',
    () async {
      await db
          .into(db.networkCredentialHosts)
          .insert(
            NetworkCredentialHostsCompanion.insert(
              id: 'host-1',
              hostname: 'photos.example.com',
              authType: 'basic',
              displayName: const Value('Example photos'),
              credentialsRef: 'cred-ref-2',
              addedAt: 0,
              lastUsedAt: const Value(99),
            ),
          );

      final rows = await db.select(db.networkCredentialHosts).get();
      expect(rows, hasLength(1));
      expect(rows.first.hostname, 'photos.example.com');
      expect(rows.first.authType, 'basic');
    },
  );

  test(
    'media_fetch_diagnostics accepts insert + select via typed API',
    () async {
      // Need a media row first because mediaItemId is a FK reference.
      await db
          .into(db.media)
          .insert(
            MediaCompanion.insert(
              id: 'm-1',
              filePath: '/tmp/x.jpg',
              createdAt: 0,
              updatedAt: 0,
            ),
          );

      await db
          .into(db.mediaFetchDiagnostics)
          .insert(
            MediaFetchDiagnosticsCompanion.insert(
              mediaItemId: 'm-1',
              lastErrorAt: const Value(123),
              lastErrorMessage: const Value('404 Not Found'),
              errorCount: const Value(2),
            ),
          );

      final rows = await db.select(db.mediaFetchDiagnostics).get();
      expect(rows, hasLength(1));
      expect(rows.first.lastErrorMessage, '404 Not Found');
      expect(rows.first.errorCount, 2);
    },
  );

  test(
    'media row round-trips all v72 source-type columns via typed API',
    () async {
      await db
          .into(db.media)
          .insert(
            MediaCompanion.insert(
              id: 'm-2',
              filePath: '',
              sourceType: const Value('localFile'),
              localPath: const Value('/Users/me/x.jpg'),
              bookmarkRef: const Value('bref-abc'),
              url: const Value('https://example.com/x.jpg'),
              subscriptionId: const Value('sub-x'),
              entryKey: const Value('entry-x'),
              connectorAccountId: const Value('acc-x'),
              remoteAssetId: const Value('remote-x'),
              originDeviceId: const Value('mac-1'),
              createdAt: 0,
              updatedAt: 0,
            ),
          );

      final rows = await db.select(db.media).get();
      final row = rows.firstWhere((r) => r.id == 'm-2');
      expect(row.sourceType, 'localFile');
      expect(row.localPath, '/Users/me/x.jpg');
      expect(row.bookmarkRef, 'bref-abc');
      expect(row.url, 'https://example.com/x.jpg');
      expect(row.subscriptionId, 'sub-x');
      expect(row.entryKey, 'entry-x');
      expect(row.connectorAccountId, 'acc-x');
      expect(row.remoteAssetId, 'remote-x');
      expect(row.originDeviceId, 'mac-1');
    },
  );
}
