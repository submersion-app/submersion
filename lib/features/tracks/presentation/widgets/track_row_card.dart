import 'package:flutter/material.dart';

/// Wraps one track row (either kind) in the same card shape the dive list
/// uses for its own rows (`dive_list_page.dart`): rounded corners and a
/// background fill while [highlighted] (issue #4024).
///
/// Only a vertical margin, not the dive list's 16px horizontal one: a track
/// row's last line already packs a dive-link chip and the kind badge onto
/// one line (#3749), and claiming 32px of width back from that budget
/// squeezed the chip into an ellipsis on a narrow phone in German (CI
/// catching exactly the #2692 hazard that line's own comment warns about).
/// `dive_list_page.dart`'s row has no equivalent last line this tight.
///
/// [child]'s `ListTile` keeps its own `onTap`, and with it the tap's cursor,
/// focus and button semantics; this card only gives its ink the card's shape.
/// The tile's `selected` stays the live split-layout pick alone: Material
/// reads it as "currently picked", which the row merely last opened is not,
/// and [highlighted]'s fill already marks both.
class TrackRowCard extends StatelessWidget {
  const TrackRowCard({
    super.key,
    required this.highlighted,
    required this.child,
  });

  /// Selected in the split layout's map pane, or the row last opened in
  /// either layout: the row the diver is looking at or just came back from.
  final bool highlighted;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: highlighted
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
          : null,
      child: ListTileTheme.merge(
        shape:
            theme.cardTheme.shape ??
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: child,
      ),
    );
  }
}
