import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Renders a photographed certification card so the whole image stays visible.
///
/// The photo is contained rather than cropped, and a blurred, dimmed copy of
/// the same bytes fills whatever space the photo does not cover. That avoids
/// both losing the edges of a card to a cover crop and letterboxing it against
/// flat bars.
class CertificationCardPhoto extends StatelessWidget {
  /// Encoded image bytes for the photographed card.
  final Uint8List bytes;

  /// Optional widget pinned to the top-right corner, used for expiry status.
  final Widget? badge;

  /// Lines rendered in the scrim along the bottom edge, first line emphasised.
  ///
  /// An empty list suppresses the strip entirely.
  final List<String> infoLines;

  /// Corner radius of this photo; [borderRadius] unless a smaller rendering,
  /// such as a list thumbnail, needs a tighter corner.
  final double radius;

  /// Whether the photo casts a drop shadow. A thumbnail inside a list row
  /// turns it off, since a shadow sized for the e-card swamps a small image.
  final bool showShadow;

  /// Corner radius, matched to the generated card faces.
  static const double borderRadius = 16;

  /// Decode width for the blurred backdrop. Deliberately tiny: decoding small
  /// is cheaper than blurring a full-resolution image, and it yields a smoother
  /// result.
  static const int backdropCacheWidth = 64;

  /// Upper bound on the foreground decode width, so an oversized source image
  /// cannot blow past a sensible texture size.
  static const int maxPhotoCacheWidth = 4096;

  const CertificationCardPhoto({
    super.key,
    required this.bytes,
    this.badge,
    this.infoLines = const [],
    this.radius = borderRadius,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          // An unbounded width makes the decode size meaningless, so fall back
          // to the image's native resolution in that case.
          final photoCacheWidth = width.isFinite
              ? (width * devicePixelRatio).round().clamp(1, maxPhotoCacheWidth)
              : null;

          return Stack(
            fit: StackFit.expand,
            children: [
              _buildBackdrop(),
              Image.memory(
                bytes,
                fit: BoxFit.contain,
                cacheWidth: photoCacheWidth,
                // A reload hands over a fresh buffer (a new image key); keep
                // the last frame up while it decodes instead of blanking.
                gaplessPlayback: true,
              ),
              if (infoLines.isNotEmpty) _buildInfoStrip(),
              if (badge != null) Positioned(top: 12, right: 12, child: badge!),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBackdrop() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            cacheWidth: backdropCacheWidth,
            gaplessPlayback: true,
          ),
        ),
        ColoredBox(color: Colors.black.withValues(alpha: 0.35)),
      ],
    );
  }

  Widget _buildInfoStrip() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.75)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < infoLines.length; i++) ...[
              if (i > 0) const SizedBox(height: 2),
              Text(
                infoLines[i],
                style: TextStyle(
                  color: i == 0
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.85),
                  fontSize: i == 0 ? 15 : 12,
                  fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400,
                  letterSpacing: i == 0 ? 0.3 : 0.8,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
