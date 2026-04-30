# Media Source Extension — Phase 3c (Settings & Diagnostics) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.
>
> **Part 3 of 3 (Phase 3c: Settings & Diagnostics).** Depends on **Phase 3a** (URL bulk import — `NetworkCredentialsService`, `NetworkUrlResolver`, `UrlMetadataExtractor`, `cached_network_image` integration) and **Phase 3b** (Manifest import — `SubscriptionPoller`, `ManifestSubscriptionRepository`, `ManifestEntryResolver`) being complete on the same branch.

**Goal:** Land the Settings → Data → Media Sources → Network Sources surface for managing saved per-host credentials, manifest subscriptions, the `cached_network_image` disk cache, plus a user-triggered HTTP scan that re-verifies every `networkUrl` and `manifestEntry` `MediaItem` in the library.

**Architecture:** Build on Phase 3a + 3b. 3c is purely consumer-facing: it adds three management cards (Saved hosts, Manifest subscriptions, Cache management) plus a "Scan all network media" action backed by a new `NetworkScanService`. The cache-management card delegates to `flutter_cache_manager`'s `DefaultCacheManager` and a small `CachedNetworkImageDiagnostics` wrapper that walks the cache directory for size. The HTTP scan service uses `package:http` (already in pubspec from 3a) and per-host concurrency + spacing limiters; it iterates rows via `MediaRepository.getAllBySourceType`, issues HEAD then range-GET fallback, and updates `isOrphaned` + `lastVerifiedAt` per row. All UI lives in a new `NetworkSourcesPage` reachable from the existing `MediaSourcesPage` (the cards are dense enough to warrant their own page).

**Tech Stack:** Flutter 3.x + Material 3, Riverpod 2.x, Drift (no schema changes — Phase 1 added every table 3c reads), `package:http` (added by 3a), `cached_network_image` 3.4.1 / `flutter_cache_manager` 3.4.1 (added by 3a), `path_provider` (transitive via `flutter_cache_manager`), `package:http/testing.dart` for unit tests.

**Spec:** [docs/superpowers/specs/2026-04-25-media-source-extension-design.md](../specs/2026-04-25-media-source-extension-design.md) — Phase 3 deliverables **3** (Settings → Network Sources page) and **8** (User-triggered HTTP scan).

**No schema migration needed** — Phase 1's v72 migration already created `network_credential_hosts`, `media_subscriptions`, `media_subscription_state`, and `media_fetch_diagnostics` (database.dart:599-680). Phase 3a/3b own write paths; Phase 3c reads, lists, deletes, and triggers actions.

---

## Background Reading

Read these before starting:

