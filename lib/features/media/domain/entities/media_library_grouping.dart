/// How a library page is grouped before the active sort applies.
///
/// The grouped views (By dive, Timeline) group the rows they have loaded, so
/// a page must hold each group's rows in one run: in plain sort order a
/// dive's photos can be scattered across the whole library, and the group
/// then shows only those on the pages read so far (issue #4268). A grouped
/// page orders by the group first and by the sort within it.
enum MediaLibraryGrouping {
  /// The sort alone (Grid, Map).
  none,

  /// By dive, then site, then equipment item, with rows attached to none of
  /// them last, matching `groupByDive`.
  dive,

  /// By the calendar day of the row's date key, matching `groupByTimeline`.
  day,
}
