import 'package:submersion/features/media_store/domain/media_upload_quality.dart';
import 'package:submersion_transcoder/submersion_transcoder.dart';

/// Photo rendition target: a long-edge ceiling and a JPEG quality.
class PhotoQualityPreset {
  const PhotoQualityPreset({
    required this.maxDimension,
    required this.jpegQuality,
  });
  final int maxDimension;
  final int jpegQuality;
}

/// Video rendition target (spec section 6): a resolution ceiling and
/// average bitrates. Bitrate-based (not CRF) because the native engines
/// (VideoToolbox, MediaCodec, Media Foundation) speak bitrate.
class VideoQualityPreset {
  const VideoQualityPreset({
    required this.maxHeight,
    required this.videoBitrateKbps,
    required this.audioBitrateKbps,
  });
  final int maxHeight;
  final int videoBitrateKbps;
  final int audioBitrateKbps;
}

const Map<MediaUploadQuality, PhotoQualityPreset> _photo = {
  MediaUploadQuality.high: PhotoQualityPreset(
    maxDimension: 3072,
    jpegQuality: 90,
  ),
  MediaUploadQuality.balanced: PhotoQualityPreset(
    maxDimension: 2048,
    jpegQuality: 85,
  ),
  MediaUploadQuality.small: PhotoQualityPreset(
    maxDimension: 1280,
    jpegQuality: 75,
  ),
};

const Map<MediaUploadQuality, VideoQualityPreset> _video = {
  MediaUploadQuality.high: VideoQualityPreset(
    maxHeight: 1080,
    videoBitrateKbps: 8000,
    audioBitrateKbps: 128,
  ),
  MediaUploadQuality.balanced: VideoQualityPreset(
    maxHeight: 720,
    videoBitrateKbps: 4000,
    audioBitrateKbps: 128,
  ),
  MediaUploadQuality.small: VideoQualityPreset(
    maxHeight: 480,
    videoBitrateKbps: 1800,
    audioBitrateKbps: 96,
  ),
};

/// The photo preset for [level], or null for [MediaUploadQuality.original].
PhotoQualityPreset? photoPresetFor(MediaUploadQuality level) => _photo[level];

/// The video preset for [level], or null for [MediaUploadQuality.original].
VideoQualityPreset? videoPresetFor(MediaUploadQuality level) => _video[level];

/// Ceiling rule (spec section 7): true when the source is already within
/// the level's budget, so the original should upload untouched. Resolution
/// alone is insufficient (a 20 Mbps 720p clip should still compress); the
/// 1.25x headroom avoids pointless re-encodes and generation loss.
bool videoWithinCeiling(VideoProbe probe, VideoQualityPreset preset) {
  final budgetKbps = 1.25 * (preset.videoBitrateKbps + preset.audioBitrateKbps);
  return probe.height <= preset.maxHeight &&
      probe.overallBitrateKbps <= budgetKbps;
}
