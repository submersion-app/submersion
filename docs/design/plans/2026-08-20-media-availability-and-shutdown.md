# Media Availability and Clean Shutdown Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop slow or not-yet-available media from freezing the Media section, and stop the macOS process from surviving its own window when the user quits from that section.

**Architecture:** Both symptoms come from one habit: unbounded media I/O on threads that must stay responsive. Three changes address it. (1) The two media concurrency gates gain a *slot budget*: a fetch that overruns it hands its permit to the next waiter and keeps running, so one stalled item can no longer block every other tile; a caller that overruns a larger *total budget* gives up with a new, recoverable `UnavailableKind.stillFetching` state instead of waiting forever. (2) The Apple `LocalMediaHandler` bookmark methods move off the platform main thread, which is both the UI thread and the thread that must answer `applicationShouldTerminate`. (3) The exit handler is made total: Dart always replies within a hard budget, and a background-queue watchdog in `AppDelegate` force-terminates if it does not.

**Tech Stack:** Flutter 3.x / Dart, Riverpod 3, Drift, Swift (macOS + iOS Runner), `flutter gen-l10n` across 11 locales.

**Spec:** This document. No separate spec exists; the Findings section below is the spec, and every claim in it was verified by reading the cited lines in this worktree.

## Global Constraints

- No em-dashes (U+2014) anywhere: code, comments, docs, ARB strings, commit messages. En-dashes (U+2013) and " - " used as prose punctuation are equally forbidden. Rewrite with commas, parentheses, colons, or semicolons. The characters are named by code point rather than shown, so that this line does not itself violate the rule it states.
- No emojis in code, comments, or documentation.
- `dart format .` must leave the tree unchanged before every commit.
- `flutter analyze` must report "No issues found!" over the whole project. Infos are fatal in CI.
- Every user-visible string goes in all 11 ARB files: `ar de en es fr he hu it nl pt zh`. Translate them; do not leave English placeholders in non-English files.
- Immutability: never mutate an existing object or list in place.
- TDD: the failing test comes first, and you must watch it fail before writing the implementation.
- Commit after each task.
- Baseline for this worktree: `flutter analyze` is clean as of branch creation. Any new issue is yours.

---

## Findings (the spec)

Verified read-outs. File paths are relative to the repo root.

**F1. The Media feature contains exactly one `.timeout(...)`**, at `lib/features/media/data/services/pdf_thumbnail_service.dart:126`. Every other fetch on every source type awaits with no deadline.

**F2. `MediaFetchGate` converts one slow item into a global stall.** `lib/features/media/data/resolvers/media_fetch_gate.dart:68-89`: `_run` holds its permit for the whole of `await fetch()`, and `_acquire` parks on a `Completer` that nothing ever completes with an error. Two instances exist: `MediaStoreResolver` with 4 permits, `LocalFileResolver` with 8 (`lib/features/media/data/resolvers/local_file_resolver.dart:32`). The gate is deliberately FIFO (`media_fetch_gate.dart:99-107`), so parked waiters belonging to disposed tiles are served first.

**F3. `GalleryThumbnailCache` has the same defect** at `lib/features/media/data/services/gallery_thumbnail_cache.dart:101-137`, with 4 permits. This is the PhotoKit path, so four iCloud assets still downloading from the cloud block every gallery thumbnail in the app. photo_manager sets `networkAccessAllowed = YES` unconditionally, and the Dart side simply awaits.

**F4. `readBookmarkBytes` reads the whole file synchronously on the platform main thread.** `macos/Runner/LocalMediaHandler.swift:269` and `ios/Runner/LocalMediaHandler.swift:224`: `let data = try Data(contentsOf: url)`. `FlutterMethodChannel` handlers run on the platform thread, which on macOS is the main thread. On a sandboxed build this is the normal path for any local file, and `LocalFileResolver.resolveThumbnail` falls through to `resolve()` for non-video items (`local_file_resolver.dart:347`). `resolveBookmark` (`:250` macOS) and `createBookmark` (`:181` macOS) also touch the volume on the main thread.

**F5. macOS defers termination to Dart and never re-checks.** `macos/Runner/AppDelegate.swift:90` returns `true` from `applicationShouldTerminateAfterLastWindowClosed`, so "alive by design" is ruled out. `applicationShouldTerminate` is not overridden, so the inherited `FlutterAppDelegate` implementation returns `NSTerminateLater` and asks Dart. There is no timer, no fallback, and no `exit()` anywhere in the Runner.

**F6. The Dart exit handler is not total.** `lib/app.dart:129-133`:
```dart
Future<AppExitResponse> _closeDatabases() async {
  await DatabaseService.instance.close();
  await LocalCacheDatabaseService.instance.close();
  return AppExitResponse.exit;
}
```
No `try`, no `.timeout()`, no fallback return. It is the only `onExitRequested` handler in the repo. If it throws or never completes, the reply is never sent and AppKit stays in `NSTerminateLater` forever: window gone, process alive. Its internal budgets (`lib/core/database/background_database_connection.dart:48-77`) are all `Future.timeout`, which cannot interrupt work already in progress and cannot fire at all if the isolate is blocked.

**F7. F4 and F6 compose.** The main thread blocked in `Data(contentsOf:)` against a hung mount is the same thread that must run `applicationShouldTerminate` and deliver `replyToApplicationShouldTerminate:`. That is why the zombie reproduces specifically in the Media section.

**F8. A store-backed video tile downloads the whole video.** `MediaStoreResolver.tryResolveRemote` deliberately returns `null` for a video thumbnail rather than download the original (`lib/features/media/data/resolvers/media_store_resolver.dart:54-60`, with an explicit comment). `MediaStoreSourceResolver.resolveThumbnail` then undoes that: `return await fn(item, thumbnail: true) ?? resolve(item);` (`lib/features/media/data/resolvers/media_store_source_resolver.dart:57`), and `resolve` calls `fn(item, thumbnail: false)`, which is `_fetchOriginal`. One full video download per grid tile, holding one of the 4 store permits.

### Product decisions already made (do not relitigate)

- **Slow media:** at the slot budget the fetch releases its permit and keeps running, so the tile keeps shimmering while every other tile proceeds. At the total budget the caller gives up and the tile shows a tappable "Still loading, tap to retry" placeholder. Nothing is abandoned merely for being slow.
- **Shutdown:** guard the Dart handler so it always replies within a hard budget, **and** add a native watchdog that force-terminates if Dart does not answer. The watchdog must not depend on the main run loop, because the case it exists for is a blocked main thread.

### Explicitly out of scope

Record these as follow-ups; do not build them here.
- Real download progress (`PMProgressHandler`, byte progress through the resolver stack).
- `LocalFileResolver.resolveThumbnail` pulling the full original across the channel per tile instead of a native downscale.
- Synchronous filesystem I/O in the EXIF/import path (`exif_extractor.dart:29-30`, `files_tab.dart:102`).
- `reverifyAll` sweeping the library on the UI isolate.
- The unclosed media-store `S3ApiClient` and the uncancelled `HostRateLimiter` wakeup timer (leaks, not hangs).
- The modal `barrierDismissible: false` spinner in `media_share_helper.dart:22-38`.

---

## File Structure

**Create:**
- `lib/core/app/app_exit.dart` - the total, budgeted exit close routine, extracted from `app.dart` so it is unit-testable without a widget tree.
- `test/core/app/app_exit_test.dart`
- `test/features/media/presentation/widgets/media_item_view_retry_test.dart`

