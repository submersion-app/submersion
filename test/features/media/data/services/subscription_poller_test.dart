// Adapted from plan `docs/superpowers/plans/2026-04-28-media-source-extension-phase3b.md`
// Task 11. The plan's outlined test sketch points at six scenarios; each is
// implemented end-to-end here against a real in-memory `AppDatabase`, real
// `MediaRepository` / `ManifestSubscriptionRepository`, a real
// `NetworkFetchPipeline` with a stub `UrlMetadataExtractor`, and a fake
// `ManifestFetchService` that returns scripted outcomes per URL. This
// follows the pattern set by `network_fetch_pipeline_test.dart` (real DB +
// stub extractor) and `trip_media_scanner_test.dart` (hand-rolled fakes
// rather than Mockito) — both pre-existing in this codebase.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/parsers/manifest_format.dart';
import 'package:submersion/features/media/data/parsers/manifest_parse_result.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/manifest_fetch_service.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/data/services/subscription_poller.dart';
import 'package:submersion/features/media/data/services/url_metadata_extractor.dart';

/// `ManifestFetchService` subclass that returns scripted outcomes per URL.
/// The base class wants an `http.Client` and a `ManifestCredentialsLookup`
/// even though we override `fetch` end-to-end and never touch them, so we
/// pass a throwing client and an empty credentials lookup.
class _StaticFetcher extends ManifestFetchService {
  _StaticFetcher(this._outcomes)
    : super(client: _ThrowingClient(), credentials: _NoopCreds());

  final Map<String, ManifestFetchOutcome> _outcomes;

  /// Track every fetch call so tests can assert on header forwarding.
  final List<_FetchCall> calls = [];

  @override
  Future<ManifestFetchOutcome> fetch(
    Uri url, {
    ManifestFormat? formatOverride,
    String? ifNoneMatch,
    String? ifModifiedSince,
  }) async {
    calls.add(
      _FetchCall(
        url: url,
        ifNoneMatch: ifNoneMatch,
        ifModifiedSince: ifModifiedSince,
        formatOverride: formatOverride,
      ),
    );
    final outcome = _outcomes[url.toString()];
    if (outcome == null) {
      return const ManifestFetchFailure(message: 'no fixture');
    }
    return outcome;
  }
}

/// Records the inputs of a single `fetch` invocation for later assertion.
class _FetchCall {
  _FetchCall({
    required this.url,
    required this.ifNoneMatch,
    required this.ifModifiedSince,
    required this.formatOverride,
  });

  final Uri url;
  final String? ifNoneMatch;
  final String? ifModifiedSince;
  final ManifestFormat? formatOverride;
}

/// `ManifestFetchService` requires a non-null `http.Client`; this client
/// throws if anything ever calls it, which would indicate the override
/// above is being bypassed.
class _ThrowingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    throw StateError('HTTP client should not be called in unit tests');
  }
}

class _NoopCreds implements ManifestCredentialsLookup {
  @override
  Future<Map<String, String>> headersFor(Uri uri) async => const {};
}

/// Stub extractor that returns "no result for this URL" for everything.
/// The pipeline's manifest path skips extraction whenever the manifest
/// fully prefills metadata, so every entry in these tests carries
/// width/height/lat/lon/takenAt to keep the extractor cold.
class _NoExtractExtractor implements UrlMetadataExtractor {
  @override
  Future<UrlExtractionResult> extract(Uri uri) async {
    throw StateError(
      'Extractor should not be called when manifest is prefilled',
    );
  }
}

/// Build a fully prefilled `ManifestEntry` so the pipeline's
/// `ingestManifestEntries` path skips network extraction entirely.
ManifestEntry _entry(String key, String url, {DateTime? takenAt}) {
  return ManifestEntry(
    entryKey: key,
    url: url,
    takenAt: takenAt ?? DateTime.utc(2024, 6, 1, 12, 0, 0),
    latitude: 1.0,
    longitude: 2.0,
    width: 800,
    height: 600,
    caption: 'cap',
  );
}

ManifestParseResult _parsed(List<ManifestEntry> entries) =>
    ManifestParseResult(format: ManifestFormat.json, entries: entries);

