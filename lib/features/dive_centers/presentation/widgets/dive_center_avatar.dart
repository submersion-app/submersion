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

    if (shape == DiveCenterAvatarShape.circle) {
      if (bytes != null) {
        return ProfileAvatar(
          photo: bytes,
          initials: '',
          radius: radius,
          backgroundColor: background,
        );
      }
      return CircleAvatar(
        radius: radius,
        backgroundColor: background,
        child: icon,
      );
    }

    final side = radius * 2;
    final borderRadius = BorderRadius.circular(cornerRadius);
    if (bytes == null) {
      return Container(
        width: side,
        height: side,
        decoration: BoxDecoration(
          color: background,
          borderRadius: borderRadius,
        ),
        child: icon,
      );
    }
    // Decode at the drawn size, as ProfileAvatar does: a bare MemoryImage
    // holds the full 512 px bitmap for every logo in a long list.
    final devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final int target = (side * devicePixelRatio).round().clamp(1, 512);
    return ClipRRect(
      borderRadius: borderRadius,
      child: Image(
        image: ResizeImage(MemoryImage(bytes), width: target, height: target),
        width: side,
        height: side,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      ),
    );
  }
}
