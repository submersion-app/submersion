import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Exempts this provider from auto-disposal for [window], measured from
/// BUILD, then lets normal auto-disposal resume.
///
/// The timer starts when the provider builds, not when its last watcher
/// leaves, because `KeepAliveLink` has no notion of the latter. So the value
/// survives an unwatched gap only within [window] of being computed, and a
/// provider still watched when the timer fires disposes as soon as its last
/// watcher goes. That is the behaviour wanted here: a bounded lifetime for a
/// value that is costly to hold (a megabyte-scale image buffer, a site's
/// 3D scene), not an idle timer that a busy surface could keep resetting.
///
/// Only meaningful on a provider declared `isAutoDispose: true`; on a
/// keep-forever provider the link has nothing to release. Mirrors the
/// `_keepAliveWithExpiry` idiom in `insights_providers.dart`.
void retainFor(Ref ref, Duration window) {
  final link = ref.keepAlive();
  final timer = Timer(window, link.close);
  ref.onDispose(timer.cancel);
}
