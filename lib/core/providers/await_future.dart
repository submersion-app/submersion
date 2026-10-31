import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

/// Awaiting a provider's future when nothing else is listening to it.
extension AwaitFuture on ProviderContainer {
  /// Awaits [future], such as `someProvider.future`, holding a listener on it
  /// until it settles.
  ///
  /// `ref.read(p.future)` drops its listener before returning. A provider with
  /// no listeners is paused, and invalidating a paused provider mid-load
  /// cancels that load without scheduling another, so the returned future
  /// never completes (issue #3807). Held here, the invalidation runs the
  /// provider again and the same future completes with the new result.
  ///
  /// Listens on the container rather than through a `ref`: a listener from a
  /// provider that is itself paused does not count as an active one, which is
  /// the position of every link in a chain of analyses reading the one before.
  Future<T> awaitFuture<T>(ProviderListenable<Future<T>> future) async {
    final subscription = listen(future, (_, _) {});
    try {
      return await subscription.read();
    } finally {
      subscription.close();
    }
  }
}
