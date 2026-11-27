import 'package:submersion/features/pop_out/data/pop_out_channel.dart';
import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';

export 'package:submersion/features/pop_out/data/pop_out_windows_io.dart'
    if (dart.library.js_interop) 'package:submersion/features/pop_out/data/pop_out_windows_web.dart'
    show createPopOutWindows;

/// Desktop pop-out windows (issue #5078): the one place that knows how a
/// window is made, so a later move to Flutter's own windowing replaces only
/// this layer.
abstract interface class PopOutWindows {
  /// This engine's end of the channel to the other window.
  PopOutChannel get channel;

  /// Opens the profile pop-out with [launch], hidden until it has placed
  /// itself.
  Future<void> openProfile(PopOutLaunch launch);

  /// Whether a profile pop-out window exists.
  Future<bool> isOpen();

  /// What this engine was launched with when it is a pop-out window; null
  /// for the main window, and on the web and mobile.
  Future<PopOutLaunch?> currentLaunch();
}