**Modify:**
- `lib/features/media/domain/value_objects/media_source_data.dart` - add `UnavailableKind.stillFetching`.
- `lib/features/media/presentation/widgets/unavailable_media_placeholder.dart:48-78` - two exhaustive switches (the only two in `lib/`).
- `lib/l10n/arb/app_{ar,de,en,es,fr,he,hu,it,nl,pt,zh}.arb` - one new key.
- `lib/features/media/data/resolvers/media_fetch_gate.dart` - slot budget, detach cap, total budget.
- `lib/features/media/data/services/gallery_thumbnail_cache.dart:101-137` - slot budget.
- `lib/features/media/data/resolvers/media_store_source_resolver.dart:57` - video fall-through.
- `lib/features/media/presentation/widgets/media_item_view.dart` - retry on tap.
- `macos/Runner/LocalMediaHandler.swift` and `ios/Runner/LocalMediaHandler.swift` - background queue.
- `macos/Runner/AppDelegate.swift` - terminate watchdog.
- `lib/app.dart:129-133` - delegate to `app_exit.dart`.

**Existing tests that must keep passing:**
- `test/features/media/data/resolvers/media_fetch_gate_test.dart`
- `test/features/media/data/resolvers/local_file_resolver_test.dart`
- `test/features/media/data/services/gallery_thumbnail_cache_test.dart` (if present; check)

---

### Task 1: A recoverable "still loading" state

**Files:**
- Modify: `lib/features/media/domain/value_objects/media_source_data.dart:4-26`
- Modify: `lib/features/media/presentation/widgets/unavailable_media_placeholder.dart:48-78`
- Modify: `lib/l10n/arb/app_en.arb` plus the other 10 ARB files
- Test: `test/features/media/presentation/widgets/unavailable_media_placeholder_test.dart` (create if absent)

**Interfaces:**
- Consumes: nothing.
- Produces: `UnavailableKind.stillFetching`, and `AppLocalizations.media_unavailablePlaceholder_stillFetching` (a plain `String` getter, no parameters).

- [ ] **Step 1: Write the failing test**

Add to `test/features/media/presentation/widgets/unavailable_media_placeholder_test.dart`. If the file does not exist, create it with the same imports the neighbouring widget tests use (`flutter_test`, `flutter_localizations`, `package:submersion/l10n/arb/app_localizations.dart`).

```dart
testWidgets('stillFetching renders the retry-able loading message', (
  tester,
) async {
  await tester.pumpWidget(
    const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 140,
          height: 140,
          child: UnavailableMediaPlaceholder(
            data: UnavailableData(kind: UnavailableKind.stillFetching),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byIcon(Icons.hourglass_empty), findsOneWidget);
  expect(find.text('Still loading. Tap to retry.'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/presentation/widgets/unavailable_media_placeholder_test.dart`
Expected: FAIL to **compile**, with "The getter 'stillFetching' isn't defined for the type 'UnavailableKind'".

- [ ] **Step 3: Add the enum value**

In `lib/features/media/domain/value_objects/media_source_data.dart`, append to `UnavailableKind` (after `volumeOffline`):

```dart
  /// The fetch is still running and outlived the caller's budget.
  ///
  /// Distinct from every other kind because nothing is wrong: the bytes
  /// exist and are on their way. It exists so a slow source (a network
  /// share, a cold store object, an iCloud asset still coming down) can
  /// stop occupying a concurrency slot without the tile claiming the item
  /// is missing. Always recoverable by retrying, and the underlying fetch
  /// may well have finished by the time the user does.
  stillFetching,
```

- [ ] **Step 4: Add the two switch arms**

In `lib/features/media/presentation/widgets/unavailable_media_placeholder.dart`, add to `_iconFor` (after the `volumeOffline` arm):

```dart
    UnavailableKind.stillFetching => Icons.hourglass_empty,
```

and to `_messageFor` (after the `volumeOffline` arm):

```dart
      UnavailableKind.stillFetching =>
        l10n.media_unavailablePlaceholder_stillFetching,
```

- [ ] **Step 5: Add the localized string to all 11 ARB files**

In `lib/l10n/arb/app_en.arb`, next to `"media_unavailablePlaceholder_volumeOffline"` (around line 15012):

```json
  "media_unavailablePlaceholder_stillFetching": "Still loading. Tap to retry.",
```

Add the same key to each of the other 10 files, at the same position relative to `media_unavailablePlaceholder_volumeOffline`:

| File | Value |
| --- | --- |
| `app_ar.arb` | `"ما زال قيد التحميل. اضغط لإعادة المحاولة."` |
| `app_de.arb` | `"Wird noch geladen. Zum Wiederholen tippen."` |
| `app_es.arb` | `"Aún se está cargando. Toca para reintentar."` |
| `app_fr.arb` | `"Chargement en cours. Touchez pour réessayer."` |
| `app_he.arb` | `"עדיין נטען. הקש כדי לנסות שוב."` |
| `app_hu.arb` | `"Még töltődik. Koppintson az újrapróbálkozáshoz."` |
| `app_it.arb` | `"Ancora in caricamento. Tocca per riprovare."` |
| `app_nl.arb` | `"Nog aan het laden. Tik om opnieuw te proberen."` |
| `app_pt.arb` | `"Ainda a carregar. Toque para tentar novamente."` |
| `app_zh.arb` | `"仍在加载。点按重试。"` |

- [ ] **Step 6: Regenerate localizations**