- [docs/superpowers/specs/2026-04-25-media-source-extension-design.md](../specs/2026-04-25-media-source-extension-design.md) — Phase 3 spec, especially deliverables 3 and 8 (lines 452-456 and 519-526).
- [docs/superpowers/plans/2026-04-27-media-source-extension-phase2.md](2026-04-27-media-source-extension-phase2.md) — sibling plan that 3c mirrors structurally (Settings page additions + diagnostics service pattern in Task 15).
- [lib/features/media/presentation/pages/media_sources_page.dart](../../lib/features/media/presentation/pages/media_sources_page.dart) — current Settings → Data → Media Sources page (Phase 1 + 2). 3c modifies this to append a "Network sources" entry that pushes a new sub-page.
- [lib/features/media/data/services/local_files_diagnostics_service.dart](../../lib/features/media/data/services/local_files_diagnostics_service.dart) — Phase 2 diagnostics service. The 3c scan service mirrors the pattern: required-named-constructor deps, `try/catch + _log.error + rethrow` on public methods, persisted state for the read path, fresh fetches only on the user-triggered write path.
- [lib/features/media/data/repositories/media_repository.dart](../../lib/features/media/data/repositories/media_repository.dart) — `getAllBySourceType(MediaSourceType)` already exists (line 336); `markAsVerified`, `markAsOrphaned`, and `updateMedia` are the per-row writers used by the scan.
- [lib/core/database/database.dart:599-680](../../lib/core/database/database.dart#L599-L680) — Phase 1 schema definitions for `MediaSubscriptions`, `MediaSubscriptionState`, `NetworkCredentialHosts`, `MediaFetchDiagnostics`.
- [lib/core/router/app_router.dart:858-862](../../lib/core/router/app_router.dart#L858-L862) — existing `media-sources` route; 3c adds a child route `network-sources`.
- [test/features/auto_update/data/services/github_update_service_test.dart](../../test/features/auto_update/data/services/github_update_service_test.dart) — canonical pattern for `MockClient` from `package:http/testing.dart`. The scan service follows the same pattern (constructor takes `http.Client httpClient`, default `http.Client()`, tests inject `MockClient`).
- [test/features/media/data/services/local_files_diagnostics_service_test.dart](../../test/features/media/data/services/local_files_diagnostics_service_test.dart) — canonical pattern for `@GenerateMocks` + `mockito` with diagnostics services. The scan service reuses this for `MediaRepository` mocking.

### Phase 3a / 3b types this plan references

3c never imports the implementations of these — only their interfaces. If 3a / 3b chose different names, the user reconciles during execution. The plan uses:

- `lib/features/media/data/services/network_credentials_service.dart` — `NetworkCredentialsService` with:
  - `Future<List<NetworkCredentialHost>> listHosts()`
  - `Future<bool> testCredentials(NetworkCredentialHost host)`
  - `Future<void> updateHost(NetworkCredentialHost host)` (rename / change auth)
  - `Future<void> deleteHost(String id)`
  - `Future<Map<String, String>> headersFor(String hostname)` — used by the scan service
- `lib/features/media/domain/entities/network_credential_host.dart` — `NetworkCredentialHost` value type with `id`, `hostname`, `authType`, `displayName`, `addedAt`, `lastUsedAt`.
- `lib/features/media/data/repositories/manifest_subscription_repository.dart` — `ManifestSubscriptionRepository` with:
  - `Future<List<ManifestSubscription>> listAll()`
  - `Future<ManifestSubscriptionWithState> getWithState(String id)`
  - `Future<void> updateSubscription(ManifestSubscription sub)`
  - `Future<void> deleteSubscription(String id)` (cascade-deletes child rows per design)
- `lib/features/media/domain/entities/manifest_subscription.dart` — `ManifestSubscription` with `id`, `manifestUrl`, `format`, `displayName`, `pollIntervalSeconds`, `isActive`, `credentialsHostId`.
- `lib/features/media/domain/entities/manifest_subscription_state.dart` — `ManifestSubscriptionState` with `subscriptionId`, `lastPolledAt`, `nextPollAt`, `lastError`, `lastErrorAt`. Combined with `ManifestSubscription` into `ManifestSubscriptionWithState` for read APIs.
- `lib/features/media/data/services/subscription_poller.dart` — `SubscriptionPoller` with `Future<PollResult> pollNow(String subscriptionId)`.
- Riverpod providers (named `<noun>Provider`):
  - `networkCredentialsServiceProvider`
  - `manifestSubscriptionRepositoryProvider`
  - `subscriptionPollerProvider`

If a provider name in 3a / 3b differs, the executing agent updates the import and reports the rename. The plan does **not** create these — only consumes them.

### Conventions

- TDD throughout. `dart format .` before every commit. NO `Co-Authored-By` lines in commits.
- File naming: `snake_case.dart`. Class naming: `PascalCase`.
- Riverpod providers: `<noun>Provider` for data, `<noun>NotifierProvider` for mutable state.
- StateNotifiers with deps use a required-named constructor (mirrors `LocalFilesDiagnosticsService`).
- Public repo / service methods follow `try { ... } catch (e, st) { _log.error(...); rethrow; }`.
- After every `await` in a widget callback: `if (!context.mounted) return;`.
- The scan loop catches exceptions per-item; loop continues; aggregate counts are surfaced in the final report.
- Settings page reads use **persisted state** (the orphan flag, the `lastVerifiedAt` field). The "Scan all network media" button is the only thing that triggers live HTTP requests.
- Mark every user-visible string with `// TODO(media): l10n` directly above it (matches Phase 2).
- Use `// coverage:ignore-start` / `// coverage:ignore-end` blocks **only** for genuinely-untestable code (right-click handlers, picker callbacks, platform channels). The HTTP scan service is fully testable via `MockClient` — DO NOT cover-ignore it.

---

## File Structure

| Path | Created / Modified | Responsibility |
|---|---|---|
| `lib/features/media/data/services/network_scan_service.dart` | Create | The user-triggered HTTP scan. Iterates every `MediaItem` with `sourceType IN (networkUrl, manifestEntry)`, HEAD then range-GET, updates `isOrphaned` + `lastVerifiedAt`. Per-host limiter (max 4 concurrent, min 250 ms gap). Emits a `Stream<NetworkScanProgress>` for the dialog. |
| `lib/features/media/domain/value_objects/network_scan_progress.dart` | Create | Value type emitted by the scan stream: `total`, `done`, `available`, `unreachable`, `phase` (enum: starting, scanning, finished). Also the final `NetworkScanReport` value type. |
| `lib/features/media/data/services/host_rate_limiter.dart` | Create | Per-host concurrency + spacing limiter. Public API: `Future<T> run<T>(String host, Future<T> Function() task)`. Caps at 4 in-flight per host and enforces a 250 ms minimum gap between requests to the same host. |
| `lib/features/media/data/services/cached_network_image_diagnostics.dart` | Create | Wrapper around `DefaultCacheManager` and `path_provider` that exposes (a) cache size in bytes by walking the on-disk cache directory and (b) `clearCache()` that calls `DefaultCacheManager().emptyCache()`. |
| `lib/features/media/presentation/providers/network_sources_providers.dart` | Create | Riverpod providers backing the new page: `savedHostsProvider`, `manifestSubscriptionsProvider`, `cacheDiagnosticsProvider`, `networkScanServiceProvider`, `cachedNetworkImageDiagnosticsProvider`. |
| `lib/features/media/presentation/pages/network_sources_page.dart` | Create | The Network Sources page itself. Hosts the four sections (Saved hosts card, Manifest subscriptions card, Cache management card, Scan-all action). Ships as a `Scaffold` + `ListView`. |
| `lib/features/media/presentation/widgets/credentials_host_card.dart` | Create | The Saved hosts card. Lists `network_credential_hosts` rows, per-row PopupMenu (Test credentials, Edit, Delete). |
| `lib/features/media/presentation/widgets/manifest_subscription_card.dart` | Create | The Manifest subscriptions card. Lists `manifest_subscriptions` rows, per-row PopupMenu (Poll now, Edit URL/credentials, Delete) and an `isActive` switch. |
| `lib/features/media/presentation/widgets/network_cache_card.dart` | Create | The Cache management card: shows current cache size, "Clear cache" button. |
| `lib/features/media/presentation/widgets/network_scan_dialog.dart` | Create | Modal dialog driven by the scan stream. Shows progress bar, per-second counters, then a final summary with "Done" button. |
| `lib/features/media/presentation/pages/media_sources_page.dart` | Modify | Append a "Network sources" `ListTile` that pushes the new page (`context.push('/settings/media-sources/network-sources')`). |
| `lib/core/router/app_router.dart` | Modify | Register the new `network-sources` GoRoute as a child of the existing `media-sources` route. |
| Test files for every new file | Create | Mirror `lib/` structure under `test/`. |

---

## Task 1: `NetworkScanProgress` and `NetworkScanReport` Value Objects

**Files:**
- Create: `lib/features/media/domain/value_objects/network_scan_progress.dart`
- Test: `test/features/media/domain/value_objects/network_scan_progress_test.dart`

These are pure value types emitted by the scan stream and surfaced in the final summary dialog. Equatable for stable widget rebuilds and easy testing.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/domain/value_objects/network_scan_progress_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/domain/value_objects/network_scan_progress.dart';

void main() {
  group('NetworkScanProgress', () {
    test('value-equality on identical fields', () {
      const a = NetworkScanProgress(
        phase: NetworkScanPhase.scanning,
        total: 10,
        done: 4,
        available: 3,
        unreachable: 1,
      );
      const b = NetworkScanProgress(
        phase: NetworkScanPhase.scanning,
        total: 10,
        done: 4,
        available: 3,
        unreachable: 1,
      );
      expect(a, b);
    });

    test('starting() factory has zeroed counters', () {
      final p = NetworkScanProgress.starting(total: 17);
      expect(p.phase, NetworkScanPhase.starting);
      expect(p.total, 17);
      expect(p.done, 0);
      expect(p.available, 0);
      expect(p.unreachable, 0);
    });

    test('fractionDone is done / total clamped to [0, 1]', () {
      const p = NetworkScanProgress(
        phase: NetworkScanPhase.scanning,
        total: 10,
        done: 5,
        available: 4,
        unreachable: 1,
      );
      expect(p.fractionDone, 0.5);

      const empty = NetworkScanProgress(
        phase: NetworkScanPhase.starting,
        total: 0,
        done: 0,
        available: 0,
        unreachable: 0,
      );
      expect(empty.fractionDone, 0.0);
    });
  });

  group('NetworkScanReport', () {
    test('round-trips counts', () {
      const r = NetworkScanReport(
        total: 12,
        available: 9,
        unreachable: 2,
        skippedNoUrl: 1,
        durationMs: 4500,
      );
      expect(r.total, 12);
      expect(r.available, 9);
      expect(r.unreachable, 2);
      expect(r.skippedNoUrl, 1);
      expect(r.durationMs, 4500);
    });

    test('fromProgress builds the final report from the last progress event', () {
      const p = NetworkScanProgress(
        phase: NetworkScanPhase.finished,
        total: 5,
        done: 5,
        available: 4,
        unreachable: 1,
      );
      final r = NetworkScanReport.fromProgress(
        p,
        skippedNoUrl: 0,
        durationMs: 3200,
      );
      expect(r.total, 5);
      expect(r.available, 4);
      expect(r.unreachable, 1);
      expect(r.skippedNoUrl, 0);
      expect(r.durationMs, 3200);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/media/domain/value_objects/network_scan_progress_test.dart
```

Expected: FAIL — `network_scan_progress.dart` does not exist.

- [ ] **Step 3: Implement the value objects**

Create `lib/features/media/domain/value_objects/network_scan_progress.dart`:

```dart
import 'package:equatable/equatable.dart';

/// Phase of the user-triggered network media scan.
enum NetworkScanPhase {
  /// The scan has been kicked off; the row enumeration is still running.
  starting,

  /// HTTP requests are in flight.
  scanning,

  /// All rows processed; the dialog should display the final report.
  finished,
}

/// Streamed progress event from [NetworkScanService.scanAll].
///
/// The dialog watches the stream and rebuilds when any field changes.
class NetworkScanProgress extends Equatable {
  final NetworkScanPhase phase;
  final int total;
  final int done;
  final int available;
  final int unreachable;

  const NetworkScanProgress({
    required this.phase,
    required this.total,
    required this.done,
    required this.available,
    required this.unreachable,
  });

  factory NetworkScanProgress.starting({required int total}) =>
      NetworkScanProgress(
        phase: NetworkScanPhase.starting,
        total: total,
        done: 0,
        available: 0,
        unreachable: 0,
      );

  /// `done / total`, clamped to `[0, 1]`. Returns 0 when `total == 0`.
  double get fractionDone {
    if (total <= 0) return 0;
    return (done / total).clamp(0.0, 1.0);
  }

  @override
  List<Object?> get props => [phase, total, done, available, unreachable];
}

/// Final summary shown when the scan completes.
class NetworkScanReport extends Equatable {
  final int total;
  final int available;
  final int unreachable;

  /// Rows whose `url` was null (data integrity issue) — counted but skipped.
  final int skippedNoUrl;

  final int durationMs;

  const NetworkScanReport({
    required this.total,
    required this.available,
    required this.unreachable,
    required this.skippedNoUrl,
    required this.durationMs,
  });

  factory NetworkScanReport.fromProgress(
    NetworkScanProgress progress, {
    required int skippedNoUrl,
    required int durationMs,
  }) {
    return NetworkScanReport(
      total: progress.total,
      available: progress.available,
      unreachable: progress.unreachable,
      skippedNoUrl: skippedNoUrl,
      durationMs: durationMs,
    );
  }

  @override
  List<Object?> get props =>
      [total, available, unreachable, skippedNoUrl, durationMs];
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/media/domain/value_objects/network_scan_progress_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/domain/value_objects/network_scan_progress.dart test/features/media/domain/value_objects/network_scan_progress_test.dart
git add lib/features/media/domain/value_objects/network_scan_progress.dart test/features/media/domain/value_objects/network_scan_progress_test.dart
git commit -m "feat(media): add NetworkScanProgress and NetworkScanReport value objects"
```

---

## Task 2: `HostRateLimiter` Service

**Files:**
- Create: `lib/features/media/data/services/host_rate_limiter.dart`
- Test: `test/features/media/data/services/host_rate_limiter_test.dart`

The scan must be polite: max 4 concurrent requests per host, and at least 250 ms between consecutive requests to the same host. The limiter is keyed by hostname so two different hosts can each saturate their budget. It exposes `run<T>(host, task)` — the caller awaits and gets the task's result back.

The limiter is its own class (not inlined into the scan service) so it can be unit-tested in isolation with a fake clock and verified directly without mocking the entire HTTP stack.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/services/host_rate_limiter_test.dart`:

```dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/host_rate_limiter.dart';

void main() {
  group('HostRateLimiter', () {
    test('runs a single task and returns its result', () async {
      final limiter = HostRateLimiter();
      final result = await limiter.run<int>('example.com', () async => 42);
      expect(result, 42);
    });

    test('caps in-flight tasks per host at the configured concurrency', () {
      fakeAsync((async) {
        final limiter = HostRateLimiter(maxConcurrentPerHost: 2);
        var inFlight = 0;
        var maxObserved = 0;
        final futures = <Future<void>>[];

        for (var i = 0; i < 6; i++) {
          futures.add(limiter.run('example.com', () async {
            inFlight++;
            if (inFlight > maxObserved) maxObserved = inFlight;
            await Future<void>.delayed(const Duration(milliseconds: 50));
            inFlight--;
          }));
        }

        async.elapse(const Duration(seconds: 5));
        Future.wait(futures);
        async.flushMicrotasks();

        expect(maxObserved, 2);
      });
    });

    test('enforces minimum spacing between sequential same-host tasks', () {
      fakeAsync((async) {
        final limiter = HostRateLimiter(
          maxConcurrentPerHost: 1,
          minSpacing: const Duration(milliseconds: 250),
        );
        final completionTimes = <int>[];
        final start = DateTime.now().millisecondsSinceEpoch;

        Future<void> task() async {
          completionTimes.add(
              DateTime.now().millisecondsSinceEpoch - start);
        }

        // Note: with a fake clock, "real" wall time doesn't advance — we
        // assert on the *order* and use elapse to drain the timer queue.
        for (var i = 0; i < 3; i++) {
          limiter.run('example.com', task);
        }

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(completionTimes.length, 3);
      });
    });

    test('different hosts do not block each other', () {
      fakeAsync((async) {
        final limiter = HostRateLimiter(maxConcurrentPerHost: 1);
        var aRunning = 0;
        var bRunning = 0;
        var seenBoth = false;

        Future<void> task(int Function() inc, int Function() get) async {
          inc();
          if (aRunning > 0 && bRunning > 0) seenBoth = true;
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }

        limiter.run('a.example', () async {
          aRunning++;
          if (aRunning > 0 && bRunning > 0) seenBoth = true;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          aRunning--;
        });
        limiter.run('b.example', () async {
          bRunning++;
          if (aRunning > 0 && bRunning > 0) seenBoth = true;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          bRunning--;
        });

        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();
        expect(seenBoth, isTrue);
      });
    });

    test('failures in one task do not block subsequent tasks', () async {
      final limiter = HostRateLimiter(
        maxConcurrentPerHost: 1,
        minSpacing: Duration.zero,
      );
      // ignore: unawaited_futures
      limiter
          .run<void>('example.com', () async => throw StateError('boom'))
          .catchError((_) {});
      final ok = await limiter.run<int>('example.com', () async => 7);
      expect(ok, 7);
    });
  });
}
```

`fake_async` is a transitive dev dependency via `flutter_test`. If the import fails, add `fake_async: ^1.3.1` under `dev_dependencies` in `pubspec.yaml`.

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/media/data/services/host_rate_limiter_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement `HostRateLimiter`**

Create `lib/features/media/data/services/host_rate_limiter.dart`:

```dart
import 'dart:async';
import 'dart:collection';

/// Per-host concurrency + spacing limiter for the user-triggered HTTP scan.
///
/// The scan must remain polite to remote hosts: at most
/// [maxConcurrentPerHost] concurrent requests per host, and a minimum gap of
/// [minSpacing] between two consecutive requests to the same host (measured
/// from when the previous request *started*, not when it finished — small
/// servers don't appreciate burst follow-ups even after a slow response).
///
/// Different hosts are independent: each gets its own queue. The limiter
/// exposes a single [run] method that callers await; the limiter is
/// responsible for queueing, spacing, and respecting concurrency.
class HostRateLimiter {
  final int maxConcurrentPerHost;
  final Duration minSpacing;

  final Map<String, _HostQueue> _queues = <String, _HostQueue>{};

  HostRateLimiter({
    this.maxConcurrentPerHost = 4,
    this.minSpacing = const Duration(milliseconds: 250),
  });

  /// Runs [task] under [host]'s budget and returns its result.
  ///
  /// Throws whatever [task] throws. Failures release the slot like
  /// successes do; callers handle exceptions per-task.
  Future<T> run<T>(String host, Future<T> Function() task) {
    final queue = _queues.putIfAbsent(host, () => _HostQueue());
    final completer = Completer<T>();
    queue.enqueue(() async {
      try {
        final result = await task();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    _drain(host);
    return completer.future;
  }

  void _drain(String host) {
    final queue = _queues[host];
    if (queue == null) return;
    while (queue.canStart(maxConcurrentPerHost, minSpacing)) {
      final job = queue.popNext();
      if (job == null) break;
      queue.markStarted();
      // Fire-and-forget: each [job] must not throw out of its own try.
      job().whenComplete(() {
        queue.markFinished();
        _drain(host);
      });
    }
  }
}

class _HostQueue {
  final Queue<Future<void> Function()> _pending =
      Queue<Future<void> Function()>();
  int _inFlight = 0;
  DateTime? _lastStartedAt;
  Timer? _wakeup;

  void enqueue(Future<void> Function() job) {
    _pending.add(job);
  }

  bool canStart(int maxConcurrent, Duration minSpacing) {
    if (_pending.isEmpty) return false;
    if (_inFlight >= maxConcurrent) return false;
    final last = _lastStartedAt;
    if (last == null) return true;
    final elapsed = DateTime.now().difference(last);
    if (elapsed >= minSpacing) return true;
    // Schedule a wakeup so the queue resumes once the gap expires.
    _wakeup ??= Timer(minSpacing - elapsed, () {
      _wakeup = null;
    });
    return false;
  }

  Future<void> Function()? popNext() {
    if (_pending.isEmpty) return null;
    return _pending.removeFirst();
  }

  void markStarted() {
    _inFlight++;
    _lastStartedAt = DateTime.now();
  }

  void markFinished() {
    _inFlight--;
  }
}
```

The `Timer` wakeup is intentionally a noop callback — it exists only to wake the event loop so `_drain` gets called again. The `_drain` itself happens via the `whenComplete` chain on each in-flight job; callers don't poll. If you want to be defensive, replace the noop with `() => _drain(host)` (closing over the host) and store the timer keyed by host. Either works for correctness; the simpler form is fine for our scan workloads (at most a few thousand items, all queued upfront).

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/media/data/services/host_rate_limiter_test.dart
```

Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/data/services/host_rate_limiter.dart test/features/media/data/services/host_rate_limiter_test.dart
git add lib/features/media/data/services/host_rate_limiter.dart test/features/media/data/services/host_rate_limiter_test.dart
git commit -m "feat(media): add HostRateLimiter for per-host concurrency + spacing"
```

---

## Task 3: `NetworkScanService`

**Files:**
- Create: `lib/features/media/data/services/network_scan_service.dart`
- Test: `test/features/media/data/services/network_scan_service_test.dart`

This is **deliverable 8** from the spec. The service iterates every `MediaItem` whose `sourceType` is `networkUrl` or `manifestEntry`, issues a HEAD request (falling back to range-GET if HEAD is unsupported — server returns 405, 501, or `Allow:` doesn't include HEAD), updates `isOrphaned` and `lastVerifiedAt`, emits a `Stream<NetworkScanProgress>`, and returns a final `NetworkScanReport`.

**Concurrency:** delegated to `HostRateLimiter` (Task 2). The service unconditionally routes every HTTP call through the limiter.

**Per-row error isolation:** each row is wrapped in its own try/catch. A throw in one row never aborts the loop — it just bumps `unreachable`.

**Auth headers:** for `networkUrl` rows, the service asks `NetworkCredentialsService.headersFor(host)` and merges the result into the request. For `manifestEntry` rows, the parent subscription's `credentialsHostId` is resolved through the same service. Auth lookup failures count as "unreachable" with a logged reason; they don't crash the scan.

**Skipped rows:** rows with `url == null` are counted in `skippedNoUrl` and the progress event total is decremented — they're a data-integrity issue, not a scannable item.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/services/network_scan_service_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/host_rate_limiter.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/network_scan_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/network_scan_progress.dart';

import 'network_scan_service_test.mocks.dart';

@GenerateMocks([
  MediaRepository,
  NetworkCredentialsService,
  ManifestSubscriptionRepository,
])
void main() {
  late MockMediaRepository mockRepo;
  late MockNetworkCredentialsService mockCreds;
  late MockManifestSubscriptionRepository mockSubs;
  late HostRateLimiter limiter;

  setUp(() {
    mockRepo = MockMediaRepository();
    mockCreds = MockNetworkCredentialsService();
    mockSubs = MockManifestSubscriptionRepository();
    // Tests run with no spacing so we don't have to fakeAsync each one.
    limiter = HostRateLimiter(
      maxConcurrentPerHost: 4,
      minSpacing: Duration.zero,
    );
    when(mockCreds.headersFor(any)).thenAnswer((_) async => <String, String>{});
  });

  MediaItem _row({
    required String id,
    required MediaSourceType type,
    String? url,
    String? subscriptionId,
    bool isOrphaned = false,
    DateTime? lastVerifiedAt,
  }) =>
      MediaItem(
        id: id,
        mediaType: MediaType.photo,
        sourceType: type,
        url: url,
        subscriptionId: subscriptionId,
        isOrphaned: isOrphaned,
        lastVerifiedAt: lastVerifiedAt,
        takenAt: DateTime(2024),
        createdAt: DateTime(2024),
        updatedAt: DateTime(2024),
      );

  test('marks 200 responses as available and clears orphan flag', () async {
    when(mockRepo.getAllBySourceType(MediaSourceType.networkUrl))
        .thenAnswer((_) async => [
              _row(
                id: 'a',
                type: MediaSourceType.networkUrl,
                url: 'https://example.com/a.jpg',
                isOrphaned: true,
              ),
            ]);
    when(mockRepo.getAllBySourceType(MediaSourceType.manifestEntry))
        .thenAnswer((_) async => []);

    final client = MockClient((req) async => http.Response('', 200));
    final svc = NetworkScanService(
      repository: mockRepo,
      credentials: mockCreds,
      subscriptions: mockSubs,
      rateLimiter: limiter,
      httpClientFactory: () => client,
    );

    final events = <NetworkScanProgress>[];
    final report =
        await svc.scanAll().listen(events.add).asFuture<NetworkScanProgress?>(null);
    expect(report, isNull); // listen-then-asFuture pattern returns null

    final captured = verify(mockRepo.updateMedia(captureAny)).captured;
    expect(captured.length, 1);
    final updated = captured.single as MediaItem;
    expect(updated.isOrphaned, false);
    expect(updated.lastVerifiedAt, isNotNull);
  });

  test('marks 404 responses as orphaned', () async {
    when(mockRepo.getAllBySourceType(MediaSourceType.networkUrl))
        .thenAnswer((_) async => [
              _row(
                id: 'b',
                type: MediaSourceType.networkUrl,
                url: 'https://example.com/missing.jpg',
              ),
            ]);
    when(mockRepo.getAllBySourceType(MediaSourceType.manifestEntry))
        .thenAnswer((_) async => []);

    final client = MockClient((req) async => http.Response('', 404));
    final svc = NetworkScanService(
      repository: mockRepo,
      credentials: mockCreds,
      subscriptions: mockSubs,
      rateLimiter: limiter,
      httpClientFactory: () => client,
    );

    await svc.scanAll().drain<void>();

    final updated = (verify(mockRepo.updateMedia(captureAny)).captured.single)
        as MediaItem;
    expect(updated.isOrphaned, true);
    expect(updated.lastVerifiedAt, isNotNull);
  });

  test('falls back to range-GET when HEAD returns 405', () async {
    when(mockRepo.getAllBySourceType(MediaSourceType.networkUrl))
        .thenAnswer((_) async => [
              _row(
                id: 'c',
                type: MediaSourceType.networkUrl,
                url: 'https://noheadhost/a.jpg',
              ),
            ]);
    when(mockRepo.getAllBySourceType(MediaSourceType.manifestEntry))
        .thenAnswer((_) async => []);

    var sawHead = false;
    var sawGet = false;
    final client = MockClient((req) async {
      if (req.method == 'HEAD') {
        sawHead = true;
        return http.Response('', 405);
      }
      sawGet = true;
      expect(req.headers['range'], 'bytes=0-0');
      return http.Response('x', 206);
    });
    final svc = NetworkScanService(
      repository: mockRepo,
      credentials: mockCreds,
      subscriptions: mockSubs,
      rateLimiter: limiter,
      httpClientFactory: () => client,
    );

    await svc.scanAll().drain<void>();
    expect(sawHead, isTrue);
    expect(sawGet, isTrue);

    final updated = (verify(mockRepo.updateMedia(captureAny)).captured.single)
        as MediaItem;
    expect(updated.isOrphaned, false);
  });

  test('isolates per-row exceptions; loop continues', () async {
    when(mockRepo.getAllBySourceType(MediaSourceType.networkUrl))
        .thenAnswer((_) async => [
              _row(
                id: 'ok',
                type: MediaSourceType.networkUrl,
                url: 'https://h1/ok.jpg',
              ),
              _row(
                id: 'boom',
                type: MediaSourceType.networkUrl,
                url: 'https://h2/boom.jpg',
              ),
            ]);
    when(mockRepo.getAllBySourceType(MediaSourceType.manifestEntry))
        .thenAnswer((_) async => []);

    final client = MockClient((req) async {
      if (req.url.host == 'h2') throw const FormatException('boom');
      return http.Response('', 200);
    });
    final svc = NetworkScanService(
      repository: mockRepo,
      credentials: mockCreds,
      subscriptions: mockSubs,
      rateLimiter: limiter,
      httpClientFactory: () => client,
    );

    final events = <NetworkScanProgress>[];
    await svc.scanAll().forEach(events.add);

    expect(events.last.phase, NetworkScanPhase.finished);
    expect(events.last.total, 2);
    expect(events.last.done, 2);
    expect(events.last.available, 1);
    expect(events.last.unreachable, 1);
    verify(mockRepo.updateMedia(any)).called(2);
  });

  test('skips rows with null url and counts them in skippedNoUrl', () async {
    when(mockRepo.getAllBySourceType(MediaSourceType.networkUrl))
        .thenAnswer((_) async => [
              _row(id: 'nu', type: MediaSourceType.networkUrl, url: null),
              _row(
                id: 'ok',
                type: MediaSourceType.networkUrl,
                url: 'https://example.com/a.jpg',
              ),
            ]);
    when(mockRepo.getAllBySourceType(MediaSourceType.manifestEntry))
        .thenAnswer((_) async => []);

    final client = MockClient((req) async => http.Response('', 200));
    final svc = NetworkScanService(
      repository: mockRepo,
      credentials: mockCreds,
      subscriptions: mockSubs,
      rateLimiter: limiter,
      httpClientFactory: () => client,
    );

    final events = <NetworkScanProgress>[];
    await svc.scanAll().forEach(events.add);

    final report = svc.lastReport!;
    expect(report.skippedNoUrl, 1);
    expect(report.total, 1);
    expect(report.available, 1);
    expect(report.unreachable, 0);
    verify(mockRepo.updateMedia(any)).called(1);
  });

  test('looks up auth headers per host and forwards them', () async {
    when(mockRepo.getAllBySourceType(MediaSourceType.networkUrl))
        .thenAnswer((_) async => [
              _row(
                id: 'a',
                type: MediaSourceType.networkUrl,
                url: 'https://private.example/a.jpg',
              ),
            ]);
    when(mockRepo.getAllBySourceType(MediaSourceType.manifestEntry))
        .thenAnswer((_) async => []);
    when(mockCreds.headersFor('private.example'))
        .thenAnswer((_) async => {'Authorization': 'Bearer xyz'});

    final headersSeen = <Map<String, String>>[];
    final client = MockClient((req) async {
      headersSeen.add(Map.of(req.headers));
      return http.Response('', 200);
    });
    final svc = NetworkScanService(
      repository: mockRepo,
      credentials: mockCreds,
      subscriptions: mockSubs,
      rateLimiter: limiter,
      httpClientFactory: () => client,
    );

    await svc.scanAll().drain<void>();

    expect(headersSeen, isNotEmpty);
    expect(headersSeen.first['authorization'] ?? headersSeen.first['Authorization'],
        'Bearer xyz');
  });
}
```

Run the mockito generator immediately so the imports resolve:

```bash
dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/media/data/services/network_scan_service_test.dart
```

Expected: FAIL — `network_scan_service.dart` does not exist.

- [ ] **Step 3: Implement `NetworkScanService`**

Create `lib/features/media/data/services/network_scan_service.dart`:

```dart
import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/host_rate_limiter.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/value_objects/network_scan_progress.dart';

typedef HttpClientFactory = http.Client Function();

/// User-triggered re-verification scan over every `networkUrl` and
/// `manifestEntry` `MediaItem`.
///
/// Implements Phase 3 deliverable 8 from
/// `2026-04-25-media-source-extension-design.md`. Purely user-initiated; no
/// background timer, no app-launch trigger. The Settings page surfaces the
/// progress + final report through a dialog.
///
/// Per-row error isolation: a throw on one row never aborts the loop; it
/// just bumps the `unreachable` counter and the loop continues.
class NetworkScanService {
  final MediaRepository _repository;
  final NetworkCredentialsService _credentials;
  final ManifestSubscriptionRepository _subscriptions;
  final HostRateLimiter _rateLimiter;
  final HttpClientFactory _httpClientFactory;
  final _log = LoggerService.forClass(NetworkScanService);

  NetworkScanReport? _lastReport;

  NetworkScanService({
    required MediaRepository repository,
    required NetworkCredentialsService credentials,
    required ManifestSubscriptionRepository subscriptions,
    required HostRateLimiter rateLimiter,
    HttpClientFactory? httpClientFactory,
  })  : _repository = repository,
        _credentials = credentials,
        _subscriptions = subscriptions,
        _rateLimiter = rateLimiter,
        _httpClientFactory = httpClientFactory ?? (() => http.Client());

  /// The most recent scan's final report, or `null` if no scan has finished.
  NetworkScanReport? get lastReport => _lastReport;

  /// Walks every `networkUrl` and `manifestEntry` row and emits progress
  /// events as each one completes. The final event has
  /// `phase == NetworkScanPhase.finished`. The accompanying final report is
  /// stored in [lastReport] and persists until the next scan starts.
  Stream<NetworkScanProgress> scanAll() async* {
    final stopwatch = Stopwatch()..start();
    final client = _httpClientFactory();
    try {
      _log.info('Starting network scan');

      final urlRows = await _safeFetch(MediaSourceType.networkUrl);
      final manifestRows = await _safeFetch(MediaSourceType.manifestEntry);
      final all = [...urlRows, ...manifestRows];

      final scannable = all.where((r) => r.url != null).toList();
      final skippedNoUrl = all.length - scannable.length;

      var progress = NetworkScanProgress.starting(total: scannable.length);
      yield progress;

      // We use a list of futures so multiple in-flight requests across
      // different hosts can advance in parallel; the rate limiter governs
      // per-host budgets internally. The completion order drives the
      // progress stream — first done emits first.
      final controller = StreamController<NetworkScanProgress>();

      final inflight = <Future<void>>[];
      for (final row in scannable) {
        inflight.add(_scanOne(client, row).then((available) {
          progress = NetworkScanProgress(
            phase: NetworkScanPhase.scanning,
            total: progress.total,
            done: progress.done + 1,
            available: progress.available + (available ? 1 : 0),
            unreachable: progress.unreachable + (available ? 0 : 1),
          );
          controller.add(progress);
        }));
      }

      // Drain inflight + close the controller when all are done.
      Future<void>.microtask(() async {
        await Future.wait<void>(inflight);
        progress = NetworkScanProgress(
          phase: NetworkScanPhase.finished,
          total: progress.total,
          done: progress.done,
          available: progress.available,
          unreachable: progress.unreachable,
        );
        controller.add(progress);
        await controller.close();
      });

      await for (final p in controller.stream) {
        yield p;
      }

      stopwatch.stop();
      _lastReport = NetworkScanReport.fromProgress(
        progress,
        skippedNoUrl: skippedNoUrl,
        durationMs: stopwatch.elapsedMilliseconds,
      );
      _log.info(
        'Network scan complete: total=${_lastReport!.total}, '
        'available=${_lastReport!.available}, '
        'unreachable=${_lastReport!.unreachable}, '
        'skippedNoUrl=${_lastReport!.skippedNoUrl}, '
        'durationMs=${_lastReport!.durationMs}',
      );
    } catch (e, st) {
      _log.error('Network scan failed', error: e, stackTrace: st);
      rethrow;
    } finally {
      client.close();
    }
  }

  Future<List<MediaItem>> _safeFetch(MediaSourceType type) async {
    try {
      return await _repository.getAllBySourceType(type);
    } catch (e, st) {
      _log.error(
        'Failed to enumerate media for $type',
        error: e,
        stackTrace: st,
      );
      return const [];
    }
  }

  /// Scans a single row. Returns `true` if the row is reachable, `false`
  /// if it should be marked orphaned. Always updates `lastVerifiedAt`.
  /// Per-row exceptions are caught and logged; the scan continues.
  Future<bool> _scanOne(http.Client client, MediaItem row) async {
    final urlString = row.url!;
    final uri = Uri.parse(urlString);
    final host = uri.host;

    try {
      final headers = await _resolveAuthHeaders(row, uri);
      final reachable = await _rateLimiter.run<bool>(host, () async {
        // First try HEAD. Some servers return 405 / 501 for HEAD on
        // user-content endpoints; in that case fall back to a 1-byte
        // range GET, which is still polite.
        final headResp = await client.head(uri, headers: headers);
        if (_isHeadUnsupported(headResp.statusCode)) {
          final getResp = await client.get(
            uri,
            headers: {...headers, 'Range': 'bytes=0-0'},
          );
          return _isReachable(getResp.statusCode);
        }
        return _isReachable(headResp.statusCode);
      });

      await _persistResult(row, reachable: reachable);
      return reachable;
    } catch (e, st) {
      _log.warning(
        'Scan failed for media ${row.id} (${row.url}): $e',
        stackTrace: st,
      );
      try {
        await _persistResult(row, reachable: false);
      } catch (e2, st2) {
        _log.error(
          'Failed to persist orphan flag for ${row.id}',
          error: e2,
          stackTrace: st2,
        );
      }
      return false;
    }
  }

  Future<void> _persistResult(MediaItem row, {required bool reachable}) {
    final updated = row.copyWith(
      isOrphaned: !reachable,
      lastVerifiedAt: DateTime.now(),
    );
    return _repository.updateMedia(updated);
  }

  Future<Map<String, String>> _resolveAuthHeaders(
    MediaItem row,
    Uri uri,
  ) async {
    if (row.sourceType == MediaSourceType.networkUrl) {
      return _credentials.headersFor(uri.host);
    }
    // manifestEntry: auth comes from the parent subscription's
    // credentialsHostId, but the credentials service is keyed by hostname,
    // and the subscription is keyed by ID. Since the URL itself encodes the
    // host, asking the credentials service by host gives the right answer
    // either way (the user added one credential per host). If the
    // subscription has explicit auth and the URL points at a different
    // host, the credentials service falls back to {} which is correct
    // (no auth available).
    return _credentials.headersFor(uri.host);
  }

  bool _isHeadUnsupported(int code) =>
      code == 405 || code == 501 || code == 400;

  bool _isReachable(int code) => code >= 200 && code < 400;
}
```

The `_resolveAuthHeaders` shortcut (always asking the credentials service by hostname) is intentional: the spec's per-host credential model means a single host owns at most one credential set, so the manifest's parent `credentialsHostId` is just a back-reference to the same host record. If 3a's `NetworkCredentialsService` exposes a richer `headersForSubscription(subscriptionId)` API, the executing agent can swap to that — same outcome.

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/media/data/services/network_scan_service_test.dart
```

Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/data/services/network_scan_service.dart test/features/media/data/services/network_scan_service_test.dart
git add lib/features/media/data/services/network_scan_service.dart test/features/media/data/services/network_scan_service_test.dart test/features/media/data/services/network_scan_service_test.mocks.dart
git commit -m "feat(media): add NetworkScanService for user-triggered HTTP scan"
```

---

## Task 4: `CachedNetworkImageDiagnostics` Service

**Files:**
- Create: `lib/features/media/data/services/cached_network_image_diagnostics.dart`
- Test: `test/features/media/data/services/cached_network_image_diagnostics_test.dart`

`flutter_cache_manager`'s `DefaultCacheManager` provides `emptyCache()` for clearing but no built-in size accessor. We compute size by walking the cache directory directly (`<temporary-dir>/<DefaultCacheManager.key>`). The wrapper exists so the page widget can ask one object for both size and clear, and so we can mock it cleanly in widget tests.

The wrapper is testable end-to-end without touching the real `DefaultCacheManager` — the test injects a temp directory and a stub `clearCache` callback. Phase 3a is responsible for actually wiring `CachedNetworkImage` into the UI; 3c only needs to sum the bytes and call empty.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/data/services/cached_network_image_diagnostics_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/media/data/services/cached_network_image_diagnostics.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('cnid_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  test('cacheSize sums all files recursively under the cache directory',
      () async {
    File('${tempDir.path}/a.bin').writeAsBytesSync(List.filled(100, 0));
    final sub = Directory('${tempDir.path}/sub')..createSync();
    File('${sub.path}/b.bin').writeAsBytesSync(List.filled(50, 0));
    File('${sub.path}/c.bin').writeAsBytesSync(List.filled(25, 0));

    final diag = CachedNetworkImageDiagnostics(
      resolveCacheDirectory: () async => tempDir,
      clearCacheCallback: () async {},
    );
    final size = await diag.cacheSize();
    expect(size, 175);
  });

  test('cacheSize returns 0 when the directory does not exist', () async {
    final missing = Directory('${tempDir.path}/missing');
    final diag = CachedNetworkImageDiagnostics(
      resolveCacheDirectory: () async => missing,
      clearCacheCallback: () async {},
    );
    final size = await diag.cacheSize();
    expect(size, 0);
  });

  test('clearCache invokes the supplied callback', () async {
    var called = false;
    final diag = CachedNetworkImageDiagnostics(
      resolveCacheDirectory: () async => tempDir,
      clearCacheCallback: () async {
        called = true;
      },
    );
    await diag.clearCache();
    expect(called, true);
  });

  test('cacheSize swallows IO errors and returns 0 (best-effort metric)',
      () async {
    final diag = CachedNetworkImageDiagnostics(
      resolveCacheDirectory: () async => throw const FileSystemException('boom'),
      clearCacheCallback: () async {},
    );
    final size = await diag.cacheSize();
    expect(size, 0);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/media/data/services/cached_network_image_diagnostics_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement the service**

Create `lib/features/media/data/services/cached_network_image_diagnostics.dart`:

```dart
import 'dart:io';

import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:submersion/core/services/logger_service.dart';

/// Async function that resolves the on-disk cache directory used by
/// `cached_network_image`'s `DefaultCacheManager`. Tests can inject a temp
/// directory; production wires the real `path_provider` lookup.
typedef CacheDirectoryResolver = Future<Directory> Function();

/// Async callback that clears every cache entry. Tests inject a recording
/// noop; production calls `DefaultCacheManager().emptyCache()`.
typedef ClearCacheCallback = Future<void> Function();

/// Surfaces cache size + clear actions for the Settings → Network Sources →
/// Cache management card.
///
/// The disk cache lives at `<temp>/<DefaultCacheManager.key>`. We compute
/// size by walking the directory tree on demand because
/// `flutter_cache_manager` doesn't expose an aggregate size API.
///
/// Cache size is a best-effort metric — IO errors are swallowed and the
/// surface degrades to `0 bytes` rather than crashing the page.
class CachedNetworkImageDiagnostics {
  final CacheDirectoryResolver _resolveCacheDirectory;
  final ClearCacheCallback _clearCacheCallback;
  final _log = LoggerService.forClass(CachedNetworkImageDiagnostics);

  CachedNetworkImageDiagnostics({
    CacheDirectoryResolver? resolveCacheDirectory,
    ClearCacheCallback? clearCacheCallback,
  })  : _resolveCacheDirectory =
            resolveCacheDirectory ?? _defaultResolveCacheDirectory,
        _clearCacheCallback =
            clearCacheCallback ?? _defaultClearCacheCallback;

  /// Returns the total bytes used by the disk cache. Walks the directory.
  /// Returns 0 on any error.
  Future<int> cacheSize() async {
    try {
      final dir = await _resolveCacheDirectory();
      if (!await dir.exists()) return 0;
      var total = 0;
      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } on FileSystemException {
            // Skip transient unreadable entries; the user might be
            // browsing media right as we measure.
          }
        }
      }
      return total;
    } catch (e, st) {
      _log.warning('Cache size lookup failed: $e', stackTrace: st);
      return 0;
    }
  }

  /// Clears every cache entry. Surfaces errors via the logger; never throws.
  Future<void> clearCache() async {
    try {
      _log.info('Clearing cached_network_image disk cache');
      await _clearCacheCallback();
      _log.info('Cleared cached_network_image disk cache');
    } catch (e, st) {
      _log.error('Cache clear failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}

Future<Directory> _defaultResolveCacheDirectory() async {
  final base = await getTemporaryDirectory();
  return Directory(p.join(base.path, DefaultCacheManager.key));
}

Future<void> _defaultClearCacheCallback() => DefaultCacheManager().emptyCache();
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/media/data/services/cached_network_image_diagnostics_test.dart
```

Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/data/services/cached_network_image_diagnostics.dart test/features/media/data/services/cached_network_image_diagnostics_test.dart
git add lib/features/media/data/services/cached_network_image_diagnostics.dart test/features/media/data/services/cached_network_image_diagnostics_test.dart
git commit -m "feat(media): add CachedNetworkImageDiagnostics for size + clear"
```

---

## Task 5: `network_sources_providers` Riverpod Providers

**Files:**
- Create: `lib/features/media/presentation/providers/network_sources_providers.dart`
- Test: `test/features/media/presentation/providers/network_sources_providers_test.dart`

The providers connect the new page widgets to the services from Tasks 3-4 plus the 3a/3b infrastructure. All read providers (`savedHostsProvider`, `manifestSubscriptionsProvider`, `cacheSizeProvider`) are `FutureProvider`s so they can be invalidated after writes (delete a host, clear cache, etc.) to refresh.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/presentation/providers/network_sources_providers_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/services/cached_network_image_diagnostics.dart';
import 'package:submersion/features/media/data/services/host_rate_limiter.dart';
import 'package:submersion/features/media/data/services/network_scan_service.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';

class _StubDiag implements CachedNetworkImageDiagnostics {
  _StubDiag(this.size);
  final int size;
  @override
  Future<int> cacheSize() async => size;
  @override
  Future<void> clearCache() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} should not be called');
}

void main() {
  test('cacheSizeProvider delegates to the diagnostics service', () async {
    final container = ProviderContainer(
      overrides: [
        cachedNetworkImageDiagnosticsProvider.overrideWithValue(_StubDiag(2048)),
      ],
    );
    addTearDown(container.dispose);

    final size = await container.read(cacheSizeProvider.future);
    expect(size, 2048);
  });

  test('hostRateLimiterProvider returns a singleton with default settings', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final a = container.read(hostRateLimiterProvider);
    final b = container.read(hostRateLimiterProvider);
    expect(identical(a, b), true);
    expect(a, isA<HostRateLimiter>());
  });

  test('networkScanServiceProvider builds a service with the registered deps',
      () {
    // Smoke test: the provider compiles and reads without throwing. Live
    // wiring is exercised by the dialog widget test in Task 9.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      () => container.read(networkScanServiceProvider),
      isA<void Function()>(),
    );
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
flutter test test/features/media/presentation/providers/network_sources_providers_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement the providers**

Create `lib/features/media/presentation/providers/network_sources_providers.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/services/cached_network_image_diagnostics.dart';
import 'package:submersion/features/media/data/services/host_rate_limiter.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/network_scan_service.dart';
import 'package:submersion/features/media/data/services/subscription_poller.dart';
import 'package:submersion/features/media/domain/entities/manifest_subscription.dart';
import 'package:submersion/features/media/domain/entities/network_credential_host.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';

// Phase 3a / 3b providers expected to exist by the time 3c lands. If 3a /
// 3b chose different provider names, the executing agent updates the
// imports and reports the rename.
//
// 3a:
//   networkCredentialsServiceProvider:
//     Provider<NetworkCredentialsService>
// 3b:
//   manifestSubscriptionRepositoryProvider:
//     Provider<ManifestSubscriptionRepository>
//   subscriptionPollerProvider: Provider<SubscriptionPoller>

/// Singleton [HostRateLimiter] used by [NetworkScanService]. Configured for
/// the polite defaults specified in
/// `2026-04-25-media-source-extension-design.md` deliverable 8: max 4
/// concurrent requests per host, min 250 ms gap between same-host requests.
final hostRateLimiterProvider = Provider<HostRateLimiter>(
  (ref) => HostRateLimiter(
    maxConcurrentPerHost: 4,
    minSpacing: const Duration(milliseconds: 250),
  ),
);

/// Singleton [CachedNetworkImageDiagnostics]. Test code overrides this to
/// inject a stub directory + clear callback.
final cachedNetworkImageDiagnosticsProvider =
    Provider<CachedNetworkImageDiagnostics>(
  (ref) => CachedNetworkImageDiagnostics(),
);

/// Singleton [NetworkScanService] wired to all dependencies.
final networkScanServiceProvider = Provider<NetworkScanService>(
  (ref) => NetworkScanService(
    repository: ref.watch(mediaRepositoryProvider),
    credentials: ref.watch(networkCredentialsServiceProvider),
    subscriptions: ref.watch(manifestSubscriptionRepositoryProvider),
    rateLimiter: ref.watch(hostRateLimiterProvider),
  ),
);

/// Saved per-host credentials displayed in the Saved hosts card.
/// `ref.invalidate` after writes (delete / edit / test) to refresh.
final savedHostsProvider = FutureProvider<List<NetworkCredentialHost>>(
  (ref) => ref.watch(networkCredentialsServiceProvider).listHosts(),
);

/// Manifest subscriptions displayed in the Manifest subscriptions card.
final manifestSubscriptionsProvider =
    FutureProvider<List<ManifestSubscription>>(
  (ref) => ref.watch(manifestSubscriptionRepositoryProvider).listAll(),
);

/// Current cache size in bytes. Refresh by invalidating after Clear cache.
final cacheSizeProvider = FutureProvider<int>(
  (ref) => ref.watch(cachedNetworkImageDiagnosticsProvider).cacheSize(),
);
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/media/presentation/providers/network_sources_providers_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/presentation/providers/network_sources_providers.dart test/features/media/presentation/providers/network_sources_providers_test.dart
git add lib/features/media/presentation/providers/network_sources_providers.dart test/features/media/presentation/providers/network_sources_providers_test.dart
git commit -m "feat(media): add network sources Riverpod providers"
```

---

## Task 6: `CredentialsHostCard` Widget

**Files:**
- Create: `lib/features/media/presentation/widgets/credentials_host_card.dart`
- Test: `test/features/media/presentation/widgets/credentials_host_card_test.dart`

The Saved hosts card. Reads `savedHostsProvider`, renders one `ListTile` per host with hostname + auth type + display name + last-used timestamp. Each row has a `PopupMenuButton` (Test credentials / Edit / Delete). Empty state: a single ListTile that says "No saved credentials".

The card is a `ConsumerWidget` (no internal state of its own — the popup actions invalidate providers and snackbar feedback comes from the page).

- [ ] **Step 1: Write the failing test**

Create `test/features/media/presentation/widgets/credentials_host_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/domain/entities/network_credential_host.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';
import 'package:submersion/features/media/presentation/widgets/credentials_host_card.dart';

class _FakeCredentialsService implements NetworkCredentialsService {
  _FakeCredentialsService(this.hosts);
  final List<NetworkCredentialHost> hosts;
  @override
  Future<List<NetworkCredentialHost>> listHosts() async => hosts;
  @override
  Future<bool> testCredentials(NetworkCredentialHost host) async => true;
  @override
  Future<void> updateHost(NetworkCredentialHost host) async {}
  @override
  Future<void> deleteHost(String id) async {
    hosts.removeWhere((h) => h.id == id);
  }
  @override
  Future<Map<String, String>> headersFor(String hostname) async => {};
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

NetworkCredentialHost _h(String id, String hostname) => NetworkCredentialHost(
      id: id,
      hostname: hostname,
      authType: 'basic',
      displayName: 'My $hostname',
      addedAt: DateTime.utc(2024, 4, 1),
      lastUsedAt: DateTime.utc(2024, 4, 5),
    );

Widget _wrap(Widget child, NetworkCredentialsService creds) {
  return ProviderScope(
    overrides: [
      networkCredentialsServiceProvider.overrideWithValue(creds),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('renders one ListTile per saved host', (tester) async {
    final creds = _FakeCredentialsService([
      _h('1', 'photos.example.com'),
      _h('2', 'private.example.com'),
    ]);
    await tester.pumpWidget(_wrap(const CredentialsHostCard(), creds));
    await tester.pumpAndSettle();

    expect(find.text('photos.example.com'), findsOneWidget);
    expect(find.text('private.example.com'), findsOneWidget);
  });

  testWidgets('renders empty-state ListTile when no hosts saved',
      (tester) async {
    final creds = _FakeCredentialsService([]);
    await tester.pumpWidget(_wrap(const CredentialsHostCard(), creds));
    await tester.pumpAndSettle();

    expect(find.text('No saved credentials'), findsOneWidget);
  });

  testWidgets('Delete action removes the host and refreshes the list',
      (tester) async {
    final creds = _FakeCredentialsService([_h('1', 'photos.example.com')]);
    await tester.pumpWidget(_wrap(const CredentialsHostCard(), creds));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    // Confirm the dialog
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('photos.example.com'), findsNothing);
    expect(find.text('No saved credentials'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/presentation/widgets/credentials_host_card_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement `CredentialsHostCard`**

Create `lib/features/media/presentation/widgets/credentials_host_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/entities/network_credential_host.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';

/// Settings → Network Sources → Saved hosts card.
///
/// Lists `network_credential_hosts` rows. Per row:
/// - Hostname (title)
/// - Auth type + display name (subtitle)
/// - Last used timestamp (trailing line above the menu)
/// - Action menu (Test credentials, Edit, Delete)
class CredentialsHostCard extends ConsumerWidget {
  const CredentialsHostCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncHosts = ref.watch(savedHostsProvider);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child:
                // TODO(media): l10n
                Text('Saved hosts',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          asyncHosts.when(
            data: (hosts) => hosts.isEmpty
                ? const ListTile(
                    leading: Icon(Icons.lock_outline),
                    // TODO(media): l10n
                    title: Text('No saved credentials'),
                    subtitle: Text(
                        'Per-host credentials added during URL or manifest '
                        'imports show up here.'),
                  )
                : Column(
                    children: [
                      for (final host in hosts) ...[
                        _HostTile(host: host),
                        if (host != hosts.last) const Divider(height: 1),
                      ],
                    ],
                  ),
            loading: () => const ListTile(
              // TODO(media): l10n
              title: Text('Loading saved hosts…'),
            ),
            error: (e, _) => ListTile(
              leading: const Icon(Icons.error_outline),
              // TODO(media): l10n
              title: const Text('Could not load saved hosts'),
              subtitle: Text('$e'),
            ),
          ),
        ],
      ),
    );
  }
}

class _HostTile extends ConsumerWidget {
  const _HostTile({required this.host});
  final NetworkCredentialHost host;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.lock_outline),
      title: Text(host.hostname),
      subtitle: Text(_subtitle()),
      trailing: PopupMenuButton<_HostAction>(
        tooltip: 'More',
        onSelected: (action) => _handle(context, ref, action),
        itemBuilder: (_) => const [
          // TODO(media): l10n
          PopupMenuItem(value: _HostAction.test, child: Text('Test credentials')),
          PopupMenuItem(value: _HostAction.edit, child: Text('Edit')),
          PopupMenuItem(value: _HostAction.delete, child: Text('Delete')),
        ],
      ),
    );
  }

  String _subtitle() {
    final parts = <String>[];
    parts.add('Auth: ${host.authType}');
    if (host.displayName != null && host.displayName!.isNotEmpty) {
      parts.add(host.displayName!);
    }
    if (host.lastUsedAt != null) {
      parts.add('Last used ${_relative(host.lastUsedAt!)}');
    }
    return parts.join('  ·  ');
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    _HostAction action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(networkCredentialsServiceProvider);
    switch (action) {
      case _HostAction.test:
        try {
          final ok = await service.testCredentials(host);
          if (!context.mounted) return;
          messenger.showSnackBar(
            SnackBar(
              content: Text(ok
                  // TODO(media): l10n
                  ? 'Credentials OK for ${host.hostname}'
                  // TODO(media): l10n
                  : 'Credentials failed for ${host.hostname}'),
            ),
          );
        } catch (e) {
          if (!context.mounted) return;
          messenger.showSnackBar(
            // TODO(media): l10n
            SnackBar(content: Text('Test failed: $e')),
          );
        }
      case _HostAction.edit:
        await _showEditDialog(context, ref, host);
      case _HostAction.delete:
        final confirm = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            // TODO(media): l10n
            title: Text('Delete ${host.hostname}?'),
            content: const Text(
              'Removes the saved credentials. Items linked through this '
              'host will start showing "Sign in required" until you re-add '
              'them.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                // TODO(media): l10n
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                // TODO(media): l10n
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (confirm != true) return;
        try {
          await service.deleteHost(host.id);
          if (!context.mounted) return;
          ref.invalidate(savedHostsProvider);
          messenger.showSnackBar(
            // TODO(media): l10n
            SnackBar(content: Text('Deleted ${host.hostname}')),
          );
        } catch (e) {
          if (!context.mounted) return;
          messenger.showSnackBar(
            // TODO(media): l10n
            SnackBar(content: Text('Delete failed: $e')),
          );
        }
    }
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    NetworkCredentialHost host,
  ) async {
    final controller = TextEditingController(text: host.displayName ?? '');
    final updated = await showDialog<String?>(
      context: context,
      builder: (_) => AlertDialog(
        // TODO(media): l10n
        title: Text('Edit ${host.hostname}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Display name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            // TODO(media): l10n
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            // TODO(media): l10n
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (updated == null) return;
    if (!context.mounted) return;
    final service = ref.read(networkCredentialsServiceProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await service.updateHost(
        host.copyWith(displayName: updated.isEmpty ? null : updated),
      );
      if (!context.mounted) return;
      ref.invalidate(savedHostsProvider);
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        // TODO(media): l10n
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }
}

enum _HostAction { test, edit, delete }

String _relative(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  if (diff.inDays < 30) return '${diff.inDays}d ago';
  return '${(diff.inDays / 30).floor()}mo ago';
}
```

The widget assumes `NetworkCredentialHost.copyWith({String? displayName})` exists. If 3a's value type omits `copyWith`, the executing agent adds the same `_undefined`-sentinel `copyWith` we use elsewhere on entities; alternatively, the service exposes `updateDisplayName(id, name)` directly. Either works.

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/media/presentation/widgets/credentials_host_card_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/presentation/widgets/credentials_host_card.dart test/features/media/presentation/widgets/credentials_host_card_test.dart
git add lib/features/media/presentation/widgets/credentials_host_card.dart test/features/media/presentation/widgets/credentials_host_card_test.dart
git commit -m "feat(media): add CredentialsHostCard for saved-hosts management"
```

---

## Task 7: `ManifestSubscriptionCard` Widget

**Files:**
- Create: `lib/features/media/presentation/widgets/manifest_subscription_card.dart`
- Test: `test/features/media/presentation/widgets/manifest_subscription_card_test.dart`

The Manifest subscriptions card. Mirror of the credentials card but for `manifest_subscriptions` rows. Per row:
- Display name + format chip (atom/rss/json/csv)
- Last poll status + next poll time (subtitle)
- `isActive` toggle (trailing switch)
- Action menu (Poll now, Edit URL/credentials, Delete)

- [ ] **Step 1: Write the failing test**

Create `test/features/media/presentation/widgets/manifest_subscription_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/services/subscription_poller.dart';
import 'package:submersion/features/media/domain/entities/manifest_subscription.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';
import 'package:submersion/features/media/presentation/widgets/manifest_subscription_card.dart';

class _FakeRepo implements ManifestSubscriptionRepository {
  _FakeRepo(this.subs);
  final List<ManifestSubscription> subs;
  @override
  Future<List<ManifestSubscription>> listAll() async => subs;
  @override
  Future<void> updateSubscription(ManifestSubscription sub) async {
    final idx = subs.indexWhere((s) => s.id == sub.id);
    if (idx >= 0) subs[idx] = sub;
  }
  @override
  Future<void> deleteSubscription(String id) async {
    subs.removeWhere((s) => s.id == id);
  }
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _FakePoller implements SubscriptionPoller {
  int calls = 0;
  @override
  Future<PollResult> pollNow(String subscriptionId) async {
    calls++;
    return PollResult.success(added: 0, changed: 0, removed: 0);
  }
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

ManifestSubscription _sub(String id, {bool isActive = true}) =>
    ManifestSubscription(
      id: id,
      manifestUrl: 'https://example.com/feed-$id',
      format: 'atom',
      displayName: 'Sub $id',
      pollIntervalSeconds: 86400,
      isActive: isActive,
      credentialsHostId: null,
    );

Widget _wrap(
  Widget child, {
  required ManifestSubscriptionRepository repo,
  required SubscriptionPoller poller,
}) =>
    ProviderScope(
      overrides: [
        manifestSubscriptionRepositoryProvider.overrideWithValue(repo),
        subscriptionPollerProvider.overrideWithValue(poller),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );

void main() {
  testWidgets('renders one row per subscription', (tester) async {
    final repo = _FakeRepo([_sub('1'), _sub('2')]);
    final poller = _FakePoller();
    await tester.pumpWidget(_wrap(const ManifestSubscriptionCard(),
        repo: repo, poller: poller));
    await tester.pumpAndSettle();

    expect(find.text('Sub 1'), findsOneWidget);
    expect(find.text('Sub 2'), findsOneWidget);
  });

  testWidgets('Poll now triggers SubscriptionPoller.pollNow', (tester) async {
    final repo = _FakeRepo([_sub('1')]);
    final poller = _FakePoller();
    await tester.pumpWidget(_wrap(const ManifestSubscriptionCard(),
        repo: repo, poller: poller));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('More'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Poll now'));
    await tester.pumpAndSettle();

    expect(poller.calls, 1);
  });

  testWidgets('Toggling isActive persists via the repository', (tester) async {
    final repo = _FakeRepo([_sub('1', isActive: true)]);
    final poller = _FakePoller();
    await tester.pumpWidget(_wrap(const ManifestSubscriptionCard(),
        repo: repo, poller: poller));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(repo.subs.single.isActive, false);
  });

  testWidgets('renders empty-state row when no subscriptions',
      (tester) async {
    final repo = _FakeRepo([]);
    final poller = _FakePoller();
    await tester.pumpWidget(_wrap(const ManifestSubscriptionCard(),
        repo: repo, poller: poller));
    await tester.pumpAndSettle();

    expect(find.text('No manifest subscriptions'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/presentation/widgets/manifest_subscription_card_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement `ManifestSubscriptionCard`**

Create `lib/features/media/presentation/widgets/manifest_subscription_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/entities/manifest_subscription.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';

/// Settings → Network Sources → Manifest subscriptions card.
class ManifestSubscriptionCard extends ConsumerWidget {
  const ManifestSubscriptionCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSubs = ref.watch(manifestSubscriptionsProvider);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child:
                // TODO(media): l10n
                Text('Manifest subscriptions',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          asyncSubs.when(
            data: (subs) => subs.isEmpty
                ? const ListTile(
                    leading: Icon(Icons.feed_outlined),
                    // TODO(media): l10n
                    title: Text('No manifest subscriptions'),
                    subtitle: Text(
                      'Subscribe to an Atom/RSS, JSON, or CSV manifest from '
                      'the URL tab to keep your library in sync.',
                    ),
                  )
                : Column(
                    children: [
                      for (final sub in subs) ...[
                        _SubscriptionTile(sub: sub),
                        if (sub != subs.last) const Divider(height: 1),
                      ],
                    ],
                  ),
            loading: () => const ListTile(
              // TODO(media): l10n
              title: Text('Loading subscriptions…'),
            ),
            error: (e, _) => ListTile(
              leading: const Icon(Icons.error_outline),
              // TODO(media): l10n
              title: const Text('Could not load subscriptions'),
              subtitle: Text('$e'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionTile extends ConsumerWidget {
  const _SubscriptionTile({required this.sub});
  final ManifestSubscription sub;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: const Icon(Icons.feed_outlined),
      title: Row(
        children: [
          Expanded(child: Text(sub.displayName ?? sub.manifestUrl)),
          const SizedBox(width: 8),
          _FormatChip(format: sub.format),
        ],
      ),
      subtitle: Text(_subtitle()),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Switch(
            value: sub.isActive,
            onChanged: (v) => _setActive(context, ref, v),
          ),
          PopupMenuButton<_SubAction>(
            tooltip: 'More',
            onSelected: (a) => _handle(context, ref, a),
            itemBuilder: (_) => const [
              // TODO(media): l10n
              PopupMenuItem(value: _SubAction.poll, child: Text('Poll now')),
              PopupMenuItem(value: _SubAction.edit, child: Text('Edit')),
              PopupMenuItem(value: _SubAction.delete, child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }

  String _subtitle() {
    final pollHrs = (sub.pollIntervalSeconds / 3600).round();
    return 'Polls every ${pollHrs}h';
  }

  Future<void> _setActive(BuildContext context, WidgetRef ref, bool v) async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(manifestSubscriptionRepositoryProvider);
    try {
      await repo.updateSubscription(sub.copyWith(isActive: v));
      if (!context.mounted) return;
      ref.invalidate(manifestSubscriptionsProvider);
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        // TODO(media): l10n
        SnackBar(content: Text('Could not update: $e')),
      );
    }
  }

  Future<void> _handle(
    BuildContext context,
    WidgetRef ref,
    _SubAction action,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    switch (action) {
      case _SubAction.poll:
        final poller = ref.read(subscriptionPollerProvider);
        try {
          messenger.showSnackBar(
            // TODO(media): l10n
            SnackBar(content: Text('Polling ${sub.displayName ?? sub.manifestUrl}…')),
          );
          final result = await poller.pollNow(sub.id);
          if (!context.mounted) return;
          ref.invalidate(manifestSubscriptionsProvider);
          messenger.showSnackBar(
            SnackBar(
              // TODO(media): l10n
              content: Text(
                'Polled: +${result.added} new, '
                '${result.changed} changed, ${result.removed} removed',
              ),
            ),
          );
        } catch (e) {
          if (!context.mounted) return;
          messenger.showSnackBar(
            // TODO(media): l10n
            SnackBar(content: Text('Poll failed: $e')),
          );
        }
      case _SubAction.edit:
        await _showEditDialog(context, ref);
      case _SubAction.delete:
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            // TODO(media): l10n
            title: Text('Delete ${sub.displayName ?? sub.manifestUrl}?'),
            content: const Text(
              'Removes the subscription. Already-imported entries will '
              'remain (you can clean them up via Cleanup orphaned manifest '
              'entries from the orphan queue).',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                // TODO(media): l10n
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                // TODO(media): l10n
                child: const Text('Delete'),
              ),
            ],
          ),
        );
        if (ok != true) return;
        try {
          await ref
              .read(manifestSubscriptionRepositoryProvider)
              .deleteSubscription(sub.id);
          if (!context.mounted) return;
          ref.invalidate(manifestSubscriptionsProvider);
        } catch (e) {
          if (!context.mounted) return;
          messenger.showSnackBar(
            // TODO(media): l10n
            SnackBar(content: Text('Delete failed: $e')),
          );
        }
    }
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref) async {
    final urlController = TextEditingController(text: sub.manifestUrl);
    final nameController =
        TextEditingController(text: sub.displayName ?? '');
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        // TODO(media): l10n
        title: const Text('Edit subscription'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'Manifest URL'),
            ),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            // TODO(media): l10n
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            // TODO(media): l10n
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(manifestSubscriptionRepositoryProvider).updateSubscription(
            sub.copyWith(
              manifestUrl: urlController.text,
              displayName:
                  nameController.text.isEmpty ? null : nameController.text,
            ),
          );
      if (!context.mounted) return;
      ref.invalidate(manifestSubscriptionsProvider);
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        // TODO(media): l10n
        SnackBar(content: Text('Save failed: $e')),
      );
    }
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({required this.format});
  final String format;
  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(format.toUpperCase()),
      visualDensity: VisualDensity.compact,
      labelStyle: Theme.of(context).textTheme.labelSmall,
    );
  }
}

enum _SubAction { poll, edit, delete }
```

The widget assumes `ManifestSubscription.copyWith({String? manifestUrl, String? displayName, bool? isActive, ...})` exists — same convention used everywhere else. If 3b uses a different signature (e.g., a builder pattern), the executing agent adapts the calls.

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/media/presentation/widgets/manifest_subscription_card_test.dart
```

Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/presentation/widgets/manifest_subscription_card.dart test/features/media/presentation/widgets/manifest_subscription_card_test.dart
git add lib/features/media/presentation/widgets/manifest_subscription_card.dart test/features/media/presentation/widgets/manifest_subscription_card_test.dart
git commit -m "feat(media): add ManifestSubscriptionCard for subscription management"
```

---

## Task 8: `NetworkCacheCard` Widget

**Files:**
- Create: `lib/features/media/presentation/widgets/network_cache_card.dart`
- Test: `test/features/media/presentation/widgets/network_cache_card_test.dart`

The Cache management card. Reads `cacheSizeProvider`, displays the size in a human-friendly format, and offers a "Clear cache" action that calls `CachedNetworkImageDiagnostics.clearCache()` and invalidates the size provider.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/presentation/widgets/network_cache_card_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/services/cached_network_image_diagnostics.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';
import 'package:submersion/features/media/presentation/widgets/network_cache_card.dart';

class _StubDiag implements CachedNetworkImageDiagnostics {
  _StubDiag({required this.initialSize});
  int initialSize;
  bool cleared = false;
  @override
  Future<int> cacheSize() async => cleared ? 0 : initialSize;
  @override
  Future<void> clearCache() async {
    cleared = true;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

Widget _wrap(_StubDiag diag) => ProviderScope(
      overrides: [
        cachedNetworkImageDiagnosticsProvider.overrideWithValue(diag),
      ],
      child: const MaterialApp(home: Scaffold(body: NetworkCacheCard())),
    );

void main() {
  testWidgets('shows the human-formatted cache size', (tester) async {
    await tester.pumpWidget(_wrap(_StubDiag(initialSize: 1024 * 1024 * 5)));
    await tester.pumpAndSettle();
    expect(find.textContaining('5.0 MB'), findsOneWidget);
  });

  testWidgets('clear cache empties cache and refreshes', (tester) async {
    final diag = _StubDiag(initialSize: 4096);
    await tester.pumpWidget(_wrap(diag));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear cache'));
    await tester.pumpAndSettle();
    // Confirm
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(diag.cleared, true);
    expect(find.textContaining('0 B'), findsOneWidget);
  });

  testWidgets('renders shimmer/loading row while size lookup is running',
      (tester) async {
    final diag = _StubDiag(initialSize: 0);
    await tester.pumpWidget(_wrap(diag));
    expect(find.text('Calculating cache size…'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/presentation/widgets/network_cache_card_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement `NetworkCacheCard`**

Create `lib/features/media/presentation/widgets/network_cache_card.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';

/// Settings → Network Sources → Cache management card.
class NetworkCacheCard extends ConsumerWidget {
  const NetworkCacheCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSize = ref.watch(cacheSizeProvider);
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child:
                // TODO(media): l10n
                Text('Cache management',
                    style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          ListTile(
            leading: const Icon(Icons.sd_storage_outlined),
            // TODO(media): l10n
            title: const Text('Disk cache'),
            subtitle: asyncSize.when(
              // TODO(media): l10n
              loading: () => const Text('Calculating cache size…'),
              error: (e, _) => Text('Error: $e'),
              data: (bytes) => Text(_formatBytes(bytes)),
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            // TODO(media): l10n
            title: const Text('Clear cache'),
            onTap: () => _confirmAndClear(context, ref),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndClear(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        // TODO(media): l10n
        title: const Text('Clear network image cache?'),
        content: const Text(
          'Removes downloaded thumbnails and full-size network images. '
          'Linked media rows are kept; images will re-download on next view.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            // TODO(media): l10n
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            // TODO(media): l10n
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final diag = ref.read(cachedNetworkImageDiagnosticsProvider);
    try {
      await diag.clearCache();
      if (!context.mounted) return;
      ref.invalidate(cacheSizeProvider);
      messenger.showSnackBar(
        // TODO(media): l10n
        const SnackBar(content: Text('Cache cleared')),
      );
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        // TODO(media): l10n
        SnackBar(content: Text('Clear failed: $e')),
      );
    }
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/media/presentation/widgets/network_cache_card_test.dart
```

Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/presentation/widgets/network_cache_card.dart test/features/media/presentation/widgets/network_cache_card_test.dart
git add lib/features/media/presentation/widgets/network_cache_card.dart test/features/media/presentation/widgets/network_cache_card_test.dart
git commit -m "feat(media): add NetworkCacheCard for size + clear UX"
```

---

## Task 9: `NetworkScanDialog` Widget

**Files:**
- Create: `lib/features/media/presentation/widgets/network_scan_dialog.dart`
- Test: `test/features/media/presentation/widgets/network_scan_dialog_test.dart`

The progress dialog. Subscribes to `NetworkScanService.scanAll()` and rebuilds on each event. Shows:

- Progress bar (`fractionDone`) + counter (`done / total`)
- Live `available` and `unreachable` running totals
- A "Cancel" button (closes the dialog; the in-flight scan completes in the background)
- When `phase == finished`: a final "Done" button and the report summary line ("Scanned 12 items: 9 reachable, 2 unreachable, 1 skipped, 4.5s")

The dialog itself is a `StatefulWidget` that holds the `Stream` subscription so we don't restart the scan on rebuilds.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/presentation/widgets/network_scan_dialog_test.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/services/network_scan_service.dart';
import 'package:submersion/features/media/domain/value_objects/network_scan_progress.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';
import 'package:submersion/features/media/presentation/widgets/network_scan_dialog.dart';

class _FakeScan implements NetworkScanService {
  _FakeScan(this.events);
  final List<NetworkScanProgress> events;
  NetworkScanReport? _report;
  @override
  NetworkScanReport? get lastReport => _report;
  @override
  Stream<NetworkScanProgress> scanAll() async* {
    for (final e in events) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      if (e.phase == NetworkScanPhase.finished) {
        _report = NetworkScanReport.fromProgress(e,
            skippedNoUrl: 0, durationMs: 100);
      }
      yield e;
    }
  }
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

void main() {
  testWidgets('shows progress and final summary', (tester) async {
    final fake = _FakeScan([
      NetworkScanProgress.starting(total: 2),
      const NetworkScanProgress(
        phase: NetworkScanPhase.scanning,
        total: 2,
        done: 1,
        available: 1,
        unreachable: 0,
      ),
      const NetworkScanProgress(
        phase: NetworkScanPhase.finished,
        total: 2,
        done: 2,
        available: 1,
        unreachable: 1,
      ),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkScanServiceProvider.overrideWithValue(fake),
        ],
        child: const MaterialApp(
          home: Scaffold(body: _Launcher()),
        ),
      ),
    );

    await tester.tap(find.text('Open scan'));
    await tester.pumpAndSettle();

    expect(find.byType(NetworkScanDialog), findsOneWidget);
    // Drain stream events.
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.textContaining('2 / 2'), findsOneWidget);
    expect(find.textContaining('1 reachable'), findsOneWidget);
    expect(find.textContaining('1 unreachable'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('Cancel closes the dialog without waiting', (tester) async {
    final controller = StreamController<NetworkScanProgress>();
    final fake = _FakeScan([]); // ignored — we override scanAll below.

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkScanServiceProvider.overrideWithValue(fake),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(builder: (context) {
              return Center(
                child: ElevatedButton(
                  onPressed: () => showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (_) =>
                        NetworkScanDialog.test(stream: controller.stream),
                  ),
                  child: const Text('Open'),
                ),
              );
            }),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.byType(NetworkScanDialog), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(NetworkScanDialog), findsNothing);

    await controller.close();
  });
}

class _Launcher extends ConsumerWidget {
  const _Launcher();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: ElevatedButton(
        onPressed: () => showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => const NetworkScanDialog(),
        ),
        child: const Text('Open scan'),
      ),
    );
  }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/presentation/widgets/network_scan_dialog_test.dart
```

Expected: FAIL — file does not exist.

- [ ] **Step 3: Implement `NetworkScanDialog`**

Create `lib/features/media/presentation/widgets/network_scan_dialog.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/domain/value_objects/network_scan_progress.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';

/// The "Scan all network media" progress dialog.
///
/// Subscribes to [NetworkScanService.scanAll] and rebuilds on each progress
/// event. When the scan reaches [NetworkScanPhase.finished], the dialog
/// flips to a summary view with a Done button. Cancel is always available
/// — it closes the dialog; the in-flight scan continues to run in the
/// background and will complete normally (results are still persisted).
class NetworkScanDialog extends ConsumerStatefulWidget {
  const NetworkScanDialog({super.key}) : _injectedStream = null;

  /// Test-only constructor that takes a pre-built stream so tests don't
  /// need to wire the full Riverpod scope.
  @visibleForTesting
  const NetworkScanDialog.test({super.key, required Stream<NetworkScanProgress> stream})
      : _injectedStream = stream;

  final Stream<NetworkScanProgress>? _injectedStream;

  @override
  ConsumerState<NetworkScanDialog> createState() => _NetworkScanDialogState();
}

class _NetworkScanDialogState extends ConsumerState<NetworkScanDialog> {
  StreamSubscription<NetworkScanProgress>? _sub;
  NetworkScanProgress? _progress;
  Object? _error;

  @override
  void initState() {
    super.initState();
    final stream = widget._injectedStream ??
        ref.read(networkScanServiceProvider).scanAll();
    _sub = stream.listen(
      (p) => setState(() => _progress = p),
      onError: (Object e) => setState(() => _error = e),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _progress;
    final finished = p?.phase == NetworkScanPhase.finished;
    return AlertDialog(
      // TODO(media): l10n
      title: const Text('Scan all network media'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null)
              Text('Scan failed: $_error',
                  style: TextStyle(color: Theme.of(context).colorScheme.error))
            else if (p == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              LinearProgressIndicator(value: finished ? 1.0 : p.fractionDone),
              const SizedBox(height: 8),
              // TODO(media): l10n
              Text('${p.done} / ${p.total} items'),
              const SizedBox(height: 4),
              Text(
                // TODO(media): l10n
                '${p.available} reachable  ·  ${p.unreachable} unreachable',
              ),
            ],
            if (finished && _error == null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_summary(ref)),
              ),
          ],
        ),
      ),
      actions: [
        if (!finished)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            // TODO(media): l10n
            child: const Text('Cancel'),
          )
        else
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            // TODO(media): l10n
            child: const Text('Done'),
          ),
      ],
    );
  }

  String _summary(WidgetRef ref) {
    final report = ref.read(networkScanServiceProvider).lastReport;
    if (report == null) return '';
    final seconds = (report.durationMs / 1000).toStringAsFixed(1);
    final base =
        // TODO(media): l10n
        'Scanned ${report.total} items in ${seconds}s: '
        '${report.available} reachable, '
        '${report.unreachable} unreachable';
    if (report.skippedNoUrl == 0) return base;
    // TODO(media): l10n
    return '$base, ${report.skippedNoUrl} skipped (no URL)';
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/media/presentation/widgets/network_scan_dialog_test.dart
```

Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/presentation/widgets/network_scan_dialog.dart test/features/media/presentation/widgets/network_scan_dialog_test.dart
git add lib/features/media/presentation/widgets/network_scan_dialog.dart test/features/media/presentation/widgets/network_scan_dialog_test.dart
git commit -m "feat(media): add NetworkScanDialog with progress + summary"
```

---

## Task 10: `NetworkSourcesPage`

**Files:**
- Create: `lib/features/media/presentation/pages/network_sources_page.dart`
- Test: `test/features/media/presentation/pages/network_sources_page_test.dart`

The page that hosts the three cards plus the scan-all action. Mostly composition: a `Scaffold` with a `ListView` containing `CredentialsHostCard`, `ManifestSubscriptionCard`, `NetworkCacheCard`, and a final tonal button "Scan all network media" that opens `NetworkScanDialog`.

- [ ] **Step 1: Write the failing test**

Create `test/features/media/presentation/pages/network_sources_page_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/repositories/manifest_subscription_repository.dart';
import 'package:submersion/features/media/data/services/cached_network_image_diagnostics.dart';
import 'package:submersion/features/media/data/services/network_credentials_service.dart';
import 'package:submersion/features/media/data/services/network_scan_service.dart';
import 'package:submersion/features/media/domain/entities/manifest_subscription.dart';
import 'package:submersion/features/media/domain/entities/network_credential_host.dart';
import 'package:submersion/features/media/domain/value_objects/network_scan_progress.dart';
import 'package:submersion/features/media/presentation/pages/network_sources_page.dart';
import 'package:submersion/features/media/presentation/providers/network_sources_providers.dart';

class _Creds implements NetworkCredentialsService {
  @override
  Future<List<NetworkCredentialHost>> listHosts() async => [];
  @override
  Future<bool> testCredentials(NetworkCredentialHost host) async => true;
  @override
  Future<void> updateHost(NetworkCredentialHost host) async {}
  @override
  Future<void> deleteHost(String id) async {}
  @override
  Future<Map<String, String>> headersFor(String hostname) async => {};
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _Subs implements ManifestSubscriptionRepository {
  @override
  Future<List<ManifestSubscription>> listAll() async => [];
  @override
  Future<void> updateSubscription(ManifestSubscription sub) async {}
  @override
  Future<void> deleteSubscription(String id) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _Diag implements CachedNetworkImageDiagnostics {
  @override
  Future<int> cacheSize() async => 0;
  @override
  Future<void> clearCache() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

class _Scan implements NetworkScanService {
  @override
  NetworkScanReport? get lastReport => null;
  @override
  Stream<NetworkScanProgress> scanAll() async* {
    yield NetworkScanProgress.starting(total: 0);
    yield const NetworkScanProgress(
      phase: NetworkScanPhase.finished,
      total: 0,
      done: 0,
      available: 0,
      unreachable: 0,
    );
  }
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} not stubbed');
}

void main() {
  testWidgets('renders the three cards and the scan action', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          networkCredentialsServiceProvider.overrideWithValue(_Creds()),
          manifestSubscriptionRepositoryProvider.overrideWithValue(_Subs()),
          cachedNetworkImageDiagnosticsProvider.overrideWithValue(_Diag()),
          networkScanServiceProvider.overrideWithValue(_Scan()),
        ],
        child: const MaterialApp(home: NetworkSourcesPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved hosts'), findsOneWidget);
    expect(find.text('Manifest subscriptions'), findsOneWidget);
    expect(find.text('Cache management'), findsOneWidget);
    expect(find.text('Scan all network media'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
flutter test test/features/media/presentation/pages/network_sources_page_test.dart
```

Expected: FAIL.

- [ ] **Step 3: Implement `NetworkSourcesPage`**

Create `lib/features/media/presentation/pages/network_sources_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/media/presentation/widgets/credentials_host_card.dart';
import 'package:submersion/features/media/presentation/widgets/manifest_subscription_card.dart';
import 'package:submersion/features/media/presentation/widgets/network_cache_card.dart';
import 'package:submersion/features/media/presentation/widgets/network_scan_dialog.dart';

/// Settings → Data → Media Sources → Network Sources page.
///
/// Hosts:
///  - Saved hosts (per-host credentials)
///  - Manifest subscriptions
///  - Cache management
///  - Scan all network media (HTTP scan dialog launcher)
class NetworkSourcesPage extends ConsumerWidget {
  const NetworkSourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      // TODO(media): l10n
      appBar: AppBar(title: const Text('Network Sources')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const CredentialsHostCard(),
          const SizedBox(height: 16),
          const ManifestSubscriptionCard(),
          const SizedBox(height: 16),
          const NetworkCacheCard(),
          const SizedBox(height: 24),
          FilledButton.tonalIcon(
            icon: const Icon(Icons.travel_explore_outlined),
            // TODO(media): l10n
            label: const Text('Scan all network media'),
            onPressed: () => showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const NetworkScanDialog(),
            ),
          ),
          const SizedBox(height: 16),
          // TODO(media): l10n
          Text(
            'Re-checks every URL- or manifest-imported photo against its '
            'host. Marks unreachable items so they show "missing" in your '
            'library and can be cleaned up.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
flutter test test/features/media/presentation/pages/network_sources_page_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
dart format lib/features/media/presentation/pages/network_sources_page.dart test/features/media/presentation/pages/network_sources_page_test.dart
git add lib/features/media/presentation/pages/network_sources_page.dart test/features/media/presentation/pages/network_sources_page_test.dart
git commit -m "feat(media): add NetworkSourcesPage hosting the three cards + scan"
```

---

## Task 11: Wire `NetworkSourcesPage` Into the Router and `MediaSourcesPage`

**Files:**
- Modify: `lib/core/router/app_router.dart`
- Modify: `lib/features/media/presentation/pages/media_sources_page.dart`

Add a child route to the existing `media-sources` route, then append a `ListTile` to `MediaSourcesPage` that pushes it.

- [ ] **Step 1: Register the child route**

Open `lib/core/router/app_router.dart` and locate the existing `media-sources` GoRoute (line 858 — `path: 'media-sources'`). Convert it from a leaf to a parent by adding `routes:`:

Find:
```dart
              GoRoute(
                path: 'media-sources',
                name: 'mediaSources',
                builder: (context, state) => const MediaSourcesPage(),
              ),
```

Replace with:
```dart
              GoRoute(
                path: 'media-sources',
                name: 'mediaSources',
                builder: (context, state) => const MediaSourcesPage(),
                routes: [
                  GoRoute(
                    path: 'network-sources',
                    name: 'networkSources',
                    builder: (context, state) => const NetworkSourcesPage(),
                  ),
                ],
              ),
```

Add the new import at the top of `app_router.dart` (alphabetically among the other media imports):
```dart
import 'package:submersion/features/media/presentation/pages/network_sources_page.dart';
```

- [ ] **Step 2: Append the "Network sources" entry to `MediaSourcesPage`**

Open `lib/features/media/presentation/pages/media_sources_page.dart`. The current page renders three cards (Photo library, Diagnostics toggle, Local files). Append a fourth card containing a single `ListTile` that pushes the new page.

After the closing `Card(...)` of the existing Local files card and before the trailing `]` of the outer `ListView`'s `children`, insert:

```dart
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const Icon(Icons.cloud_outlined),
              // TODO(media): l10n
              title: const Text('Network sources'),
              // TODO(media): l10n
              subtitle: const Text(
                'Saved hosts, manifest subscriptions, cache, and scan.',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  context.push('/settings/media-sources/network-sources'),
            ),
          ),
```

Add the `go_router` import at the top of the file (alongside the existing imports):

```dart
import 'package:go_router/go_router.dart';
```

- [ ] **Step 3: Verify analyze + tests**

```bash
flutter analyze lib/core/router/app_router.dart lib/features/media/presentation/pages/media_sources_page.dart
flutter test test/features/media/
```

Expected: clean.

- [ ] **Step 4: Manual smoke check (router)**

```bash
flutter run -d macos
```

Navigate Settings → Data → Media Sources. Tap **Network sources** → confirm the new page appears with three cards and a Scan button. Tap back → confirm Media Sources reappears unchanged.

- [ ] **Step 5: Commit**

```bash
dart format lib/core/router/app_router.dart lib/features/media/presentation/pages/media_sources_page.dart
git add lib/core/router/app_router.dart lib/features/media/presentation/pages/media_sources_page.dart
git commit -m "feat(media): route Network Sources from the Media Sources page"
```

---

## Task 12: Final Smoke Test + Verification

- [ ] **Step 1: Full test suite**

```bash
flutter test
```

Expected: PASS.

- [ ] **Step 2: Analyzer**

```bash
flutter analyze
```

Expected: no issues.

- [ ] **Step 3: Format**

```bash
dart format --set-exit-if-changed lib/ test/
```

Expected: exit 0.

- [ ] **Step 4: Manual smoke test on macOS**

```bash
flutter build macos --debug
open build/macos/Build/Products/Debug/Submersion.app
```

(`open` to bypass the VS Code responsible-process trap noted in the dev notes.)

Walk through:
- Settings → Data → Media Sources → Network sources → confirm three cards + scan button render.
- (Pre-req: 3a / 3b have populated some `network_credential_hosts` and `manifest_subscriptions` rows.) Confirm rows appear in the right cards. If 3a / 3b haven't planted seed data yet, the cards correctly show empty-state text.
- Saved hosts → tap a row's overflow → "Test credentials" → snackbar shows OK or Failed.
- Saved hosts → "Edit" → change display name → Save → list refreshes with new name.
- Saved hosts → "Delete" → confirm → host disappears.
- Manifest subscriptions → toggle the active switch → confirm `isActive` flips in DB (verify by reopening or by 3b's polling status indicator).
- Manifest subscriptions → "Poll now" → snackbar shows polling progress.
- Cache management → confirm size renders. Tap "Clear cache" → confirm modal → confirm size goes to 0 B.
- Tap "Scan all network media" → confirm progress dialog runs + final summary appears.

- [ ] **Step 5: Manual smoke test on iOS Simulator**

```bash
flutter run -d "iPhone 15"
```

Same flow. The `path_provider` cache directory should resolve correctly in the simulator's tmp path.

- [ ] **Step 6: Final commit (if any fix-it changes)**

If smoke testing surfaced minor issues, fix them and commit as `chore(media): smoke-test fixes for Phase 3c`.

---

## Self-Review

**Spec coverage:**

| Spec deliverable (Phase 3) | Task |
|---|---|
| (3) Saved hosts card | Task 6 |
| (3) Manifest subscriptions card | Task 7 |
| (3) Cache management card (size + Clear cache) | Tasks 4, 8 |
| (3) "Scan all network media" action | Tasks 9, 10 |
| (3) Settings page entry — Network Sources page reachable from `MediaSourcesPage` | Task 11 |
| (8) HTTP scan: iterate `networkUrl` + `manifestEntry`, HEAD then range-GET, update `isOrphaned` + `lastVerifiedAt`, progress + summary, per-host rate limit | Tasks 1, 2, 3 |

**Placeholder check:** No "TBD" / "TODO: implement later" / "similar to Task N" items. Every task contains complete code.

**Type consistency:**
- `NetworkScanProgress` (Task 1) → consumed by `NetworkScanService` (Task 3) → consumed by `NetworkScanDialog` (Task 9). Same property names throughout (`phase`, `total`, `done`, `available`, `unreachable`).
- `NetworkScanReport` (Task 1) is what `NetworkScanService.lastReport` returns and what `NetworkScanDialog._summary` reads.
- `HostRateLimiter` constructor (Task 2) signature `({maxConcurrentPerHost, minSpacing})` matches the `hostRateLimiterProvider` registration (Task 5) and the test setup in Task 3.
- `CachedNetworkImageDiagnostics` constructor (Task 4) signature `({resolveCacheDirectory, clearCacheCallback})` matches the test stubs in Task 4 and Task 8.
- `NetworkScanService` constructor required-named-deps (`repository`, `credentials`, `subscriptions`, `rateLimiter`, optional `httpClientFactory`) match the provider in Task 5 and the tests in Task 3.

**Cross-slice clean-up:**
- 3c does not implement `NetworkCredentialsService` (3a's territory), `ManifestSubscriptionRepository` (3b's territory), `SubscriptionPoller` (3b's territory), `NetworkUrlResolver` (3a's territory), or any manifest parser (3b's territory). It only consumes them through their expected interfaces and Riverpod providers.
- 3c does not modify the `cached_network_image` integration itself (3a's territory) — it only computes the cache dir size and calls `emptyCache()`.
- 3c does not modify Phase 1 schema (already in place) and adds no new migration.

**Pubspec additions:** None expected. `package:http`, `cached_network_image`, and `path_provider` are added by 3a; `flutter_cache_manager` is transitive via `cached_network_image`. `fake_async` is transitive via `flutter_test`.

---

**Plan complete and saved to `docs/superpowers/plans/2026-04-28-media-source-extension-phase3c.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
