/// Which layout to use for the dive list.
enum DiveListViewMode {
  /// Full-size card with profile chart, stats, tags
  detailed,

  /// Two-line compact card: site + date on line 1, depth + duration on line 2
  compact,

  /// Single-row flat: all data on one line, divider-separated
  dense;

  /// Parse from stored string, defaulting to detailed.
  static DiveListViewMode fromName(String name) {
    return DiveListViewMode.values.firstWhere(
      (e) => e.name == name,
      orElse: () => DiveListViewMode.detailed,
    );
  }
}
