import 'dart:typed_data';

import 'package:flutter/material.dart';

/// One avatar for divers and buddies: the stored photo when there is one,
/// their initials otherwise.
///
/// Replaces 13 hand-rolled CircleAvatar sites that each re-implemented the
/// initials fallback, two of which had drifted into disagreeing about how a
/// photo is even loaded (one used FileImage, the other AssetImage on the same
/// filesystem path).
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.photo,
    required this.initials,
    this.radius = 20,
    this.backgroundColor,
    this.foregroundColor,
    this.ringColor,
    this.textStyle,
  });

  /// The stored 512x512 square JPEG, or null to show [initials].
  ///
  /// Pass the SAME Uint8List instance the repository handed you. MemoryImage
  /// equality is identity-based on the byte list and that is what keys
  /// Flutter's image cache, so a defensive copy would mint a fresh cache key
  /// on every rebuild and re-decode every avatar on every frame.
  final Uint8List? photo;

  final String initials;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  /// Draws a coloured ring around the avatar (the buddy list uses this for
  /// the usual-role indicator).
  final Color? ringColor;

  /// Overrides the initials text style. Two sites render initials at 36pt.
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bytes = photo;
    final resolvedForeground =
        foregroundColor ?? theme.colorScheme.onPrimaryContainer;

    // Decode at the size actually drawn. Flutter decodes to the image's
    // INTRINSIC size, so a bare MemoryImage on a 512x512 JPEG holds about 1 MB
    // of bitmap for an avatar drawn at 40 logical pixels; a list of 200
    // buddies would hold roughly 200 MB.
    final devicePixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    // `target` is an int, not a num: Dart special-cases clamp so the result is
    // int when the receiver and both bounds are int, which .round() and the
    // literals satisfy. No toInt() is needed to satisfy ResizeImage's int?.
    final int target = (radius * 2 * devicePixelRatio).round().clamp(1, 512);

    final avatar = CircleAvatar(
      radius: ringColor == null ? radius : radius - 2,
      backgroundColor: backgroundColor ?? theme.colorScheme.primaryContainer,
      foregroundColor: resolvedForeground,
      backgroundImage: bytes == null
          ? null
          : ResizeImage(MemoryImage(bytes), width: target, height: target),
      child: bytes == null
          ? Text(
              initials,
              style:
                  textStyle ??
                  TextStyle(
                    color: resolvedForeground,
                    fontWeight: FontWeight.bold,
                  ),
            )
          : null,
    );

    if (ringColor == null) return avatar;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: ringColor!, width: 2),
      ),
      child: avatar,
    );
  }
}
