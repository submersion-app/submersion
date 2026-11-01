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

  /// Asks the diver. True gives the work up and lets the quit go ahead.
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
class AppExitGuard {
  AppExitGuard({
    Future<void> Function()? retryExit,
    Future<void> Function(bool prevent)? preventWindowClose,
  }) : _retryExit = retryExit ?? _exitThroughThePlatform {
    _preventWindowClose = preventWindowClose ?? _platformPreventWindowClose();
  }

  final Future<void> Function() _retryExit;
  late final Future<void> Function(bool prevent) _preventWindowClose;
  final _blockers = <AppExitBlocker>[];
  bool _asking = false;

  static Future<void> _exitThroughThePlatform() =>
      ServicesBinding.instance.exitApplication(AppExitType.cancelable);

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
    try {
      await _retryExit();
    } catch (error, stackTrace) {
      _log.warning(
        'Could not exit after the window was closed',
        error: error,
        stackTrace: stackTrace,
      );
    }
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

  Future<void> _ask(AppExitBlocker blocker) async {
    // A repeated quit lands on the prompt already showing.
    if (_asking) return;
    _asking = true;
    try {
      final leave = await blocker.confirmLeaving();
      _asking = false;
      if (leave) await _retryExit();
    } catch (error, stackTrace) {
      // The request was cancelled and the app is still up: the work is safe.
      _log.warning(
        'Could not finish asking about unsaved work at exit',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _asking = false;
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
