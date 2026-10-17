import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/features/media/data/media_cache_settings.dart';
import 'package:submersion/features/settings/presentation/providers/media_cache_settings_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SharedPreferences> prefsWith(Map<String, Object> values) async {
    SharedPreferences.setMockInitialValues(values);
    return SharedPreferences.getInstance();
  }

  test('starts from the defaults when nothing is stored', () async {
    final notifier = MediaCacheSettingsNotifier(
      await prefsWith({}),
      applyMemoryCap: (_) {},
    );
    expect(notifier.state.memoryCacheMb, kDefaultMemoryCacheMb);
    expect(notifier.state.diskCacheMb, kDefaultDiskCacheMb);
  });

  test('starts from the stored sizes', () async {
    final notifier = MediaCacheSettingsNotifier(
      await prefsWith({
        kMediaMemoryCacheMbKey: 512,
        kMediaDiskCacheMbKey: 4096,
      }),
      applyMemoryCap: (_) {},
    );
    expect(notifier.state.memoryCacheMb, 512);
    expect(notifier.state.diskCacheMb, 4096);
  });

  test(
    'a memory change is persisted and applied to the cache at once',
    () async {
      final prefs = await prefsWith({});
      final applied = <int>[];
      final notifier = MediaCacheSettingsNotifier(
        prefs,
        applyMemoryCap: applied.add,
      );

      await notifier.setMemoryCacheMb(1024);

      expect(notifier.state.memoryCacheMb, 1024);
      expect(prefs.getInt(kMediaMemoryCacheMbKey), 1024);
      expect(applied, [1024 * 1024 * 1024]);
    },
  );

  test('a disk change is persisted and brings the pool inside it', () async {
    final prefs = await prefsWith({});
    var evictions = 0;
    final notifier = MediaCacheSettingsNotifier(
      prefs,
      applyMemoryCap: (_) {},
      onDiskCapChanged: () async => evictions++,
    );

    await notifier.setDiskCacheMb(256);

    expect(notifier.state.diskCacheMb, 256);
    expect(prefs.getInt(kMediaDiskCacheMbKey), 256);
    expect(evictions, 1);
  });

  test('an off-step size is stored as the nearest step', () async {
    final prefs = await prefsWith({});
    final notifier = MediaCacheSettingsNotifier(prefs, applyMemoryCap: (_) {});

    await notifier.setMemoryCacheMb(200);

    expect(notifier.state.memoryCacheMb, 256);
    expect(prefs.getInt(kMediaMemoryCacheMbKey), 256);
  });

  test('setting the size it already has does nothing', () async {
    final prefs = await prefsWith({});
    final applied = <int>[];
    var evictions = 0;
    final notifier = MediaCacheSettingsNotifier(
      prefs,
      applyMemoryCap: applied.add,
      onDiskCapChanged: () async => evictions++,
    );

    await notifier.setMemoryCacheMb(kDefaultMemoryCacheMb);
    await notifier.setDiskCacheMb(kDefaultDiskCacheMb);

    expect(applied, isEmpty);
    expect(evictions, 0);
  });

  test('a failed eviction does not fail the change', () async {
    final prefs = await prefsWith({});
    final notifier = MediaCacheSettingsNotifier(
      prefs,
      applyMemoryCap: (_) {},
      onDiskCapChanged: () async => throw StateError('no cache database'),
    );

    await notifier.setDiskCacheMb(1024);

    expect(prefs.getInt(kMediaDiskCacheMbKey), 1024);
  });

  test('the unstored notifier changes state without storage', () async {
    final notifier = MediaCacheSettingsNotifier.unstored(
      applyMemoryCap: (_) {},
    );

    await notifier.setMemoryCacheMb(256);
    await notifier.setDiskCacheMb(2048);

    expect(notifier.state.memoryCacheMb, 256);
    expect(notifier.state.diskCacheMb, 2048);
  });

  group('emptying the disk cache', () {
    test('runs the clear and reports success', () async {
      var clears = 0;
      final notifier = MediaCacheSettingsNotifier(
        await prefsWith({}),
        applyMemoryCap: (_) {},
        onEmptyDiskCache: () async => clears++,
      );

      expect(await notifier.emptyDiskCache(), isTrue);
      expect(clears, 1);
    });

    test('reports a failure instead of throwing', () async {
      final notifier = MediaCacheSettingsNotifier(
        await prefsWith({}),
        applyMemoryCap: (_) {},
        onEmptyDiskCache: () async => throw StateError('no cache database'),
      );

      expect(await notifier.emptyDiskCache(), isFalse);
    });

    test('with nothing behind it there is nothing to empty', () async {
      final notifier = MediaCacheSettingsNotifier.unstored(
        applyMemoryCap: (_) {},
      );

      expect(await notifier.emptyDiskCache(), isFalse);
    });
  });

  test('writes reach storage one at a time, in the order they were made, '
      'so a slow first write cannot land over a later one', () async {
    final prefs = _SlowFirstWritePrefs();
    final notifier = MediaCacheSettingsNotifier(prefs, applyMemoryCap: (_) {});

    // Two slider releases in quick succession; the slider awaits neither.
    final first = notifier.setDiskCacheMb(1024);
    final second = notifier.setDiskCacheMb(4096);
    prefs.releaseFirst.complete();
    await Future.wait([first, second]);

    expect(prefs.landed, [1024, 4096]);
    expect(prefs.stored[kMediaDiskCacheMbKey], 4096);
  });
}

/// Storage whose first write is held until [releaseFirst] completes, as a
/// whole-file write can be overtaken by a later one.
class _SlowFirstWritePrefs extends Fake implements SharedPreferences {
  final stored = <String, int>{};
  final landed = <int>[];
  final releaseFirst = Completer<void>();
  var _writes = 0;

  @override
  int? getInt(String key) => stored[key];

  @override
  Future<bool> setInt(String key, int value) async {
    if (_writes++ == 0) await releaseFirst.future;
    stored[key] = value;
    landed.add(value);
    return true;
  }
}