Run: `flutter gen-l10n`
Expected: exit 0. `lib/l10n/arb/app_localizations*.dart` are checked in, so they will show as modified. Confirm with `git status` that all 11 generated files changed.

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/features/media/presentation/widgets/unavailable_media_placeholder_test.dart`
Expected: PASS.

- [ ] **Step 8: Verify nothing else switched exhaustively on the enum**

Run: `flutter analyze`
Expected: "No issues found!". A non-exhaustive switch elsewhere would surface here as an error. (Only the two arms above exist in `lib/`; this step proves it.)

- [ ] **Step 9: Format and commit**

```bash
dart format .
git add lib/features/media/domain/value_objects/media_source_data.dart lib/features/media/presentation/widgets/unavailable_media_placeholder.dart lib/l10n/arb test/features/media/presentation/widgets/unavailable_media_placeholder_test.dart
git commit -m "feat(media): add a recoverable still-loading placeholder state"
```

---

### Task 2: Bound MediaFetchGate so one stalled fetch cannot block the rest

**Files:**
- Modify: `lib/features/media/data/resolvers/media_fetch_gate.dart`
- Test: `test/features/media/data/resolvers/media_fetch_gate_test.dart`

**Interfaces:**
- Consumes: `UnavailableKind.stillFetching` from Task 1.
- Produces: `MediaFetchGate({int maxConcurrent, Duration slotBudget, Duration totalBudget, int? maxDetached})`, plus `int get detachedCount`. `run(String key, Future<MediaSourceData?> Function() fetch)` keeps its signature and now never returns a future that outlives `totalBudget`.

**Design, so the implementer does not have to infer it:**

Three numbers, each doing one job.

- `maxConcurrent` (unchanged defaults: 4 for the store, 8 for local files) is how many fetches hold a *slot*.
- `slotBudget` (default 5s) is how long a fetch may hold that slot. On expiry the slot passes to the next waiter and the fetch keeps running, now "detached". This is what stops head-of-line blocking.
- `totalBudget` (default 30s) is how long a *caller* waits. On expiry the caller gets `UnavailableData(kind: stillFetching)`. The fetch is not cancelled; Dart cannot cancel a `Future`.

Detaching without a ceiling would leak: on a dead mount the gate would start `maxConcurrent` new fetches every `slotBudget`, each parking a `dart:io` pool thread, which is the exact starvation this whole change exists to remove. So `maxDetached` (default `maxConcurrent * 3`) caps it. At the cap a fetch keeps its slot rather than detaching, which restores back-pressure. Maximum outstanding is therefore `maxConcurrent + maxDetached`, a fixed number.

`_inFlight` must map the key to the **raw** fetch future, not to the caller's bounded view of it. Otherwise a retry after `totalBudget` starts a second download of bytes already on the way. Keeping the raw future means a retry coalesces onto the fetch still in flight and gets a fresh `totalBudget` to wait out.

- [ ] **Step 1: Write the failing tests**

Append to `test/features/media/data/resolvers/media_fetch_gate_test.dart`. Match the file's existing imports and add `package:fake_async/fake_async.dart` if it is not already there.

```dart
group('slot budget', () {
  test('a fetch that overruns the slot budget frees it for the next waiter', () {
    fakeAsync((async) {
      final gate = MediaFetchGate(
        maxConcurrent: 1,
        slotBudget: const Duration(seconds: 5),
        totalBudget: const Duration(seconds: 30),
      );
      final slow = Completer<MediaSourceData?>();
      var secondStarted = false;

      gate.run('slow', () => slow.future);
      async.flushMicrotasks();
      gate.run('other', () async {
        secondStarted = true;
        return const BytesData(bytes: <int>[] as dynamic);
      });
      async.flushMicrotasks();

      expect(
        secondStarted,
        isFalse,
        reason: 'the only slot is held by the slow fetch',
      );

      async.elapse(const Duration(seconds: 5));
      async.flushMicrotasks();

      expect(
        secondStarted,
        isTrue,
        reason: 'the slot budget expired and handed the slot on',
      );
      expect(gate.detachedCount, 1);

      slow.complete(null);
      async.flushMicrotasks();
      expect(gate.detachedCount, 0);
    });
  });

  test('the caller gives up at the total budget with stillFetching', () {
    fakeAsync((async) {
      final gate = MediaFetchGate(
        maxConcurrent: 1,
        slotBudget: const Duration(seconds: 5),
        totalBudget: const Duration(seconds: 30),
      );
      final never = Completer<MediaSourceData?>();
      MediaSourceData? seen;
      gate.run('never', () => never.future).then((v) => seen = v);

      async.elapse(const Duration(seconds: 29));
      async.flushMicrotasks();
      expect(seen, isNull);

      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(seen, isA<UnavailableData>());
      expect(
        (seen! as UnavailableData).kind,
        UnavailableKind.stillFetching,
      );

      // Not cancelled: completing late must not throw into the void.
      never.complete(null);
      async.flushMicrotasks();
    });
  });

  test('detaching is capped so outstanding fetches cannot grow without bound', () {
    fakeAsync((async) {
      final gate = MediaFetchGate(
        maxConcurrent: 1,
        maxDetached: 2,
        slotBudget: const Duration(seconds: 5),
        totalBudget: const Duration(minutes: 5),
      );
      final held = <Completer<MediaSourceData?>>[];
      for (var i = 0; i < 4; i++) {
        final c = Completer<MediaSourceData?>();
        held.add(c);
        gate.run('k$i', () => c.future);
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
      }

      expect(
        gate.detachedCount,
        2,
        reason: 'at the cap a fetch keeps its slot instead of detaching',
      );
      expect(gate.runningCount, 1);

      for (final c in held) {
        c.complete(null);
      }
      async.flushMicrotasks();
    });
  });

  test('a retry after the total budget coalesces onto the live fetch', () {
    fakeAsync((async) {
      final gate = MediaFetchGate(
        maxConcurrent: 4,
        slotBudget: const Duration(seconds: 5),
        totalBudget: const Duration(seconds: 30),
      );
      final slow = Completer<MediaSourceData?>();
      var starts = 0;
      Future<MediaSourceData?> fetch() {
        starts++;
        return slow.future;
      }

      gate.run('k', fetch);
      async.elapse(const Duration(seconds: 31));
      async.flushMicrotasks();

      MediaSourceData? retried;
      gate.run('k', fetch).then((v) => retried = v);
      async.flushMicrotasks();
      expect(starts, 1, reason: 'the first fetch is still running');

      slow.complete(const NetworkData(url: Uri.parse('https://x/y') as dynamic));
      async.flushMicrotasks();
      expect(retried, isNotNull);
    });
  });
});
```

Note on the two `as dynamic` casts above: they are there only so the snippet compiles standalone. Replace them with whatever `MediaSourceData` constructor the existing tests in this file already use for a dummy value (check the top of the file first, it very likely has a helper), and delete the casts.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/media/data/resolvers/media_fetch_gate_test.dart`
Expected: FAIL to compile with "No named parameter with the name 'slotBudget'".

- [ ] **Step 3: Rewrite the gate**

Replace the body of `class MediaFetchGate` in `lib/features/media/data/resolvers/media_fetch_gate.dart` (keep the existing class doc comment, and append the new paragraph shown at the end of this step):

```dart
/// Default time a fetch may hold a slot before it is handed on (#1182 follow-up).
const Duration kMediaFetchSlotBudget = Duration(seconds: 5);

/// Default time a caller waits before showing the still-loading placeholder.
const Duration kMediaFetchTotalBudget = Duration(seconds: 30);

class MediaFetchGate {
  MediaFetchGate({
    this.maxConcurrent = 4,
    this.slotBudget = kMediaFetchSlotBudget,
    this.totalBudget = kMediaFetchTotalBudget,
    int? maxDetached,
  }) : assert(maxConcurrent > 0),
       assert(slotBudget <= totalBudget),
       maxDetached = maxDetached ?? maxConcurrent * 3;

  /// Ceiling on fetches holding a slot.
  final int maxConcurrent;

  /// Ceiling on fetches that overran [slotBudget] and are still running.
  ///
  /// Without this, a dead mount would start [maxConcurrent] fresh fetches
  /// every [slotBudget] forever, each parking a `dart:io` pool thread: the
  /// exact starvation this class exists to prevent. At the cap a fetch keeps
  /// its slot instead of detaching, which restores back-pressure. Outstanding
  /// work is therefore never more than [maxConcurrent] + [maxDetached].
  final int maxDetached;

  /// How long a fetch may hold a slot.
  final Duration slotBudget;

  /// How long a caller waits before settling for [UnavailableKind.stillFetching].
  final Duration totalBudget;

  /// Raw fetches in flight, keyed for coalescing.
  ///
  /// Deliberately the fetch itself rather than the caller's bounded view of
  /// it: a caller that gave up at [totalBudget] leaves the fetch running, and
  /// a retry must join that one rather than start a second download of bytes
  /// already on the way.
  final Map<String, Future<MediaSourceData?>> _inFlight =
      <String, Future<MediaSourceData?>>{};

  /// Callers parked waiting for a slot.
  final Queue<Completer<void>> _waiting = Queue<Completer<void>>();

  int _running = 0;
  int _detached = 0;

  /// Fetches holding a slot, for tests.
  int get runningCount => _running;

  /// Fetches that outlived [slotBudget] and are still running, for tests.
  int get detachedCount => _detached;

  /// Callers currently parked, for tests.
  int get waitingCount => _waiting.length;

  /// Runs [fetch] under the cap, sharing the result with any caller that asks
  /// for the same [key] while it is still running.
  ///
  /// Never waits longer than [totalBudget]; past that the caller is handed
  /// [UnavailableKind.stillFetching] and the fetch carries on without it.
  Future<MediaSourceData?> run(
    String key,
    Future<MediaSourceData?> Function() fetch,
  ) {
    final pending = _inFlight[key];
    if (pending != null) return _bounded(pending);
    final future = _withSlot(fetch);
    _inFlight[key] = future;
    // Cleared when the fetch really settles, not when a caller stops waiting.
    future
        .whenComplete(() {
          if (identical(_inFlight[key], future)) _inFlight.remove(key);
        })
        .ignore();
    return _bounded(future);
  }

  /// A caller's view of [future]: the fetch itself is never cancelled.
  Future<MediaSourceData?> _bounded(Future<MediaSourceData?> future) {
    return future.timeout(
      totalBudget,
      onTimeout: () =>
          const UnavailableData(kind: UnavailableKind.stillFetching),
    );
  }

  Future<MediaSourceData?> _withSlot(
    Future<MediaSourceData?> Function() fetch,
  ) async {
    await _acquire();
    var holdsSlot = true;
    var detached = false;

    void detach() {
      // At the cap, keep the slot: back-pressure beats fairness once the
      // detached pool is full.
      if (!holdsSlot || _detached >= maxDetached) return;
      holdsSlot = false;
      detached = true;
      _detached++;
      _release();
    }

    final timer = Timer(slotBudget, detach);
    try {
      return await fetch();
    } finally {
      timer.cancel();
      if (detached) {
        _detached--;
      } else if (holdsSlot) {
        holdsSlot = false;
        _release();
      }
    }
  }

  Future<void> _acquire() {
    if (_running < maxConcurrent) {
      _running++;
      return Future<void>.value();
    }
    final waiter = Completer<void>();
    _waiting.add(waiter);
    return waiter.future;
  }

  /// FIFO, unlike `GalleryThumbnailCache`'s LIFO.
  ///
  /// That class serves newest-first on the argument that older waiters belong
  /// to tiles already scrolled away. It does not hold here: [run] hands a
  /// parked future to any later caller asking for the same key, so a waiter
  /// can have live tiles behind it, and newest-first would leave them
  /// shimmering for the whole of a long fling. Fairness is worth more than
  /// recency when a slot is 30-60 tiles deep.
  void _release() {
    if (_waiting.isEmpty) {
      _running--;
      return;
    }
    // The slot passes straight to the next waiter: _running stays put because
    // one fetch ends exactly as another begins.
    _waiting.removeFirst().complete();
  }
}
```

