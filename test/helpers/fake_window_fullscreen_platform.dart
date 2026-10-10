import 'package:submersion/core/services/window_fullscreen.dart';

/// Records every call and keeps the window's fullscreen state, like the real
/// plugin does, including the leave event it sends on every exit.
class FakeWindowFullscreenPlatform implements WindowFullscreenPlatform {
  FakeWindowFullscreenPlatform({this.fullScreen = false});

  bool fullScreen;
  final List<bool> setCalls = [];
  bool throwOnSet = false;

  /// Holds leave events back until [deliverLeaveEvents], as macOS does until
  /// its exit animation ends.
  bool deferLeaveEvents = false;
  int _deferredLeaves = 0;
  void Function()? _onLeave;

  @override
  Future<bool> isFullScreen() async => fullScreen;

  @override
  Future<void> setFullScreen(bool value) async {
    if (throwOnSet) throw StateError('plugin unavailable');
    setCalls.add(value);
    final wasFullScreen = fullScreen;
    fullScreen = value;
    if (wasFullScreen && !value) {
      if (deferLeaveEvents) {
        _deferredLeaves++;
      } else {
        _onLeave?.call();
      }
    }
  }

  void deliverLeaveEvents() {
    for (; _deferredLeaves > 0; _deferredLeaves--) {
      _onLeave?.call();
    }
  }

  @override
  void listenForLeave(void Function() onLeave) => _onLeave = onLeave;

  /// The user leaves fullscreen through the window itself.
  void userLeaves() {
    fullScreen = false;
    _onLeave?.call();
  }
}
