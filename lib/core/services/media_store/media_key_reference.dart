/// The facts about one media row that decide which media store keys it can
/// resolve to (storage GC design, leak 3).
///
/// Several rows can share one content hash, and they need not agree:
/// `photo.JPG` and `photo.jpeg` hash identically but key differently, and one
/// row may be stored as an original while another of the same bytes is stored
/// compressed.
class MediaKeyReference {
  const MediaKeyReference({
    required this.originalExtension,
    required this.isVideo,
    required this.hasOriginalStamp,
    required this.hasRenditionStamp,
  });

  /// `StoreKeys.extensionFor(originalFilename)`: the extension of the
  /// original object this row would upload.
  final String originalExtension;

  /// A video's rendition is mp4; any other row's is jpg.
  final bool isVideo;

  /// `remoteUploadedAt` is set: the original object is this row's copy.
  final bool hasOriginalStamp;

  /// `remoteCompressedUploadedAt` is set: the rendition is this row's copy.
  final bool hasRenditionStamp;

  @override
  bool operator ==(Object other) =>
      other is MediaKeyReference &&
      other.originalExtension == originalExtension &&
      other.isVideo == isVideo &&
      other.hasOriginalStamp == hasOriginalStamp &&
      other.hasRenditionStamp == hasRenditionStamp;

  @override
  int get hashCode => Object.hash(
    originalExtension,
    isVideo,
    hasOriginalStamp,
    hasRenditionStamp,
  );
}
