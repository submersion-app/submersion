import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/window_fullscreen.dart';

/// Records every call and keeps the window's fullscreen state, like the real
/// plugin does.
class FakeWindowFullscreenPlatform implements WindowFullscreenPlatform {
  FakeWindowFullscreenPlatform({this.fullScreen = false});

  bool fullScreen;
  final List<bool> setCalls = [];
  bool throwOnSet = false;

  @override
  Future<bool> isFullScreen() async => fullScreen;

  @override
  Future<void> setFullScreen(bool value) async {
    if (throwOnSet) throw StateError('plugin unavailable');
    setCalls.add(value);
    fullScreen = value;
  }
}

void main() {
  late FakeWindowFullscreenPlatform platform;
  late WindowFullscreenController controller;

  setUp(() {
    platform = FakeWindowFullscreenPlatform();
    controller = WindowFullscreenController(platform);
  });

  test('the first request puts the window into fullscreen', () async {
    final owner = Object();
    await controller.request(owner);

    expect(platform.setCalls, [true]);
    expect(platform.fullScreen, isTrue);
  });

  test('releasing the only owner takes the window back out', () async {
    final owner = Object();
    await controller.request(owner);
    await controller.release(owner);

    expect(platform.setCalls, [true, false]);
    expect(platform.fullScreen, isFalse);
  });

  test(
    'a nested owner keeps the window fullscreen until both release',
    () async {
      final profile = Object();
      final viewer = Object();
      await controller.request(profile);
      await controller.request(viewer);
      await controller.release(viewer);

      expect(platform.fullScreen, isTrue, reason: 'the profile still holds it');

      await controller.release(profile);
      expect(platform.setCalls, [true, false]);
      expect(platform.fullScreen, isFalse);
    },
  );

  test('a window the user already made fullscreen is left that way', () async {
    platform.fullScreen = true;
    final owner = Object();
    await controller.request(owner);
    await controller.release(owner);

    expect(platform.setCalls, isEmpty);
    expect(platform.fullScreen, isTrue);
  });

  test('a release with no matching request does nothing', () async {
    await controller.release(Object());

    expect(platform.setCalls, isEmpty);
  });

  test('requesting twice for one owner needs only one release', () async {
    final owner = Object();
    await controller.request(owner);
    await controller.request(owner);
    await controller.release(owner);

    expect(platform.setCalls, [true, false]);
  });

  test(
    'a release before the request has run leaves the window alone',
    () async {
      final owner = Object();
      final entered = controller.request(owner);
      final left = controller.release(owner);
      await Future.wait([entered, left]);

      expect(platform.setCalls, isEmpty);
      expect(platform.fullScreen, isFalse);
    },
  );

  test('a window the user already left fullscreen is not toggled', () async {
    final owner = Object();
    await controller.request(owner);
    // The user left OS fullscreen through the window itself (the green
    // button on macOS) while the viewer was still in fullscreen mode.
    platform.fullScreen = false;
    await controller.release(owner);

    expect(platform.setCalls, [true]);
  });

  test(
    'a plugin failure is contained and the next request still runs',
    () async {
      platform.throwOnSet = true;
      final first = Object();
      await controller.request(first);
      await controller.release(first);

      platform.throwOnSet = false;
      final second = Object();
      await controller.request(second);

      expect(platform.setCalls, [true]);
    },
  );

  group('windowFullscreenPlatformProvider', () {
    for (final platformCase in [
      (TargetPlatform.macOS, true),
      (TargetPlatform.windows, true),
      (TargetPlatform.linux, true),
      (TargetPlatform.android, false),
      (TargetPlatform.iOS, false),
    ]) {
      test('${platformCase.$1.name}: desktop window is '
          '${platformCase.$2 ? '' : 'not '}driven', () {
        debugDefaultTargetPlatformOverride = platformCase.$1;
        addTearDown(() => debugDefaultTargetPlatformOverride = null);
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(
          container.read(windowFullscreenPlatformProvider)
              is WindowManagerFullscreenPlatform,
          platformCase.$2,
        );
      });
    }
  });
}
