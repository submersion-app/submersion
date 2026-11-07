import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show KeepAliveLink;

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
/// A paused listener (a page under another route) counts as gone, so the
/// window runs while it is paused. If the window ends first, the provider
/// stays only as long as that listener does: it disposes as soon as the
/// listener leaves, and if the listener comes back instead, leaving later
/// starts a full window again.
///
/// Compare `retainFor`, whose window runs from build regardless of use, for a
/// bounded lifetime that a busy surface cannot extend. Only meaningful on a
/// provider declared `isAutoDispose: true`.
void retainUntilIdle(Ref ref, Duration idle) {
  KeepAliveLink? link = ref.keepAlive();
  Timer? timer;
  var disposed = false;

  void startWindow() {
    timer?.cancel();
    timer = Timer(idle, () {
      // A listener that arrived after the window started without a
      // cancel/resume pair (one added during build) keeps the value: the
      // next onCancel starts a fresh window.
      if (!ref.isPaused) return;
      link?.close();
      link = null;
    });
  }

  ref.onCancel(startWindow);
  ref.onResume(() {
    timer?.cancel();
    if (link != null) return;
    // The window ran out under a paused listener and released the link.
    // Take a new one so that leaving again starts a full window instead of
    // disposing at once. Not from here: keepAlive is refused inside a
    // life-cycle callback. A resumed listener is active, so nothing can
    // dispose the provider before the microtask runs.
    scheduleMicrotask(() {
      if (disposed || link != null) return;
      link = ref.keepAlive();
      // The listener already left again: its onCancel found no link to hold.
      if (ref.isPaused) startWindow();
    });
  });
  ref.onDispose(() {
    disposed = true;
    timer?.cancel();
  });
  startWindow();
}
