import 'package:flutter/material.dart';

/// A track row's last line and, when given, the kind badge pinned to its
/// right edge: the dive link on an underwater row, the detail line on a GPS
/// row. Which dive a track belongs to and what kind of track it is read as
/// one line that way (#3749), and the title above keeps the full width. The
/// line takes the width the badge leaves, so long content cannot push the
/// badge off the row.
///
/// Shared by `GpsTrackListTile` and `NavTrackListRow`, the two kinds of row
/// one mixed Tracks list shows, so their badge placement cannot drift apart.
class TrackBadgeLine extends StatelessWidget {
  const TrackBadgeLine({super.key, required this.child, this.badge});

  final Widget child;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final badge = this.badge;
    if (badge == null) return child;
    return Row(
      children: [
        Expanded(child: child),
        const SizedBox(width: 8),
        badge,
      ],
    );
  }
}
