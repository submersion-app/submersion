import 'package:flutter/services.dart';

import 'package:desktop_multi_window/desktop_multi_window.dart';

import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/pop_out/data/pop_out_channel.dart';
import 'package:submersion/features/pop_out/data/pop_out_windows.dart';
import 'package:submersion/features/pop_out/data/pop_out_windows_web.dart'
    as unsupported;
import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';

const _log = LoggerService('PopOutWindows');

/// Real windows on macOS, Windows and Linux; none on phones and tablets,
/// which have no multi-window plugin.
PopOutWindows createPopOutWindows() => HostPlatform.isDesktop
    ? _DesktopPopOutWindows()
    : unsupported.createPopOutWindows();

class _DesktopPopOutWindows implements PopOutWindows {
  @override
  PopOutChannel channelNamed(String name) => _WindowPopOutChannel(name);

  @override
  Future<void> openProfile(PopOutLaunch launch) async {
    await WindowController.create(
      WindowConfiguration(arguments: launch.encode(), hiddenAtLaunch: true),
    );
  }

  @override
  Future<bool> isOpen() async {
    try {
      final windows = await WindowController.getAll();
      return windows.any((w) => PopOutLaunch.decode(w.arguments) != null);
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<PopOutLaunch?> currentLaunch() async {
    try {
      final controller = await WindowController.fromCurrentEngine();
      return PopOutLaunch.decode(controller.arguments);
    } on MissingPluginException {
      return null;
    } catch (e) {
      // The main window's engine answers with empty arguments; anything
      // else means this engine is no pop-out either.
      _log.debug('No pop-out launch for this engine: $e');
      return null;
    }
  }
}

class _WindowPopOutChannel implements PopOutChannel {
  _WindowPopOutChannel(String name) : _channel = WindowMethodChannel(name);

  final WindowMethodChannel _channel;

  @override
  Future<void> send(PopOutMessage message) async {
    final call = message.toCall();
    try {
      await _channel.invokeMethod<void>(call.method, call.arguments);
    } on WindowChannelException catch (e) {
      // No window at the other end (not open yet, or just closed).
      _log.debug('Pop-out message ${call.method} not delivered: $e');
    } on MissingPluginException {
      // No multi-window plugin in this engine.
    }
  }

  /// The last registration or removal, so a removal waits for a pending
  /// registration: removing before it lands would remove nothing, and the
  /// registration would then hold the channel.
  Future<void> _pending = Future<void>.value();

  @override
  void setHandler(void Function(PopOutMessage message)? handler) {
    _pending = _pending.then((_) async {
      try {
        await _channel.setMethodCallHandler(
          handler == null
              ? null
              : (call) async {
                  final message = PopOutMessage.fromCall(call);
                  if (message != null) handler(message);
                  return null;
                },
        );
      } on MissingPluginException {
        // No multi-window plugin in this engine.
      } catch (e) {
        _log.warning('Could not change the pop-out channel handler: $e');
      }
    });
  }
}
