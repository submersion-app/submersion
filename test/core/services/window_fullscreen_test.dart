import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/window_fullscreen.dart';

import '../../helpers/fake_window_fullscreen_platform.dart';

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
    'a late leave event from its own exit does not drop a new hold',
    () async {
      platform.deferLeaveEvents = true;
      final first = Object();
      await controller.request(first);
      await controller.release(first);
      // Fullscreen again before the first exit's event has arrived.
      final second = Object();
      await controller.request(second);
      platform.deliverLeaveEvents();
      await controller.release(second);

      expect(platform.setCalls, [true, false, true, false]);
      expect(platform.fullScreen, isFalse);
    },
  );

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

  test(
    'a failed exit keeps the hold, so the next release retries it',
    () async {
      final first = Object();
      await controller.request(first);
      platform.throwOnSet = true;
      await controller.release(first);
      expect(platform.fullScreen, isTrue, reason: 'the exit failed');

      platform.throwOnSet = false;
      final second = Object();
      await controller.request(second);
      await controller.release(second);

      expect(platform.setCalls, [true, false]);
      expect(platform.fullScreen, isFalse);
    },
  );

  test(
    'a failed exit does not swallow the next leave the user makes',
    () async {
      final first = Object();
      await controller.request(first);
      platform.throwOnSet = true;
      await controller.release(first);
      platform.throwOnSet = false;

      // Still fullscreen and ours; the user now leaves and goes back in.
      final second = Object();
      await controller.request(second);
      platform.userLeaves();
      platform.fullScreen = true;
      await controller.release(second);

      expect(platform.fullScreen, isTrue);
    },
  );

  group('WindowManagerFullscreenPlatform', () {
    const channel = MethodChannel('window_manager');

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return switch (call.method) {
              'isFullScreen' => false,
              _ => true,
            };
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('disposing the container removes its window listener', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final before = windowManager.listeners.length;
      // A soft restart (restartApp) builds a new root scope, so the old
      // scope's listener must not outlive it.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(windowFullscreenPlatformProvider).isFullScreen();
      expect(windowManager.listeners.length, before + 1);

      container.dispose();
      expect(windowManager.listeners.length, before);
    });

    test('a container disposed mid-initialization adds no listener', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final before = windowManager.listeners.length;
      final container = ProviderContainer();

      final pending = container
          .read(windowFullscreenPlatformProvider)
          .isFullScreen();
      container.dispose();
      await pending;

      expect(windowManager.listeners.length, before);
    });
  });

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
