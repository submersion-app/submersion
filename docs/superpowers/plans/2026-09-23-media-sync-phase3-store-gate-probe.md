# Media Sync Slice 11: Store Gate Probe

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A foreign row whose upload stamps were lost or have not arrived yet is still shown from the media store this device is attached to (spec 7.2, issue #2129). Turns harness scenario S4 green.

**Architecture:** The tile gate (`storeConfirmed`) consults the store only for rows whose synced stamps say it holds bytes. For a row whose native verdict is `fromOtherDevice` and which carries a `contentHash`, the tile now asks the attached store directly: `MediaStoreResolver.tryResolveProbed` HEADs the tier the tile needs, caches each answer per store key (the tier's full key, which for an original carries its extension) for the life of the resolver (found and not-found alike; a failed HEAD is not cached), and serves through the existing fetch path by treating the probed tiers as stamped. Nothing is written: the stamps stay the uploading device's facts.

**Tech Stack:** Flutter, Dart, the media store adapters behind `MediaObjectStore`, the two-device media harness.

**Spec:** `docs/superpowers/specs/2026-09-18-media-sync-program-design.md`, section 7.2.

## Global Constraints

- No em-dashes (U+2014), and no en-dashes or spaced hyphens as prose punctuation, anywhere.
- No mention of Claude, Claude Code or Anthropic in anything written to the repository or GitHub.
- `dart format .` before every commit; `flutter analyze` must report no issues.
- PR body: `Closes #2129` and `Part of #2090`.

## Decisions (owner, 2026-09-23)

- **Show only.** A successful probe serves the tile and writes nothing. Stamps are the uploading device's facts, and a grid render must not publish sync writes.

## Facts the design rests on

- `MediaTileResolver.resolve` returns the native placeholder whenever `storeConfirmed` is false, so an unstamped row never reaches the store.
- `MediaStoreResolver.tryResolveRemote` also gates each tier on its stamp (`remoteThumbUploadedAt`, `remoteUploadedAt`, `remoteCompressedUploadedAt`); the stamps are only gates there, never values.
- Store keys: `StoreKeys.thumbKey(hash)`, `StoreKeys.objectKey(hash, extension: StoreKeys.extensionFor(item.originalFilename))`, `StoreKeys.renditionKey(hash, ext: video ? 'mp4' : 'jpg')`. `MediaObjectStore.head(key)` answers null when absent.
- `MediaFetchGate.run(key, fn)` caps concurrency and coalesces duplicate keys; the resolver already routes fetches through it.
- Only `fromOtherDevice` is probed: `notFound` is the linking device's own verdict that the bytes are gone, and `accessDenied` is a permission problem, not a missing stamp.

## File Structure

| File | Change |
| --- | --- |
| `lib/features/media/data/resolvers/media_store_resolver.dart` | `tryResolveProbed`, per-hash per-tier probe cache |
| `lib/features/media/data/services/media_tile_resolver.dart` | probe branch for unstamped `fromOtherDevice` rows |
| `test/features/media/data/resolvers/media_store_resolver_probe_test.dart` | create |
| `test/features/media/data/services/media_tile_resolver_test.dart` | probe branch cases |
| `test/features/media/two_device/store_scenarios_test.dart` | unskip S4 |
| spec 7.2 | record the decision |

---

### Task 1: The store resolver can serve a row on a probe

**Interfaces:**
- Produces: `Future<MediaSourceData?> MediaStoreResolver.tryResolveProbed(MediaItem item, {required bool thumbnail})`.

- [ ] **Step 1: Failing tests** in `media_store_resolver_probe_test.dart`, against a real `MediaStoreResolver` over an `InMemoryMediaObjectStore` subclass that counts `head` calls, with a `MediaCacheStore` over an in-memory `LocalCacheDatabase` and a temp root:
  - an unstamped photo whose thumb object exists is served as a thumbnail;
  - with no thumb object but the original present, a thumbnail request is served from the original;
  - a full view HEADs and serves the original;
  - a second request for an absent object does not HEAD again (negative cache);
  - a HEAD that throws is not cached: the next request HEADs again;
  - a video thumbnail never falls back to the original (no original HEAD);
  - a row with no `contentHash` returns null without a HEAD.
- [ ] **Step 2:** run, expect compile failure.
- [ ] **Step 3: Implement.**

```dart
  /// Probe answers per store key for the life of this resolver (superseded
  /// in review; see As executed):
  /// true found, false absent. A HEAD that failed is not recorded.
  final Map<String, bool> _probes = {};

  /// Serves [item] from the store when its synced stamps are missing but
  /// the store may hold it anyway (media sync program spec 7.2): a stamp
  /// that is late, or lost. Each tier the request needs is HEADed once and
  /// remembered, found or not, so a grid of such rows costs one HEAD per row
  /// and tier per session. Serving goes through [tryResolveRemote], with the
  /// found tiers treated as stamped. Nothing is written.
  Future<MediaSourceData?> tryResolveProbed(
    MediaItem item, {
    required bool thumbnail,
  }) async {
    final hash = item.contentHash;
    if (hash == null) return null;
    final isVideo = item.mediaType == MediaType.video;
    final thumbFound = thumbnail && await _probe(hash, 'thumb', StoreKeys.thumbKey(hash));
    // A video's original is a video: a thumbnail cannot degrade to it.
    final originalFound =
        (!thumbnail || (!thumbFound && !isVideo)) &&
        await _probe(hash, 'original', StoreKeys.objectKey(hash, extension: StoreKeys.extensionFor(item.originalFilename)));
    if (!thumbFound && !originalFound) return null;
    final probedAt = DateTime.fromMillisecondsSinceEpoch(0);
    return tryResolveRemote(
      item.copyWith(
        remoteThumbUploadedAt: thumbFound ? probedAt : null,
        remoteUploadedAt: originalFound ? probedAt : null,
        remoteCompressedUploadedAt: null,
      ),
      thumbnail: thumbnail,
    );
  }

  Future<bool> _probe(String hash, String tier, String key) async {
    final cacheKey = '$hash#$tier';
    final known = _probes[cacheKey];
    if (known != null) return known;
    try {
      final found = await _gate.run('$cacheKey#probe', () async => await _store.head(key) != null);
      _probes[cacheKey] = found;
      return found;
    } on Object catch (e) {
      _log.debug('Store probe for $cacheKey failed; not remembered', error: e);
      return false;
    }
  }
```

The executor adapts `_gate.run`'s exact signature (read `media_fetch_gate.dart`): if its result type is fixed to `MediaSourceData?`, HEAD directly instead of through the gate and keep the coalescing with an in-flight `Map<String, Future<bool>>`.

- [ ] **Step 4:** run, expect PASS. **Step 5:** commit `feat(media): the store resolver can serve a row its stamps have not reached`.

### Task 2: The tile probes unstamped foreign rows (S4)

- [ ] **Step 1: Failing tests** in `media_tile_resolver_test.dart` (extend `_ScriptedRemote` with a scripted `tryResolveProbed` and a `probes` counter):
  - an unstamped row whose native verdict is `fromOtherDevice` is served by the probe, `storeFallbackUsed` true, `nativeFailure` `fromOtherDevice`;
  - a `notFound` native verdict is never probed;
  - a row with no `contentHash` is never probed and the remote is never looked up;
  - no remote (not attached) keeps the native placeholder;
  - a probe that throws keeps the native placeholder;
  - a stamped row still takes the confirmed path, not the probe.

  The native verdict comes from `FakeLocalFileResolver`; read it for how to script `fromOtherDevice`.
- [ ] **Step 2:** run, expect FAIL.
- [ ] **Step 3: Implement** in `MediaTileResolver.resolve`, replacing the early return for an unconfirmed row:

```dart
    if (!storeConfirmed(item, thumbnail: thumbnail)) {
      // A foreign row whose stamps have not reached this device (late, or
      // lost) may still be in the store this device is attached to (spec
      // 7.2). Only fromOtherDevice: notFound is the linking device's own
      // verdict that the bytes are gone.
      if (nativeFailure == UnavailableKind.fromOtherDevice &&
          item.contentHash != null) {
        return _probe(item, native, thumbnail: thumbnail);
      }
      return TileResolution(data: native, nativeFailure: nativeFailure);
    }
```

with `_probe` mirroring the confirmed branch: look up the remote (null keeps native), `tryResolveProbed`, served returns `storeFallbackUsed: true` and the same `documentRenderable` rule, any throw keeps native. Update the class doc and the `RemoteResolverLookup` doc (the runtime is now also built for unstamped foreign rows with a content hash).
- [ ] **Step 4:** remove the `skip:` from S4 in `store_scenarios_test.dart`; run `flutter test test/features/media test/features/media_store`, expect PASS.
- [ ] **Step 5:** commit `feat(media): a foreign row with lost stamps is served from the attached store`.

### Task 3: Spec and verification

- [ ] Add to spec 7.2: "Read-only (decided 2026-09-23): a successful probe serves the tile and writes nothing; the stamps stay the uploading device's facts. Only `fromOtherDevice` is probed, and a failed HEAD is not remembered."
- [ ] `dart format .`, `flutter analyze`, `flutter test`. Commit `docs(spec): record slice 11's decisions in 7.2`.

---

## As executed

- **Coalescing uses the resolver's own in-flight map.** `MediaFetchGate.run` is typed to `MediaSourceData?`, so concurrent probes for one tier share a `Future<bool?>` in `_probing` instead; the fetch that follows a positive probe still goes through the gate.
- **A self-waiting future.** The first version removed the in-flight entry with `whenComplete(() => _probing.remove(key))`. `remove` returns the entry, which is that same future, and `whenComplete` waits on a future its callback returns, so every probe waited on itself forever (the tests timed out at 30 s). The callback is now a block that returns nothing, with a comment saying why.
- **Mutation checks**, each compiling and red on its named test: dropping the negative cache, caching a failed HEAD, dropping the video-thumbnail guard (Task 1); dropping the probe branch (S4), probing `notFound`, probing without a content hash (Task 2).
- **Review round (PR #2311).** The shipped probe differs from the Task 1 sample above: answers are keyed by the full store key, not the content hash and tier (an original's key carries its extension, so one hash can have several, and a miss for one said nothing about another); after an absent original it probes the compressed rendition, the tier `tryResolveRemote` tries last; probes run at most `maxConcurrentProbes` (4) at a time and each gives up after `probeBudget` (the fetch slot budget), a timeout being remembered no more than a failure; the constructor refuses a non-positive cap or budget, as `MediaFetchGate` does; and a probe with no store attached reports `storeFallbackUsed`.
- **Second review round.** A found tier is treated as stamped at the store's own `lastModified` rather than the epoch, so the rendition cache's freshness check drops a copy cached before the object was overwritten. A probe slot now follows the HEAD itself, not the wait for it (a timeout cannot cancel the request), so a stalled endpoint never has more than the cap in flight; a probe that finds no free slot within the budget gives up rather than holding its tile.
- **Third review round.** The probe now goes tier by tier: a found tier is served with only that tier stamped, and the next tier is asked about only if its fetch fails (a broken GET, a hash mismatch), as `tryResolveRemote` falls through for a stamped row. A row whose first tier serves still costs one HEAD.
