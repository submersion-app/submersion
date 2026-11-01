/// The facts of a stored dive that duplicate matching reads (issue #3855).
///
/// Import review compares incoming dives with the whole logbook, so it reads
/// these columns rather than a full `Dive`, which hydrates tanks, gear, tags
/// and every other relation for each row.
class DiveMatchRecord {
  const DiveMatchRecord({
    required this.id,
    required this.dateTime,
    this.maxDepth,
    this.runtime,
    this.entryTime,
    this.exitTime,
    this.bottomTime,
    this.siteName,
  });

  final String id;
  final DateTime dateTime;
  final double? maxDepth;
  final Duration? runtime;
  final DateTime? entryTime;
  final DateTime? exitTime;
  final Duration? bottomTime;

  /// Shown on the review card beside a match.
  final String? siteName;

  /// Total time in the water, the figure compared with an incoming dive's
  /// `runtime ?? duration`, so not bottom time unless nothing better is
  /// recorded. Zero when the dive records no time at all.
  int get durationSeconds {
    if (runtime != null) return runtime!.inSeconds;
    if (exitTime != null && entryTime != null) {
      return exitTime!.difference(entryTime!).inSeconds;
    }
    if (bottomTime != null) return bottomTime!.inSeconds;
    return 0;
  }
}
