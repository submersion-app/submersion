import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/media/data/parsers/manifest_entry.dart';
import 'package:submersion/features/media/data/services/network_fetch_pipeline.dart';
import 'package:submersion/features/media/data/services/url_metadata_extractor.dart';

/// Stub `UrlMetadataExtractor` that lets each test script per-call results
/// (success / failure) and per-call gating (block/release) so the test can
/// drive the pipeline's bounded-concurrency and per-host throttle behaviour
/// deterministically without real network or real timers.
class _StubExtractor implements UrlMetadataExtractor {
  _StubExtractor({required this.results, this.gates, this.onCall});

  /// Per-call result, looked up by `uri.toString()`.
  final Map<String, UrlExtractionResult> results;

  /// Optional per-call gate (Completer keyed by `uri.toString()`). When
  /// present, `extract(uri)` awaits the matching completer before returning.
  /// Lets tests measure peak concurrency / interleaving.
  final Map<String, Completer<void>>? gates;

  /// Optional hook invoked at the very start of each `extract` call so a
  /// test can record the active-call count or the call timestamp.
  final void Function(Uri uri)? onCall;

  final List<Uri> calls = [];

  @override
  Future<UrlExtractionResult> extract(Uri uri) async {
    calls.add(uri);
    onCall?.call(uri);
    final gate = gates?[uri.toString()];
    if (gate != null) {
      await gate.future;
    }
    final result = results[uri.toString()];
    if (result == null) {
      throw StateError('No stub result for $uri');
    }
    return result;
  }

  @override
  // ignore: no_runtimetype_tostring
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// Wraps a `_StubExtractor` to record the synthetic clock value at the
/// moment `extract` is invoked, so the throttle test can compare per-host
/// call timestamps without depending on real wall-clock time.
class _RecordingExtractor implements UrlMetadataExtractor {
  _RecordingExtractor(this._inner, this._clock, this._record);

  final UrlMetadataExtractor _inner;
  final DateTime Function() _clock;
  final Map<Uri, DateTime> _record;

  @override
  Future<UrlExtractionResult> extract(Uri uri) {
    _record[uri] = _clock();
    return _inner.extract(uri);
  }

  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

UrlExtractionResult _ok(String url) => UrlExtractionResult(
  url: url,
  finalUrl: url,
  contentType: 'image/jpeg',
  width: 1024,
  height: 768,
  takenAt: DateTime.utc(2024, 6, 1, 12, 0, 0),
);

UrlExtractionResult _err(String url, String message) =>
    UrlExtractionResult(url: url, finalUrl: url, failure: message);

void main() {
  late AppDatabase db;
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    // The pending-sync mark goes through SyncRepository, which resolves
    // the database via DatabaseService.
    DatabaseService.instance.setTestDatabase(db);
  });
  tearDown(() async {
    await db.close();
    DatabaseService.instance.resetForTesting();
  });

