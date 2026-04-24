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
  bool _cancelled = false;

  /// True once [cancel] has been called. Adapters should check this between
  /// work items and break out of the loop cleanly when true, returning a
  /// partial result for whatever was already committed.
  bool get isCancelled => _cancelled;

  /// Signal cancellation. Idempotent — calling twice has no additional
  /// effect.
  void cancel() {
    _cancelled = true;
  }
}
