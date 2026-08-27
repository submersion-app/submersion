import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

/// How long a PhotoKit fetch may hold a concurrency slot.
///
/// photo_manager asks PhotoKit with `networkAccessAllowed = YES`, so an
/// iCloud-only asset triggers a full cloud download behind a plain `await`.
/// Four of those used to hold every slot this cache has, which is a gallery of
/// permanent shimmer on a slow connection. Matching `MediaFetchGate`'s budget:
/// the two caps govern the same grid and staggering them would only make the
/// slower one invisible.
const Duration kGalleryThumbnailSlotBudget = Duration(seconds: 5);

/// Bounded, deduplicating, concurrency-capped cache for gallery thumbnail
/// bytes.
///
/// Exists because the library grid re-resolves a tile from scratch every time
/// it scrolls back into view: [GridView.builder] recycles tiles, and
/// `MediaItemView` builds its resolver future in `initState`. A measured pass
/// over a 434-photo library issued 1,691 resolutions (3.9x the item count) and
/// peaked at 265 concurrent PhotoKit requests, none of them cancelled when the
/// tile scrolled away. This cache addresses all three of those:
///
///   * **Memoization** — a resolved thumbnail is served from memory on
///     re-entry, so scrolling back costs nothing.
///   * **Coalescing** — concurrent requests for one key share a single fetch,
///     so a fling cannot queue the same photo twice.
///   * **A concurrency cap** — at most [maxConcurrent] fetches run at once, so
///     the platform channel and the UI thread's reply queue stay shallow.
///
/// Returning the *identical* [Uint8List] on a hit is load-bearing, not an
/// optimization: Flutter's `MemoryImage.operator==` compares `other.bytes ==
/// bytes` and `Uint8List` does not override `==`, so its `ImageCache` key is
/// reference identity. Handing back a fresh copy would make every `ImageCache`
/// lookup miss, which is what made gallery thumbnails uncacheable before.
class GalleryThumbnailCache {
  GalleryThumbnailCache({
    this.maxBytes = 32 * 1024 * 1024,
    this.maxConcurrent = 4,
    this.slotBudget = kGalleryThumbnailSlotBudget,
    int? maxDetached,
  }) : assert(maxBytes > 0),
       assert(maxConcurrent > 0),
       maxDetached = maxDetached ?? maxConcurrent * 3;

  /// Total retained thumbnail bytes before least-recently-used eviction.
  /// Thumbnails run tens of KB each, so the default holds a large library.
  final int maxBytes;

  /// Ceiling on simultaneous [getOrFetch] fetches.
  final int maxConcurrent;

  /// How long a fetch may hold a slot before handing it to the next waiter.
  ///
  /// The fetch is not cancelled and its bytes are still cached when they land:
  /// an iCloud asset that took twenty seconds to come down is a hit for every
  /// later request, and throwing that away because it was slow would mean
  /// downloading it again.
  final Duration slotBudget;

  /// Ceiling on fetches that outlived [slotBudget] and are still running.
  ///
  /// Without it, detaching would leak: a stalled photo library would start
  /// [maxConcurrent] fresh PhotoKit requests every [slotBudget] forever. At the
  /// cap a fetch keeps its slot instead, restoring back-pressure.
  final int maxDetached;

  /// Insertion-ordered, so the first key is the least recently used. Dart map
  /// literals are LinkedHashMap, and a hit re-inserts to move the entry to the
  /// end.
  final Map<String, Uint8List> _entries = <String, Uint8List>{};

  /// Fetches currently running, so concurrent callers can share one.
  final Map<String, Future<Uint8List?>> _inFlight =
      <String, Future<Uint8List?>>{};

  /// Callers parked waiting for a concurrency slot.
  final Queue<Completer<void>> _waiting = Queue<Completer<void>>();

  int _bytesHeld = 0;
  int _running = 0;
  int _detached = 0;

  bool containsKey(String key) => _entries.containsKey(key);

  int get byteCount => _bytesHeld;

  int get length => _entries.length;

  /// Fetches holding a slot, for tests.
  int get runningCount => _running;

  /// Fetches that outlived [slotBudget] and are still running, for tests.
  int get detachedCount => _detached;

  /// Cached bytes for [key], else [fetch]'s result — run under the concurrency
  /// cap and cached on success.
  ///
  /// A null result is deliberately not cached: null means "no bytes right now",
  /// which covers a transient PhotoKit failure as readily as a deleted asset,
  /// and caching it would leave the tile permanently blank. Callers that can
  /// distinguish a genuinely dead asset should act on the null themselves.
  Future<Uint8List?> getOrFetch(
    String key,
    Future<Uint8List?> Function() fetch,
  ) {
    final hit = _entries.remove(key);
    if (hit != null) {
      _entries[key] = hit;
      return Future<Uint8List?>.value(hit);
    }
    final pending = _inFlight[key];
    if (pending != null) return pending;

    // _run suspends at its first await before returning, so the assignment
    // below always lands before the finally block that clears it.
    final future = _run(key, fetch);
    _inFlight[key] = future;
    return future;
  }

  /// Drops [key] so the next request re-fetches it. Use when the underlying
  /// asset is known to have changed or vanished.
  void invalidate(String key) {
    final removed = _entries.remove(key);
    if (removed != null) _bytesHeld -= removed.lengthInBytes;
  }

  /// Drops every entry. In-flight fetches are unaffected and will repopulate.
  void clear() {
    _entries.clear();
    _bytesHeld = 0;
  }

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

    // Cancelled below rather than left to fire harmlessly: a stale firing
    // would release a slot this fetch no longer holds, letting the effective
    // cap drift upward for the life of the process.
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

  void _store(String key, Uint8List bytes) {
    // An entry that cannot fit even in an empty cache would evict everything
    // and still overflow, so it is never admitted.
    if (bytes.lengthInBytes > maxBytes) return;
    _entries[key] = bytes;
    _bytesHeld += bytes.lengthInBytes;
    while (_bytesHeld > maxBytes && _entries.isNotEmpty) {
      final oldest = _entries.keys.first;
      final evicted = _entries.remove(oldest);
      if (evicted != null) _bytesHeld -= evicted.lengthInBytes;
    }
  }

  Future<void> _acquire() {
    if (_running < maxConcurrent) {
      _running++;
      return Future<void>.value();
    }
    final completer = Completer<void>();
    _waiting.add(completer);
    return completer.future;
  }

  void _release() {
    // Hand the slot straight to the next waiter rather than decrementing and
    // letting it re-acquire: that keeps _running honest and cannot drop a
    // parked caller.
    //
    // Newest-first (removeLast), not FIFO. During a fling the queue fills with
    // tiles that have already scrolled off; serving those first would leave
    // the tiles actually under the user's eyes shimmering until the backlog
    // cleared. Starving the old entries is correct -- their widgets are
    // disposed and nothing awaits them -- and the queue is bounded by the
    // page size anyway, since the memo admits each key at most once.
    if (_waiting.isNotEmpty) {
      _waiting.removeLast().complete();
      return;
    }
    _running--;
  }
}
