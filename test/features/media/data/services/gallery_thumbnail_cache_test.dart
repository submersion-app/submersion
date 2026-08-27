import 'dart:async';
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/media/data/services/gallery_thumbnail_cache.dart';

Uint8List _bytes(int length, [int fill = 7]) =>
    Uint8List.fromList(List<int>.filled(length, fill));

void main() {
  group('memoization', () {
    test(
      'a second request for the same key does not re-run the fetch',
      () async {
        final cache = GalleryThumbnailCache();
        var fetches = 0;

        Future<Uint8List?> fetch() async {
          fetches++;
          return _bytes(10);
        }

        await cache.getOrFetch('a', fetch);
        await cache.getOrFetch('a', fetch);

        expect(fetches, 1);
      },
    );

    test('returns the identical byte list instance on a hit', () async {
      // Load-bearing for Flutter's ImageCache: MemoryImage's operator== compares
      // `other.bytes == bytes`, and Uint8List does not override ==, so the cache
      // key is reference identity. Handing back a fresh copy would make every
      // ImageCache lookup miss -- which is exactly the bug this cache fixes.
      final cache = GalleryThumbnailCache();
      final first = await cache.getOrFetch('a', () async => _bytes(10));
      final second = await cache.getOrFetch('a', () async => _bytes(10));

      expect(identical(first, second), isTrue);
    });

    test('distinct keys are cached independently', () async {
      final cache = GalleryThumbnailCache();
      final a = await cache.getOrFetch('a', () async => _bytes(10, 1));
      final b = await cache.getOrFetch('b', () async => _bytes(10, 2));

      expect(a!.first, 1);
      expect(b!.first, 2);
    });

    test('invalidate forces the next request to re-fetch', () async {
      final cache = GalleryThumbnailCache();
      var fetches = 0;
      Future<Uint8List?> fetch() async {
        fetches++;
        return _bytes(10);
      }

      await cache.getOrFetch('a', fetch);
      cache.invalidate('a');
      await cache.getOrFetch('a', fetch);

      expect(fetches, 2);
    });
  });

  group('in-flight coalescing', () {
    test('concurrent requests for one key share a single fetch', () async {
      final cache = GalleryThumbnailCache();
      final gate = Completer<void>();
      var fetches = 0;

      Future<Uint8List?> fetch() async {
        fetches++;
        await gate.future;
        return _bytes(10);
      }

      final futures = List.generate(20, (_) => cache.getOrFetch('a', fetch));
      gate.complete();
      final results = await Future.wait(futures);

      expect(fetches, 1);
      // Every caller gets the same instance, not 20 copies.
      expect(results.every((r) => identical(r, results.first)), isTrue);
    });
  });

  group('concurrency cap', () {
    test('never runs more than maxConcurrent fetches at once', () async {
      // The measured freeze had 265 tile resolutions in flight simultaneously,
      // each holding a PhotoKit request whose reply had to be drained on the UI
      // thread. The cap is what makes that impossible.
      final cache = GalleryThumbnailCache(maxConcurrent: 4);
      var inFlight = 0;
      var maxObserved = 0;
      final gate = Completer<void>();

      Future<Uint8List?> fetch() async {
        inFlight++;
        if (inFlight > maxObserved) maxObserved = inFlight;
        await gate.future;
        inFlight--;
        return _bytes(10);
      }

      final futures = List.generate(
        50,
        (i) => cache.getOrFetch('key-$i', fetch),
      );
      // Let the first wave saturate the pool before releasing it.
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await Future.wait(futures);

      expect(maxObserved, lessThanOrEqualTo(4));
      expect(maxObserved, greaterThan(0));
    });

    test('drains newest-first so the visible tiles win', () async {
      // During a fling the queue fills with tiles that have already scrolled
      // away. FIFO would serve those first and leave whatever is actually
      // on screen shimmering; LIFO serves the most recent request next.
      final cache = GalleryThumbnailCache(maxConcurrent: 1);
      final order = <String>[];
      final gate = Completer<void>();

      Future<Uint8List?> fetch(String key) async {
        order.add(key);
        if (key == 'first') await gate.future;
        return _bytes(10);
      }

      // 'first' takes the only slot and blocks; the rest queue behind it.
      final futures = <Future<Uint8List?>>[
        cache.getOrFetch('first', () => fetch('first')),
        cache.getOrFetch('a', () => fetch('a')),
        cache.getOrFetch('b', () => fetch('b')),
        cache.getOrFetch('c', () => fetch('c')),
      ];
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await Future.wait(futures);

      expect(order.first, 'first');
      expect(order.sublist(1), [
        'c',
        'b',
        'a',
      ], reason: 'queued fetches should drain newest-first');
    });

    test('a queued fetch still runs after the pool drains', () async {
      final cache = GalleryThumbnailCache(maxConcurrent: 2);
      final completed = <String>[];

      final futures = List.generate(6, (i) async {
        await cache.getOrFetch('key-$i', () async => _bytes(10));
        completed.add('key-$i');
      });
      await Future.wait(futures);

      expect(completed, hasLength(6));
    });
  });

  group('eviction', () {
    test('evicts least-recently-used entries past the byte budget', () async {
      // 3 entries of 100 bytes fit; the 4th forces the LRU out.
      final cache = GalleryThumbnailCache(maxBytes: 300);
      await cache.getOrFetch('a', () async => _bytes(100));
      await cache.getOrFetch('b', () async => _bytes(100));
      await cache.getOrFetch('c', () async => _bytes(100));
      // Touch 'a' so 'b' becomes the least-recently-used.
      await cache.getOrFetch('a', () async => _bytes(100));
      await cache.getOrFetch('d', () async => _bytes(100));

      var refetched = false;
      await cache.getOrFetch('b', () async {
        refetched = true;
        return _bytes(100);
      });

      expect(refetched, isTrue, reason: 'b should have been evicted');
      expect(cache.containsKey('a'), isTrue, reason: 'a was touched recently');
    });

    test('an entry larger than the whole budget is not cached', () async {
      final cache = GalleryThumbnailCache(maxBytes: 100);
      await cache.getOrFetch('big', () async => _bytes(500));

      expect(cache.containsKey('big'), isFalse);
    });
  });

  group('failure handling', () {
    test('a null result is not cached, so the next request retries', () async {
      // A null thumbnail can mean a transient PhotoKit failure as easily as a
      // deleted asset; caching it would make the tile permanently blank.
      final cache = GalleryThumbnailCache();
      var fetches = 0;
      await cache.getOrFetch('a', () async {
        fetches++;
        return null;
      });
      await cache.getOrFetch('a', () async {
        fetches++;
        return _bytes(10);
      });

      expect(fetches, 2);
    });

    test('a throwing fetch propagates and releases its slot', () async {
      final cache = GalleryThumbnailCache(maxConcurrent: 1);

      await expectLater(
        cache.getOrFetch('a', () async => throw StateError('boom')),
        throwsStateError,
      );

      // The pool must not be permanently held by the failed job.
      final after = await cache.getOrFetch('b', () async => _bytes(10));
      expect(after, isNotNull);
    });

    test('a throwing fetch is not cached', () async {
      final cache = GalleryThumbnailCache();
      await expectLater(
        cache.getOrFetch('a', () async => throw StateError('boom')),
        throwsStateError,
      );

      final recovered = await cache.getOrFetch('a', () async => _bytes(10));
      expect(recovered, isNotNull);
    });
  });

  /// photo_manager asks PhotoKit with `networkAccessAllowed = YES`, so an
  /// iCloud-only asset triggers a full cloud download behind a plain await.
  group('slot budget', () {
    test('a fetch that overruns the slot budget frees it', () {
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
          return _bytes(10);
        });
        async.flushMicrotasks();
        expect(
          secondStarted,
          isFalse,
          reason: 'the only slot is held by the iCloud download',
        );

        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();
        expect(secondStarted, isTrue);
        expect(cache.detachedCount, 1);

        stuck.complete(null);
        async.flushMicrotasks();
        expect(cache.detachedCount, 0);
      });
    });

    test('a fetch inside the budget never detaches and cancels its timer', () {
      fakeAsync((async) {
        final cache = GalleryThumbnailCache(
          maxConcurrent: 1,
          slotBudget: const Duration(seconds: 5),
        );
        cache.getOrFetch('quick', () async => _bytes(10));
        async.elapse(const Duration(seconds: 1));
        async.flushMicrotasks();

        expect(cache.detachedCount, 0);
        expect(cache.runningCount, 0);

        // A stale firing would release a slot nobody holds, drifting the
        // effective cap upward for the life of the process.
        async.elapse(const Duration(seconds: 30));
        expect(cache.runningCount, 0);
      });
    });

    test('detaching is capped so outstanding work cannot grow unbounded', () {
      fakeAsync((async) {
        final cache = GalleryThumbnailCache(
          maxConcurrent: 1,
          maxDetached: 2,
          slotBudget: const Duration(seconds: 5),
        );
        final held = <Completer<Uint8List?>>[];

        for (var i = 0; i < 4; i++) {
          final blocker = Completer<Uint8List?>();
          held.add(blocker);
          cache.getOrFetch('k$i', () => blocker.future);
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();
        }

        expect(cache.detachedCount, 2);
        expect(cache.runningCount, 1);

        for (final blocker in held) {
          blocker.complete(null);
        }
        async.flushMicrotasks();
      });
    });

    test('a detached fetch still caches its bytes when it lands', () {
      fakeAsync((async) {
        final cache = GalleryThumbnailCache(
          maxConcurrent: 1,
          slotBudget: const Duration(seconds: 5),
        );
        final late = Completer<Uint8List?>();
        cache.getOrFetch('slow', () => late.future);
        async.elapse(const Duration(seconds: 5));
        async.flushMicrotasks();

        late.complete(_bytes(10));
        async.flushMicrotasks();
        expect(
          cache.containsKey('slow'),
          isTrue,
          reason: 'losing the slot must not lose the memoization',
        );
      });
    });
  });
}
