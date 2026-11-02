import 'dart:async';
import 'dart:io';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:submersion/core/services/storage/cache_location.dart';

import '../../../helpers/fake_path_provider.dart';

/// Counts platform lookups so the memoization is asserted, and can be made to
/// fail on demand.
class _CountingPathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _CountingPathProvider(this.supportPath);

  final String supportPath;
  int calls = 0;
  bool shouldThrow = false;

  /// When set, the lookup waits for this, like a real platform channel.
  Future<void>? gate;

  @override
  Future<String?> getApplicationSupportPath() async {
    calls++;
    await gate;
    if (shouldThrow) throw const FileSystemException('support dir unavailable');
    return supportPath;
  }
}

void main() {
  late Directory root;
  late Directory cache;
  late Directory support;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('cache_location_test');
    cache = Directory(p.join(root.path, 'cache'));
    support = Directory(p.join(root.path, 'support'));
    await cache.create();
    await support.create();
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  Future<CacheLocation> phone() => resolveCacheLocation(
    osManagesCaches: true,
    cacheDirectory: () async => cache,
    supportDirectory: () async => support,
  );

  Future<CacheLocation> desktop() => resolveCacheLocation(
    osManagesCaches: false,
    cacheDirectory: () async => fail('desktop must not ask for it'),
    supportDirectory: () async => support,
  );

  String inSupport(List<String> segments) =>
      p.joinAll([support.path, 'Submersion', ...segments]);

  String inCache(List<String> segments) =>
      p.joinAll([cache.path, 'Submersion', ...segments]);

  Future<void> write(String path, [String contents = 'x']) async {
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsString(contents);
  }

  group('resolveCacheLocation', () {
    test('phones keep regenerable caches under the cache directory', () async {
      final location = await phone();

      expect(location.osManagesCaches, isTrue);
      expect(location.mediaPools.path, inCache(['media_cache']));
      expect(location.mediaScratch.path, inSupport(['media_cache']));
      expect(location.mediaStaging.path, inSupport(['media_cache', 'staging']));
      expect(
        location.mediaTranscode.path,
        inSupport(['media_cache', 'transcode']),
      );
      expect(location.videoThumbnails.path, inCache(['video_thumbnails']));
      expect(location.pdfThumbnails.path, inCache(['pdf_thumbnails']));
    });

    test('desktop keeps everything under support and never asks for the cache '
        'directory', () async {
      final location = await desktop();

      expect(location.osManagesCaches, isFalse);
      expect(location.mediaPools.path, inSupport(['media_cache']));
      expect(location.mediaScratch.path, location.mediaPools.path);
      expect(location.videoThumbnails.path, inSupport(['video_thumbnails']));
      expect(location.pdfThumbnails.path, inSupport(['pdf_thumbnails']));
    });
  });

  group('moveCachesToOsDirectory', () {
    test('moves all five directories, keeping their contents', () async {
      await write(
        inSupport(['media_cache', 'thumbs', 'ab', 'abc.jpg']),
        'thumb',
      );
      await write(inSupport(['media_cache', 'originals', 'ab', 'abc']), 'orig');
      await write(inSupport(['media_cache', 'renditions', 'ab', 'abc']), 'ren');
      await write(inSupport(['video_thumbnails', 'poster.jpg']), 'poster');
      await write(inSupport(['pdf_thumbnails', 'page.jpg']), 'page');

      final leftovers = await moveCachesToOsDirectory(await phone());

      expect(leftovers, isEmpty);
      for (final (segments, contents) in [
        (['media_cache', 'thumbs', 'ab', 'abc.jpg'], 'thumb'),
        (['media_cache', 'originals', 'ab', 'abc'], 'orig'),
        (['media_cache', 'renditions', 'ab', 'abc'], 'ren'),
        (['video_thumbnails', 'poster.jpg'], 'poster'),
        (['pdf_thumbnails', 'page.jpg'], 'page'),
      ]) {
        expect(File(inCache(segments)).readAsStringSync(), contents);
        expect(File(inSupport(segments)).existsSync(), isFalse);
      }
    });

    test('leaves staging and transcode where they are', () async {
      final staged = inSupport(['media_cache', 'staging', 'stage_1']);
      final transcoded = inSupport(['media_cache', 'transcode', 'abc_low.mp4']);
      await write(staged);
      await write(transcoded);

      await moveCachesToOsDirectory(await phone());

      expect(File(staged).existsSync(), isTrue);
      expect(File(transcoded).existsSync(), isTrue);
    });

    test('a second run is a no-op', () async {
      final moved = inCache(['media_cache', 'thumbs', 'ab', 'abc.jpg']);
      await write(inSupport(['media_cache', 'thumbs', 'ab', 'abc.jpg']));
      final location = await phone();

      await moveCachesToOsDirectory(location);
      final leftovers = await moveCachesToOsDirectory(location);

      expect(leftovers, isEmpty);
      expect(File(moved).existsSync(), isTrue);
    });

    test('does nothing on desktop', () async {
      final thumb = inSupport(['media_cache', 'thumbs', 'ab', 'abc.jpg']);
      await write(thumb);

      final leftovers = await moveCachesToOsDirectory(await desktop());

      expect(leftovers, isEmpty);
      expect(File(thumb).existsSync(), isTrue);
    });

    test('an old pool whose new location already has files is returned as a '
        'leftover', () async {
      final kept = inCache(['media_cache', 'thumbs', 'keep.jpg']);
      await write(kept);
      final old = inSupport(['media_cache', 'thumbs']);
      await write(p.join(old, 'old.jpg'));
      await write(inSupport(['pdf_thumbnails', 'page.jpg']));

      final leftovers = await moveCachesToOsDirectory(await phone());

      expect(leftovers.map((d) => d.path), [old]);
      expect(File(kept).existsSync(), isTrue);
      expect(
        File(inCache(['pdf_thumbnails', 'page.jpg'])).existsSync(),
        isTrue,
      );

      await deleteLeftoverCaches(leftovers);

      expect(Directory(old).existsSync(), isFalse);
      expect(File(kept).existsSync(), isTrue);
    });
  });

  group('deleteLeftoverCaches', () {
    test('ignores a directory that has already gone', () async {
      final gone = Directory(p.join(root.path, 'gone'));

      await expectLater(deleteLeftoverCaches([gone]), completes);
    });
  });

  group('cacheLocation', () {
    late _CountingPathProvider platform;

    setUp(() {
      platform = _CountingPathProvider(support.path);
      useFakePathProvider(platform);
      resetCacheLocationForTesting();
      addTearDown(resetCacheLocationForTesting);
    });

    test('resolves once across many callers', () async {
      await cacheLocation();
      await Future.wait([cacheLocation(), cacheLocation(), cacheLocation()]);

      expect(platform.calls, 1);
    });

    test(
      'a lookup abandoned in a fake zone does not strand later callers',
      () async {
        // A grid tile in a widget test can be the first to ask, and such a test
        // can end with the answer still on its way. The memo outlives that
        // test, and CI runs many files in one isolate, so a future tied to the
        // test's zone would hang every later caller in the bundle. Through
        // `then` because a plain await on a future can shortcut this.
        final platformReplied = Completer<void>();
        platform.gate = platformReplied.future;
        fakeAsync((_) => unawaited(cacheLocation()));

        platformReplied.complete();
        final location = await cacheLocation()
            .then((location) => location)
            .timeout(const Duration(seconds: 5));

        expect(location.mediaPools.path, inSupport(['media_cache']));
      },
    );

    test('a failed lookup abandoned in a fake zone is not cached', () async {
      final platformReplied = Completer<void>();
      platform
        ..gate = platformReplied.future
        ..shouldThrow = true;
      fakeAsync(
        (_) => unawaited(cacheLocation().then<void>((_) {}, onError: (_) {})),
      );
      platformReplied.complete();
      await Future<void>.delayed(Duration.zero);

      platform.shouldThrow = false;
      final location = await cacheLocation().timeout(
        const Duration(seconds: 5),
      );

      expect(location.mediaPools.path, inSupport(['media_cache']));
    });

    test('a failed lookup is not cached, so the next caller retries', () async {
      platform.shouldThrow = true;
      await expectLater(cacheLocation(), throwsA(isA<FileSystemException>()));

      platform.shouldThrow = false;
      final location = await cacheLocation();

      expect(location.mediaPools.path, inSupport(['media_cache']));
      expect(platform.calls, 2);
    });
  });
}
