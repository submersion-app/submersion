import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/window_fullscreen.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// What fullscreen means for the dive profile and media viewers on desktop
/// (#3178).
enum ViewerFullscreenMode {
  /// The viewer fills the app window and hides the app's navigation; the
  /// window itself is left as it is.
  fullWindow,

  /// The desktop window goes into OS fullscreen as well.
  fullscreen,
}

/// The diver's [ViewerFullscreenMode] choice, stored per device.
///
/// Device-local like `MediaProvenanceBadgesNotifier`: whether a viewer takes
/// over the screen is a property of the computer, not of the diver, and it
/// needs no settings-table column. Seeded synchronously from
/// SharedPreferences so the first viewer opened already sees the choice.
class ViewerFullscreenModeNotifier extends StateNotifier<ViewerFullscreenMode> {
  ViewerFullscreenModeNotifier(SharedPreferences prefs)
    : _prefs = prefs,
      super(_decode(prefs.getString(SettingsKeys.viewerFullscreenMode)));

  /// Fixed state with nothing behind it, for a container without
  /// SharedPreferences; [setMode] then changes only the live state.
  ViewerFullscreenModeNotifier.unstored(super.mode) : _prefs = null;

  final SharedPreferences? _prefs;

  static ViewerFullscreenMode _decode(String? stored) =>
      ViewerFullscreenMode.values.asNameMap()[stored] ??
      ViewerFullscreenMode.fullWindow;

  Future<void> setMode(ViewerFullscreenMode mode) async {
    if (state == mode) return;
    state = mode;
    await _prefs?.setString(SettingsKeys.viewerFullscreenMode, mode.name);
  }
}

/// Defaults to [ViewerFullscreenMode.fullWindow] with no storage behind it,
/// so a container without SharedPreferences (most widget tests) keeps the
/// viewers as they always were. `rootProviderOverrides` swaps in the stored
/// notifier for the app.
final viewerFullscreenModeProvider =
    StateNotifierProvider<ViewerFullscreenModeNotifier, ViewerFullscreenMode>(
      (ref) => ViewerFullscreenModeNotifier.unstored(
        ViewerFullscreenMode.fullWindow,
      ),
    );

/// What a fullscreen viewer calls on entering and leaving its fullscreen
/// mode. [enter] takes the window into OS fullscreen only when the setting
/// asks for it; [exit] always hands back a hold, so changing the setting
/// while a viewer is open still restores the window on the way out.
class ViewerWindowFullscreen {
  ViewerWindowFullscreen({
    required WindowFullscreenController controller,
    required ViewerFullscreenMode Function() mode,
  }) : _controller = controller,
       _mode = mode;

  final WindowFullscreenController _controller;
  final ViewerFullscreenMode Function() _mode;

  Future<void> enter(Object owner) async {
    if (_mode() != ViewerFullscreenMode.fullscreen) return;
    await _controller.request(owner);
  }

  Future<void> exit(Object owner) => _controller.release(owner);
}

final viewerWindowFullscreenProvider = Provider<ViewerWindowFullscreen>(
  (ref) => ViewerWindowFullscreen(
    controller: ref.watch(windowFullscreenControllerProvider),
    mode: () => ref.read(viewerFullscreenModeProvider),
  ),
);
