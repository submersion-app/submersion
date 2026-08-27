/// Which tier of `ExifExtractor`'s cascade produced a
/// `MediaSourceMetadata.takenAt`.
///
/// Surfaced on the Files-tab review card so a diver can tell a real capture
/// time from a filesystem timestamp before deciding whether a failed dive
/// match is the app's fault or the file's (issue #312).
enum TakenAtSource {
  /// `native_exif` read DateTimeOriginal. iOS and Android only.
  nativeExif,

  /// The pure-Dart reader parsed JPEG EXIF or an MP4/MOV `mvhd` box. This is
  /// the only tier that can date a file on macOS, Windows, or Linux.
  containerMetadata,

  /// Nothing could date the file, so its modification time was used. For most
  /// transfer routes that is the copy-to-disk time, which rarely lands inside
  /// a dive window.
  fileModifiedTime,

  /// No timestamp at all. Only reachable if the file vanished mid-read.
  none,
}
