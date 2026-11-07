import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Exempts this provider from auto-disposal until it has gone [idle]
/// without an active listener, then lets normal auto-disposal resume.
///
/// The window restarts each time the last listener leaves (Riverpod's
/// `onCancel`) and is called off when one comes back (`onResume`), so a value
/// stays warm for [idle] after anything last used it. That suits a value that
/// is costly to rebuild and costly to keep forever, such as a dive's decoded
/// profile and tissue analysis (#4254): stepping between neighbouring dives
/// reuses the residual chain, while every dive left alone for [idle] frees
/// itself.
///
/// The window is also started at build, so a value only ever read (never
/// listened to) is held for [idle] and then released. That keeps an awaited
/// `ref.read(provider.future)` safe: its build cannot be disposed between two
/// awaits.
///
/// When the window ends while a paused listener (a page under another route)
/// still holds the provider, the provider stays until that listener leaves,
/// then disposes at once.
///
/// Compare `retainFor`, whose window runs from build regardless of use, for a
/// bounded lifetime that a busy surface cannot extend. Only meaningful on a
/// provider declared `isAutoDispose: true`.
void retainUntilIdle(Ref ref, Duration idle) {
  final link = ref.keepAlive();
  Timer? timer;
  void startWindow() {
    timer?.cancel();
    timer = Timer(idle, () {
      // A listener that arrived after the window started without a
      // cancel/resume pair (one added during build) keeps the value: the
      // next onCancel starts a fresh window.
      if (ref.isPaused) link.close();
    });
  }

  ref.onCancel(startWindow);
  ref.onResume(() => timer?.cancel());
  ref.onDispose(() => timer?.cancel());
  startWindow();
}