Add these imports at the top of the file if they are not already present:

```dart
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
```

(`dart:async` and `dart:collection` are already imported.)

Append to the existing class doc comment, before `class MediaFetchGate`:

```dart
/// A third problem, added after #1182: **time**. A cap with no deadline turns
/// one unreachable item into a stalled gallery, because a permit held by a
/// fetch against a dead share is a permit no live tile can have. So a fetch
/// that outlives [slotBudget] hands its slot on and keeps running, and a
/// caller that outlives [totalBudget] settles for
/// [UnavailableKind.stillFetching] rather than waiting forever. Neither
/// cancels anything: Dart cannot cancel a `Future`, and the honest thing to
/// tell the user about a slow download is that it is slow, not that it failed.
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/media/data/resolvers/media_fetch_gate_test.dart`
Expected: PASS, including every pre-existing test in the file.

- [ ] **Step 5: Run the resolver tests that depend on the gate**

Run: `flutter test test/features/media/data/resolvers/`
Expected: all pass. `local_file_resolver_test.dart` constructs the gate; if any test asserted on unbounded parking, fix the test to pass an explicit long `totalBudget` rather than weakening the implementation.

- [ ] **Step 6: Format and commit**

```bash
dart format .
git add lib/features/media/data/resolvers/media_fetch_gate.dart test/features/media/data/resolvers/media_fetch_gate_test.dart
git commit -m "fix(media): give the fetch gate a slot budget so one stall cannot block the rest"
```

---

### Task 3: The same slot budget for the PhotoKit path

