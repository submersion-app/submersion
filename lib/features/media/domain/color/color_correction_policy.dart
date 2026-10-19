import 'package:submersion/features/media/domain/color/auto_correction.dart';
import 'package:submersion/features/media/domain/color/channel_stats.dart';
import 'package:submersion/features/media/domain/color/color_adjustment.dart';
import 'package:submersion/features/media/domain/color/color_matrix.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';

/// Whether [e] places a photo at the surface: outside the recorded profile
/// (the matcher marks those `estimated`: before the descent, after the
/// ascent) or shallower than 1 m. Boat, beach and surface-interval shots
/// must not be warmed into orange.
bool isSurfaceShot(MediaEnrichment? e) {
  if (e == null) return false;
  if (e.matchConfidence == MatchConfidence.estimated) return true;
  final depth = e.depthMeters;
  return depth != null && depth < 1.0;
}

/// Whether the automatic fix is switched on for [item]: the item's own Auto
/// switch, else the diver's setting. Only ever for photos and videos on a
/// dive, so maps, receipts, signatures and library-only items are never
/// touched.
bool autoEnabledFor(
  MediaItem item, {
  ColorAdjustment? adjustment,
  required bool diverAutoEnabled,
}) {
  if (item.diveId == null) return false;
  if (item.mediaType != MediaType.photo && item.mediaType != MediaType.video) {
    return false;
  }
  return adjustment?.autoOverride ?? diverAutoEnabled;
}

enum AutoNeed { none, stats }

/// Whether drawing [item] needs its pixel statistics.
///
/// A video is never skipped as a whole for starting at the surface: its
/// correction follows the depth moment by moment instead.
AutoNeed autoNeedFor(
  MediaItem item, {
  ColorAdjustment? adjustment,
  required bool diverAutoEnabled,
}) {
  if (!autoEnabledFor(
    item,
    adjustment: adjustment,
    diverAutoEnabled: diverAutoEnabled,
  )) {
    return AutoNeed.none;
  }
  if (adjustment?.whitePoint != null) return AutoNeed.none;
  if (!item.isVideo && isSurfaceShot(item.enrichment)) return AutoNeed.none;
  return AutoNeed.stats;
}

/// The automatic fix for a photo with these [stats], or null when there is
/// none: no stats, or no depth and colours that do not look underwater.
AutoCorrectionParams? autoParamsForPhoto(MediaItem item, ChannelStats? stats) {
  if (stats == null) return null;
  final depth = item.enrichment?.depthMeters;
  if (depth == null && !stats.looksUnderwater) return null;
  return computeAutoCorrection(stats, depthMeters: depth);
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
