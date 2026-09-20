import 'dart:math' as math;

import 'package:flutter/painting.dart';

/// The story band's two heights, computed rather than hardcoded.
///
/// A `SliverPersistentHeaderDelegate` must report both extents before layout
/// runs, which is the one thing the day header's `PinnedHeaderSliver` was
/// protecting it from: that sliver sizes itself, so scaled accessibility text
/// grew the band instead of being clipped. Deriving both extents from the
/// active [TextScaler] preserves that property inside a fixed-extent sliver.
class TripStoryBandExtents {
  /// Docked height at default text scale. Comfortably clears the panel's two
  /// lines, so it only has to grow above roughly 2.3x scale.
  static const double dockedFloor = 96;

  /// Expanded height at default text scale.
  static const double expandedFloor = 260;

  /// Travel between the two states. Also the minimum, so there is always room
  /// to morph no matter how tall the docked band grows.
  static const double expandedHeadroom = 100;

  /// Title line (titleMedium, 16px) and subtitle (bodySmall, 12px) with their
  /// line-height factors, plus the band's vertical padding.
  static const double _titleFontSize = 16;
  static const double _subtitleFontSize = 12;
  static const double _titleLineFactor = 1.25;
  static const double _subtitleLineFactor = 1.33;
  static const double _verticalPadding = 12;

  /// Day badge minimum, which floors the panel when the text is tiny.
  static const double _badgeMinimum = 28;

  final double docked;
  final double expanded;

  const TripStoryBandExtents({required this.docked, required this.expanded});

  factory TripStoryBandExtents.forScaler(TextScaler scaler) {
    final lines =
        scaler.scale(_titleFontSize) * _titleLineFactor +
        scaler.scale(_subtitleFontSize) * _subtitleLineFactor;
    final panel = math.max(_badgeMinimum, lines) + _verticalPadding;
    final docked = math.max(dockedFloor, panel);
    return TripStoryBandExtents(
      docked: docked,
      expanded: math.max(expandedFloor, docked + expandedHeadroom),
    );
  }
}
