import 'package:flutter/material.dart';

/// A track row's last line and, when given, the kind badge at its end: the
/// dive link on an underwater row, the detail line on a GPS row. Which dive
/// a track belongs to and what kind of track it is read as one line that way
/// (#3749), and the title above keeps the full width.
///
/// When the line and the badge do not both fit (a narrow phone, a long
/// locale such as German's "Tauchgang #412" beside "Unterwasser", large
/// text), the badge drops to the start of its own line below rather than
/// truncating either: the dive link is worth more whole than the badge is
/// on one line.
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
    // A Wrap sizes itself to its widest run, so without the full-width box
    // spaceBetween would have no free space to put between the two.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 4,
        children: [child, badge],
      ),
    );
  }
}
