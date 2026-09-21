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

  /// Fallbacks matching Material 3 titleMedium (16px, 1.50) and bodySmall
  /// (12px, 1.33), used only when a theme hands over a style with no explicit
  /// size or height. The real numbers come from the theme: guessing them is
  /// how this under-reserved 12px at 3x text and clipped the panel.
  static const double _titleFontSize = 16;
  static const double _subtitleFontSize = 12;
  static const double _titleLineFactor = 1.50;
  static const double _subtitleLineFactor = 1.33;
  static const double _verticalPadding = 12;

  /// Day badge minimum, which floors the panel when the text is tiny.
  static const double _badgeMinimum = 28;

  final double docked;
  final double expanded;

  const TripStoryBandExtents({required this.docked, required this.expanded});

  /// [title] and [subtitle] are the styles the docked panel actually renders
  /// with (titleMedium and bodySmall from the ambient theme). Pass them
  /// wherever a theme is in reach: a theme that changes either style moves the
  /// band with it instead of silently clipping the panel.
  factory TripStoryBandExtents.forScaler(
    TextScaler scaler, {
    TextStyle? title,
    TextStyle? subtitle,
  }) {
    double line(TextStyle? style, double fallbackSize, double fallbackFactor) {
      final size = style?.fontSize ?? fallbackSize;
      final factor = style?.height ?? fallbackFactor;
      return scaler.scale(size) * factor;
    }

    final lines =
        line(title, _titleFontSize, _titleLineFactor) +
        line(subtitle, _subtitleFontSize, _subtitleLineFactor);
    // Rounded up: text layout lands on whole pixels, so a height computed to
    // the fraction can sit a tenth of a pixel under what the panel actually
    // paints and overflow by that much.
    final panel = (math.max(_badgeMinimum, lines) + _verticalPadding)
        .ceilToDouble();
    final docked = math.max(dockedFloor, panel);
    return TripStoryBandExtents(
      docked: docked,
      expanded: math.max(expandedFloor, docked + expandedHeadroom),
    );
  }
}
