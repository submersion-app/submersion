import 'package:flutter/foundation.dart';

import 'package:window_manager/window_manager.dart';

import 'package:submersion/core/platform/desktop_target_platform.dart';
import 'package:submersion/core/platform/host_platform.dart';
import 'package:submersion/core/presentation/providers/app_lock_provider.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/pop_out/data/pop_out_windows.dart';
import 'package:submersion/features/pop_out/domain/pop_out_frame.dart';
import 'package:submersion/features/pop_out/domain/pop_out_messages.dart';
import 'package:submersion/features/settings/presentation/providers/display_zoom_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Where the profile pop-out was last, as JSON (issue #5078). Written only
/// by the main window.
const kPopOutProfileFrameKey = 'pop_out_profile_frame';

/// Whether this app can open pop-out windows: macOS, Windows and Linux.
///
/// The target platform rather than the host: a widget test runs on a Mac
/// host but lays out as Android, and its toolbars must not gain a button no
/// phone has.
final popOutAvailableProvider = Provider<bool>(
  (ref) =>
      !HostPlatform.isWeb && isDesktopTargetPlatform(defaultTargetPlatform),
);

/// The window layer.
final popOutWindowsProvider = Provider<PopOutWindows>(
  (ref) => createPopOutWindows(),
);

/// The dive the main window shows, kept when it moves to a screen with no
/// dive. Written by [ShownDiveReporter] in the dive detail page.
final mainWindowDiveIdProvider = StateProvider<String?>((ref) => null);

/// One cursor position as it arrived from the pop-out.
///
/// Compared by identity, not by the message's value: the same position sent
/// again (the pop-out scrubbed back to where it was, after the main window
/// moved) is a new arrival, and a value-equal state would not notify.
class InboundCursor {
  InboundCursor(this.message);

  final CursorMessage message;
}

/// The last cursor position the pop-out sent; the dive's chart applies it.
final popOutInboundCursorProvider = StateProvider<InboundCursor?>(
  (ref) => null,
);

/// Whether the pop-out window holds keyboard focus, as it last reported.
final popOutFocusedProvider = StateProvider<bool>((ref) => false);

/// Whether App Lock has the app locked; a seam so tests need no lock.
final popOutAppLockedProvider = Provider<bool>(
  (ref) => ref.watch(appLockNotifierProvider),
);

/// The prefs the pop-out reads that the main window changes before it
/// stores them: the display zoom (a slider previews without storing, then
/// commits the value it previewed) and the device-local settings the profile
/// draws with. Taken from the live values, so what is sent is what the main
/// window shows. Settings kept in the diver's row reach the pop-out through
/// the shared database instead.
final popOutLivePrefsProvider = Provider<Map<String, Object>>((ref) {
  // Narrow: only these fields, not every settings change.
  ref.watch(
    settingsProvider.select(
      (s) => (
        s.o2CellUnit,
        s.counterdiffusionShowAll,
        s.perdixOverlayEnabled,
        s.perdixOverlayX,
        s.perdixOverlayY,
      ),
    ),
  );
  return {
    ...profileDevicePrefs(ref.read(settingsProvider)),
    SettingsKeys.displayZoom: ref.watch(displayZoomNotifierProvider),
  };
});

/// Changes whenever a value the pop-out reads from SharedPreferences may have
/// changed: the active diver (stored before it changes), and the live prefs.
final popOutPrefsTriggerProvider = Provider<Object?>(
  (ref) =>
      (ref.watch(currentDiverIdProvider), ref.watch(popOutLivePrefsProvider)),
);

/// Reads the main window's frame, to centre a first pop-out on its screen.
final mainWindowFrameProvider = Provider<Future<PopOutFrame> Function()>(
  (ref) => () async {
    try {
      // The main window initializes window_manager only when something
      // first needs it (fullscreen); asking an uninitialized plugin for its
      // window is a native crash no try can catch. Idempotent.
      await windowManager.ensureInitialized();
      final bounds = await windowManager.getBounds();
      return PopOutFrame(
        x: bounds.left,
        y: bounds.top,
        width: bounds.width,
        height: bounds.height,
      );
    } catch (_) {
      return const PopOutFrame(x: 0, y: 0, width: 1280, height: 800);
    }
  },
);
