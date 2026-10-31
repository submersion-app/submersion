import 'package:submersion/core/providers/provider.dart';

/// True while a root-navigator overlay (one of a small, known set of app-wide
/// flows that push straight onto the root `Navigator`, bypassing whichever
/// `ShellRoute` the diver is currently inside) covers the screen (issue
/// #3361, Task 4b).
///
/// `RouteAware`'s `didPushNext`/`didPopNext` only fire for pushes within the
/// *same* `Navigator`'s route stack. `RestoreCompletePage.show`, the adopt-
/// replaced-library dialog, buddy-card links and passport-tag links all push
/// on the root `Navigator` one level above the nested shell, so none of them
/// trip that mechanism. This is a plain foreground signal, not a
/// lifecycle/background concept: the app stays in the foreground the whole
/// time, a root-level screen is just covering the shell underneath it.
///
/// Each of the four call sites sets this `true` immediately before its push
/// and `false` once the overlay is gone, so `AutoConnectController` can pause
/// its passive scan for exactly the same reason it already pauses for a
/// child route pushed on top within the shell's own `Navigator`.
final rootOverlayActiveProvider = StateProvider<bool>((ref) => false);
