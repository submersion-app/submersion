import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:submersion/core/providers/provider.dart';

/// Stops on the library's thumbnail size slider, smallest to largest
/// (issue #3297).
const int kMediaThumbnailSteps = 7;

/// The lowest row the slider gives, in logical pixels (issue #4738).
const double kMediaThumbnailMinExtent = 64;

/// No thumbnail is laid out narrower than this: a comfortable tap target.
/// Taller shapes crop to it at the smallest stops.
const double kMediaThumbnailMinTileWidth = 48;

/// Below this pane width the library packs tighter, as on a phone.
const double kMediaThumbnailNarrowPane = 600;

/// Gap between thumbnails, across and down.
double mediaThumbnailGap(double paneWidth) =>
    paneWidth < kMediaThumbnailNarrowPane ? 2 : 4;

/// Space each side of the thumbnails.
double mediaThumbnailInset(double paneWidth) =>
    paneWidth < kMediaThumbnailNarrowPane ? 2 : 8;

/// The row height [step] gives across a pane [paneWidth] wide.
///
/// The stops run from [kMediaThumbnailMinExtent] to half the pane in equal
/// ratios, not equal pixel amounts, so each one looks like the same change.
/// They are the sides the square tiles had at each stop before the rows
/// became justified, so a stop looks as big as it did.
double mediaThumbnailRowHeightForStep(int step, double paneWidth) {
  final largest = paneWidth / 2;
  if (largest <= kMediaThumbnailMinExtent) return kMediaThumbnailMinExtent;
  final fraction =
      step.clamp(0, kMediaThumbnailSteps - 1) / (kMediaThumbnailSteps - 1);
  return kMediaThumbnailMinExtent *
      math.pow(largest / kMediaThumbnailMinExtent, fraction);
}

/// The size to resolve and decode a thumbnail laid out at [tile] at.
///
/// One of three sizes, picked by the tile's longest side, rather than the
/// exact size: every change of target re-resolves the tile, and a window
/// being dragged wider would otherwise do that on each frame. 200 is what
/// the fixed 140px grid always used.
///
/// 800 is a memory ceiling, not a match for the largest tile. Past 800
/// logical px a thumbnail is drawn from the 800 decode scaled up, which
/// looks a little soft there. A larger step would hold four times the pixels
/// per tile (a 1600 decode at 2x is about 40 MB a tile) for the few widest
/// desktop panes.
///
/// This is an upper bound on the decode, not a promise of pixels. A photo
/// linked from a local file is drawn from its cached thumbnail, 512px on
/// its longest edge, at every size here (issue #3337); a decode is never
/// scaled up, so the larger targets cost such a tile nothing more.
Size mediaThumbnailDecodeTarget(Size tile) {
  final longest = math.max(tile.width, tile.height);
  final side = longest <= 200
      ? 200.0
      : longest <= 400
      ? 400.0
      : 800.0;
  return Size.square(side);
}

/// The library's thumbnail size: the slider stop, and the row height it came
/// to at the width it was chosen at.
class MediaThumbnailScale {
  const MediaThumbnailScale({
    this.step = (kMediaThumbnailSteps - 1) ~/ 2,
    this.rowHeight,
  });

  /// The slider stop, 0 (smallest) to [kMediaThumbnailSteps] - 1.
  final int step;

  /// The height being held, so that resizing the window re-packs the rows
  /// at the same height. Null until the pane has been measured since [step]
  /// was last chosen.
  final double? rowHeight;

  /// The row height for a pane [paneWidth] wide. A held height gives way
  /// only where it would be more than half the pane.
  double rowHeightAt(double paneWidth) {
    final height = rowHeight ?? mediaThumbnailRowHeightForStep(step, paneWidth);
    return math.max(kMediaThumbnailMinExtent, math.min(height, paneWidth / 2));
  }

  MediaThumbnailScale copyWith({int? step, double? rowHeight}) =>
      MediaThumbnailScale(
        step: step ?? this.step,
        rowHeight: rowHeight ?? this.rowHeight,
      );
}

/// Thumbnail size for the library's grid, by-dive and timeline views.
///
/// Kept for the session, not persisted: it resets to the middle step when
/// the app restarts.
final mediaThumbnailScaleProvider =
    StateNotifierProvider<MediaThumbnailScaleNotifier, MediaThumbnailScale>(
      (ref) => MediaThumbnailScaleNotifier(),
    );

class MediaThumbnailScaleNotifier extends StateNotifier<MediaThumbnailScale> {
  MediaThumbnailScaleNotifier() : super(const MediaThumbnailScale());

  /// Moves the slider. The height held for the old step is dropped, so the
  /// new one is worked out at the pane's current width.
  void setStep(int step) {
    state = MediaThumbnailScale(step: step.clamp(0, kMediaThumbnailSteps - 1));
  }

  /// Moves [delta] stops along the slider, stopping at either end. At an
  /// end nothing changes, so the height being held is kept.
  void stepBy(int delta) {
    final next = (state.step + delta).clamp(0, kMediaThumbnailSteps - 1);
    if (next != state.step) setStep(next);
  }

  /// Holds [rowHeight] for the current step. A height already held stays,
  /// which is what keeps it through a resize.
  void hold(double rowHeight) {
    if (state.rowHeight != null) return;
    state = state.copyWith(rowHeight: rowHeight);
  }
}
