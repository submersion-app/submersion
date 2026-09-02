/// Thrown when a packed series blob cannot be decoded.
///
/// Decoders never guess. An unknown version byte, a truncated payload,
/// trailing bytes, or a block that disagrees with its field table all end
/// here rather than in a partial sample list.
class ProfileSeriesCodecException implements Exception {
  const ProfileSeriesCodecException(this.message);

  final String message;

  @override
  String toString() => 'ProfileSeriesCodecException: $message';
}

/// The blob names a codec version this build has no field table for.
///
/// A distinct type because the two answers differ: a version ABOVE
/// everything this build knows is forward compatibility, not corruption.
/// The samples are fine and a newer build reads them, so the sync door
/// stores the row rather than discarding a peer's data this device simply
/// cannot render yet. Anything else stays a refusal.
class UnknownSeriesVersionException extends ProfileSeriesCodecException {
  const UnknownSeriesVersionException(this.blobVersion, this.knownVersions)
    : super('unknown codec version $blobVersion');

  /// The version byte the blob carries.
  final int blobVersion;

  /// The versions this build can decode.
  final Set<int> knownVersions;

  /// Whether [blobVersion] is newer than anything this build knows, which
  /// is what separates "not yet" from "not valid".
  bool get isForwardVersion =>
      knownVersions.isNotEmpty &&
      blobVersion > knownVersions.reduce((a, b) => a > b ? a : b);
}
