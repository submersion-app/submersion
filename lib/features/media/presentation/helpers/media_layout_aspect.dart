import 'dart:ui' show Size;

import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/value_objects/learned_aspect.dart';

export 'package:submersion/features/media/domain/value_objects/learned_aspect.dart';

/// The shape an item is laid out at when its stored size is unknown. Most
/// underwater cameras and phones shoot 4:3 by default.
const double kMediaFallbackAspect = 4 / 3;

/// Documents lay out at a page's shape; their poster is a rendered page.
const double kMediaDocumentAspect = 3 / 4;

/// The narrowest and widest shapes a tile takes, so one item cannot fill a
/// row or become a sliver. Beyond these the thumbnail is cropped to fit.
const double kMediaMinAspect = 1 / 3;
const double kMediaMaxAspect = 3;

/// How far a decoded thumbnail's shape may stray from the laid-out one
/// before it is learned. Thumbnail and poster rounding stays well inside.
const double _kAspectTolerance = 0.02;

/// Whether [learned] was recorded against the stored size [item] still has.
/// A relinked or re-read item has new dimensions, and the old ratio is then
/// stale.
bool learnedAspectApplies(MediaItem item, LearnedAspect learned) =>
    learned.width == item.width && learned.height == item.height;

/// The shape [item] is laid out at, before [clampMediaAspect]: fixed for a
/// document, else a [learned] ratio that still applies, else the stored
/// size, else [kMediaFallbackAspect].
///
/// The stored size is the container's, with no EXIF rotation applied, which
/// is why a learned ratio wins over it.
double mediaRawAspect(MediaItem item, {LearnedAspect? learned}) {
  if (item.mediaType == MediaType.document) return kMediaDocumentAspect;
  if (learned != null && learnedAspectApplies(item, learned)) {
    return learned.ratio;
  }
  final width = item.width;
  final height = item.height;
  if (width != null && height != null && width > 0 && height > 0) {
    return width / height;
  }
  return kMediaFallbackAspect;
}

/// [raw] held within [kMediaMinAspect] and [kMediaMaxAspect].
double clampMediaAspect(double raw) =>
    raw.clamp(kMediaMinAspect, kMediaMaxAspect).toDouble();

/// Each of [items]' shapes as a justified grid lays it out: learned, stored
/// or fallback, then clamped. The one rule the library and the dive card
/// share (issues #4738, #4739).
List<double> mediaLayoutRatios(
  Iterable<MediaItem> items,
  Map<String, LearnedAspect> learned,
) => [
  for (final item in items)
    clampMediaAspect(mediaRawAspect(item, learned: learned[item.id])),
];

/// Whether a thumbnail decoded at [decoded] has a different shape from
/// [raw], the unclamped shape it was laid out from. Compared unclamped so a
/// panorama held at 3:1 does not count as a mismatch on every draw.
bool decodedAspectDiffers(double raw, Size decoded) {
  if (decoded.width <= 0 || decoded.height <= 0) return false;
  final ratio = decoded.width / decoded.height;
  // The epsilon keeps exactly 2 % on the "same" side despite rounding.
  return (ratio / raw - 1).abs() > _kAspectTolerance + 1e-9;
}