**Files:**
- Modify: `lib/features/media/data/services/gallery_thumbnail_cache.dart:28-32, 101-155`
- Test: `test/features/media/data/services/gallery_thumbnail_cache_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks (this class deals in `Uint8List?`, not `MediaSourceData`).
- Produces: `GalleryThumbnailCache({int maxBytes, int maxConcurrent, Duration slotBudget, int? maxDetached})` and `int get detachedCount`.

**Why this is separate from Task 2:** the class caches `Uint8List?` and has no `MediaSourceData` vocabulary, so it cannot return `stillFetching`. It gets the slot budget only. Its caller (`platform_gallery_resolver.dart:83`) sits inside a `MediaFetchGate`-governed resolve, so the total budget is already applied one level up. `null` here still means "no bytes right now" and is still not cached, which is the existing documented contract at `:65-68`.

- [ ] **Step 1: Write the failing test**

Append to `test/features/media/data/services/gallery_thumbnail_cache_test.dart` (create it if absent, mirroring the imports of the media_fetch_gate test):

```dart
test('an iCloud fetch that overruns the slot budget frees it', () {
  fakeAsync((async) {
    final cache = GalleryThumbnailCache(
      maxConcurrent: 1,
      slotBudget: const Duration(seconds: 5),
    );
    final stuck = Completer<Uint8List?>();
    var secondStarted = false;

    cache.getOrFetch('cloud', () => stuck.future);
    async.flushMicrotasks();
    cache.getOrFetch('local', () async {
      secondStarted = true;
      return Uint8List.fromList(<int>[1, 2, 3]);
    });
    async.flushMicrotasks();
    expect(secondStarted, isFalse);

    async.elapse(const Duration(seconds: 5));
    async.flushMicrotasks();
    expect(secondStarted, isTrue);
    expect(cache.detachedCount, 1);

    stuck.complete(null);
    async.flushMicrotasks();
    expect(cache.detachedCount, 0);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/services/gallery_thumbnail_cache_test.dart`
Expected: FAIL to compile with "No named parameter with the name 'slotBudget'".

- [ ] **Step 3: Implement**

Change the constructor at `lib/features/media/data/services/gallery_thumbnail_cache.dart:28-32` to:

```dart
  GalleryThumbnailCache({
    this.maxBytes = 32 * 1024 * 1024,
    this.maxConcurrent = 4,
    this.slotBudget = kGalleryThumbnailSlotBudget,
    int? maxDetached,
  }) : assert(maxBytes > 0),
       assert(maxConcurrent > 0),
       maxDetached = maxDetached ?? maxConcurrent * 3;
```

Above the class, add:

```dart
/// How long a PhotoKit fetch may hold a concurrency slot.
///
/// photo_manager asks PhotoKit with `networkAccessAllowed = YES`, so an
/// iCloud-only asset triggers a full cloud download behind a plain `await`.
/// Four of those used to hold every slot this cache has, which is a gallery
/// of permanent shimmer on a slow connection.
const Duration kGalleryThumbnailSlotBudget = Duration(seconds: 5);
```

Add the fields next to `maxConcurrent`:

```dart
  /// How long a fetch may hold a slot before handing it to the next waiter.
  final Duration slotBudget;

  /// Ceiling on fetches that overran [slotBudget] and are still running.
  final int maxDetached;
```

Add `int _detached = 0;` next to `int _running = 0;`, and a getter next to `byteCount`:

```dart
  /// Fetches that outlived [slotBudget] and are still running, for tests.
  int get detachedCount => _detached;
```

Replace `_run` (`:101-114`) with:

```dart
  Future<Uint8List?> _run(
    String key,
    Future<Uint8List?> Function() fetch,
  ) async {
    await _acquire();
    var holdsSlot = true;
    var detached = false;

    void detach() {
      if (!holdsSlot || _detached >= maxDetached) return;
      holdsSlot = false;
      detached = true;
      _detached++;
      _release();
    }

    final timer = Timer(slotBudget, detach);
    try {
      final bytes = await fetch();
      if (bytes != null) _store(key, bytes);
      return bytes;
    } finally {
      timer.cancel();
      if (detached) {
        _detached--;
      } else if (holdsSlot) {
        holdsSlot = false;
        _release();
      }
      _inFlight.remove(key);
    }
  }
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/media/data/services/gallery_thumbnail_cache_test.dart`
Expected: PASS, pre-existing tests included.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/data/services/gallery_thumbnail_cache.dart test/features/media/data/services/gallery_thumbnail_cache_test.dart
git commit -m "fix(media): free a gallery thumbnail slot when an iCloud fetch overruns"
```

---

### Task 4: Stop a store-backed video tile downloading the whole video

**Files:**
- Modify: `lib/features/media/data/resolvers/media_store_source_resolver.dart:48-58`
- Test: `test/features/media/data/resolvers/media_store_source_resolver_test.dart` (create if absent)

**Interfaces:**
- Consumes: nothing.
- Produces: no signature change.

**Why:** see finding F8. `tryResolveRemote` returns `null` for a video thumbnail on purpose, with a comment saying so; the `?? resolve(item)` on line 57 immediately re-asks with `thumbnail: false` and downloads the original. `MediaItemView` already knows how to draw the right thing when a video has no poster: it checks `widget.item.remoteThumbUploadedAt == null` and renders `_VideoThumbnailPlaceholder`. So the fix is to not fall through for a video that has no stamped remote thumb.

- [ ] **Step 1: Write the failing test**

```dart
test('a video thumbnail with no stamped thumb does not fetch the original', () async {
  final calls = <bool>[];
  final resolver = MediaStoreSourceResolver(
    remote: () => (MediaItem item, {required bool thumbnail}) async {
      calls.add(thumbnail);
      return null;
    },
  );

  final data = await resolver.resolveThumbnail(
    _videoItem(remoteThumbUploadedAt: null),
    target: const Size(140, 140),
  );

  expect(
    calls,
    [true],
    reason: 'asking again with thumbnail:false is a full video download',
  );
  expect(data, isA<UnavailableData>());
  expect((data as UnavailableData).kind, UnavailableKind.notFound);
});

test('a photo thumbnail still degrades to the original', () async {
  final calls = <bool>[];
  final resolver = MediaStoreSourceResolver(
    remote: () => (MediaItem item, {required bool thumbnail}) async {
      calls.add(thumbnail);
      return thumbnail ? null : const BytesData(bytes: _oneByte);
    },
  );

  final data = await resolver.resolveThumbnail(
    _photoItem(),
    target: const Size(140, 140),
  );

  expect(calls, [true, false]);
  expect(data, isA<BytesData>());
});
```

Build `_videoItem`, `_photoItem` and `_oneByte` with whatever `MediaItem` factory the neighbouring resolver tests already use. Check `test/features/media/data/resolvers/media_store_resolver_test.dart` first, it almost certainly has one; reuse it rather than writing a new one.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/media/data/resolvers/media_store_source_resolver_test.dart`
Expected: FAIL on the first test with `calls` being `[true, false]` instead of `[true]`.

- [ ] **Step 3: Implement**

Replace `resolveThumbnail`'s body (`:48-58`) with:

```dart
  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) async {
    final fn = remote();
    if (fn == null) {
      return const UnavailableData(kind: UnavailableKind.unauthenticated);
    }
    final thumb = await fn(item, thumbnail: true);
    if (thumb != null) return thumb;
    // A video's original and rendition are both video, so degrading to them
    // renders the same movie placeholder the caller already has and costs a
    // full download per grid tile. MediaStoreResolver.tryResolveRemote
    // declines for exactly this reason; falling through here would undo it.
    if (item.isVideo) {
      return const UnavailableData(kind: UnavailableKind.notFound);
    }
    return resolve(item);
  }
```

Confirm `MediaItem.isVideo` exists (it is used at `media_item_view.dart:311`); if the row's type lives elsewhere, use `item.mediaType == MediaType.video` and import `media_type.dart` as `media_store_resolver.dart` does.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/media/data/resolvers/`
Expected: PASS.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/data/resolvers/media_store_source_resolver.dart test/features/media/data/resolvers/media_store_source_resolver_test.dart
git commit -m "fix(media): stop a store video tile downloading the whole video"
```

---

### Task 5: Let the user retry a still-loading tile

**Files:**
- Modify: `lib/features/media/presentation/widgets/media_item_view.dart:326-345`
- Test: `test/features/media/presentation/widgets/media_item_view_retry_test.dart` (create)

**Interfaces:**
- Consumes: `UnavailableKind.stillFetching` (Task 1); the gate returning it (Task 2).
- Produces: no public signature change.

**Why:** without this the new state is a dead end. The placeholder's copy says "tap to retry", so tapping must actually re-resolve. Re-running `_resolve()` is cheap and correct: `MediaFetchGate.run` coalesces the retry onto the fetch still in flight (Task 2), so the tap joins the live download rather than starting a second one.

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('tapping a still-loading tile re-resolves it', (tester) async {
  var attempts = 0;
  final registry = _FakeRegistry(
    onResolve: (item) async {
      attempts++;
      return attempts == 1
          ? const UnavailableData(kind: UnavailableKind.stillFetching)
          : BytesData(bytes: _transparentPngBytes);
    },
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        mediaSourceResolverRegistryProvider.overrideWithValue(registry),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 140,
            height: 140,
            child: MediaItemView(item: _photoItem(), thumbnail: true),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  expect(find.byType(UnavailableMediaPlaceholder), findsOneWidget);
  expect(attempts, 1);

  await tester.tap(find.byType(UnavailableMediaPlaceholder));
  await tester.pumpAndSettle();

  expect(attempts, 2);
  expect(find.byType(UnavailableMediaPlaceholder), findsNothing);
});

testWidgets('tapping a genuinely missing tile does not re-resolve', (
  tester,
) async {
  var attempts = 0;
  final registry = _FakeRegistry(
    onResolve: (item) async {
      attempts++;
      return const UnavailableData(kind: UnavailableKind.notFound);
    },
  );
  // ... same pumpWidget as above ...
  await tester.tap(find.byType(UnavailableMediaPlaceholder));
  await tester.pumpAndSettle();
  expect(attempts, 1);
});
```

Build `_FakeRegistry` and `_photoItem` from the existing media widget-test harness. Read `test/features/media/presentation/widgets/media_item_view_test.dart` first and reuse its fakes verbatim; that file already overrides `mediaSourceResolverRegistryProvider`, so copy that setup rather than inventing one. Use its transparent-PNG helper for `_transparentPngBytes`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/media/presentation/widgets/media_item_view_retry_test.dart`
Expected: FAIL with `attempts` still 1 after the tap.

- [ ] **Step 3: Implement**

In `lib/features/media/presentation/widgets/media_item_view.dart`, add this method to `_MediaItemViewState`, next to `_resolve`:

```dart
  /// Re-runs resolution after the user taps a still-loading tile.
  ///
  /// Only [UnavailableKind.stillFetching] is retryable by tapping: it is the
  /// one kind that means "nothing is wrong, this is just slow", so a retry has
  /// a real chance of a different answer. Retrying a dead pointer or an
  /// offline volume on tap would be a placebo. The gate coalesces this onto
  /// the fetch still in flight, so the tap joins the live download rather than
  /// starting a second one.
  void _retry() => setState(() => _future = _resolve());
```

Then, in `build`, replace the final `UnavailableData()` switch arm:

```dart
          UnavailableData() => UnavailableMediaPlaceholder(data: data),
```

with:

```dart
          UnavailableData(kind: UnavailableKind.stillFetching) => GestureDetector(
            onTap: _retry,
            // The placeholder paints its own opaque background, but the
            // Column inside it does not fill the tile; without this the gaps
            // are not hit-testable and the tap lands on whatever is behind.
            behavior: HitTestBehavior.opaque,
            child: UnavailableMediaPlaceholder(data: data),
          ),
          UnavailableData() => UnavailableMediaPlaceholder(data: data),
```

Also update the `snapshot.hasError` branch at `:329-333` so a thrown resolution is not silently reported as `notFound` forever. Leave the kind alone (an exception really is a failure, not a slow fetch) but make it retryable is **not** required here; do not change it.

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/media/presentation/widgets/`
Expected: PASS, including the pre-existing `media_item_view_test.dart`.

- [ ] **Step 5: Format and commit**

```bash
dart format .
git add lib/features/media/presentation/widgets/media_item_view.dart test/features/media/presentation/widgets/media_item_view_retry_test.dart
git commit -m "feat(media): let the user retry a still-loading tile by tapping it"
```

---

### Task 6: Get the Apple bookmark methods off the platform main thread

**Files:**
- Modify: `macos/Runner/LocalMediaHandler.swift:172-273`
- Modify: `ios/Runner/LocalMediaHandler.swift:~150-228`
- Test: manual, plus `flutter analyze` and the full Dart suite for regressions. There is a `macos/RunnerTests` target but it is the stock stub, and these methods are private on a handler that needs a `FlutterBinaryMessenger`; adding an XCTest harness for them is more scaffolding than the change warrants. Verification is the manual repro in Task 9.

**Interfaces:**
- Consumes: nothing.
- Produces: no channel contract change. Same method names, same arguments, same result payloads and error codes. Only the thread the work runs on changes.

**Why:** finding F4 and F7. `FlutterMethodChannel` handlers run on the platform thread, which on macOS is the main thread. `Data(contentsOf:)` against an SMB mount or an evicted iCloud Drive file blocks it, which freezes the UI **and** blocks the thread that must answer `applicationShouldTerminate`.

**The rule to follow:** do the filesystem work on `DispatchQueue.global(qos: .userInitiated)`, and call `result(...)` and touch any handler state (`active`) back on `DispatchQueue.main`. `FlutterResult` must be invoked on the platform thread, and `active` is unsynchronised mutable state owned by the main thread.

- [ ] **Step 1: Rewrite `readBookmarkBytes` (macOS)**

In `macos/Runner/LocalMediaHandler.swift`, replace `readBookmarkBytes` (`:250-273`) with:

```swift
    /// Reads the bookmarked file's bytes.
    ///
    /// Runs off the platform thread. `Data(contentsOf:)` is a synchronous
    /// whole-file read, and on a sandboxed build this is the normal path for
    /// every local media item, including grid thumbnails. Against a network
    /// share or an evicted iCloud Drive file it blocks until the mount's own
    /// timeout, and on macOS the platform thread is the main thread: the same
    /// thread that paints frames and that must answer
    /// applicationShouldTerminate. Blocking it froze the Media section and
    /// left the process alive after its window closed.
    private func readBookmarkBytes(blob: Data, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            var stale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: blob,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
                guard url.startAccessingSecurityScopedResource() else {
                    DispatchQueue.main.async {
                        result(
                            FlutterError(
                                code: "ACCESS_DENIED",
                                message: "Security-scoped resource access denied",
                                details: nil
                            ))
                    }
                    return
                }
                defer { url.stopAccessingSecurityScopedResource() }
                let data = try Data(contentsOf: url)
                DispatchQueue.main.async {
                    result(FlutterStandardTypedData(bytes: data))
                }
            } catch {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "READ_FAILED",
                            message:
                                "Could not read bookmark bytes: \(error.localizedDescription)",
                            details: nil
                        ))
                }
            }
        }
    }
```

- [ ] **Step 2: Rewrite `resolveBookmark` (macOS)**

Same file, replace `resolveBookmark` (`:200-231`). Note that `active[ref] = url` must stay on the main thread:

```swift
    /// Resolves a bookmark and starts security-scoped access.
    ///
    /// Off the platform thread for the same reason as readBookmarkBytes:
    /// resolving a bookmark touches the volume it points at, so a dead mount
    /// blocks here too. The `active` map is main-thread-owned state and is
    /// mutated back on main.
    private func resolveBookmark(blob: Data, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            var stale = false
            do {
                let url = try URL(
                    resolvingBookmarkData: blob,
                    options: .withSecurityScope,
                    relativeTo: nil,
                    bookmarkDataIsStale: &stale
                )
                guard url.startAccessingSecurityScopedResource() else {
                    DispatchQueue.main.async {
                        result(
                            FlutterError(
                                code: "ACCESS_DENIED",
                                message: "Security-scoped resource access denied",
                                details: nil
                            ))
                    }
                    return
                }
                let ref = UUID().uuidString
                let isStale = stale
                DispatchQueue.main.async {
                    self.active[ref] = url
                    result([
                        "bookmarkRef": ref,
                        "filePath": url.path,
                        "stale": isStale,
                    ])
                }
            } catch {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "RESOLVE_FAILED",
                            message:
                                "Could not resolve bookmark: \(error.localizedDescription)",
                            details: nil
                        ))
                }
            }
        }
    }
```

- [ ] **Step 3: Rewrite `createBookmark` (macOS)**

Same file, replace `createBookmark` (`:181-198`):

```swift
    /// Mints a security-scoped bookmark. Off the platform thread: bookmarking
    /// a file on an unreachable share blocks in the same way a read does.
    private func createBookmark(filePath: String, result: @escaping FlutterResult) {
        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: filePath)
            do {
                let data = try url.bookmarkData(
                    options: .withSecurityScope,
                    includingResourceValuesForKeys: nil,
                    relativeTo: nil
                )
                DispatchQueue.main.async {
                    result(FlutterStandardTypedData(bytes: data))
                }
            } catch {
                DispatchQueue.main.async {
                    result(
                        FlutterError(
                            code: "BOOKMARK_FAILED",
                            message:
                                "Could not create bookmark: \(error.localizedDescription)",
                            details: nil
                        ))
                }
            }
        }
    }
```

- [ ] **Step 4: Move the bookmark resolution inside `generateVideoThumbnail` off the main thread (macOS)**

`QLThumbnailGenerator.generateBestRepresentation` is already asynchronous, but the `URL(resolvingBookmarkData:)` above it at `:141-148` is not. Wrap the whole body of `generateVideoThumbnail` from `var url: URL?` through the closing of the QuickLook call in `DispatchQueue.global(qos: .userInitiated).async { ... }`. The existing `DispatchQueue.main.async { result(...) }` calls inside the QuickLook completion already do the right thing and need no change. Add `[weak self]` only if the compiler requires it; this method does not touch `self`.

- [ ] **Step 5: Apply the same three changes to iOS**

`ios/Runner/LocalMediaHandler.swift` mirrors the macOS file with `options: []` instead of `.withSecurityScope`. Apply Steps 1 to 3 there, preserving each method's existing `options:` value exactly. iOS has no `generateVideoThumbnail`, so skip Step 4.

- [ ] **Step 6: Verify it builds**

Run: `flutter build macos --debug`
Expected: exit 0, no Swift warnings introduced.

If a Mac is unavailable to the executor, run `swift -frontend -parse macos/Runner/LocalMediaHandler.swift` as a syntax-only check and flag that the build was not run.

- [ ] **Step 7: Commit**

```bash
git add macos/Runner/LocalMediaHandler.swift ios/Runner/LocalMediaHandler.swift
git commit -m "fix(media): read bookmarked media off the platform main thread"
```

---

### Task 7: Make the Dart exit reply total

**Files:**
- Create: `lib/core/app/app_exit.dart`
- Create: `test/core/app/app_exit_test.dart`
- Modify: `lib/app.dart:120-133`

**Interfaces:**
- Consumes: nothing.
- Produces:
  ```dart
  const Duration kAppExitCloseBudget = Duration(seconds: 8);

  Future<AppExitResponse> closeDatabasesForExit({
    required Future<void> Function() closeMain,
    required Future<void> Function() closeCache,
    Duration budget = kAppExitCloseBudget,
    void Function(Object error, StackTrace stack)? onError,
  });
  ```
  It always completes with `AppExitResponse.exit`, never throws, and never takes longer than `budget`.

**Why:** finding F6. Extracted from `_SubmersionAppState` because a private method on a `ConsumerState` cannot be unit-tested without standing up a widget tree and a real `AppLifecycleListener`, and this routine's whole contract is "always replies, whatever happens", which is exactly what wants a fast unit test.

- [ ] **Step 1: Write the failing tests**

Create `test/core/app/app_exit_test.dart`:

```dart
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/app/app_exit.dart';

void main() {
  test('closes both databases in order and replies exit', () async {
    final calls = <String>[];
    final response = await closeDatabasesForExit(
      closeMain: () async => calls.add('main'),
      closeCache: () async => calls.add('cache'),
    );
    expect(calls, ['main', 'cache']);
    expect(response, AppExitResponse.exit);
  });

  test('still replies exit when the main database close throws', () async {
    final errors = <Object>[];
    final calls = <String>[];
    final response = await closeDatabasesForExit(
      closeMain: () async => throw StateError('boom'),
      closeCache: () async => calls.add('cache'),
      onError: (e, _) => errors.add(e),
    );
    expect(response, AppExitResponse.exit);
    expect(errors, hasLength(1));
    expect(
      calls,
      ['cache'],
      reason: 'a failed main close must not strand the cache database',
    );
  });

  test('still replies exit when a close never completes', () {
    fakeAsync((async) {
      AppExitResponse? response;
      final errors = <Object>[];
      closeDatabasesForExit(
        closeMain: () => Completer<void>().future,
        closeCache: () async {},
        budget: const Duration(seconds: 8),
        onError: (e, _) => errors.add(e),
      ).then((r) => response = r);

      async.elapse(const Duration(seconds: 7));
      async.flushMicrotasks();
      expect(response, isNull);

      async.elapse(const Duration(seconds: 2));
      async.flushMicrotasks();
      expect(response, AppExitResponse.exit);
      expect(errors.single, isA<TimeoutException>());
    });
  });

  test('the cache close gets the remainder of the budget, not a fresh one', () {
    fakeAsync((async) {
      AppExitResponse? response;
      closeDatabasesForExit(
        closeMain: () => Future<void>.delayed(const Duration(seconds: 6)),
        closeCache: () => Completer<void>().future,
        budget: const Duration(seconds: 8),
      ).then((r) => response = r);

      async.elapse(const Duration(seconds: 9));
      async.flushMicrotasks();
      expect(
        response,
        AppExitResponse.exit,
        reason: 'the total must be bounded by budget, not by 2 x budget',
      );
    });
  });
}
```

Add `import 'dart:async';` at the top for `Completer` and `TimeoutException`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/core/app/app_exit_test.dart`
Expected: FAIL to compile, "Target of URI doesn't exist: 'package:submersion/core/app/app_exit.dart'".

- [ ] **Step 3: Implement**

Create `lib/core/app/app_exit.dart`:

```dart
import 'dart:async';

import 'package:flutter/services.dart';

/// Hard ceiling on database closing during app exit.
///
/// Deliberately shorter than the sum of the close helpers' own internal
/// timeouts (roughly 13s worst case across the two databases). Those are
/// `Future.timeout`s, which cannot interrupt work already in progress and
/// cannot fire at all if the isolate is blocked, so they bound the happy path
/// and nothing else. This is the bound that holds regardless.
const Duration kAppExitCloseBudget = Duration(seconds: 8);

/// Closes both databases, then answers the platform's exit request.
///
/// **Always** completes with [AppExitResponse.exit], never throws, and never
/// takes longer than [budget].
///
/// That totality is the whole point. On macOS the inherited
/// `FlutterAppDelegate.applicationShouldTerminate` returns `NSTerminateLater`
/// and hands the decision to Dart; this handler is the only thing that can
/// send the reply, and nothing on the native side re-checks. An unguarded
/// throw or a close that never returns therefore left AppKit waiting forever:
/// the window was already dismissed, so the user saw the app quit while the
/// process stayed alive. Reported against the Media section, whose local-file
/// reads are the likeliest thing to be mid-flight at quit.
///
/// The two closes run sequentially and share one budget. Sequentially because
/// racing two shutdown sequences is not worth the second or two it saves; one
/// shared budget because a per-close budget would make the worst case twice
/// what the name promises. [closeCache] is attempted even when [closeMain]
/// fails, so one bad database cannot strand the other.
Future<AppExitResponse> closeDatabasesForExit({
  required Future<void> Function() closeMain,
  required Future<void> Function() closeCache,
  Duration budget = kAppExitCloseBudget,
  void Function(Object error, StackTrace stack)? onError,
}) async {
  final deadline = Stopwatch()..start();

  Duration remaining() {
    final left = budget - deadline.elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  Future<void> attempt(Future<void> Function() close) async {
    try {
      await close().timeout(remaining());
    } catch (error, stack) {
      onError?.call(error, stack);
    }
  }

  await attempt(closeMain);
  await attempt(closeCache);
  return AppExitResponse.exit;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/core/app/app_exit_test.dart`
Expected: PASS, all four.

- [ ] **Step 5: Wire it into the app**

In `lib/app.dart`, replace `_closeDatabases` (`:120-133`, doc comment included) with:

```dart
  /// Closes databases before the app exits.
  ///
  /// Uses `onExitRequested` (mapped from
  /// `NSApplicationDelegate.applicationShouldTerminate:` on macOS), which is
  /// async and fires before the Dart VM begins isolate/FFI teardown. Without
  /// it the Drift background isolate can outlive the FFI subsystem and crash
  /// in `sqlite3_close_v2` -> `functionDestroy` ("GetFfiCallbackMetadata
  /// called after shutdown"), which stalls the quit.
  ///
  /// The guarantees that make this safe to be the platform's only reply path
  /// live in [closeDatabasesForExit]; see its doc for why totality matters
  /// here.
  Future<AppExitResponse> _closeDatabases() => closeDatabasesForExit(
    closeMain: () => DatabaseService.instance.close(),
    closeCache: () => LocalCacheDatabaseService.instance.close(),
    onError: (error, stack) => LoggerService.forClass(SubmersionApp).warning(
      'Database close during app exit did not finish cleanly',
      error,
      stack,
    ),
  );
```

Add `import 'package:submersion/core/app/app_exit.dart';` to `lib/app.dart`. Check whether `LoggerService` is already imported there and whether `warning` takes `(String, Object, StackTrace)`; match the signature the rest of the file uses, or use `LoggerService.forClass(SubmersionApp).severe(...)` if that is the convention. Read a neighbouring call site before writing this.

- [ ] **Step 6: Verify**

Run: `flutter analyze`
Expected: "No issues found!".

Run: `flutter test test/core/ test/app_test.dart`
Expected: PASS. (Drop `test/app_test.dart` from the command if no such file exists.)

- [ ] **Step 7: Format and commit**

```bash
dart format .
git add lib/core/app/app_exit.dart lib/app.dart test/core/app/app_exit_test.dart
git commit -m "fix(app): always answer the platform exit request within a hard budget"
```

---

### Task 8: A native watchdog for a wedged main thread

**Files:**
- Modify: `macos/Runner/AppDelegate.swift`
- Test: manual (Task 9). A blocked main thread cannot be reproduced in XCTest without the very hang it guards against.

**Interfaces:**
- Consumes: nothing. Independent of Task 7 by design: Task 7 guards a Dart-level stall, this guards a stall Dart cannot answer at all.
- Produces: no Dart-visible surface.

**Why:** finding F5 plus the decision recorded above. Task 7 cannot help when the main isolate or the macOS main thread is genuinely blocked, because there is no thread left to run the timeout. The watchdog must therefore live off the main run loop.

**Budget:** 20 seconds, comfortably past Task 7's 8-second Dart budget plus the platform round-trip, so a healthy quit never reaches it.

- [ ] **Step 1: Add the watchdog state and override**

In `macos/Runner/AppDelegate.swift`, add next to the other private properties (after `displayChannel` at `:15`):

```swift
  /// Guards `terminateAnswered` across the watchdog queue and the main thread.
  private let terminateLock = NSLock()
  private var terminateAnswered = false
```

Add these methods before `applicationWillTerminate`:

```swift
  /// How long to wait for Dart's answer to the exit request before quitting
  /// anyway.
  ///
  /// Generous next to the 8s budget `closeDatabasesForExit` holds itself to,
  /// so a healthy quit never reaches this. It exists for the case that budget
  /// cannot cover: a blocked main isolate or a blocked main thread has no
  /// thread left to run a `Future.timeout` or a run-loop `Timer`.
  private static let terminateWatchdogInterval: TimeInterval = 20

  override func applicationShouldTerminate(
    _ sender: NSApplication
  ) -> NSApplication.TerminateReply {
    let reply = super.applicationShouldTerminate(sender)
    guard reply == .terminateLater else { return reply }
    armTerminateWatchdog()
    return reply
  }

  /// Force-quits if Dart never answers the exit request.
  ///
  /// FlutterAppDelegate returns `NSTerminateLater` and asks Dart over the
  /// `flutter/platform` channel. Nothing on the native side re-checks, so a
  /// Dart side that never replies leaves AppKit deferring forever: AppKit has
  /// already dismissed the window, so the user sees the app quit while the
  /// process lives on. That is the reported symptom, and the Media section's
  /// local-file reads are the likeliest thing to be mid-flight at quit.
  ///
  /// Runs on a background queue, not a `Timer` on the main run loop, because
  /// a wedged main thread is precisely the case this guards. For the same
  /// reason it cannot rely on `reply(toApplicationShouldTerminate:)` landing:
  /// that has to be called on the main thread, so it is attempted first and
  /// `exit(0)` follows if the process is still here a moment later. By then
  /// the databases have had their own budget and drift runs in WAL mode, so
  /// an abrupt exit is recoverable.
  private func armTerminateWatchdog() {
    let deadline: DispatchTime =
      .now() + AppDelegate.terminateWatchdogInterval
    DispatchQueue.global(qos: .utility).asyncAfter(deadline: deadline) {
      [weak self] in
      guard let self, !self.hasAnsweredTerminate() else { return }
      NSLog(
        "[AppDelegate] No exit-request answer after "
          + "\(AppDelegate.terminateWatchdogInterval)s; forcing termination"
      )
      DispatchQueue.main.async {
        NSApplication.shared.reply(toApplicationShouldTerminate: true)
      }
      DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 2) {
        NSLog("[AppDelegate] Exit still pending; calling exit(0)")
        exit(0)
      }
    }
  }

  private func hasAnsweredTerminate() -> Bool {
    terminateLock.lock()
    defer { terminateLock.unlock() }
    return terminateAnswered
  }
```

- [ ] **Step 2: Disarm the watchdog on a normal quit**

Replace `applicationWillTerminate` (`:94-97`) with:

```swift
  override func applicationWillTerminate(_ notification: Notification) {
    terminateLock.lock()
    terminateAnswered = true
    terminateLock.unlock()
    bookmarkHandler?.cleanup()
    backupBookmarkHandler?.releaseAll()
    // Released here as well as in its own deinit, which does not run on
    // terminate: these are security-scoped URLs the Media section opened.
    localMediaHandler?.releaseAll()
  }
```

Check `macos/Runner/LocalMediaHandler.swift:44-52` for the exact name of its cleanup method (`deinit` calls something; it may be `releaseAll()` or inline). If the cleanup is inlined in `deinit`, extract it into an internal `releaseAll()` and call that from both places. If no such cleanup exists, drop that line and the comment rather than inventing one.

- [ ] **Step 3: Verify it builds**

Run: `flutter build macos --debug`
Expected: exit 0.

- [ ] **Step 4: Commit**

```bash
git add macos/Runner/AppDelegate.swift macos/Runner/LocalMediaHandler.swift
git commit -m "fix(macos): force termination if Dart never answers the exit request"
```

---

### Task 9: Verification

**Files:** none modified unless a failure demands it.

- [ ] **Step 1: Format check**

Run: `dart format --set-exit-if-changed lib/ test/`
Expected: exit 0.

- [ ] **Step 2: Analyze the whole project**

Run: `flutter analyze`
Expected: "No issues found!". Infos are fatal.

- [ ] **Step 3: Run the full suite, twice**

Run: `flutter test 2>&1 | tail -40` is **forbidden**: a piped `flutter test` returns the pipe's exit status, so a five-failure run reads as exit 0. Instead:

```bash
flutter test > /tmp/suite-run-1.txt 2>&1; echo "exit=$?"
flutter test > /tmp/suite-run-2.txt 2>&1; echo "exit=$?"
tail -20 /tmp/suite-run-1.txt /tmp/suite-run-2.txt
```

Expected: exit 0 both times.

Run it twice because this repo has known pre-existing flakes (a recovery-code yo-yo split, a security-settings recovery dialog, a 50ms zip temp-dir delete, a media share-helper temp-bytes case). **Disjoint failure sets across the two runs disprove your diff; a single green run proves nothing.** Do not overlap the two runs, and do not run anything else concurrently: a sibling `pkill` will kill your run and it looks exactly like a lone failure (no summary plus exit 0).

- [ ] **Step 4: Manual repro, symptom one (media availability)**

On macOS, with a debug build:

1. `flutter run -d macos`.
2. Attach a media item on a network share, then make that share unreachable (disconnect Wi-Fi, or use a mounted share on a host you then power off). If no share is available, an iCloud Drive file whose local copy has been evicted works too.
3. Open the Media section and scroll the grid.

Expected: the grid scrolls smoothly. Unresolvable tiles shimmer, and after about 30 seconds they show "Still loading. Tap to retry."; tiles from reachable sources paint normally throughout. Before this change the whole window froze.

- [ ] **Step 5: Manual repro, symptom two (shutdown)**

1. Relaunch, open the Media section with the same unreachable source, and scroll so several fetches are in flight.
2. Close the window with the red button (not Cmd-Q, which takes a different AppKit path).
3. `ps aux | grep -i submersion` immediately, then again after 30 seconds.

Expected: the process is gone within a couple of seconds. If it survives, `Console.app` will carry the `[AppDelegate] No exit-request answer` line, which tells you the watchdog fired and that a Dart-side stall remains to be found: return to Phase 1 rather than raising the budget.

- [ ] **Step 6: Commit anything the verification forced**

```bash
dart format .
git add -A
git commit -m "test: verification fixes for media availability and shutdown"
```

Skip this step if nothing changed.

---

## Self-Review

**Spec coverage.** F1 and F2 are Task 2. F3 is Task 3. F4 is Task 6. F5 is Task 8. F6 is Task 7. F7 is Tasks 6 plus 8 together. F8 is Task 4. The "slow media UX" decision is Tasks 1, 2, and 5. The "shutdown" decision is Tasks 7 and 8. Out-of-scope items have no task, deliberately, and are listed as such.

**Placeholder scan.** Every code step carries real code. Four steps deliberately tell the implementer to read an existing file before writing (the `MediaItem` test factory in Task 4, the widget-test fakes in Task 5, the `LocalMediaHandler` cleanup name in Task 8, the `LoggerService` call shape in Task 7). Those are named files with named symbols to copy, not "figure it out": inventing a second `MediaItem` factory or a second fake registry when the suite already has one is the failure mode being avoided.

**Type consistency.** `UnavailableKind.stillFetching` is defined in Task 1 and used in Tasks 2 and 5. `slotBudget` / `totalBudget` / `maxDetached` / `detachedCount` are defined in Task 2 and reused with identical names in Task 3 (minus `totalBudget`, which Task 3's `Uint8List?` vocabulary cannot express, stated explicitly there). `closeDatabasesForExit` and `kAppExitCloseBudget` are defined in Task 7 and referenced in Task 8's doc comment only. `MediaFetchGate.run`'s signature is unchanged, so no caller needs updating.
