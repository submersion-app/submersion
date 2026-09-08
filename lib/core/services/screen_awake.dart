import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on while foreground work the user is watching runs --
/// whether that work is a single awaited call ([hold]) or an event-driven
/// span with no owning [Future] ([acquire]).
///
/// A phone that locks part-way through a sync repair suspends the app behind
/// it, so an operation the user was told not to interrupt is interrupted by
/// the idle timer instead (issue #1194); a dive-computer download dropped the
/// same way, suspended mid-transfer when the screen locked (issue #1646).
/// Every holder that takes a lock must release it, which [hold] guarantees by
/// construction and [acquire] leaves to the caller.
///
/// The lock is deliberately tied to work the user is WATCHING. Nothing here is
/// for background sync: a lock that outlives its screen is a flat battery.
class ScreenAwake {
  const ScreenAwake._();

  /// Nested holds are counted, so an inner release cannot let the screen sleep
  /// while an outer hold is still running.
  static int _holders = 0;

  /// Test seam: receives every enable/disable instead of the real plugin.
  /// Production leaves this null. Mirrors
  /// `BackupBookmarkService.debugSupportedOverride`.
  @visibleForTesting
  static Future<void> Function({required bool enable})? debugToggle;

  @visibleForTesting
  static int get debugHolders => _holders;

  /// Drops the seam and any leaked holds between tests. A leaked hold is
  /// released through the seam that took it BEFORE the seam is dropped:
  /// clearing the count on its own would leave the screen pinned on for the
  /// rest of the run, and on a device for the rest of the session.
  @visibleForTesting
  static void debugReset() {
    if (_holders > 0) {
      _holders = 0;
      _toggle(enable: false);
    }
    debugToggle = null;
  }

  /// Runs [body] with the screen held awake, releasing the lock however [body]
  /// ends. Returns whatever [body] returns.
  ///
  /// The lock is requested and released WITHOUT being awaited, on purpose: the
  /// caller's first frame (a progress dialog, typically) must not wait on a
  /// platform round trip to appear, and a plugin that never answers must not
  /// be able to hang the maintenance work or swallow its error. Ordering is
  /// safe regardless -- both calls travel the same method channel, which
  /// delivers them in order.
  static Future<T> hold<T>(Future<T> Function() body) async {
    _acquire();
    try {
      return await body();
    } finally {
      _release();
    }
  }

  /// Takes a hold that lives until [ScreenAwakeHold.release] is called, for
  /// work whose span is not a single [Future] and so cannot use [hold] -- an
  /// event-driven dive-computer download, say, that starts on one call and
  /// ends when a completion event arrives.
  ///
  /// The caller owns the release. Every path that ends the work -- success,
  /// error, cancel, and the owner's own disposal as a backstop -- must call
  /// [ScreenAwakeHold.release]; it is idempotent, so calling it on more than
  /// one of those paths is safe. Prefer [hold] wherever the work is scoped to
  /// a future: it cannot leak.
  static ScreenAwakeHold acquire() {
    _acquire();
    return ScreenAwakeHold._();
  }

  static void _acquire() {
    _holders++;
    if (_holders == 1) _toggle(enable: true);
  }

  static void _release() {
    _holders--;
    if (_holders > 0) return;
    _holders = 0;
    _toggle(enable: false);
  }

  /// Never throws, and never reports: an unsupported platform, or a test with
  /// no plugin registered, must not disturb the work the lock was protecting.
  static void _toggle({required bool enable}) {
    try {
      (debugToggle ?? WakelockPlus.toggle)(enable: enable).catchError((_) {});
    } catch (_) {
      // Cosmetic. The operation matters; the screen staying on does not.
    }
  }
}

/// One outstanding [ScreenAwake.acquire] hold. [release] drops it exactly
/// once; further calls are no-ops, so an owner can release on several end
/// paths (completion, error, cancel, disposal) without counting them.
class ScreenAwakeHold {
  ScreenAwakeHold._();

  bool _released = false;

  void release() {
    if (_released) return;
    _released = true;
    ScreenAwake._release();
  }
}
