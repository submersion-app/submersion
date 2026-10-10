import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';

const _log = LoggerService('WindowFullscreen');

/// The desktop window's OS fullscreen state (#3178).
///
/// `SystemChrome.setEnabledSystemUIMode` hides the system bars on phones and
/// tablets but does nothing on macOS, Windows or Linux, so a viewer that
/// wants the whole screen there has to ask the window itself.
abstract interface class WindowFullscreenPlatform {
  Future<bool> isFullScreen();
  Future<void> setFullScreen(bool value);

  /// Calls [onLeave] whenever the window leaves fullscreen, whoever asked:
  /// this app, or the user through the window itself.
  void listenForLeave(void Function() onLeave);
}

/// Drives the real window through the window_manager plugin.
class WindowManagerFullscreenPlatform
    with WindowListener
    implements WindowFullscreenPlatform {
  /// The plugin finds the app's window only once initialized, and on
  /// Windows every other call needs that handle. Its window events start
  /// then too, and a leave can only follow an enter this app asked for.
  Future<void>? _initialized;

  void Function()? _onLeave;

  Future<void> _ensureInitialized() => _initialized ??= _initialize();

  Future<void> _initialize() async {
    await windowManager.ensureInitialized();
    windowManager.addListener(this);
  }

  @override
  void listenForLeave(void Function() onLeave) => _onLeave = onLeave;

  @override
  void onWindowLeaveFullScreen() => _onLeave?.call();

  @override
  Future<bool> isFullScreen() async {
    await _ensureInitialized();
    return windowManager.isFullScreen();
  }

  @override
  Future<void> setFullScreen(bool value) async {
    await _ensureInitialized();
    await windowManager.setFullScreen(value);
  }
}

/// No window to drive: phones, tablets and the web, where the viewers'
/// immersive system UI mode already covers the screen.
class _NoWindowFullscreenPlatform implements WindowFullscreenPlatform {
  const _NoWindowFullscreenPlatform();

  @override
  Future<bool> isFullScreen() async => false;

  @override
  Future<void> setFullScreen(bool value) async {}

  @override
  void listenForLeave(void Function() onLeave) {}
}

/// Holds the window in OS fullscreen while at least one owner wants it.
///
/// Owners nest: the fullscreen profile can open a photo in the media viewer,
/// and closing the viewer must not take the window out from under the
/// profile. Only a fullscreen this controller entered is ever left, so a
/// window the user had already made fullscreen stays that way.
///
/// Platform calls run one at a time, in order, so a quick enter and exit
/// cannot reach the window reversed. Each step re-checks the owners when it
/// runs, which lets a release that overtakes its own request cancel it.
class WindowFullscreenController {
  WindowFullscreenController(this._platform) {
    // Once the window has left fullscreen, a later fullscreen is no longer
    // this controller's to undo: the user may have gone back in themselves.
    _platform.listenForLeave(() => _enteredByUs = false);
  }

  final WindowFullscreenPlatform _platform;
  final Set<Object> _owners = {};
  bool _enteredByUs = false;
  Future<void> _queue = Future<void>.value();

  Future<void> request(Object owner) {
    final wasEmpty = _owners.isEmpty;
    if (!_owners.add(owner) || !wasEmpty) return _queue;
    return _enqueue(() async {
      if (_owners.isEmpty || _enteredByUs) return;
      if (await _platform.isFullScreen()) return;
      _enteredByUs = true;
      await _platform.setFullScreen(true);
    });
  }

  Future<void> release(Object owner) {
    if (!_owners.remove(owner) || _owners.isNotEmpty) return _queue;
    return _enqueue(() async {
      if (_owners.isNotEmpty || !_enteredByUs) return;
      _enteredByUs = false;
      // The user may already have left through the window itself (the
      // green button on macOS); toggling again would put them back in.
      if (!await _platform.isFullScreen()) return;
      await _platform.setFullScreen(false);
    });
  }

  Future<void> _enqueue(Future<void> Function() step) {
    return _queue = _queue.then((_) async {
      try {
        await step();
      } catch (e, stackTrace) {
        // A window that will not change mode leaves the viewer full-window,
        // which is still usable; it must not take the viewer down.
        _log.warning(
          'Could not change the window fullscreen state',
          error: e,
          stackTrace: stackTrace,
        );
      }
    });
  }
}

/// Whether the app runs in a desktop window whose fullscreen state it can
/// change: macOS, Windows or Linux.
bool hasDesktopWindow() =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };

/// The window this app runs in. Read through [defaultTargetPlatform] so a
/// widget test, which reports Android, never reaches the real plugin.
final windowFullscreenPlatformProvider = Provider<WindowFullscreenPlatform>(
  (ref) => hasDesktopWindow()
      ? WindowManagerFullscreenPlatform()
      : const _NoWindowFullscreenPlatform(),
);

final windowFullscreenControllerProvider = Provider<WindowFullscreenController>(
  (ref) =>
      WindowFullscreenController(ref.watch(windowFullscreenPlatformProvider)),
);
