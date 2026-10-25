import 'package:flutter/material.dart';

/// A track row's title line: the title on one ellipsised line and, when
/// given, the kind badge right after it (dive-list parity: the badge sits
/// next to the title the way `DiveModeBadge` does). The title takes the
/// width the badge leaves, so a long site name or file name cannot push the
/// badge off the row.
///
/// Shared by `GpsTrackListTile` and `NavTrackListRow`, the two kinds of row
/// one mixed Tracks list shows, so their title lines cannot drift apart.
class TrackTitleRow extends StatelessWidget {
  const TrackTitleRow({super.key, required this.title, this.badge});

  final String title;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final text = Text(title, overflow: TextOverflow.ellipsis, maxLines: 1);
    final badge = this.badge;
    if (badge == null) return text;
    return Row(
      children: [
        Expanded(child: text),
        const SizedBox(width: 8),
        badge,
      ],
    );
  }
}
