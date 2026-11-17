import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:submersion/shared/widgets/profile_photo/profile_avatar.dart';

/// The outline a [DiveCenterAvatar] draws in. Each place a center appears
/// keeps the shape its store icon had before logos (issue #4460).
enum DiveCenterAvatarShape { circle, roundedSquare }

/// A dive center's logo, or the store icon when it has none.
///
/// The logo is the 512x512 JPEG the profile photo codec stores, decoded at
/// the size drawn. Pass the entity's own [logo] instance: image caching is
/// keyed by the byte list's identity, so a copy would re-decode every frame.
class DiveCenterAvatar extends StatelessWidget {
  const DiveCenterAvatar({
    super.key,
    required this.logo,
    this.radius = 20,
    this.shape = DiveCenterAvatarShape.circle,
    this.cornerRadius = 8,
    this.backgroundColor,
    this.iconColor,
    this.iconSize,
  });

  final Uint8List? logo;

  /// Half the side: the drawn size is `radius * 2` in either shape.
  final double radius;
  final DiveCenterAvatarShape shape;

  /// Corner radius of the [DiveCenterAvatarShape.roundedSquare] outline.
  final double cornerRadius;

  /// Background behind the store icon; defaults to primaryContainer.
  final Color? backgroundColor;

  /// Store icon colour; defaults to onPrimaryContainer.
  final Color? iconColor;

  /// Store icon size; defaults to [radius].
  final double? iconSize;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bytes = logo;
    final background = backgroundColor ?? colors.primaryContainer;
    final icon = Icon(
      Icons.store,
      color: iconColor ?? colors.onPrimaryContainer,
      size: iconSize ?? radius,
    );

    final side = radius * 2;
    final circle = shape == DiveCenterAvatarShape.circle;
    final borderRadius = BorderRadius.circular(cornerRadius);
    final Widget iconOnly = circle
        ? CircleAvatar(radius: radius, backgroundColor: background, child: icon)
        : Container(
            width: side,
            height: side,
            decoration: BoxDecoration(
              color: background,
              borderRadius: borderRadius,
            ),
            child: icon,
          );
    if (bytes == null) return iconOnly;

    // Decoded at the drawn size, as ProfileAvatar does: a bare MemoryImage
    // holds the full 512 px bitmap for every logo in a long list.
    final decodeSize = storedAvatarDecodeSize(context, side);
    final image = Image(
      image: ResizeImage(
        MemoryImage(bytes),
        width: decodeSize,
        height: decodeSize,
      ),
      width: side,
      height: side,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      // The name beside it already says which center this is.
      excludeFromSemantics: true,
      // Bytes that will not decode show the store icon in either shape, not
      // a blank or a debug error box.
      errorBuilder: (_, _, _) => iconOnly,
    );
    return circle
        ? ClipOval(child: image)
        : ClipRRect(borderRadius: borderRadius, child: image);
  }
}

/// What sits inside a dive center map marker's coloured circle: the logo,
/// sized by the caller to leave a band of the marker's rating (or selection)
/// colour showing around it, or with none the bare store icon the markers
/// always drew, so a center without a logo looks exactly as it did (#4460).
class DiveCenterMarkerGlyph extends StatelessWidget {
  const DiveCenterMarkerGlyph({
    super.key,
    required this.logo,
    required this.radius,
    required this.iconColor,
    required this.iconSize,
  });

  /// The [radius] for a marker [markerSize] wide: inside its 2 px border,
  /// less a 4 px band of the marker's colour, so the rating stays readable
  /// around a logo.
  static double radiusFor(double markerSize) =>
      markerSize / 2 - _markerBorder - _ratingBand;

  static const _markerBorder = 2.0;
  static const _ratingBand = 4.0;

  final Uint8List? logo;

  /// Radius of the logo circle; [radiusFor] gives it from the marker size.
  final double radius;
  final Color iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final bytes = logo;
    if (bytes == null) {
      return Icon(Icons.store, size: iconSize, color: iconColor);
    }
    // The marker's colour and size reach the avatar too, so a logo that will
    // not decode falls back to the same icon a center without one shows.
    return DiveCenterAvatar(
      logo: bytes,
      radius: radius,
      backgroundColor: Colors.transparent,
      iconColor: iconColor,
      iconSize: iconSize,
    );
  }
}
