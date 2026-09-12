/// Why a resync from the stored original file did not update the dive.
///
/// A closed set rather than a message: the services that detect these cases
/// have no locale, and the diver reads the result in one of eleven
/// languages, so the sentence is chosen in the presentation layer (see
/// `diveResyncFailureMessage`).
enum DiveResyncFailure {
  /// The dive was deleted between offering the action and running it.
  diveMissing,

  /// The dive's primary source names no stored file.
  noStoredFile,

  /// The stored file's format has no parser a resync can replay.
  unsupportedFormat,

  /// The pointer resolves to nothing on this device's disk.
  storedFileMissing,

  /// The file parsed, but none of its dives still matches this one.
  noMatchingDive,

  /// Reading or parsing the stored file threw.
  unexpectedError,
}
