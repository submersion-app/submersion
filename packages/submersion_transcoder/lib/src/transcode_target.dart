/// Encoder-agnostic rendition target: a resolution ceiling and bitrates.
/// The app maps its quality presets onto this; engines never see app types.
class TranscodeTarget {
  const TranscodeTarget({
    required this.maxHeight,
    required this.videoBitrateKbps,
    required this.audioBitrateKbps,
  });
  final int maxHeight;
  final int videoBitrateKbps;
  final int audioBitrateKbps;
}
