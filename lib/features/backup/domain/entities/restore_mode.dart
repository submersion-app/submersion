/// How a database restore treats the cloud library.
enum RestoreMode {
  /// Restore locally; the next sync merges the restored data with the
  /// cloud library (historical behavior, the default).
  merge,

  /// The restored backup becomes the library everywhere: a pending replace
  /// intent is minted and the next sync wipes and re-seeds the cloud under
  /// a new library epoch.
  replace,
}
