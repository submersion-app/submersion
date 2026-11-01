import 'dart:async';

/// A cooperative cancellation signal passed through an import pipeline.
///
/// Long-running import adapters check [isCancelled] between work items (for
/// example, between dives in a batched download) and return a partial result
/// when true. Cancellation is cooperative, not preemptive: the in-flight
/// transaction finishes cleanly before the loop exits.
///
/// Cooperative semantics matter because SQLite cannot recover from a
/// transaction that gets killed mid-write without a subsequent read-write
/// open to roll back the hot journal — the exact failure mode that blocks
/// app startup with SQLITE_READONLY_ROLLBACK (extended code 776).
class ImportCancellationToken {
  final _cancelled = Completer<void>();

  /// True once [cancel] has been called. Adapters should check this between
  /// work items and break out of the loop cleanly when true, returning a
  /// partial result for whatever was already committed.
  bool get isCancelled => _cancelled.isCompleted;

  /// Signal cancellation. Idempotent — calling twice has no additional
  /// effect.
  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }

  /// [work]'s result, or null as soon as this token is cancelled.
  ///
  /// For work with nothing to commit, such as a parse, whose caller has no
  /// reason to wait for a result it would throw away. The work itself carries
  /// on unseen, so its result and any error it later ends in are dropped. It
  /// must not be work that writes: the cooperative rule above still applies.
  Future<T?> untilCancelled<T extends Object>(Future<T> work) async {
    try {
      final result = await Future.any<T?>([
        work,
        _cancelled.future.then((_) => null),
      ]);
      return isCancelled ? null : result;
    } catch (_) {
      if (isCancelled) return null;
      rethrow;
    }
  }
}