  Future<void> insertDiveRow(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: const Value(1700000000000),
          createdAt: const Value(1700000000000),
          updatedAt: const Value(1700000000000),
        ),
      );

  Future<void> insertSubscriptionRow(String id) => db.customStatement(
    "INSERT INTO media_subscriptions (id, manifest_url, format, "
    "created_at, updated_at) VALUES ('$id', 'https://x/f', 'atom', 0, 0)",
  );

  Future<MediaData> rowOf(String id) =>
      (db.select(db.media)..where((t) => t.id.equals(id))).getSingle();

  group('resolve', () {
    test('returns metadata in input order without inserting', () async {
      const a = 'https://example.com/a.jpg';
      const b = 'https://example.com/b.jpg';
      final extractor = _StubExtractor(
        results: {a: _ok(a), b: _err(b, 'HTTP 404')},
      );
      final pipeline = NetworkFetchPipeline(db: db, extractor: extractor);

      final resolved = await pipeline.resolve([Uri.parse(a), Uri.parse(b)]);

      expect(resolved.map((r) => r.uri.toString()), [a, b]);
      expect(resolved[0].takenAt, DateTime.utc(2024, 6, 1, 12));
      expect(resolved[0].failed, isFalse);
      expect(resolved[1].failed, isTrue);
      expect(resolved[1].failure, 'HTTP 404');
      expect(await db.select(db.media).get(), isEmpty);
    });

    test('an extractor throw becomes a failure, not an exception', () async {
      const url = 'https://example.com/boom.jpg';
      // No stub result: the extractor throws StateError.
      final pipeline = NetworkFetchPipeline(
        db: db,
        extractor: _StubExtractor(results: const {}),
      );

      final resolved = await pipeline.resolve([Uri.parse(url)]);

      expect(resolved.single.failed, isTrue);
      expect(resolved.single.failure, startsWith('pipeline:'));
    });

    test('respects the 4-concurrent fan-out', () async {
      // Eight URLs across distinct hosts so the per-host throttle does not
      // serialise them. Each call awaits a per-URL gate so we can hold
      // them open and measure peak active.
      final urls = List.generate(8, (i) => 'https://h$i.example.com/a$i.jpg');
      final gates = {for (final u in urls) u: Completer<void>()};
      var active = 0;
      var peak = 0;
      final extractor = _StubExtractor(
        results: {for (final u in urls) u: _ok(u)},
        gates: gates,
        onCall: (_) {
          active += 1;
          if (active > peak) peak = active;
        },
      );
      final pipeline = NetworkFetchPipeline(db: db, extractor: extractor);

      final pending = pipeline.resolve(urls.map(Uri.parse).toList());

      // Yield a few times so the worker pool spins up to its limit.
      for (var i = 0; i < 10; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(peak, lessThanOrEqualTo(4));
      expect(peak, greaterThan(0));

      for (final c in gates.values) {
        c.complete();
      }
      final resolved = await pending;
      expect(resolved, hasLength(8));
      expect(resolved.every((r) => !r.failed), isTrue);
    });

    test('throttles the same host to one call per 250ms', () async {
      // Two URLs on the same host. Drive a fake clock so the second call's
      // observed call-time is at least 250ms after the first.
      final urls = [
        'https://shared.example.com/a.jpg',
        'https://shared.example.com/b.jpg',
      ];
      final extractor = _StubExtractor(
        results: {for (final u in urls) u: _ok(u)},
        onCall: (_) {},
      );
      final clockTimes = <Uri, DateTime>{};
      var clock = DateTime.utc(2025, 1, 1, 0, 0, 0);
      final pipeline = NetworkFetchPipeline(
        db: db,
        extractor: _RecordingExtractor(extractor, () => clock, clockTimes),
        now: () => clock,
        perHostMinInterval: const Duration(milliseconds: 250),
      );

      final pending = pipeline.resolve(urls.map(Uri.parse).toList());

      // Pump until both calls have started. Each pump advances the
      // synthetic clock by 50ms, simulating real time passing while the
      // worker waits for the throttle window to clear.
      for (var i = 0; i < 50 && clockTimes.length < 2; i++) {
        await Future<void>.delayed(Duration.zero);
        clock = clock.add(const Duration(milliseconds: 50));
      }
      await pending;

      expect(clockTimes.length, 2);
      final first = clockTimes[Uri.parse(urls[0])]!;
      final second = clockTimes[Uri.parse(urls[1])]!;
      expect(
        second.difference(first).inMilliseconds,
        greaterThanOrEqualTo(250),
      );
    });
  });

  group('resolveManifestEntries', () {
    test('a fully prefilled entry never touches the network', () async {
      final entry = ManifestEntry(
        entryKey: 'k1',
        url: 'https://example.com/m.jpg',
        takenAt: DateTime.utc(2024, 6, 1, 12),
        latitude: 1,
        longitude: 2,
        width: 800,
        height: 600,
      );
      final extractor = _StubExtractor(results: const {});
      final pipeline = NetworkFetchPipeline(db: db, extractor: extractor);

      final resolved = await pipeline.resolveManifestEntries([entry]);

      expect(extractor.calls, isEmpty);
      expect(resolved.single.entry, entry);
      expect(resolved.single.takenAt, entry.takenAt);
    });

    test('a partially prefilled entry is extracted', () async {
      const url = 'https://feed.example.com/partial.jpg';
      final extractor = _StubExtractor(results: {url: _ok(url)});
      final pipeline = NetworkFetchPipeline(db: db, extractor: extractor);
      final entry = ManifestEntry(
        entryKey: 'k-partial',
        url: url,
        takenAt: DateTime.utc(2024, 6, 10, 14, 30, 0),
        latitude: 1.0,
        longitude: 2.0,
        // width/height intentionally absent
      );

      final resolved = await pipeline.resolveManifestEntries([entry]);

      expect(extractor.calls, [Uri.parse(url)]);
      expect(resolved.single.result, isNotNull);
      // The manifest's takenAt wins over the extracted one.
      expect(resolved.single.takenAt, entry.takenAt);
    });
  });

  group('insertResolved', () {
    test('writes a linked, verified row', () async {
      const url = 'https://example.com/a.jpg';
      await insertDiveRow('d1');
      final fixedNow = DateTime.utc(2025, 4, 28, 10, 0, 0);
      final pipeline = NetworkFetchPipeline(
        db: db,
        extractor: _StubExtractor(results: {url: _ok(url)}),
        now: () => fixedNow,
      );
      final resolved = await pipeline.resolve([Uri.parse(url)]);

      final ids = await pipeline.insertResolved([
        NetworkInsertRequest(media: resolved.single, diveId: 'd1'),
      ]);

      final row = await rowOf(ids.single);
      expect(row.sourceType, 'networkUrl');
      expect(row.diveId, 'd1');
      expect(row.siteId, isNull);
      expect(row.url, url);
      expect(row.width, 1024);
      expect(row.height, 768);
      expect(
        row.takenAt,
        DateTime.utc(2024, 6, 1, 12, 0, 0).millisecondsSinceEpoch,
      );
      expect(row.lastVerifiedAt, fixedNow.millisecondsSinceEpoch);
      expect(row.isOrphaned, isFalse);
    });

    test('stamps siteId when the request targets a site', () async {
      const url = 'https://example.com/a.jpg';
      // media.site_id carries a real FK, so the row has to point at a real
      // site.
      await db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion.insert(
              id: 'site-1',
              name: 'Blue Hole',
              createdAt: 1700000000000,
              updatedAt: 1700000000000,
            ),
          );
      final pipeline = NetworkFetchPipeline(
        db: db,
        extractor: _StubExtractor(results: {url: _ok(url)}),
      );
      final resolved = await pipeline.resolve([Uri.parse(url)]);

      final ids = await pipeline.insertResolved([
        NetworkInsertRequest(media: resolved.single, siteId: 'site-1'),
      ]);

      final row = await rowOf(ids.single);
      expect(row.siteId, 'site-1');
      expect(row.diveId, isNull);
    });

    test('a failed fetch writes an orphaned row with diagnostics', () async {
      const url = 'https://example.com/gone.jpg';
      await insertDiveRow('d1');
      final fixedNow = DateTime.utc(2025, 4, 28, 13, 0, 0);
      final pipeline = NetworkFetchPipeline(
        db: db,
        extractor: _StubExtractor(results: {url: _err(url, 'HTTP 404')}),
        now: () => fixedNow,
      );
      final resolved = await pipeline.resolve([Uri.parse(url)]);

      final ids = await pipeline.insertResolved([
        NetworkInsertRequest(media: resolved.single, diveId: 'd1'),
      ]);

      final row = await rowOf(ids.single);
      expect(row.isOrphaned, isTrue);
      expect(row.lastVerifiedAt, isNull);
      expect(row.diveId, 'd1');
      final diag = await (db.select(
        db.mediaFetchDiagnostics,
      )..where((t) => t.mediaItemId.equals(ids.single))).getSingle();
      expect(diag.lastErrorMessage, 'HTTP 404');
      expect(diag.lastErrorAt, fixedNow.millisecondsSinceEpoch);
      expect(diag.errorCount, 1);
    });

    test('stamps manifest rows with subscription, entry key and '
        'manifest scalars', () async {
      await insertDiveRow('d1');
      await insertSubscriptionRow('sub-1');
      final entry = ManifestEntry(
        entryKey: 'k1',
        url: 'https://feed.example.com/photo1.jpg',
        takenAt: DateTime.utc(2024, 6, 10, 14, 30, 0),
        latitude: 37.7749,
        longitude: -122.4194,
        width: 4032,
        height: 3024,
        caption: 'San Francisco',
        mediaType: 'photo',
      );
      final pipeline = NetworkFetchPipeline(
        db: db,
        extractor: _StubExtractor(results: const {}),
      );
      final resolved = await pipeline.resolveManifestEntries([entry]);

      final ids = await pipeline.insertResolved([
        NetworkInsertRequest(media: resolved.single, diveId: 'd1'),
      ], subscriptionId: 'sub-1');

      final row = await rowOf(ids.single);
      expect(row.sourceType, 'manifestEntry');
      expect(row.subscriptionId, 'sub-1');
      expect(row.entryKey, 'k1');
      expect(row.url, entry.url);
      expect(row.latitude, 37.7749);
      expect(row.longitude, -122.4194);
      expect(row.width, 4032);
      expect(row.height, 3024);
      expect(row.takenAt, entry.takenAt!.millisecondsSinceEpoch);
      expect(row.caption, 'San Francisco');
      expect(row.fileType, 'photo');
      expect(row.diveId, 'd1');
      expect(row.lastVerifiedAt, isNotNull);
    });

    test('manifest scalars win over extracted ones, extraction fills the '
        'gaps', () async {
      const url = 'https://feed.example.com/partial.jpg';
      await insertDiveRow('d1');
      await insertSubscriptionRow('sub-y');
      final pipeline = NetworkFetchPipeline(
        db: db,
        extractor: _StubExtractor(results: {url: _ok(url)}),
      );
      final entry = ManifestEntry(
        entryKey: 'k-partial',
        url: url,
        takenAt: DateTime.utc(2024, 6, 10, 14, 30, 0),
        latitude: 1.0,
        longitude: 2.0,
      );
      final resolved = await pipeline.resolveManifestEntries([entry]);

      final ids = await pipeline.insertResolved([
        NetworkInsertRequest(media: resolved.single, diveId: 'd1'),
      ], subscriptionId: 'sub-y');

      final row = await rowOf(ids.single);
      // Extracted width/height fill the gap.
      expect(row.width, 1024);
      expect(row.height, 768);
      // Manifest-supplied takenAt + lat/lon win over extracted values.
      expect(row.takenAt, entry.takenAt!.millisecondsSinceEpoch);
      expect(row.latitude, 1.0);
      expect(row.longitude, 2.0);
    });

    test('a video entry stores fileType=video and durationSeconds', () async {
      await insertDiveRow('d1');
      await insertSubscriptionRow('sub-vid');
      final pipeline = NetworkFetchPipeline(
        db: db,
        extractor: _StubExtractor(results: const {}),
      );
      final entry = ManifestEntry(
        entryKey: 'k-vid',
        url: 'https://feed.example.com/clip.mp4',
        takenAt: DateTime.utc(2024, 6, 10),
        latitude: 1.0,
        longitude: 2.0,
        width: 1920,
        height: 1080,
        durationSeconds: 42,
        mediaType: 'video',
      );
      final resolved = await pipeline.resolveManifestEntries([entry]);

      final ids = await pipeline.insertResolved([
        NetworkInsertRequest(media: resolved.single, diveId: 'd1'),
      ], subscriptionId: 'sub-vid');

      final row = await rowOf(ids.single);
      expect(row.fileType, 'video');
      expect(row.durationSeconds, 42);
    });

    test('a request needs exactly one target', () {
      final media = ResolvedNetworkMedia(uri: Uri.parse('https://e.com/a.jpg'));
      expect(() => NetworkInsertRequest(media: media), throwsAssertionError);
      expect(
        () => NetworkInsertRequest(media: media, diveId: 'd', siteId: 's'),
        throwsAssertionError,
      );
    });
  });
}
