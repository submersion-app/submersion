/// The dives a diver has logged, set against the ones statistics count.
///
/// Statistics leave out dives the diver excluded, so a total of zero does not
/// mean an empty logbook. These counts ignore every view filter, which lets a
/// screen tell a diver who has yet to log a dive from one whose dives are
/// filtered out or excluded (issue #3963).
class LogbookDiveCounts {
  /// Dives that happened. A planned dive has not, so it is not one of these.
  final int logged;

  /// The [logged] dives that statistics include.
  final int counted;

  const LogbookDiveCounts({required this.logged, required this.counted});

  /// True when dives exist and the diver has excluded every one of them, so
  /// no filter can be what emptied a statistic.
  bool get allExcluded => logged > 0 && counted == 0;
}