void main() {
  late AppDatabase db;
  late ManifestSubscriptionRepository subscriptions;
  late MediaRepository mediaRepo;
  late NetworkFetchPipeline pipeline;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    DatabaseService.instance.setTestDatabase(db);
    subscriptions = ManifestSubscriptionRepository();
    mediaRepo = MediaRepository();
    pipeline = NetworkFetchPipeline(db: db, extractor: _NoExtractExtractor());
  });

  tearDown(() async {
    await db.close();
    DatabaseService.instance.resetForTesting();
  });

  test('success: new entries are inserted and queued in pipeline', () async {
    final sub = await subscriptions.createSubscription(
      manifestUrl: 'https://feed.example.com/m.json',
      format: ManifestFormat.json,
      pollIntervalSeconds: 3600,
    );
    final fetcher = _StaticFetcher({
      'https://feed.example.com/m.json': ManifestFetchSuccess(
        parsed: _parsed([
          _entry('k1', 'https://feed.example.com/photo1.jpg'),
          _entry('k2', 'https://feed.example.com/photo2.jpg'),
        ]),
        etag: 'W/"abc"',
        lastModified: 'Sat, 12 Apr 2024 14:00:00 GMT',
      ),
    });
    final poller = SubscriptionPoller(
      subscriptions: subscriptions,
      mediaRepo: mediaRepo,
      fetchService: fetcher,
      pipeline: pipeline,
    );

    final now = DateTime.utc(2024, 4, 27, 10, 0, 0);
    final visited = await poller.pollAllDue(now);
    await pipeline.idle();

    expect(visited, 1);
    final rows = await mediaRepo.getAllBySubscription(sub.id);
    expect(rows, hasLength(2));
    final keys = rows.map((m) => m.entryKey).toSet();
    expect(keys, {'k1', 'k2'});
    // Spot-check: rows have manifest-supplied scalars and the right
    // sourceType.
    final k1 = rows.firstWhere((m) => m.entryKey == 'k1');
    expect(k1.subscriptionId, sub.id);
    expect(k1.url, 'https://feed.example.com/photo1.jpg');
    expect(k1.latitude, 1.0);
    expect(k1.width, 800);
    expect(k1.isOrphaned, isFalse);

    // recordPollSuccess should have written ETag + bumped nextPollAt.
    final after = await subscriptions.getById(sub.id);
    expect(after!.lastEtag, 'W/"abc"');
    expect(after.lastModified, 'Sat, 12 Apr 2024 14:00:00 GMT');
    expect(after.nextPollAt, isNotNull);
    expect(after.nextPollAt!.difference(now), const Duration(seconds: 3600));
    expect(after.lastError, isNull);

    // The fetch call should have forwarded the subscription's format
    // override but no conditional headers (no prior ETag yet).
    expect(fetcher.calls, hasLength(1));
    expect(fetcher.calls.single.formatOverride, ManifestFormat.json);
    expect(fetcher.calls.single.ifNoneMatch, isNull);
    expect(fetcher.calls.single.ifModifiedSince, isNull);
  });

  test('not-modified: 304 path bumps timestamps only', () async {
    final firstNow = DateTime.utc(2024, 4, 27, 10, 0, 0);
    final sub = await subscriptions.createSubscription(
      manifestUrl: 'https://feed.example.com/m.json',
      format: ManifestFormat.json,
      pollIntervalSeconds: 3600,
    );
    // Seed the subscription with a prior ETag + Last-Modified by
    // recording a successful poll first.
    await subscriptions.recordPollSuccess(
      sub.id,
      pollIntervalSeconds: 3600,
      etag: 'W/"abc"',
      lastModified: 'Sat, 12 Apr 2024 14:00:00 GMT',
      now: firstNow,
    );

    // Make the subscription due again so listActiveDue includes it.
    final secondNow = firstNow.add(const Duration(hours: 2));
    final fetcher = _StaticFetcher({
      'https://feed.example.com/m.json': const ManifestFetchNotModified(),
    });
    final poller = SubscriptionPoller(
      subscriptions: subscriptions,
      mediaRepo: mediaRepo,
      fetchService: fetcher,
      pipeline: pipeline,
    );

    final visited = await poller.pollAllDue(secondNow);
    await pipeline.idle();

    expect(visited, 1);
    // No media inserted on a 304.
    final rows = await mediaRepo.getAllBySubscription(sub.id);
    expect(rows, isEmpty);

    // Conditional headers must have been forwarded from the seeded ETag.
    expect(fetcher.calls, hasLength(1));
    expect(fetcher.calls.single.ifNoneMatch, 'W/"abc"');
    expect(
      fetcher.calls.single.ifModifiedSince,
      'Sat, 12 Apr 2024 14:00:00 GMT',
    );

    // The bump moves nextPollAt forward but preserves the ETag for the
    // next conditional round.
    final after = await subscriptions.getById(sub.id);
    expect(after!.lastEtag, 'W/"abc"');
    expect(after.lastModified, 'Sat, 12 Apr 2024 14:00:00 GMT');
    expect(after.nextPollAt!.difference(secondNow), const Duration(hours: 1));
    expect(after.lastError, isNull);
  });

  test('failure: 500 records error and applies backoff', () async {
    final sub = await subscriptions.createSubscription(
      manifestUrl: 'https://feed.example.com/m.json',
      format: ManifestFormat.json,
      pollIntervalSeconds: 3600,
    );
    final fetcher = _StaticFetcher({
      'https://feed.example.com/m.json': const ManifestFetchFailure(
        statusCode: 500,
        message: 'HTTP 500',
      ),
    });
    final poller = SubscriptionPoller(
      subscriptions: subscriptions,
      mediaRepo: mediaRepo,
      fetchService: fetcher,
      pipeline: pipeline,
    );

    final now = DateTime.utc(2024, 4, 27, 10, 0, 0);
    final visited = await poller.pollAllDue(now);

    expect(visited, 1);
    // No media touched.
    final rows = await mediaRepo.getAllBySubscription(sub.id);
    expect(rows, isEmpty);

    // recordPollFailure should have written the message and doubled the
    // poll interval (capped at 24h, but 3600*2 = 7200 is well under that).
    final after = await subscriptions.getById(sub.id);
    expect(after!.lastError, 'HTTP 500');
    expect(after.lastErrorAt, isNotNull);
    expect(after.nextPollAt!.difference(now), const Duration(seconds: 7200));
  });

  test(
    'error isolation: one failing subscription does not block another',
    () async {
      final goodSub = await subscriptions.createSubscription(
        manifestUrl: 'https://good.example.com/m.json',
        format: ManifestFormat.json,
        pollIntervalSeconds: 3600,
      );
      final badSub = await subscriptions.createSubscription(
        manifestUrl: 'https://bad.example.com/m.json',
        format: ManifestFormat.json,
        pollIntervalSeconds: 3600,
      );
      // The bad URL has no fixture so `_StaticFetcher` returns 'no fixture'
      // failure; we still expect the good URL to be polled successfully.
      final fetcher = _StaticFetcher({
        'https://good.example.com/m.json': ManifestFetchSuccess(
          parsed: _parsed([_entry('g1', 'https://good.example.com/g1.jpg')]),
          etag: null,
          lastModified: null,
        ),
        // bad URL intentionally absent.
      });
      final poller = SubscriptionPoller(
        subscriptions: subscriptions,
        mediaRepo: mediaRepo,
        fetchService: fetcher,
        pipeline: pipeline,
      );

      final now = DateTime.utc(2024, 4, 27, 10, 0, 0);
      final visited = await poller.pollAllDue(now);
      await pipeline.idle();

      expect(visited, 2);

      // Good subscription got its row.
      final goodRows = await mediaRepo.getAllBySubscription(goodSub.id);
      expect(goodRows, hasLength(1));
      expect(goodRows.single.entryKey, 'g1');
      final goodAfter = await subscriptions.getById(goodSub.id);
      expect(goodAfter!.lastError, isNull);

      // Bad subscription got an error recorded but no rows.
      final badRows = await mediaRepo.getAllBySubscription(badSub.id);
      expect(badRows, isEmpty);
      final badAfter = await subscriptions.getById(badSub.id);
      expect(badAfter!.lastError, 'no fixture');
      expect(badAfter.lastErrorAt, isNotNull);
    },
  );

  test('orphan: removed entries are flipped to isOrphaned=true', () async {
    final sub = await subscriptions.createSubscription(
      manifestUrl: 'https://feed.example.com/m.json',
      format: ManifestFormat.json,
      pollIntervalSeconds: 3600,
    );

    // First poll: two entries make it into the DB.
    final fetcher = _StaticFetcher({
      'https://feed.example.com/m.json': ManifestFetchSuccess(
        parsed: _parsed([
          _entry('k1', 'https://feed.example.com/p1.jpg'),
          _entry('k2', 'https://feed.example.com/p2.jpg'),
        ]),
        etag: null,
        lastModified: null,
      ),
    });
    final poller = SubscriptionPoller(
      subscriptions: subscriptions,
      mediaRepo: mediaRepo,
      fetchService: fetcher,
      pipeline: pipeline,
    );

    final t0 = DateTime.utc(2024, 4, 27, 10, 0, 0);
    await poller.pollAllDue(t0);
    await pipeline.idle();
    expect(await mediaRepo.getAllBySubscription(sub.id), hasLength(2));

    // Second poll: only k1 still in the manifest. k2 should be orphaned.
    fetcher._outcomes['https://feed.example.com/m.json'] = ManifestFetchSuccess(
      parsed: _parsed([_entry('k1', 'https://feed.example.com/p1.jpg')]),
      etag: null,
      lastModified: null,
    );
    final t1 = t0.add(const Duration(hours: 2));
    await poller.pollAllDue(t1);
    await pipeline.idle();

    final rows = await mediaRepo.getAllBySubscription(sub.id);
    expect(rows, hasLength(2)); // not deleted, just orphaned
    final k1 = rows.firstWhere((m) => m.entryKey == 'k1');
    final k2 = rows.firstWhere((m) => m.entryKey == 'k2');
    expect(k1.isOrphaned, isFalse);
    expect(k2.isOrphaned, isTrue);
  });

  test('change: existing rows are patched when fields change', () async {
    final sub = await subscriptions.createSubscription(
      manifestUrl: 'https://feed.example.com/m.json',
      format: ManifestFormat.json,
      pollIntervalSeconds: 3600,
    );

    // First poll seeds k1 with caption='cap'.
    final fetcher = _StaticFetcher({
      'https://feed.example.com/m.json': ManifestFetchSuccess(
        parsed: _parsed([_entry('k1', 'https://feed.example.com/p1.jpg')]),
        etag: null,
        lastModified: null,
      ),
    });
    final poller = SubscriptionPoller(
      subscriptions: subscriptions,
      mediaRepo: mediaRepo,
      fetchService: fetcher,
      pipeline: pipeline,
    );

    final t0 = DateTime.utc(2024, 4, 27, 10, 0, 0);
    await poller.pollAllDue(t0);
    await pipeline.idle();

    final firstRow = (await mediaRepo.getAllBySubscription(sub.id)).single;
    expect(firstRow.caption, 'cap');

    // Second poll: same entryKey, different caption + width.
    fetcher._outcomes['https://feed.example.com/m.json'] = ManifestFetchSuccess(
      parsed: _parsed([
        ManifestEntry(
          entryKey: 'k1',
          url: 'https://feed.example.com/p1.jpg',
          takenAt: DateTime.utc(2024, 6, 1, 12, 0, 0),
          latitude: 1.0,
          longitude: 2.0,
          width: 1600,
          height: 1200,
          caption: 'updated',
        ),
      ]),
      etag: null,
      lastModified: null,
    );
    final t1 = t0.add(const Duration(hours: 2));
    await poller.pollAllDue(t1);
    await pipeline.idle();

    // Still only one row (no duplicate insert), but it's been patched.
    final rows = await mediaRepo.getAllBySubscription(sub.id);
    expect(rows, hasLength(1));
    expect(rows.single.caption, 'updated');
    expect(rows.single.width, 1600);
    expect(rows.single.height, 1200);
    // ID is preserved across the patch.
    expect(rows.single.id, firstRow.id);
  });
}
