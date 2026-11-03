import 'dart:async';
import 'dart:ui' show AppExitResponse, AppExitType;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show ServicesBinding;
import 'package:window_manager/window_manager.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/logger_service.dart';

final _log = LoggerService.forClass(AppExitGuard);

/// Work a quit would lose, held by the page that has it (#3422).
class AppExitBlocker {
  /// Whether there is anything to lose right now.
  final bool Function() hasUnsavedWork;

  /// Asks the diver. True gives the work up and lets the quit or the leaving
  /// go ahead.
  final Future<bool> Function() confirmLeaving;

  const AppExitBlocker({
    required this.hasUnsavedWork,
    required this.confirmLeaving,
  });
}

/// Stands between the platform's exit request and closing the databases.
///
/// The answer to an exit request never waits for the diver. On macOS the
/// engine treats a quit as already approved until Dart replies, so while a
/// reply is outstanding a second Cmd+Q terminates at once, with no prompt and
/// no database close. A blocked request is therefore cancelled immediately
/// and the prompt runs after it; if the diver gives the work up, the exit is
/// requested again, and this time nothing stands in its way.
///
/// The macOS close button needs more. Closing the last window quits, but
/// AppKit only asks once the window is gone, so a cancelled quit would leave
/// a process with no window. While anything is held the window is kept from
/// closing and the attempt comes here as [closeWindowRequested] instead. A
/// close on Windows and Linux already reaches the engine as a cancellable
/// exit request with the window still up.
///
/// A quit can also come from the Dock or the taskbar with the window out of
/// sight, where no prompt would be seen and Flutter draws no frames at all, so
/// the window is brought back before asking.
class AppExitGuard {
  AppExitGuard({
    Future<void> Function()? retryExit,
    Future<void> Function(bool prevent)? preventWindowClose,
    Future<void> Function()? revealWindow,
  }) : _retryExit = retryExit ?? _exitThroughThePlatform,
       _revealWindow = revealWindow ?? _revealThroughThePlugin {
    _preventWindowClose = preventWindowClose ?? _platformPreventWindowClose();
  }

  final Future<void> Function() _retryExit;
  final Future<void> Function() _revealWindow;
  late final Future<void> Function(bool prevent) _preventWindowClose;
  final _blockers = <AppExitBlocker>[];
  bool _asking = false;

  static Future<void> _exitThroughThePlatform() =>
      ServicesBinding.instance.exitApplication(AppExitType.cancelable);

  static Future<void> _revealThroughThePlugin() async {
    final desktop =
        !kIsWeb &&
        const {
          TargetPlatform.macOS,
          TargetPlatform.windows,
          TargetPlatform.linux,
        }.contains(defaultTargetPlatform);
    if (!desktop) return;
    await windowManager.ensureInitialized();
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.show();
  }

  Future<void> Function(bool prevent) _platformPreventWindowClose() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) {
      return (_) async {};
    }
    return _MacWindowClose(closeWindowRequested).prevent;
  }

  void hold(AppExitBlocker blocker) {
    _blockers.add(blocker);
    if (_blockers.length == 1) unawaited(_setPreventWindowClose(true));
  }

  void release(AppExitBlocker blocker) {
    if (_blockers.remove(blocker) && _blockers.isEmpty) {
      unawaited(_setPreventWindowClose(false));
    }
  }

  Future<void> _setPreventWindowClose(bool prevent) async {
    try {
      await _preventWindowClose(prevent);
    } catch (error, stackTrace) {
      _log.warning(
        'Could not change whether the window may close',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Answers an exit request: [close] when nothing stands in the way, else
  /// cancel, with the prompt to follow. Part of the platform's only reply
  /// path, so like [close] it always answers and never throws.
  Future<AppExitResponse> answer(
    Future<AppExitResponse> Function() close,
  ) async {
    final blocker = _blockerWithWork();
    if (blocker == null) return close();
    unawaited(_ask(blocker));
    return AppExitResponse.cancel;
  }

  /// The window was kept from closing. With nothing to lose it goes ahead as
  /// the quit it would have been; with nothing held the window has closed by
  /// itself and there is nothing to do.
  Future<void> closeWindowRequested() async {
    if (_blockers.isEmpty) return;
    final blocker = _blockerWithWork();
    if (blocker != null) return _ask(blocker);
    await _exit();
  }

  /// Whether a held page may be left inside the app: the same question a quit
  /// asks, for a way out the page itself cannot stop (`GoRoute.onExit`).
  Future<bool> mayLeave() async {
    final blocker = _blockerWithWork();
    return blocker == null || await _confirm(blocker);
  }

  AppExitBlocker? _blockerWithWork() {
    try {
      for (final blocker in _blockers) {
        if (blocker.hasUnsavedWork()) return blocker;
      }
    } catch (error, stackTrace) {
      // Unable to tell is no reason to refuse a quit.
      _log.warning(
        'Could not check for unsaved work at exit',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return null;
  }

  /// A cancelled quit: the diver is asked, and the exit requested again.
  Future<void> _ask(AppExitBlocker blocker) async {
    if (await _confirm(blocker, reveal: true)) await _exit();
  }

  Future<bool> _confirm(AppExitBlocker blocker, {bool reveal = false}) async {
    // A repeated request lands on the prompt already showing.
    if (_asking) return false;
    _asking = true;
    try {
      if (reveal) await _revealForPrompt();
      return await blocker.confirmLeaving();
    } catch (error, stackTrace) {
      // Nothing has gone and the app is still up: the work is safe.
      _log.warning(
        'Could not finish asking about unsaved work',
        error: error,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      _asking = false;
    }
  }

  /// A window that stays hidden is no reason not to ask: the prompt waits for
  /// the diver to come back to it.
  Future<void> _revealForPrompt() async {
    try {
      await _revealWindow();
    } catch (error, stackTrace) {
      _log.warning(
        'Could not bring the window back to ask about unsaved work',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _exit() async {
    try {
      await _retryExit();
    } catch (error, stackTrace) {
      _log.warning(
        'Could not ask the platform to exit',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }
}

/// The window's close button, through the plugin that owns its delegate.
class _MacWindowClose with WindowListener {
  _MacWindowClose(this._onCloseAttempt);

  final Future<void> Function() _onCloseAttempt;
  bool _listening = false;

  Future<void> prevent(bool value) async {
    await windowManager.ensureInitialized();
    if (!_listening) {
      _listening = true;
      windowManager.addListener(this);
    }
    await windowManager.setPreventClose(value);
  }

  @override
  void onWindowClose() => unawaited(_onCloseAttempt());
}

final appExitGuardProvider = Provider<AppExitGuard>((ref) => AppExitGuard());
