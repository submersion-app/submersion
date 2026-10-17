// Locks the values of the caps this app actually applies. The memory byte cap
// is a setting now (issue #3337), so what is locked here is its steps, its
// default and the object cap that keeps the byte cap the limit that matters.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/media/data/media_cache_settings.dart';
import 'package:submersion/features/media/data/network_cache_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('media cache steps and defaults', () {
    test('memory steps are 64 MB to 4 GB', () {
      expect(kMemoryCacheStepsMb, [64, 128, 256, 512, 1024, 2048, 4096]);
    });

    test('disk steps are 256 MB to 16 GB', () {
      expect(kDiskCacheStepsMb, [256, 512, 1024, 2048, 4096, 8192, 16384]);
    });

    test('defaults are steps: 128 MB in memory, 512 MB on disk', () {
      expect(kDefaultMemoryCacheMb, 128);
      expect(kDefaultDiskCacheMb, 512);
      expect(kMemoryCacheStepsMb, contains(kDefaultMemoryCacheMb));
      expect(kDiskCacheStepsMb, contains(kDefaultDiskCacheMb));
    });

    test('memory object cap is 2000', () {
      expect(kMemoryCacheCapObjects, 2000);
    });
  });

  group('snapToCacheStep', () {
    test('a missing value is the fallback', () {
      expect(snapToCacheStep(null, kMemoryCacheStepsMb, fallback: 128), 128);
    });

    test('a step is kept', () {
      expect(snapToCacheStep(1024, kMemoryCacheStepsMb, fallback: 128), 1024);
    });

    test('an off-step value moves to the nearest step', () {
      // 75 MB is what the cap was before it became a setting.
      expect(snapToCacheStep(75, kMemoryCacheStepsMb, fallback: 128), 64);
      expect(snapToCacheStep(900, kMemoryCacheStepsMb, fallback: 128), 1024);
      expect(snapToCacheStep(1, kDiskCacheStepsMb, fallback: 512), 256);
      expect(snapToCacheStep(99999, kDiskCacheStepsMb, fallback: 512), 16384);
    });
  });

  group('MediaCacheSettings.fromPrefs', () {
    test('empty prefs give the defaults', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = MediaCacheSettings.fromPrefs(
        await SharedPreferences.getInstance(),
      );
      expect(settings.memoryCacheMb, 128);
      expect(settings.diskCacheMb, 512);
      expect(settings.memoryCacheBytes, 128 * 1024 * 1024);
      expect(settings.diskCacheBytes, 512 * 1024 * 1024);
    });

    test('stored values are read, snapped to a step', () async {
      SharedPreferences.setMockInitialValues({
        kMediaMemoryCacheMbKey: 2048,
        kMediaDiskCacheMbKey: 300,
      });
      final settings = MediaCacheSettings.fromPrefs(
        await SharedPreferences.getInstance(),
      );
      expect(settings.memoryCacheMb, 2048);
      expect(settings.diskCacheMb, 256);
    });
  });

  group('applyMediaCacheCaps', () {
    late int bytesBefore;
    late int objectsBefore;

    setUp(() {
      final cache = PaintingBinding.instance.imageCache;
      bytesBefore = cache.maximumSizeBytes;
      objectsBefore = cache.maximumSize;
    });

    tearDown(() {
      final cache = PaintingBinding.instance.imageCache;
      cache.maximumSizeBytes = bytesBefore;
      cache.maximumSize = objectsBefore;
    });

    test('with no size it applies the default and the object cap', () {
      applyMediaCacheCaps();
      final cache = PaintingBinding.instance.imageCache;
      expect(cache.maximumSizeBytes, 128 * 1024 * 1024);
      expect(cache.maximumSize, 2000);
    });

    test('a given size becomes the byte cap', () {
      applyMediaCacheCaps(memoryBytes: 256 * 1024 * 1024);
      expect(
        PaintingBinding.instance.imageCache.maximumSizeBytes,
        256 * 1024 * 1024,
      );
    });
  });
}
