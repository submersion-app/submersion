/// Reports how far a bulk cloud cleanup actually got.
///
/// Wiping a backend is best-effort by design: an offline provider or a listing
/// timeout leaves files behind. Before issue #1032 those failures were logged
/// and swallowed, and the UI reported "Wiped all sync data" regardless -- a
/// user whose marker listing timed out was told the backend was clean while
/// hundreds of files remained. Callers now have to look at [isComplete] to make
/// that claim.
class SyncCleanupOutcome {
  const SyncCleanupOutcome({
    this.deleted = 0,
    this.failed = 0,
    this.listIncomplete = false,
  });

  /// Files confirmed removed from the backend.
  final int deleted;

  /// Files that were listed but whose delete threw (offline, denied, timeout).
  final int failed;

  /// At least one listing call failed, so files may exist that were never even
  /// attempted. Distinct from [failed]: the count of what was missed is
  /// unknowable, which is exactly why success cannot be claimed.
  final bool listIncomplete;

  /// Every file that could be seen was removed. The only basis on which a
  /// caller may tell the user the backend is clean.
  bool get isComplete => failed == 0 && !listIncomplete;

  /// Total files acted on, successfully or not -- the denominator a progress
  /// bar finished at.
  int get attempted => deleted + failed;

  /// Fold another cleanup's result into this one, for callers that clean up in
  /// several passes and report a single outcome.
  SyncCleanupOutcome merge(SyncCleanupOutcome other) => SyncCleanupOutcome(
    deleted: deleted + other.deleted,
    failed: failed + other.failed,
    listIncomplete: listIncomplete || other.listIncomplete,
  );

  @override
  String toString() =>
      'SyncCleanupOutcome(deleted: $deleted, failed: $failed, '
      'listIncomplete: $listIncomplete)';
}

/// Called as a bulk cleanup advances: [done] of [total] files attempted.
///
/// [total] is fixed before the first delete (the whole listing is taken up
/// front) so the bar does not grow under the user mid-wipe.
typedef SyncCleanupProgress = void Function(int done, int total);
