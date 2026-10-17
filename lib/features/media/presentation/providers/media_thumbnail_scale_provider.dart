import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:submersion/core/providers/provider.dart';

/// Stops on the library's thumbnail size slider, smallest to largest
/// (issue #3297).
const int kMediaThumbnailSteps = 7;

/// No step draws a thumbnail smaller than this, in logical pixels.
const double kMediaThumbnailMinExtent = 64;

/// Gap between thumbnails, across and down, in every library grid.
const double kMediaThumbnailGap = 4;

/// The widest horizontal padding a library grid puts around its thumbnails,
/// both sides together. The grouped list pads each side by half of it; the
/// flat grid pads by less.
const double kMediaThumbnailMaxInset = 16;

/// The largest step: two across, each thumbnail half the pane.
const int kMediaThumbnailMinColumns = 2;

/// The most columns [paneWidth] holds with thumbnails at
/// [kMediaThumbnailMinExtent] or more, once the padding and the gaps
/// between them are taken off: n columns need n tiles and n - 1 gaps.
int mediaThumbnailMaxColumns(double paneWidth) => math.max(
  kMediaThumbnailMinColumns,
  ((paneWidth - kMediaThumbnailMaxInset + kMediaThumbnailGap) /
          (kMediaThumbnailMinExtent + kMediaThumbnailGap))
      .floor(),
);

/// How many thumbnails [step] puts across a pane [paneWidth] wide.
///
/// The steps run from [kMediaThumbnailMinExtent] to half the pane in equal
/// ratios, not equal pixel amounts, so each one looks like the same change:
/// 17, 13, 9, 6, 4, 3 and 2 across at 1200. A pane narrower than about 556
/// has fewer than seven whole column counts in that range, so neighbouring
/// steps can share one there.
int mediaThumbnailColumnsForStep(int step, double paneWidth) {
  final largest = paneWidth / kMediaThumbnailMinColumns;
  final maxColumns = mediaThumbnailMaxColumns(paneWidth);
  if (largest <= kMediaThumbnailMinExtent) return maxColumns;
  final fraction =
      step.clamp(0, kMediaThumbnailSteps - 1) / (kMediaThumbnailSteps - 1);
  final extent =
      kMediaThumbnailMinExtent *
      math.pow(largest / kMediaThumbnailMinExtent, fraction);
  return (paneWidth / extent).round().clamp(
    kMediaThumbnailMinColumns,
    maxColumns,
  );
}

/// The size to resolve and decode a thumbnail at when [columns] of them
/// share [paneWidth].
///
/// One of three sizes rather than the exact extent: every change of target
/// re-resolves the tile, and a window being dragged wider would otherwise
/// do that on each frame. 200 is what the fixed 140px grid always used.
///
/// 800 is a memory ceiling, not a match for the largest tile. Past 800
/// logical px a thumbnail is drawn from the 800 decode scaled up, which
/// only happens two across on panes wider than about 1600, and looks a
/// little soft there. A larger step would hold four times the pixels per
/// tile (a 1600 decode at 2x is about 40 MB a tile) for the few widest
/// desktop panes.
///
/// This is an upper bound on the decode, not a promise of pixels. A photo
/// linked from a local file is drawn from its cached thumbnail, 512px on
/// its longest edge, at every size here (issue #3337); a decode is never
/// scaled up, so the larger targets cost such a tile nothing more.
Size mediaThumbnailDecodeTarget(double paneWidth, int columns) {
  final extent = paneWidth / columns;
  final side = extent <= 200
      ? 200.0
      : extent <= 400
      ? 400.0
      : 800.0;
  return Size.square(side);
}

/// The library's thumbnail size: the slider stop, and the column count it
/// came to at the width it was chosen at.
class MediaThumbnailScale {
  const MediaThumbnailScale({
    this.step = (kMediaThumbnailSteps - 1) ~/ 2,
    this.columns,
  });

  /// The slider stop, 0 (smallest) to [kMediaThumbnailSteps] - 1.
  final int step;

  /// The count being held, so that resizing the window scales the
  /// thumbnails instead of changing how many are across. Null until the
  /// pane has been measured since [step] was last chosen.
  final int? columns;

  /// How many thumbnails to put across a pane [paneWidth] wide. A held
  /// count gives way only where it would take thumbnails under
  /// [kMediaThumbnailMinExtent].
  int columnsAt(double paneWidth) =>
      (columns ?? mediaThumbnailColumnsForStep(step, paneWidth)).clamp(
        kMediaThumbnailMinColumns,
        mediaThumbnailMaxColumns(paneWidth),
      );

  MediaThumbnailScale copyWith({int? step, int? columns}) =>
      MediaThumbnailScale(
        step: step ?? this.step,
        columns: columns ?? this.columns,
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

  /// Moves the slider. The count held for the old step is dropped, so the
  /// new one is worked out at the pane's current width.
  void setStep(int step) {
    state = MediaThumbnailScale(step: step.clamp(0, kMediaThumbnailSteps - 1));
  }

  /// Moves [delta] stops along the slider, stopping at either end. At an
  /// end nothing changes, so the count being held is kept.
  void stepBy(int delta) {
    final next = (state.step + delta).clamp(0, kMediaThumbnailSteps - 1);
    if (next != state.step) setStep(next);
  }

  /// Holds [columns] for the current step. A count already held stays, which
  /// is what keeps it through a resize.
  void hold(int columns) {
    if (state.columns != null) return;
    state = state.copyWith(columns: columns);
  }
}
