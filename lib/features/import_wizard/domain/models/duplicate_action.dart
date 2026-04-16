/// The action the user has chosen for an item detected as a duplicate.
enum DuplicateAction {
  /// Skip the incoming item — do not import it.
  skip,

  /// Import the incoming item as a brand-new entry, ignoring the match.
  importAsNew,

  /// Merge the incoming item's data into the matched existing entry.
  consolidate,

  /// Replace the matched entry's source data with the incoming item.
  replaceSource,
}
