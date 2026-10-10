import 'package:submersion/core/services/window_fullscreen.dart';

/// Records every call and keeps the window's fullscreen state, like the real
/// plugin does, including the leave event it sends on every exit.
class FakeWindowFullscreenPlatform implements WindowFullscreenPlatform {
  FakeWindowFullscreenPlatform({this.fullScreen = false});

  bool fullScreen;
  final List<bool> setCalls = [];
  bool throwOnSet = false;
  void Function()? _onLeave;

  @override
  Future<bool> isFullScreen() async => fullScreen;

  @override
  Future<void> setFullScreen(bool value) async {
    if (throwOnSet) throw StateError('plugin unavailable');
    setCalls.add(value);
    final wasFullScreen = fullScreen;
    fullScreen = value;
    if (wasFullScreen && !value) _onLeave?.call();
  }

  @override
  void listenForLeave(void Function() onLeave) => _onLeave = onLeave;

  /// The user leaves fullscreen through the window itself.
  void userLeaves() {
    fullScreen = false;
    _onLeave?.call();
  }
}
