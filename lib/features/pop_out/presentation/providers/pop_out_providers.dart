import 'package:window_manager/window_manager.dart';

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
final popOutAvailableProvider = Provider<bool>(
  (ref) => !HostPlatform.isWeb && HostPlatform.isDesktop,
);

/// The window layer.
final popOutWindowsProvider = Provider<PopOutWindows>(
  (ref) => createPopOutWindows(),
);

/// The dive the main window shows, kept when it moves to a screen with no
/// dive. Written by [ShownDiveReporter] in the dive detail page.
final mainWindowDiveIdProvider = StateProvider<String?>((ref) => null);

/// The last cursor position the pop-out sent; the dive's chart applies it.
final popOutInboundCursorProvider = StateProvider<CursorMessage?>(
  (ref) => null,
);

/// Whether the pop-out window holds keyboard focus, as it last reported.
final popOutFocusedProvider = StateProvider<bool>((ref) => false);

/// Whether App Lock has the app locked; a seam so tests need no lock.
final popOutAppLockedProvider = Provider<bool>(
  (ref) => ref.watch(appLockNotifierProvider),
);

/// Changes whenever a value the pop-out reads from SharedPreferences may have
/// changed: the active diver, the display zoom, any setting.
final popOutPrefsTriggerProvider = Provider<Object?>(
  (ref) => (
    ref.watch(currentDiverIdProvider),
    ref.watch(displayZoomNotifierProvider),
    ref.watch(settingsProvider),
  ),
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
