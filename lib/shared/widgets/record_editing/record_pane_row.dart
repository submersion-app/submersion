import 'package:flutter/material.dart';

/// Below this window width a record page's locked top bar has no room for
/// History beside the lock, so History moves into its menu (issue #4527).
const double kRecordCompactBarWidth = 600;

/// A list pane's header row (issue #4527): the [locked] row, and while the
/// record is unlocked the [unlocked] row (Cancel, the title, the menu and
/// Save) laid over it. The locked row keeps its place, unseen and not
/// tappable, so the pane under the header does not move as it locks and
/// unlocks.
class RecordPaneRow extends StatelessWidget {
  const RecordPaneRow({super.key, required this.locked, this.unlocked});

  final Widget locked;

  /// The row while unlocked; null while locked.
  final Widget? unlocked;

  @override
  Widget build(BuildContext context) {
    final unlocked = this.unlocked;
    if (unlocked == null) return locked;
    return Stack(
      children: [
        Visibility(
          visible: false,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: locked,
        ),
        Positioned.fill(child: unlocked),
      ],
    );
  }
}
