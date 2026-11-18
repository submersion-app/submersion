import 'package:flutter/material.dart';

import 'package:submersion/features/species_id/domain/services/track_labels.dart';

/// Where one label's parts sit over the video: a dot on the animal, and,
/// for a named one, a pill above it joined by a thin line (issue #4675).
class TrackLabelGeometry {
  const TrackLabelGeometry({
    required this.dot,
    required this.pillCentre,
    required this.pillBelow,
  });

  /// The middle of the animal's box, on screen.
  final Offset dot;

  /// Where the pill is centred, on screen.
  final Offset pillCentre;

  /// The pill went below the animal: above it there was no room.
  final bool pillBelow;

  static const double pillHeight = 26;
  static const double gap = 10;

  /// [box] is the animal's box on screen; [video] the rect the video is
  /// drawn in.
  factory TrackLabelGeometry.of(Rect box, Rect video) {
    final dot = box.center;
    final above = box.top - gap - pillHeight / 2;
    final below = above - pillHeight / 2 < video.top;
    var centreY = below ? box.bottom + gap + pillHeight / 2 : above;
    // A fish filling the frame's height has room neither above nor below:
    // the pill then sits just inside the video's bottom edge.
    if (centreY + pillHeight / 2 > video.bottom) {
      centreY = video.bottom - pillHeight / 2;
    }
    return TrackLabelGeometry(
      dot: dot,
      pillCentre: Offset(dot.dx, centreY),
      pillBelow: below,
    );
  }
}

/// The plain dot on an animal.
class TrackDot extends StatelessWidget {
  const TrackDot({super.key});

  static const double size = 12;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.black54, width: 2),
      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 3)],
    ),
  );
}

/// The thin line from a pill to its dot.
class TrackLine extends StatelessWidget {
  const TrackLine({super.key});

  @override
  Widget build(BuildContext context) => Container(
    width: 1.5,
    decoration: const BoxDecoration(
      color: Colors.white,
      boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 2)],
    ),
  );
}

/// The rounded name pill: outlined for the app's name, filled for the
/// species the diver tagged.
class TrackPill extends StatelessWidget {
  const TrackPill({super.key, required this.name, required this.kind});

  final String name;
  final TrackLabelKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final filled = kind == TrackLabelKind.accepted;
    return Container(
      height: TrackLabelGeometry.pillHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: filled ? scheme.primary : Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(TrackLabelGeometry.pillHeight / 2),
        border: Border.all(
          color: filled ? scheme.primary : Colors.white,
          width: 1.5,
        ),
      ),
      // As wide as the name, not the room the pill is given.
      child: Center(
        widthFactor: 1,
        child: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: filled ? scheme.onPrimary : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// A [side]-square box around [centre], for a touch target.
Rect touchTarget(Offset centre, {double side = 44}) =>
    Rect.fromCenter(center: centre, width: side, height: side);
