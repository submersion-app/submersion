import 'package:submersion/features/media/domain/color/auto_correction.dart';
import 'package:submersion/features/media/domain/color/channel_stats.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/color/color_matrix.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Whether [e] places a photo at the surface: outside the recorded profile
/// (before the descent or after the ascent: the matcher clamps those to the
/// profile's edge, marks them `estimated` and records the offset from the
/// edge) or shallower than 1 m. Boat, beach and surface-interval shots must
/// not be warmed into orange. An `estimated` match with no offset is a
/// mid-dive interpolation across a sparse profile, not a surface shot.
bool isSurfaceShot(MediaEnrichment? e) {
  if (e == null) return false;
  if (e.matchConfidence == MatchConfidence.estimated &&
      e.timestampOffsetSeconds != null) {
    return true;
  }
  final depth = e.depthMeters;
  return depth != null && depth < 1.0;
}

/// Whether the automatic fix can apply to [item] at all: only photos and
/// videos on a dive, so maps, receipts, signatures and library-only items
/// are never touched.
bool isAutoCorrectable(MediaItem item) =>
    item.diveId != null &&
    (item.mediaType == MediaType.photo || item.mediaType == MediaType.video);

/// Whether the automatic fix is switched on for [item]: the item's own Auto
/// switch, else the diver's setting, for an [isAutoCorrectable] item.
bool autoEnabledFor(
  MediaItem item, {
  ColorAdjustment? adjustment,
  required bool diverAutoEnabled,
}) {
  if (!isAutoCorrectable(item)) return false;
  return adjustment?.autoOverride ?? diverAutoEnabled;
}

/// Whether [item] came without its profile match (the library reads lean
/// rows) while the automatic fix is on for it, so the stored match must be
/// read first: its depth and surface check decide the fix.
bool needsStoredMatch(
  MediaItem item, {
  ColorAdjustment? adjustment,
  required bool diverAutoEnabled,
}) =>
    item.enrichment == null &&
    autoEnabledFor(
      item,
      adjustment: adjustment,
      diverAutoEnabled: diverAutoEnabled,
    );

/// Whether drawing [item] needs its pixel statistics for the automatic fix.
///
/// A video is never skipped as a whole for starting at the surface: its
/// correction follows the depth moment by moment instead.
bool needsAutoStats(
  MediaItem item, {
  ColorAdjustment? adjustment,
  required bool diverAutoEnabled,
}) {
  if (!autoEnabledFor(
    item,
    adjustment: adjustment,
    diverAutoEnabled: diverAutoEnabled,
  )) {
    return false;
  }
  if (adjustment?.whitePoint != null) return false;
  return item.isVideo || !isSurfaceShot(item.enrichment);
}

/// The automatic fix for a photo or a video frame with these [stats] at
/// [depthMeters], or null when there is none: no stats, or no depth and
/// colours that do not look underwater. The one rule for both.
AutoCorrectionParams? autoParamsFor(
  ChannelStats? stats, {
  double? depthMeters,
}) {
  if (stats == null) return null;
  if (depthMeters == null && !stats.looksUnderwater) return null;
  return computeAutoCorrection(stats, depthMeters: depthMeters);
}

/// The automatic fix for a photo with these [stats], or null when there is
/// none. Also guards a video drawn from its poster (no per-moment track):
/// a boat or beach clip must not be warmed either.
AutoCorrectionParams? autoParamsForPhoto(MediaItem item, ChannelStats? stats) {
  if (isSurfaceShot(item.enrichment)) return null;
  return autoParamsFor(stats, depthMeters: item.enrichment?.depthMeters);
}

/// Gains that turn the picked white point [w] neutral grey.
ColorMatrix whitePointGains(WhitePoint w) {
  final avg = (w.r + w.g + w.b) / 3;
  double gain(double c) => c > 0 ? (avg / c).clamp(0.5, 3.0) : 3.0;
  return ColorMatrix.gains(gain(w.r), gain(w.g), gain(w.b));
}

/// The one matrix drawn for an item: a white point (or else the automatic
/// fix) scaled by strength, then warmth, tint, saturation, contrast and
/// brightness in that order.
ColorMatrix composeCorrection({
  required ColorAdjustment? adjustment,
  AutoCorrectionParams? auto,
}) {
  final white = adjustment?.whitePoint;
  final base = white != null
      ? whitePointGains(white)
      : auto?.toMatrix() ?? ColorMatrix.identity;
  final strength = adjustment?.strength ?? 1.0;
  final scaled = switch (strength) {
    >= 1.0 => base,
    <= 0.0 => ColorMatrix.identity,
    _ => ColorMatrix.lerp(ColorMatrix.identity, base, strength),
  };
  if (adjustment == null) return scaled;
  return scaled
      .then(ColorMatrix.warmth(adjustment.warmth))
      .then(ColorMatrix.tint(adjustment.tint))
      .then(ColorMatrix.saturation(adjustment.saturation))
      .then(ColorMatrix.contrast(adjustment.contrast))
      .then(ColorMatrix.brightness(adjustment.brightness));
}
