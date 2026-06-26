import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Pause-aware self-invalidation for providers that refresh off a repository
/// change-tick stream.
extension RefInvalidateOnChange on Ref {
  /// Rebuilds this provider whenever [changes] emits, while still playing nicely
  /// with Riverpod's auto-pause.
  ///
  /// The naive form -- `changes.listen((_) => ref.invalidateSelf())` -- keeps
  /// invalidating while the provider is paused (its widgets leave the screen and
  /// `TickerMode` disables). The deferred rebuild then flushes during the next
  /// TickerMode *resume*, cascading a re-entrant pause/invalidate through this
  /// provider's `ref.watch` dependents and tripping Riverpod 3's internal
  /// `pausedActiveSubscriptionCount` assertion
  /// (`Expected pausedActiveSubscriptionCount to be N, but was N+1`).
  ///
  /// The fix is to defer, not to pause the subscription: while the provider is
  /// paused a tick only records that a refresh is due ([isPaused]); the catch-up
  /// [invalidateSelf] is scheduled on [onResume], so the provider is never dirty
  /// across a resume and the cascade never re-enters mid-resume. Ticks that
  /// arrive while active invalidate immediately; several ticks while paused
  /// coalesce into one refresh on resume.
  ///
  /// Because the subscription is never paused, this is correct for broadcast
  /// change streams too: Drift's `tableUpdates(...)` is broadcast, and a paused
  /// broadcast subscription would silently drop a tick fired while off-screen
  /// (e.g. a background sync), leaving the provider stale on return.
  void invalidateSelfWhen(Stream<void> changes) {
    var refreshDue = false;
    final sub = changes.listen((_) {
      if (isPaused) {
        refreshDue = true;
      } else {
        invalidateSelf();
      }
    });
    onResume(() {
      if (!refreshDue) return;
      refreshDue = false;
      // invalidateSelf() is rejected inside a life-cycle callback
      // (Ref._throwIfInvalidUsage), so hop to a microtask to run it once the
      // resume has settled; guard against disposal in that window.
      Future.microtask(() {
        if (mounted) invalidateSelf();
      });
    });
    onDispose(sub.cancel);
  }
}
