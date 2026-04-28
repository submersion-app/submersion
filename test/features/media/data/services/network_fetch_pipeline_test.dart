import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
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
  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() async => db.close());

  test(
    'synchronous insert fills url+sourceType, leaves lastVerifiedAt null',
    () async {
      const url = 'https://example.com/a.jpg';
      // Block the background fill so we can inspect rows pre-fill.
      final gate = Completer<void>();
      final extractor = _StubExtractor(
        results: {url: _ok(url)},
        gates: {url: gate},
      );
      final pipeline = NetworkFetchPipeline(db: db, extractor: extractor);

      final ids = await pipeline.ingest([Uri.parse(url)]);

      expect(ids, hasLength(1));
      final row = await (db.select(
        db.media,
      )..where((t) => t.id.equals(ids.single))).getSingle();
      expect(row.sourceType, 'networkUrl');
      expect(row.url, url);
      expect(row.lastVerifiedAt, isNull);
      expect(row.isOrphaned, isFalse);

      // Release the gate and let the pipeline drain so tearDown is clean.
      gate.complete();
      await pipeline.idle();
    },
  );

  test('background success patches row + sets lastVerifiedAt', () async {
    const url = 'https://example.com/a.jpg';
    final extractor = _StubExtractor(results: {url: _ok(url)});
    final fixedNow = DateTime.utc(2025, 4, 28, 10, 0, 0);
    final pipeline = NetworkFetchPipeline(
      db: db,
      extractor: extractor,
      now: () => fixedNow,
    );

    final ids = await pipeline.ingest([Uri.parse(url)]);
    await pipeline.idle();

    final row = await (db.select(
      db.media,
    )..where((t) => t.id.equals(ids.single))).getSingle();
    expect(row.lastVerifiedAt, fixedNow.millisecondsSinceEpoch);
    expect(row.width, 1024);
    expect(row.height, 768);
    expect(
      row.takenAt,
      DateTime.utc(2024, 6, 1, 12, 0, 0).millisecondsSinceEpoch,
    );
    expect(row.isOrphaned, isFalse);
  });

  test('background failure sets isOrphaned + writes diagnostics row', () async {
    const url = 'https://example.com/missing.jpg';
    final extractor = _StubExtractor(results: {url: _err(url, 'HTTP 404')});
    final fixedNow = DateTime.utc(2025, 4, 28, 11, 0, 0);
    final pipeline = NetworkFetchPipeline(
      db: db,
      extractor: extractor,
      now: () => fixedNow,
    );

    final ids = await pipeline.ingest([Uri.parse(url)]);
    await pipeline.idle();

    final row = await (db.select(
      db.media,
    )..where((t) => t.id.equals(ids.single))).getSingle();
    expect(row.isOrphaned, isTrue);
    expect(row.lastVerifiedAt, isNull);

    final diag = await (db.select(
      db.mediaFetchDiagnostics,
    )..where((t) => t.mediaItemId.equals(ids.single))).getSingle();
    expect(diag.lastErrorMessage, 'HTTP 404');
    expect(diag.lastErrorAt, fixedNow.millisecondsSinceEpoch);
    expect(diag.errorCount, 1);
  });

  test('respects 4-concurrent fan-out', () async {
    // Eight URLs across distinct hosts so the per-host throttle does not
    // serialise them. Each call awaits a per-URL gate so we can hold them
    // open and measure peak active.
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
    await pipeline.ingest(urls.map(Uri.parse).toList());

    // Yield a few times so the worker pool spins up to its limit.
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(peak, lessThanOrEqualTo(4));
    expect(peak, greaterThan(0));

    // Release everything and drain so tearDown is clean.
    for (final c in gates.values) {
      c.complete();
      // Decrement on completion through a microtask hop.
    }
    // Manually decrement once each gate completes by waiting for idle.
    // The stub doesn't track completion to keep things simple; use idle().
    extractor.calls.clear();
    // Reset counters so completion ordering doesn't accidentally re-trip peak.
    await pipeline.idle();
  });

  test('throttles same host to 1 per 250ms', () async {
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

    await pipeline.ingest(urls.map(Uri.parse).toList());

    // Pump until the pipeline drains. Each pump advances the synthetic
    // clock by 50ms, simulating real time passing while the worker waits
    // for the throttle window to clear.
    for (var i = 0; i < 50 && clockTimes.length < 2; i++) {
      await Future<void>.delayed(Duration.zero);
      clock = clock.add(const Duration(milliseconds: 50));
    }
    await pipeline.idle();

    expect(clockTimes.length, 2);
    final first = clockTimes[Uri.parse(urls[0])]!;
    final second = clockTimes[Uri.parse(urls[1])]!;
    expect(second.difference(first).inMilliseconds, greaterThanOrEqualTo(250));
  });
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
